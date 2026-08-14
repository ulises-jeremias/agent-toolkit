#!/usr/bin/env -S v run
// Validate Agent Plugins 1.0 manifests (structural checks; no jsonschema).
// Usage: ./scripts/validate-agent-plugins.vsh [--check]

import json

fn repo_root() string {
	mut d := dir(@FILE)
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

fn rel_to(root string, path string) string {
	prefix := '${root}/'
	if path.starts_with(prefix) {
		return path[prefix.len..]
	}
	return path
}

fn valid_plugin_name(name string) bool {
	if name.len == 0 || name.len > 64 {
		return false
	}
	if name.contains('--') || name.contains('..') {
		return false
	}
	first := name[0]
	last := name[name.len - 1]
	if !((first >= `a` && first <= `z`) || (first >= `0` && first <= `9`)) {
		return false
	}
	if !((last >= `a` && last <= `z`) || (last >= `0` && last <= `9`)) {
		return false
	}
	for c in name {
		ok := (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `.` || c == `-`
		if !ok {
			return false
		}
	}
	return true
}

struct PluginManifest {
	schema      string @[json: '\$schema']
	name        string
	version     string
	description string
}

struct McpFile {
	schema      string @[json: '\$schema']
	mcp_servers map[string]McpServer @[json: 'mcpServers']
}

struct McpServer {
	command string
	cwd     string
	env     map[string]string
}

fn main() {
	root := repo_root()
	plugins_dir := join_path(root, 'plugins')
	mut errors := []string{}
	mut warnings := []string{}
	plugins := ls(plugins_dir) or { []string{} }
	mut count := 0
	for name in plugins.sorted() {
		pd := join_path(plugins_dir, name)
		if !is_dir(pd) {
			continue
		}
		count++
		validate_plugin_manifest(root, pd, mut errors, mut warnings)
		validate_mcp(root, pd, mut errors, mut warnings)
	}
	if count == 0 {
		eprintln('No plugins found in plugins/')
		exit(0)
	}
	println('Validating ${count} plugin(s) for Agent Plugins 1.0...')
	for w in warnings {
		println('  ⚠ ${w}')
	}
	for e in errors {
		println('  ✗ ${e}')
	}
	if errors.len > 0 {
		println('\n❌ Agent Plugins validation failed: ${errors.len} error(s), ${warnings.len} warning(s)')
		exit(1)
	}
	if warnings.len > 0 {
		println('\n⚠️  Validation passed with ${warnings.len} warning(s)')
	} else {
		println('\n✅ All ${count} plugin(s) valid per Agent Plugins 1.0')
	}
}

fn validate_plugin_manifest(root string, plugin_dir string, mut errors []string, mut warnings []string) {
	p := join_path(plugin_dir, 'plugin.json')
	if !is_file(p) {
		warnings << '${rel_to(root, plugin_dir)}: missing plugin.json (not an Agent Plugins plugin yet)'
		return
	}
	raw := read_file(p) or {
		errors << '${rel_to(root, p)}: cannot read'
		return
	}
	data := json.decode(PluginManifest, raw) or {
		errors << '${rel_to(root, p)}: invalid JSON: ${err}'
		return
	}
	expected := 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json'
	if data.schema != expected {
		errors << "${rel_to(root, p)}: \$schema must be '${expected}'"
	}
	if data.name.len == 0 {
		errors << "${rel_to(root, p)}: missing required 'name'"
	} else if !valid_plugin_name(data.name) {
		errors << "${rel_to(root, p)}: name '${data.name}' violates Agent Plugins naming (1-64, a-z0-9.-, no --/.., alphanumeric start/end)"
	}
	skills_dir := join_path(plugin_dir, 'skills')
	if exists(skills_dir) {
		if !is_dir(skills_dir) {
			errors << '${rel_to(root, plugin_dir)}/skills: must be a directory'
		} else {
			for child in ls(skills_dir) or { []string{} } {
				cp := join_path(skills_dir, child)
				if is_dir(cp) && !is_file(join_path(cp, 'SKILL.md')) {
					warnings << '${rel_to(root, plugin_dir)}/skills/${child}: missing SKILL.md (will be skipped per §7.1)'
				}
			}
		}
	}
}

fn validate_mcp(root string, plugin_dir string, mut errors []string, mut warnings []string) {
	p := join_path(plugin_dir, 'mcp.json')
	if !is_file(p) {
		return
	}
	raw := read_file(p) or {
		errors << '${rel_to(root, p)}: cannot read'
		return
	}
	data := json.decode(McpFile, raw) or {
		errors << '${rel_to(root, p)}: invalid JSON: ${err}'
		return
	}
	expected := 'https://agent-plugins.org/schemas/1.0.0/mcp.schema.json'
	if data.schema != expected {
		errors << "${rel_to(root, p)}: \$schema must be '${expected}'"
	}
	if data.mcp_servers.len == 0 && !raw.contains('"mcpServers"') {
		errors << "${rel_to(root, p)}: missing required 'mcpServers' object"
		return
	}
	for srv_id, srv in data.mcp_servers {
		if srv.command.starts_with('./') && srv.command.contains('..') {
			errors << "${rel_to(root, p)} mcpServers.${srv_id}.command: plugin-relative path must not escape root (contains '..')"
		}
		if srv.cwd.starts_with('./') && srv.cwd.contains('..') {
			errors << "${rel_to(root, p)} mcpServers.${srv_id}.cwd: must not escape root"
		}
		if 'PLUGIN_ROOT' in srv.env || 'PLUGIN_DATA' in srv.env {
			errors << '${rel_to(root, p)} mcpServers.${srv_id}.env: must not contain PLUGIN_ROOT/PLUGIN_DATA (reserved)'
		}
	}
}
