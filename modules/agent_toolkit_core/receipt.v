module agent_toolkit_core

import crypto.sha256
import json2
import os
import time

// profiles_product is the receipt product id used by the profile installer.
pub const profiles_product = 'agent-toolkit-profiles'

// receipt_schema_version is the only supported InstallReceipt schemaVersion (#511).
pub const receipt_schema_version = 1

// ArtifactEntry is one installed file recorded in an InstallReceipt.
pub struct ArtifactEntry {
pub:
	path      string
	digest    string
	ownership string // created | merged
}

// InstallReceipt matches Python installer/receipt.py JSON (camelCase keys).
pub struct InstallReceipt {
pub mut:
	schema_version      int @[json: 'schemaVersion']
	product             string
	target              string
	scope               string
	version             string
	installed_at        string @[json: 'installedAt']
	source_digest       string @[json: 'sourceDigest']
	artifacts           []ArtifactEntry
	config_patches_json string // raw JSON array; always round-tripped, default "[]"
	secrets             []string
}

// new_install_receipt creates a schemaVersion=1 receipt (secrets always empty).
pub fn new_install_receipt(product string, target string, scope string, version string, source_digest string) InstallReceipt {
	return InstallReceipt{
		schema_version: receipt_schema_version
		product: product
		target: target
		scope: scope
		version: version
		installed_at: ''
		source_digest: source_digest
		artifacts: []ArtifactEntry{}
		config_patches_json: '[]'
		secrets: []string{}
	}
}

// receipt_filename returns <target>-<product>.json.
pub fn receipt_filename(target string, product string) string {
	return '${target}-${product}.json'
}

// default_receipt_dir returns ~/.config/agent-toolkit/receipts.
pub fn default_receipt_dir() string {
	return new_fs().receipt_dir()
}

// parse_install_receipt parses receipt JSON (read-only; no filesystem writes).
// Refuses non-empty secrets and unknown ownership values. Validates schemaVersion >= 1.
pub fn parse_install_receipt(text string) !InstallReceipt {
	trimmed := text.trim_space()
	if trimmed.len == 0 {
		return error('empty receipt JSON')
	}
	mut r := json2.decode[InstallReceipt](trimmed) or { return error('receipt decode failed: ${err}') }
	if r.schema_version < 1 {
		r.schema_version = receipt_schema_version
	}
	if r.schema_version != receipt_schema_version {
		return error('unsupported receipt schemaVersion ${r.schema_version} (expected ${receipt_schema_version})')
	}
	if r.product.len == 0 || r.target.len == 0 {
		return error('receipt missing required product/target')
	}
	if r.scope.len == 0 {
		r.scope = 'project'
	}
	r.config_patches_json = extract_json_array_field(trimmed, 'configPatches') or { '[]' }
	if r.secrets.len > 0 {
		return error('receipt must not contain secrets')
	}
	r.secrets = []string{}
	for a in r.artifacts {
		if a.path.len == 0 {
			return error('artifact path must not be empty')
		}
		if a.ownership !in ['created', 'merged'] {
			return error("artifact ownership must be 'created' or 'merged' (got '${a.ownership}')")
		}
		if receipt_path_escapes(a.path) {
			return error('artifact path refused (path escape): ${a.path}')
		}
	}
	return r
}

// encode_install_receipt serializes a receipt to camelCase JSON (secrets always []).
pub fn encode_install_receipt(r InstallReceipt) string {
	wire := InstallReceiptWire{
		schema_version: r.schema_version
		product: r.product
		target: r.target
		scope: r.scope
		version: r.version
		installed_at: r.installed_at
		source_digest: r.source_digest
		artifacts: r.artifacts
		secrets: []string{}
	}
	mut body := json2.encode(wire, escape_unicode: true)
	patches := if r.config_patches_json.len > 0 { r.config_patches_json } else { '[]' }
	// Inject configPatches before secrets (wire struct omits raw patches field).
	needle := '"secrets"'
	if idx := body.index(needle) {
		body = body[..idx] + '"configPatches":' + patches + ',' + body[idx..]
	}
	return body
}

// save_install_receipt writes the receipt atomically under receipt_dir.
// Sets installed_at when empty. Returns the written path.
pub fn save_install_receipt(mut r InstallReceipt, receipt_dir string) !string {
	if r.secrets.len > 0 {
		return error('receipt must not contain secrets')
	}
	r.secrets = []string{}
	for a in r.artifacts {
		if receipt_path_escapes(a.path) {
			return error('artifact path refused (path escape): ${a.path}')
		}
	}
	if r.installed_at.len == 0 {
		r.installed_at = time.utc().format_rfc3339()
	}
	dir := if receipt_dir.len > 0 { receipt_dir } else { default_receipt_dir() }
	fs := new_fs()
	fs.ensure_dir(dir)!
	path := os.join_path(dir, receipt_filename(r.target, r.product))
	payload := encode_install_receipt(r)
	fs.write_atomic(path, payload + '\n')!
	return path
}

// profiles_source_digest mirrors Python tracking.source_digest.
pub fn profiles_source_digest(toolkit_root string) string {
	marker := os.join_path(toolkit_root, 'profiles')
	if os.is_dir(marker) {
		resolved := os.real_path(marker)
		sum := sha256.hexhash(resolved)
		if sum.len < 12 {
			return sum
		}
		return sum[..12]
	}
	return resolve_toolkit_version()
}

// InstallReceiptWire is encode-only (no config_patches_json field).
struct InstallReceiptWire {
	schema_version int @[json: 'schemaVersion']
	product        string
	target         string
	scope          string
	version        string
	installed_at   string @[json: 'installedAt']
	source_digest  string @[json: 'sourceDigest']
	artifacts      []ArtifactEntry
	secrets        []string
}

// load_install_receipt loads ~/.config/.../receipts/<target>-<product>.json (or receipt_dir).
pub fn load_install_receipt(target string, product string, receipt_dir string) ?InstallReceipt {
	dir := if receipt_dir.len > 0 { receipt_dir } else { default_receipt_dir() }
	path := os.join_path(dir, receipt_filename(target, product))
	if !os.is_file(path) {
		return none
	}
	text := os.read_file(path) or { return none }
	return parse_install_receipt(text) or { return none }
}

// list_install_receipts lists parsed receipts under receipt_dir (skip invalid).
pub fn list_install_receipts(receipt_dir string) []InstallReceipt {
	dir := if receipt_dir.len > 0 { receipt_dir } else { default_receipt_dir() }
	mut out := []InstallReceipt{}
	if !os.is_dir(dir) {
		return out
	}
	entries := os.ls(dir) or { return out }
	for e in entries {
		if !e.ends_with('.json') {
			continue
		}
		path := os.join_path(dir, e)
		if !os.is_file(path) {
			continue
		}
		text := os.read_file(path) or { continue }
		r := parse_install_receipt(text) or { continue }
		out << r
	}
	return out
}

// receipt_artifact_digest returns SHA256 hex truncated to 16 chars (Python tracking.file_digest).
pub fn receipt_artifact_digest(path string) string {
	if !os.is_file(path) {
		return 'missing'
	}
	data := os.read_file(path) or { return 'missing' }
	sum := sha256.hexhash(data)
	if sum.len < 16 {
		return sum
	}
	return sum[..16]
}

// receipt_path_escapes reports suspicious path forms that install/uninstall must refuse.
// Blocks NUL, and Windows/Unix relative escapes (`..` segments). Absolute paths are allowed
// (receipts store resolved home paths) but must not contain `..` after normalization.
pub fn receipt_path_escapes(path string) bool {
	if path.contains('\0') {
		return true
	}
	normalized := path.replace('\\', '/')
	parts := normalized.split('/')
	for p in parts {
		if p == '..' {
			return true
		}
	}
	return false
}

fn extract_json_array_field(text string, key string) ?string {
	needle := '"${key}"'
	mut i := text.index(needle) or { return none }
	i += needle.len
	for i < text.len && text[i].is_space() {
		i++
	}
	if i >= text.len || text[i] != `:` {
		return none
	}
	i++
	for i < text.len && text[i].is_space() {
		i++
	}
	if i >= text.len || text[i] != `[` {
		return none
	}
	start := i
	mut depth := 0
	for i < text.len {
		c := text[i]
		if c == `[` {
			depth++
		} else if c == `]` {
			depth--
			if depth == 0 {
				return text[start..i + 1]
			}
		}
		i++
	}
	return none
}
