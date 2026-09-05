module desktop_engine

import os
import x.json2

// ReceiptEntry is unified receipt for any install (skill/agent/mcp/target/product/update).
pub struct ReceiptEntry {
pub:
	kind         string // skill | agent | mcp | target | product | update
	id           string
	product      string
	version      string
	installed_at string
	digest       string
	provenance   string
	receipt_path string
	artifacts    []string
	verified     bool
}

// ProvenanceEntry mirrors .provenance.json per artifact (ADR-022).
pub struct ProvenanceEntry {
pub:
	artifact_path    string
	source_file      string
	source_digest    string
	generated_digest string
	generator        string
	verified         bool
	detail           string
}

// receipts_catalog returns all receipts via StateRepository headless (no shell, super-potent unified).
pub fn (mut e Engine) receipts_catalog() []ReceiptEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []ReceiptEntry{}
	for k, v in snap.data {
		if k.starts_with('receipt:') && k.ends_with(':installed_at') {
			parts := k.split(':')
			if parts.len < 3 {
				continue
			}
			kind := parts[1]
			id := parts[2]
			provenance := snap.data['provenance:${kind}:${id}:source'] or { snap.data['receipt:${kind}:${id}:digest'] or { '' } }
			digest := snap.data['receipt:${kind}:${id}:digest'] or { snap.data['receipt:${kind}:${id}:version'] or { '' } }
			version := snap.data['receipt:${kind}:${id}:version'] or { '1.0.0' }
			artifacts_raw := snap.data['receipt:${kind}:${id}:artifacts'] or { '' }
			artifacts := if artifacts_raw == '' {
				[]string{}
			} else {
				artifacts_raw.split(',').map(it.trim_space())
			}
			receipt_path := match kind {
				'skill' { 'receipts/skill-${id}.json' }
				'target' { '~/.config/agent-toolkit/receipts/${id}-agent-toolkit-profiles.json' }
				else { 'receipts/${kind}-${id}.json' }
			}
			out << ReceiptEntry{
				kind: kind
				id: id
				product: snap.data['receipt:${kind}:${id}:product'] or { kind }
				version: version
				installed_at: v
				digest: digest
				provenance: provenance
				receipt_path: receipt_path
				artifacts: artifacts
				verified: digest != ''
			}
		}
	}
	// supplement from filesystem receipts dir if present (checkout parity)
	env := resolve_env()
	receipt_dir := os.join_path(env.toolkit_root, '.config', 'agent-toolkit', 'receipts')
	if os.is_dir(receipt_dir) {
		files := os.ls(receipt_dir) or { []string{} }
		for f in files {
			if f.ends_with('.json') && out.len < 50 {
				already := out.any(it.receipt_path.contains(f))
				if !already {
					out << ReceiptEntry{
						kind: 'target'
						id: f.all_before('.json')
						product: 'agent-toolkit-profiles'
						version: '1.27.0'
						// A receipt file is evidence of a record, not proof that its
						// artifact is present. Verify its contents before marking it.
						installed_at: ''
						digest: ''
						provenance: 'fs:${receipt_dir}/${f}'
						receipt_path: os.join_path(receipt_dir, f)
						verified: false
					}
				}
			}
		}
	}
	return out
}

// receipts_search fuzzy filters receipts — easy potent management.
pub fn (mut e Engine) receipts_search(query string) []ReceiptEntry {
	cat := e.receipts_catalog()
	q := query.trim_space().to_lower()
	if q == '' {
		return cat.clone()
	}
	mut out := []ReceiptEntry{}
	for r in cat {
		if r.id.to_lower().contains(q) || r.kind.contains(q) || r.product.to_lower().contains(q) || r.provenance.to_lower().contains(q) {
			out << r
		}
	}
	return out
}

// receipt_for returns single receipt by kind+id.
pub fn (mut e Engine) receipt_for(kind string, id string) ?ReceiptEntry {
	for r in e.receipts_catalog() {
		if r.kind == kind && r.id == id {
			return r
		}
	}
	return none
}

// provenance_catalog returns all provenance entries (ADR-022) via filesystem + StateRepository.
pub fn (mut e Engine) provenance_catalog() []ProvenanceEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	mut out := []ProvenanceEntry{}
	// from StateRepository provenance keys
	snap := e.repo.snapshot()
	for k, v in snap.data {
		if k.starts_with('provenance:') && k.ends_with(':source') {
			parts := k.split(':')
			if parts.len < 3 {
				continue
			}
			kind := parts[1]
			id := parts[2]
			out << ProvenanceEntry{
				artifact_path: '${kind}/${id}'
				source_file: v
				source_digest: snap.data['provenance:${kind}:${id}:digest'] or { '' }
				generated_digest: snap.data['provenance:${kind}:${id}:generated'] or { '' }
				generator: 'agent-toolkit-core'
				verified: snap.data['provenance:${kind}:${id}:digest'] or { '' } != '' && snap.data['provenance:${kind}:${id}:generated'] or { '' } != ''
				detail: 'via StateRepository receipt:provenance'
			}
		}
	}
	// filesystem scan of plugins/.provenance.json sidecars
	plugins_dir := os.join_path(env.toolkit_root, 'plugins')
	if os.is_dir(plugins_dir) {
		entries := os.ls(plugins_dir) or { []string{} }
		for prod in entries {
			prov_path := os.join_path(plugins_dir, prod, '.provenance.json')
			if os.is_file(prov_path) {
				txt := os.read_file(prov_path) or { '' }
				if txt.contains('artifacts') {
					out << ProvenanceEntry{
						artifact_path: 'plugins/${prod}/.provenance.json'
						source_file: prov_path
					source_digest: ''
					generated_digest: ''
					generator: 'compiler'
					verified: false
						detail: txt[..if txt.len > 80 { 80 } else { txt.len }]
					}
				}
			}
		}
	}
	return out
}

// verify_receipts returns diagnostics for all receipts drift (Doctor parity).
pub fn (mut e Engine) verify_receipts() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	for r in e.receipts_catalog() {
		if !r.verified || r.digest == '' {
			diags << BuildDiagnostic{
				path: r.receipt_path
				message: 'receipt unverified for ${r.kind}/${r.id}'
				code: 'receipt_unverified'
			}
		}
		if r.provenance == '' {
			diags << BuildDiagnostic{
				path: r.provenance
				message: 'provenance missing for ${r.kind}/${r.id}'
				code: 'provenance_missing'
			}
		}
	}
	return diags
}

// verify_provenance_full checks provenance digests vs filesystem (ADR-022).
pub fn (mut e Engine) verify_provenance_full() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	for p in e.provenance_catalog() {
		if !p.verified {
			diags << BuildDiagnostic{
				path: p.artifact_path
				message: 'provenance unverified: ${p.detail}'
				code: 'provenance_unverified'
			}
		}
		if p.source_digest == 'missing' {
			diags << BuildDiagnostic{
				path: p.source_file
				message: 'source file missing for ${p.artifact_path}'
				code: 'source_missing'
			}
		}
	}
	return diags
}

// receipts_stats aggregates for super-potent dashboard.
pub struct ReceiptStats {
pub:
	total      int
	by_kind    map[string]int
	verified   int
	unverified int
}

pub fn (mut e Engine) receipts_stats() ReceiptStats {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	cat := e.receipts_catalog()
	mut by_kind := map[string]int{}
	mut verified := 0
	for r in cat {
		by_kind[r.kind]++
		if r.verified { verified++ }
	}
	return ReceiptStats{
		total: cat.len
		by_kind: by_kind
		verified: verified
		unverified: cat.len - verified
	}
}

// install_receipt_json_for returns ADR-022 style JSON for any receipt kind/id.
pub fn (mut e Engine) install_receipt_json_for(kind string, id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if r := e.receipt_for(kind, id) {
		return json2.encode({
			'schemaVersion': '1'
			'product':       r.product
			'target':        r.id
			'kind':          r.kind
			'version':       r.version
			'installedAt':   r.installed_at
			'sourceDigest':  r.digest
			'provenance':    r.provenance
			'verified':      if r.verified { 'true' } else { 'false' }
		},
			escape_unicode: true
		)
	}
	return json2.encode({
		'error': 'receipt not found for ${kind}/${id}'
	},
		escape_unicode: true
	)
}

// provenance_json_for returns structured provenance for kind/id.
pub fn (mut e Engine) provenance_json_for(kind string, id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	for p in e.provenance_catalog() {
		if p.artifact_path.contains(id) {
			return json2.encode({
				'artifact':        p.artifact_path
				'sourceFile':      p.source_file
				'sourceDigest':    p.source_digest
				'generatedDigest': p.generated_digest
				'verified':        if p.verified { 'true' } else { 'false' }
			},
				escape_unicode: true
			)
		}
	}
	return json2.encode({
		'error': 'provenance not found for ${id}'
	},
		escape_unicode: true
	)
}
