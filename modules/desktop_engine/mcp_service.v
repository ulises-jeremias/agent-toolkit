module desktop_engine

import os
import x.json2

// McpProvider mirrors mcp/templates — super-potent: provenance, receipts, health detail.
pub struct McpProvider {
pub:
	id              string
	name            string
	description     string
	enabled         bool
	health          string
	requires_docker bool
	template_path   string
	registry_path   string
	version         string
	provenance      string
}

// McpStats aggregates provider health.
pub struct McpStats {
pub mut:
	total        int
	healthy      int
	unconfigured int
	error        int
	enabled      int
}

// McpInstallPreview is dry-run diff for MCP.
pub struct McpInstallPreview {
pub:
	provider_id     string
	will_write      []string
	will_update     []string
	receipt_path    string
	provenance_path string
}

// mcp_catalog discovers providers from packaged mcp/templates/<id>/ files.
// A missing catalog is empty rather than a reason to invent a provider roster.
// Catalog discovery uses the tier-aware data_* helpers so embedded binaries
// resolve bundled templates the same way a checkout does.
pub fn (mut e Engine) mcp_catalog() []McpProvider {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	reg_dir_rel := 'mcp/templates'
	mut ids := []string{}
	if data_dir_exists(env, reg_dir_rel) {
		entries := data_list_dir(env, reg_dir_rel)
		for id in entries {
			template_rel := '${reg_dir_rel}/${id}/config.template.json'
			local_template_rel := '${reg_dir_rel}/${id}/config.local.template.json'
			if data_file_exists(env, template_rel) || data_file_exists(env, local_template_rel) {
				ids << id
			}
		}
	}
	ids.sort()
	mut out := []McpProvider{}
	snap := e.repo.snapshot()
	for id in ids {
		template_name := if data_file_exists(env, '${reg_dir_rel}/${id}/config.template.json') {
			'config.template.json'
		} else {
			'config.local.template.json'
		}
		enabled_str := snap.data['mcp:${id}:enabled'] or { 'false' }
		out << McpProvider{
			id: id
			name: id
			description: 'MCP ${id} — packaged template'
			enabled: enabled_str == 'true'
			health: e.mcp_health_detailed(id)
			requires_docker: id == 'github'
			template_path: '${reg_dir_rel}/${id}/${template_name}'
			registry_path: 'mcp/registry/${id}.yaml'
			version: ''
			provenance: '${reg_dir_rel}/${id}/${template_name}'
		}
	}
	return out
}

// mcp_catalog_search fuzzy filters MCP providers.
pub fn (mut e Engine) mcp_catalog_search(query string) []McpProvider {
	cat := e.mcp_catalog()
	q := query.trim_space().to_lower()
	if q == '' {
		return cat.clone()
	}
	mut out := []McpProvider{}
	for p in cat {
		if p.id.to_lower().contains(q) || p.name.to_lower().contains(q) || p.description.to_lower().contains(q) || p.health.contains(q) {
			out << p
		}
	}
	return out
}

pub fn (mut e Engine) mcp_health(provider_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			return p.health
		}
	}
	return 'unconfigured'
}

// mcp_health_detailed checks docker for github when enabled; disabled
// providers are honestly unconfigured rather than hardcoded to error.
pub fn (mut e Engine) mcp_health_detailed(provider_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	if 'mcp:${provider_id}:health' in snap.data {
		return snap.data['mcp:${provider_id}:health'] or { 'unconfigured' }
	}
	enabled := (snap.data['mcp:${provider_id}:enabled'] or { 'false' }) == 'true'
	if !enabled {
		return 'unconfigured'
	}
	if provider_id == 'github' {
		docker := os.find_abs_path_of_executable('docker') or { '' }
		if docker == '' {
			return 'warn'
		}
		return 'healthy'
	}
	// Enabled providers without a special probe are configured, not healthy:
	// health is a probe result, never a default for being enabled.
	return 'configured'
}

// mcp_stats returns super-potent aggregation.
pub fn (mut e Engine) mcp_stats() McpStats {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	cat := e.mcp_catalog()
	mut s := McpStats{ total: cat.len }
	for p in cat {
		if p.enabled { s.enabled++ }
		match p.health {
			'healthy' { s.healthy++ }
			'error' { s.error++ }
			else { s.unconfigured++ }
		}
	}
	return s
}

// mcp_validate performs real validation: the provider must exist in the
// packaged catalog, and any recorded configuration must parse as JSON.
pub fn (mut e Engine) mcp_validate(provider_id string) []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	if provider_id == '' {
		return [
			BuildDiagnostic{ path: 'mcp.json', message: 'provider id empty', code: 'missing_id' },
		]
	}
	mut known := false
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			known = true
			break
		}
	}
	if !known {
		return [
			BuildDiagnostic{ path: 'mcp/${provider_id}.json', message: 'provider not in packaged catalog', code: 'unknown_provider' },
		]
	}
	snap := e.repo.snapshot()
	config := snap.data['mcp:${provider_id}:config'] or { '' }
	if config != '' {
		if _ := json2.decode[json2.Any](config) {
		} else {
			return [
				BuildDiagnostic{ path: 'mcp/${provider_id}.json', message: 'recorded config is not valid JSON', code: 'schema_invalid' },
			]
		}
	}
	return diags
}

pub fn (mut e Engine) mcp_preview(provider_id string) (string, string) {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			content := data_file_read(env, p.template_path) or { '' }
			return content, content
		}
	}
	return '', ''
}

// mcp_install_preview returns dry-run diff (easy management).
pub fn (mut e Engine) mcp_install_preview(provider_id string) McpInstallPreview {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut template_path := ''
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			template_path = p.template_path
			break
		}
	}
	if template_path == '' {
		return McpInstallPreview{
			provider_id: provider_id
			will_write: []
			will_update: []
			receipt_path: ''
			provenance_path: ''
		}
	}
	return McpInstallPreview{
		provider_id: provider_id
		will_write: [template_path]
		will_update: [os.join_path(os.home_dir(), '.config', 'mcp.json')]
		receipt_path: os.join_path(os.home_dir(), '.config', 'agent-toolkit', 'receipts', '${provider_id}-mcp.json')
		provenance_path: template_path
	}
}

// McpProbeResult is the typed health-probe outcome (#1106). Read-only:
// the probe never writes state, the GUI caches the display for 60s.
pub struct McpProbeResult {
pub:
	healthy bool
	detail  string
}

// mcp_template_json returns only real packaged template content. The bool
// reports whether the provider was discovered from a file (#1106).
pub fn (mut e Engine) mcp_template_json(provider_id string) (string, bool) {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			content := data_file_read(env, p.template_path) or { '' }
			if content != '' {
				return content, true
			}
			break
		}
	}
	return '', false
}

// mcp_probe runs the typed health probe: schema validation + secret-guard
// scan of the template + live health (#1106).
pub fn (mut e Engine) mcp_probe(provider_id string) !McpProbeResult {
	if provider_id == '' {
		return error('provider id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut known := false
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			known = true
			break
		}
	}
	if !known {
		return error('mcp provider not found: ${provider_id}')
	}
	mut problems := []string{}
	for d in e.mcp_validate(provider_id) {
		problems << '${d.path}: ${d.message}'
	}
	content, _ := e.mcp_template_json(provider_id)
	if has_raw_secret(content) {
		problems << 'raw secret in template — replace with \${ENV_VAR}'
	}
	health_now := e.mcp_health_detailed(provider_id)
	if health_now != 'healthy' {
		problems << 'provider reports ${health_now}'
	}
	if problems.len == 0 {
		return McpProbeResult{ healthy: true, detail: 'probe clean — ${health_now}' }
	}
	return McpProbeResult{ healthy: false, detail: problems.join('; ') }
}

// mcp_receipt returns receipt info for MCP provider.
pub fn (mut e Engine) mcp_receipt(provider_id string) ?McpInstallPreview {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	if 'mcp:${provider_id}:enabled' !in snap.data {
		return none
	}
	return e.mcp_install_preview(provider_id)
}

// mask_mcp_secrets replaces raw token values with ${ENV_VAR} so config
// previews never render secrets (#1106). Pure — unit-tested. Existing
// ${...} placeholders pass through untouched.
pub fn mask_mcp_secrets(text string) string {
	mut out := text
	for pat in ['ghp_', 'gho_', 'sk-', 'xoxb-'] {
		mut from := 0
		for {
			rel := out[from..].index(pat) or { break }
			idx := from + rel
			before := if idx >= 2 { out[idx - 2..idx] } else { '' }
			if before == '\${' {
				from = idx + pat.len
				continue
			}
			mut end := idx + pat.len
			for end < out.len {
				c := out[end]
				if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) || c == `_` || c == `-` {
					end++
				} else {
					break
				}
			}
			// bare prefix with no token material — not a secret, skip it
			if end == idx + pat.len {
				from = end
				continue
			}
			out = out[..idx] + '\${ENV_VAR}' + out[end..]
			from = idx + '\${ENV_VAR}'.len
		}
	}
	return out
}

pub fn has_raw_secret(text string) bool {
	if text.contains('ghp_') || text.contains('gho_') || text.contains('sk-') || text.contains('xoxb-') {
		if text.contains('\${') {
			for pat in ['ghp_', 'sk-', 'xoxb-'] {
				idx := text.index(pat) or { continue }
				before := if idx > 2 { text[idx - 2..idx] } else { '' }
				if before != '\${' {
					return true
				}
			}
			return false
		}
		return true
	}
	return false
}

pub fn (mut e Engine) upsert_mcp_provider(provider_id string, config_json string) !u64 {
	if provider_id == '' {
		return error('provider id empty')
	}
	if has_raw_secret(config_json) {
		return error('secret guard: raw token detected, use \${ENV_VAR} placeholder per SECURITY.md')
	}
	// real validation: the offered config must parse as JSON before it is
	// accepted into configuration state.
	if _ := json2.decode[json2.Any](config_json) {
	} else {
		return error('validation failed: config is not valid JSON')
	}
	diags := e.mcp_validate(provider_id)
	if diags.len > 0 {
		return error('validation failed: ${diags[0].message}')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('upsert-mcp')
	tx.set('mcp:${provider_id}:config', config_json)
	tx.set('mcp:${provider_id}:enabled', 'true')
	// Config recorded ≠ server healthy. Honest state until a probe succeeds.
	tx.set('mcp:${provider_id}:health', 'configured')
	// provenance records the packaged template this provider was discovered
	// from (real catalog evidence), not a constructed path.
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			tx.set('provenance:mcp:${provider_id}:source', p.provenance)
			break
		}
	}
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

pub fn (mut e Engine) remove_mcp_provider(provider_id string) !u64 {
	if provider_id == '' {
		return error('provider id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('remove-mcp')
	tx.set('mcp:${provider_id}:enabled', 'false')
	tx.set('mcp:${provider_id}:health', 'unconfigured')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// mcp_toggle enables/disables in one click. Enabling installs the packaged
// template content for the provider — never an invented npx stanza.
pub fn (mut e Engine) mcp_toggle(provider_id string) !u64 {
	env := resolve_env()
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			if p.enabled {
				return e.remove_mcp_provider(provider_id)!
			}
			template := data_file_read(env, p.template_path) or { '' }
			if template == '' {
				return error('no packaged template for ${provider_id} — cannot enable without real config')
			}
			return e.upsert_mcp_provider(provider_id, template)!
		}
	}
	return error('mcp provider not found: ${provider_id}')
}

// verify_mcp_receipts checks that every enabled MCP provider has a recorded
// configuration (real config-truth drift check). Enabled without config is a
// genuine defect; no receipt is fabricated to satisfy this.
pub fn (mut e Engine) verify_mcp_receipts() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	snap := e.repo.snapshot()
	for p in e.mcp_catalog() {
		if p.enabled {
			if 'mcp:${p.id}:config' !in snap.data {
				diags << BuildDiagnostic{
					path: 'mcp/${p.id}.json'
					message: 'enabled MCP ${p.id} has no recorded config'
					code: 'config_missing'
				}
			}
		}
	}
	return diags
}

// mcp_provenance_json returns structured provenance for a provider. The
// template path is the real packaged template this provider was discovered
// from; verified is true only when the template content is actually readable
// from the resolved data tier.
pub fn (mut e Engine) mcp_provenance_json(provider_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	mut template := ''
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			template = p.template_path
			break
		}
	}
	mut verified := false
	if template != '' {
		content := data_file_read(env, template) or { '' }
		verified = content != ''
	}
	return json2.encode({
		'provider': provider_id
		'template': template
		'verified': if verified { 'true' } else { 'false' }
	},
		escape_unicode: true
	)
}
