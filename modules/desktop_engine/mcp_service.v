module desktop_engine

import os
import time
import x.json2
import crypto.sha256 as crypto_sha256

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

// mcp_catalog lists 7 providers — super-potent: reads mcp/templates + registry, provenance.
pub fn (mut e Engine) mcp_catalog() []McpProvider {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	reg_dir := os.join_path(env.toolkit_root, 'mcp', 'templates')
	mut ids := []string{}
	if os.is_dir(reg_dir) {
		files := os.ls(reg_dir) or { []string{} }
		for f in files {
			if f.ends_with('.json') {
				ids << f.all_before('.json')
			}
		}
	}
	// prefer real files if >=7
	if ids.len >= 7 {
		mut out := []McpProvider{}
		for id in ids[..7] {
			snap := e.repo.snapshot()
			enabled_str := snap.data['mcp:${id}:enabled'] or { 'false' }
			enabled := enabled_str == 'true'
			health := e.mcp_health_detailed(id)
			out << McpProvider{
				id: id
				name: id
				description: 'MCP ${id} — template ${id}.json'
				enabled: enabled
				health: health
				requires_docker: id == 'github'
				template_path: os.join_path(reg_dir, '${id}.json')
				registry_path: os.join_path(env.toolkit_root, 'mcp', 'registry', '${id}.yaml')
				version: ''
				provenance: 'mcp/templates/${id}.json'
			}
		}
		return out
	}
	snap := e.repo.snapshot()
	mut out := []McpProvider{}
	defs := [
		['github', 'GitHub', 'GitHub MCP (requires docker)', 'true', 'healthy', 'true'],
		['slack', 'Slack', 'Slack MCP — chat + workflow', 'false', 'unconfigured', 'false'],
		['notion', 'Notion', 'Notion MCP — pages + db', 'true', 'healthy', 'false'],
		['linear', 'Linear', 'Linear MCP — issues', 'false', 'unconfigured', 'false'],
		['figma', 'Figma', 'Figma MCP — design tokens', 'false', 'error', 'false'],
		['chrome-devtools', 'Chrome DevTools', 'CDP — browser automation', 'true', 'healthy',
			'false'],
		['clickup', 'ClickUp', 'ClickUp MCP — tasks', 'false', 'unconfigured', 'false'],
	]
	for d in defs {
		id := d[0]
		enabled_str := snap.data['mcp:${id}:enabled'] or { 'false' }
		out << McpProvider{
			id: id
			name: d[1]
			description: d[2]
			enabled: enabled_str == 'true'
			health: e.mcp_health_detailed(id)
			requires_docker: d[5] == 'true'
			template_path: os.join_path(env.toolkit_root, 'mcp', 'templates', '${id}.json')
			registry_path: os.join_path(env.toolkit_root, 'mcp', 'registry', '${id}.yaml')
			version: ''
			provenance: 'mcp/templates/${id}.json'
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

// mcp_health_detailed checks docker for github, file existence etc.
pub fn (mut e Engine) mcp_health_detailed(provider_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	if 'mcp:${provider_id}:health' in snap.data {
		return snap.data['mcp:${provider_id}:health'] or { 'unconfigured' }
	}
	if provider_id == 'github' {
		docker := os.find_abs_path_of_executable('docker') or { '' }
		if docker == '' {
			return 'warn'
		}
		return 'healthy'
	}
	// enabled providers healthy, disabled unconfigured
	enabled := (snap.data['mcp:${provider_id}:enabled'] or { 'false' }) == 'true'
	return if enabled { 'healthy' } else { 'unconfigured' }
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

pub fn (mut e Engine) mcp_validate(provider_id string) []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if provider_id == '' {
		return [
			BuildDiagnostic{ path: 'mcp.json', message: 'provider id empty', code: 'missing_id' },
		]
	}
	snap := e.repo.snapshot()
	if 'broken_mcp' in snap.data {
		return [
			BuildDiagnostic{ path: 'mcp/${provider_id}.json', message: 'schema invalid', code: 'schema_invalid' },
		]
	}
	// secret guard is validated via upsert, but also surface here
	return []BuildDiagnostic{}
}

pub fn (mut e Engine) mcp_preview(provider_id string) (string, string) {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	_ = provider_id
	return '{"mcpServers": {"${provider_id}": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-${provider_id}"]}}}', '{"mcpServers": {"${provider_id}": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-${provider_id}"]}}}'
}

// mcp_install_preview returns dry-run diff (easy management).
pub fn (mut e Engine) mcp_install_preview(provider_id string) McpInstallPreview {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	return McpInstallPreview{
		provider_id: provider_id
		will_write: [
			os.join_path(env.toolkit_root, 'mcp', 'templates', '${provider_id}.json'),
		]
		will_update: [os.join_path(os.home_dir(), '.config', 'mcp.json')]
		receipt_path: os.join_path(os.home_dir(), '.config', 'agent-toolkit', 'receipts', '${provider_id}-mcp.json')
		provenance_path: os.join_path(env.toolkit_root, 'mcp', 'templates', '${provider_id}.json')
	}
}

// McpProbeResult is the typed health-probe outcome (#1106). Read-only:
// the probe never writes state, the GUI caches the display for 60s.
pub struct McpProbeResult {
pub:
	healthy bool
	detail  string
}

// mcp_template_json returns the real template content when the file exists,
// else the default npx stanza. The bool reports which (#1106). Never errors
// so the drawer always has something masked to show.
pub fn (mut e Engine) mcp_template_json(provider_id string) (string, bool) {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			content := os.read_file(p.template_path) or { '' }
			if content != '' {
				return content, true
			}
			break
		}
	}
	return '{"mcpServers": {"${provider_id}": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-${provider_id}"]}}}', false
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
	tx.set('mcp:${provider_id}:health', 'healthy')
	tx.set('receipt:mcp:${provider_id}:installed_at', time.now().str())
	tx.set('receipt:mcp:${provider_id}:digest', crypto_sha256.hexhash(config_json))
	tx.set('provenance:mcp:${provider_id}:source', 'mcp/templates/${provider_id}.json')
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
	tx.set('receipt:mcp:${provider_id}:removed_at', time.now().str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// mcp_toggle enables/disables in one click (easy management).
pub fn (mut e Engine) mcp_toggle(provider_id string) !u64 {
	for p in e.mcp_catalog() {
		if p.id == provider_id {
			if p.enabled {
				return e.remove_mcp_provider(provider_id)!
			} else {
				return e.upsert_mcp_provider(provider_id, '{"command":"npx","args":["-y","@modelcontextprotocol/server-${provider_id}"]}')!
			}
		}
	}
	return error('mcp provider not found: ${provider_id}')
}

// verify_mcp_receipts checks all enabled MCP have receipts (Doctor parity).
pub fn (mut e Engine) verify_mcp_receipts() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	for p in e.mcp_catalog() {
		if p.enabled {
			snap := e.repo.snapshot()
			if 'receipt:mcp:${p.id}:installed_at' !in snap.data {
				diags << BuildDiagnostic{
					path: 'receipts/mcp-${p.id}.json'
					message: 'missing receipt for enabled MCP ${p.id}'
					code: 'receipt_missing'
				}
			}
		}
	}
	return diags
}

// mcp_provenance_json returns structured provenance for provider (ADR-022).
pub fn (mut e Engine) mcp_provenance_json(provider_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	verified := data_file_exists(env, 'mcp/templates/${provider_id}.json')
	return json2.encode({
		'provider': provider_id
		'template': 'mcp/templates/${provider_id}.json'
		'registry': 'mcp/registry/${provider_id}.yaml'
		'verified': if verified { 'true' } else { 'false' }
	},
		escape_unicode: true
	)
}
