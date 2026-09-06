module desktop_engine

import os
import x.json2
import crypto.sha256
import agent_toolkit_core

// ReceiptEntry is the Engine projection of a real install receipt (S7 evidence
// truth). A receipt exists only if the core installer wrote it under the user
// config authority; this Engine never invents receipt rows.
pub struct ReceiptEntry {
pub:
	kind         string // install
	id           string // install target
	product      string
	version      string
	installed_at string
	digest       string
	provenance   string
	receipt_path string
	artifacts    []string
	verified     bool
}

// ProvenanceEntry mirrors .provenance.json artifact records (ADR-022).
// source/generated digests come from the real manifest; verified means the
// recomputed SHA-256 of the artifact bytes matches the recorded digest.
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

// receipts_catalog returns only real install receipts recorded by the core
// installer under the user config authority
// ($XDG_CONFIG_HOME/agent-toolkit/receipts). A receipt is verified by
// recomputing each artifact digest from the artifact file on disk and comparing
// it to the digest recorded in the receipt. An empty directory yields an
// empty catalog; nothing is fabricated.
pub fn (mut e Engine) receipts_catalog() []ReceiptEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut out := []ReceiptEntry{}
	receipt_dir := agent_toolkit_core.default_receipt_dir()
	for r in agent_toolkit_core.list_install_receipts('') {
		mut verified := r.artifacts.len > 0
		mut artifacts := []string{}
		for a in r.artifacts {
			artifacts << a.path
			if agent_toolkit_core.receipt_artifact_digest(a.path) != a.digest {
				verified = false
			}
		}
		out << ReceiptEntry{
			kind: 'install'
			id: r.target
			product: r.product
			version: r.version
			installed_at: r.installed_at
			digest: r.source_digest
			provenance: ''
			receipt_path: os.join_path(receipt_dir, agent_toolkit_core.receipt_filename(r.target, r.product))
			artifacts: artifacts
			verified: verified
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

// receipt_for returns a single real receipt by kind+id.
pub fn (mut e Engine) receipt_for(kind string, id string) ?ReceiptEntry {
	for r in e.receipts_catalog() {
		if r.kind == kind && r.id == id {
			return r
		}
	}
	return none
}

// provenance_catalog returns real provenance records from the bundled
// plugins/<product>/.provenance.json manifests (ADR-022), read through the
// tier-aware data_* helpers. Each artifact record is verified by recomputing
// the SHA-256 of the artifact bytes and comparing it to the recorded
// generatedDigest. No manifest yields no entries; no fallback is fabricated.
pub fn (mut e Engine) provenance_catalog() []ProvenanceEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	mut out := []ProvenanceEntry{}
	if !data_dir_exists(env, 'plugins') {
		return out
	}
	prods := data_list_dir(env, 'plugins')
	for prod in prods {
		manifest_rel := 'plugins/${prod}/.provenance.json'
		if !data_file_exists(env, manifest_rel) {
			continue
		}
		txt := data_file_read(env, manifest_rel) or { continue }
		m := json2.decode[agent_toolkit_core.ProvenanceManifest](txt) or { continue }
		for rec in m.artifacts {
			artifact_rel := 'plugins/${rec.path}'
			mut verified := false
			mut detail := 'artifact missing from bundled data'
			if data_file_exists(env, artifact_rel) {
				content := data_file_read(env, artifact_rel) or { '' }
				if content != '' {
					sum := sha256.hexhash(content)
					short := if sum.len < 12 { sum } else { sum[..12] }
					verified = short == rec.generated_digest
					detail = if verified {
						'digest verified against artifact bytes'
					} else {
						'digest drift: expected ${rec.generated_digest}, got ${short}'
					}
				}
			}
			out << ProvenanceEntry{
				artifact_path: artifact_rel
				source_file: rec.source_file
				source_digest: rec.source_digest
				generated_digest: rec.generated_digest
				generator: m.generator_version
				verified: verified
				detail: detail
			}
		}
	}
	return out
}

// verify_receipts returns diagnostics for receipts whose artifact evidence does
// not check out (Doctor parity). Verified flags come from real digest
// recomputation; an unverified receipt is reported, never silently accepted.
pub fn (mut e Engine) verify_receipts() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	for r in e.receipts_catalog() {
		if !r.verified {
			diags << BuildDiagnostic{
				path: r.receipt_path
				message: 'receipt unverified for ${r.product}/${r.id} (artifact missing or digest drift)'
				code: 'receipt_unverified'
			}
		}
	}
	return diags
}

// verify_provenance_full checks provenance digests vs bundled bytes (ADR-022).
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

// install_receipt_json_for returns the real recorded receipt fields for
// kind/id, or an honest not-found payload. No receipt is synthesized.
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

// provenance_json_for returns structured provenance for an artifact path
// fragment, or an honest not-found payload.
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
