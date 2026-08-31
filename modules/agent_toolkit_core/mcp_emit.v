module agent_toolkit_core

import json
import os

struct McpTemplateJson {
mut:
	name      string
	command   string
	args      []string
	env       map[string]string
	transport string
	url       string
	headers   map[string]string
	auth      string
}

// emit_portable_mcp generates mcp.json under out_dir from product.included_mcp.
// It reads mcp/templates/<id>/config.template.json and converts to portable
// Agent Plugins 1.0 mcp.json (stdio vs streamable-http). Returns true if a
// file was written.
fn emit_portable_mcp(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string, repo_root string) bool {
	if product.included_mcp.len == 0 {
		return false
	}
	mut servers := map[string]string{}
	mut server_order := []string{}
	for mcp_id in product.included_mcp {
		tmpl_path := os.join_path(repo_root, 'mcp', 'templates', mcp_id, 'config.template.json')
		alt_path := os.join_path(repo_root, 'mcp', 'templates', mcp_id, 'config.local.template.json')
		mut raw := ''
		mut used_path := tmpl_path
		if os.is_file(tmpl_path) {
			raw = os.read_file(tmpl_path) or {
				result.warnings << "MCP template '${mcp_id}' unreadable: ${err}"
				continue
			}
		} else if os.is_file(alt_path) {
			raw = os.read_file(alt_path) or {
				result.warnings << "MCP template '${mcp_id}' unreadable: ${err}"
				continue
			}
			used_path = alt_path
		} else {
			// Fallback: try registry yaml for transport info
			reg_path := os.join_path(repo_root, 'mcp', 'registry', '${mcp_id}.yaml')
			if os.is_file(reg_path) {
				// Minimal fallback: stdio with npx for community packages
				// Try to infer from registry
				reg_text := os.read_file(reg_path) or { '' }
				// crude: if transport contains streamable_http prefer http
				if reg_text.contains('streamable_http') {
					result.warnings << "MCP '${mcp_id}' has no template; registry indicates http — skipping (needs template)"
					continue
				}
				result.warnings << "MCP '${mcp_id}' template not found: ${used_path}"
				continue
			}
			result.warnings << "MCP '${mcp_id}' template not found: ${used_path}"
			result.omitted << 'mcp:${mcp_id}'
			continue
		}
		// Decode template JSON; tolerate extra fields via struct with only needed keys
		tmpl := json.decode(McpTemplateJson, raw) or {
			result.warnings << "MCP template '${mcp_id}' invalid JSON: ${err}"
			continue
		}
		server_json := build_mcp_server_json(tmpl, mcp_id) or {
			result.warnings << "MCP '${mcp_id}' skipped: ${err}"
			continue
		}
		if mcp_id in servers {
			result.warnings << "MCP '${mcp_id}' duplicate — overwriting"
		} else {
			server_order << mcp_id
		}
		servers[mcp_id] = server_json
		_ = graph
		_ = used_path
	}
	if servers.len == 0 {
		if product.included_mcp.len > 0 {
			result.warnings << 'MCP requested but no servers emitted for ${product.id}'
		}
		return false
	}
	server_order.sort()
	mut entries := []string{}
	for id in server_order {
		entries << '    "${json_escape(id)}": ${servers[id]}'
	}
	body := '{\n' + '  "\$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",\n' +
		'  "mcpServers": {\n' + entries.join(',\n') + '\n  }\n}\n'
	write_text_artifact(os.join_path(out_dir, 'mcp.json'), body, 'generated', output_root, mut result,
		mut records)
	result.emitted << 'mcp.json'
	return true
}

fn build_mcp_server_json(tmpl McpTemplateJson, mcp_id string) !string {
	// Determine server type
	mut typ := ''
	mut is_stdio := false
	mut is_http := false
	if tmpl.command.len > 0 {
		typ = 'stdio'
		is_stdio = true
	} else if tmpl.transport.len > 0 {
		trans := tmpl.transport.to_lower()
		if trans == 'streamable_http' || trans == 'streamable-http' {
			typ = 'streamable-http'
			is_http = true
		} else if trans == 'sse' {
			typ = 'sse'
			is_http = true
		} else if trans == 'stdio' {
			typ = 'stdio'
			is_stdio = true
		} else {
			return error('unknown transport ${tmpl.transport}')
		}
	} else if tmpl.url.len > 0 {
		// No transport but url present -> treat as streamable-http
		typ = 'streamable-http'
		is_http = true
	} else {
		return error('template has neither command nor transport/url')
	}

	if is_stdio {
		if tmpl.command.len == 0 {
			return error('stdio server missing command')
		}
		// Containment: command must be single token, bare name or ./ relative, no ..
		if tmpl.command.contains(' ') || tmpl.command.contains('\t') {
			return error('command must be single token')
		}
		if tmpl.command.contains('..') {
			return error('command must not contain ..')
		}
		if tmpl.command.contains('/') && !tmpl.command.starts_with('./') {
			return error('command with slash must start with ./')
		}
		mut parts := []string{}
		parts << '"type": "stdio"'
		parts << '"command": "${json_escape(tmpl.command)}"'
		if tmpl.args.len > 0 {
			mut arg_json := []string{}
			for a in tmpl.args {
				arg_json << '"${json_escape(a)}"'
			}
			parts << '"args": [${arg_json.join(', ')}]'
		}
		if tmpl.env.len > 0 {
			// Validate env keys not PLUGIN_ROOT/DATA
			for k, _ in tmpl.env {
				if k == 'PLUGIN_ROOT' || k == 'PLUGIN_DATA' {
					return error('env must not contain PLUGIN_ROOT/PLUGIN_DATA')
				}
			}
			mut env_parts := []string{}
			mut keys := tmpl.env.keys()
			keys.sort()
			for k in keys {
				v := tmpl.env[k]
				env_parts << '"${json_escape(k)}": "${json_escape(v)}"'
			}
			parts << '"env": {${env_parts.join(', ')}}'
		}
		// cwd per spec: must be ./, ${PLUGIN_ROOT}, ${PLUGIN_DATA} etc. Use PLUGIN_ROOT for stdio
		parts << '"cwd": "\${PLUGIN_ROOT}"'
		return '{ ${parts.join(', ')} }'
	}
	if is_http {
		if tmpl.url.len == 0 {
			return error('http server missing url')
		}
		// Basic url validation: must be absolute http/https, no user info or fragment
		if !(tmpl.url.starts_with('https://') || tmpl.url.starts_with('http://')) {
			return error('url must be http(s)')
		}
		if tmpl.url.contains('@') && tmpl.url.contains('://') {
			// crude check for user info: if @ appears before first / after scheme
			scheme_end := tmpl.url.index('://') or { -1 }
			if scheme_end >= 0 {
				after_scheme := tmpl.url[scheme_end + 3..]
				slash_idx := after_scheme.index('/') or { after_scheme.len }
				host_part := after_scheme[..slash_idx]
				if host_part.contains('@') {
					return error('url must not contain user info')
				}
			}
		}
		if tmpl.url.contains('#') {
			return error('url must not contain fragment')
		}
		// Enforce https for non-loopback
		if tmpl.url.starts_with('http://') {
			lower := tmpl.url.to_lower()
			if !(lower.contains('localhost') || lower.contains('127.0.0.1') || lower.contains('[::1]')) {
				return error('non-loopback url must use https')
			}
		}
		mut parts := []string{}
		parts << '"type": "${typ}"'
		parts << '"url": "${json_escape(tmpl.url)}"'
		if tmpl.headers.len > 0 {
			mut hdr_parts := []string{}
			mut keys := tmpl.headers.keys()
			keys.sort()
			// Validate header names unique case-insensitive
			mut seen := map[string]bool{}
			for k in keys {
				lk := k.to_lower()
				if lk in seen {
					return error('duplicate header name case-insensitive: ${k}')
				}
				seen[lk] = true
				v := tmpl.headers[k]
				hdr_parts << '"${json_escape(k)}": "${json_escape(v)}"'
			}
			parts << '"headers": {${hdr_parts.join(', ')}}'
		}
		return '{ ${parts.join(', ')} }'
	}
	return error('unhandled mcp type for ${mcp_id}')
}
