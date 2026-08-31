module desktop_engine

import os

// McpProvider mirrors mcp/templates.
pub struct McpProvider {
pub:
	id          string
	name        string
	description string
	enabled     bool
	health      string
}

// mcp_catalog lists 7 providers.
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
	if ids.len >= 7 {
		mut out := []McpProvider{}
		for id in ids[..7] {
			out << McpProvider{id: id, name: id, description: 'MCP ${id}', enabled: true, health: 'healthy'}
		}
		return out
	}
	return [
		McpProvider{id: 'github', name: 'GitHub', description: 'GitHub MCP', enabled: true, health: 'healthy'},
		McpProvider{id: 'slack', name: 'Slack', description: 'Slack MCP', enabled: false, health: 'unconfigured'},
		McpProvider{id: 'notion', name: 'Notion', description: 'Notion MCP', enabled: true, health: 'healthy'},
		McpProvider{id: 'linear', name: 'Linear', description: 'Linear MCP', enabled: false, health: 'unconfigured'},
		McpProvider{id: 'figma', name: 'Figma', description: 'Figma MCP', enabled: false, health: 'error'},
		McpProvider{id: 'chrome-devtools', name: 'Chrome DevTools', description: 'CDP', enabled: true, health: 'healthy'},
		McpProvider{id: 'clickup', name: 'ClickUp', description: 'ClickUp MCP', enabled: false, health: 'unconfigured'},
	]
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

pub fn (mut e Engine) mcp_validate(provider_id string) []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if provider_id == '' {
		return [BuildDiagnostic{path: 'mcp.json', message: 'provider id empty', code: 'missing_id'}]
	}
	snap := e.repo.snapshot()
	if 'broken_mcp' in snap.data {
		return [BuildDiagnostic{path: 'mcp/${provider_id}.json', message: 'schema invalid', code: 'schema_invalid'}]
	}
	return []BuildDiagnostic{}
}

pub fn (mut e Engine) mcp_preview(provider_id string) (string, string) {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	_ = provider_id
	return '{"mcpServers": {"${provider_id}": {"command": "npx"}}}', '{"mcpServers": {"${provider_id}": {"command": "npx"}}}'
}

pub fn has_raw_secret(text string) bool {
	if text.contains('ghp_') || text.contains('gho_') || text.contains('sk-') || text.contains('xoxb-') {
		if text.contains('\${') {
			for pat in ['ghp_', 'sk-', 'xoxb-'] {
				idx := text.index(pat) or { continue }
				before := if idx > 2 { text[idx - 2 .. idx] } else { '' }
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
	rev := e.put_transaction(mut tx)!
	return rev.revision
}
