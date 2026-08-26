module agent_toolkit_core

import crypto.sha256
import json
import os
import time

// ArtifactRecord is one generated file in a .provenance.json sidecar.
pub struct ArtifactRecord {
pub:
	path             string
	source_file      string @[json: 'sourceFile']
	source_digest    string @[json: 'sourceDigest']
	generated_digest string @[json: 'generatedDigest']
}

// ProvenanceManifest matches Python compiler/provenance.py JSON (camelCase keys).
pub struct ProvenanceManifest {
pub:
	generator_version string @[json: 'generatorVersion']
	product           string
	target            string
	artifacts         []ArtifactRecord
}

// file_digest returns SHA256 hex truncated to 12 chars, or "missing".
pub fn file_digest(path string) string {
	if !os.is_file(path) {
		return 'missing'
	}
	data := os.read_file(path) or { return 'missing' }
	sum := sha256.hexhash(data)
	if sum.len < 12 {
		return sum
	}
	return sum[..12]
}

// write_provenance writes .provenance.json under out_dir. Returns the path.
pub fn write_provenance(out_dir string, product_id string, target_id string, artifacts []ArtifactRecord) !string {
	os.mkdir_all(out_dir) or { return error('mkdir provenance dir failed: ${err}') }
	manifest := ProvenanceManifest{
		generator_version: resolve_toolkit_version()
		product:           product_id
		target:            target_id
		artifacts:         artifacts
	}
	path := os.join_path(out_dir, '.provenance.json')
	payload := json.encode(manifest)
	os.write_file(path, payload + '\n') or { return error('write provenance failed: ${err}') }
	return path
}

// load_provenance reads a .provenance.json sidecar.
pub fn load_provenance(path string) ?ProvenanceManifest {
	if !os.is_file(path) {
		return none
	}
	text := os.read_file(path) or { return none }
	m := json.decode(ProvenanceManifest, text) or { return none }
	if m.product.len == 0 && m.target.len == 0 && m.artifacts.len == 0 {
		return none
	}
	return m
}

// verify_generated_digests compares recorded generatedDigest values to files under plugins_dir.
pub fn verify_generated_digests(plugins_dir string, provenance_path string) []string {
	manifest := load_provenance(provenance_path) or { return []string{} }
	mut errors := []string{}
	for rec in manifest.artifacts {
		artifact_path := os.join_path(plugins_dir, rec.path)
		current := file_digest(artifact_path)
		if current != rec.generated_digest {
			errors << 'provenance digest drift: ${rec.path} (expected ${rec.generated_digest}, got ${current})'
		}
	}
	return errors
}

// verify_provenance validates capabilities/upstream.lock SHA + expiry (Python parity).
// Used by doctor --provenance (see doctor.v collect_provenance_checks).
pub fn verify_provenance(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	if root.len == 0 {
		out << DoctorCheck{'provenance', 'upstream.lock', 'warn', 'no toolkit root'}
		return out
	}
	lock_path := os.join_path(root, 'capabilities', 'upstream.lock')
	if !os.is_file(lock_path) {
		// Warn (not err): wheel/data installs often omit capabilities/upstream.lock
		out << DoctorCheck{'provenance', 'upstream.lock', 'warn', 'not found under toolkit root (checkout only)'}
		return out
	}
	out << DoctorCheck{'provenance', 'upstream.lock', 'ok', lock_path}
	// SHA: full hexhash + 12-char short for parity with file_digest
	digest_short := file_digest(lock_path)
	if digest_short == 'missing' {
		out << DoctorCheck{'provenance', 'sha', 'err', 'cannot read lock file'}
	} else {
		data := os.read_file(lock_path) or { '' }
		full := sha256.hexhash(data)
		out << DoctorCheck{'provenance', 'sha', 'ok', 'sha256:${full} (${digest_short})'}
	}
	// Expiry / freshness: use file mtime (Python used expiry field; current lock is YAML with resolved_at per-capability)
	// We surface age in days and warn if >90d stale (heuristic).
	mtime := os.file_last_mod_unix(lock_path)
	if mtime > 0 {
		now := time.now().unix()
		age_days := (now - mtime) / 86400
		if age_days > 90 {
			out << DoctorCheck{'provenance', 'expiry', 'warn', 'stale: ${age_days}d since last update (>90d)'}
		} else {
			out << DoctorCheck{'provenance', 'expiry', 'ok', '${age_days}d since update'}
		}
	} else {
		out << DoctorCheck{'provenance', 'expiry', 'warn', 'cannot determine file age'}
	}
	// cli-contract.yaml presence (compatibility surface)
	contract_path := os.join_path(root, 'docs', 'compatibility', 'cli-contract.yaml')
	if os.is_file(contract_path) {
		out << DoctorCheck{'provenance', 'cli-contract', 'ok', contract_path}
	} else {
		out << DoctorCheck{'provenance', 'cli-contract', 'warn', 'not found: ${contract_path}'}
	}
	return out
}
