#!/usr/bin/env -S v run
// Validate Claude and Cursor marketplace manifests and plugin.json files.
// Usage: v run scripts/validate-manifests.vsh

import json

struct MarketplacePlugin {
	name   string
	source string
}

struct MarketplaceMeta {
	plugin_root string @[json: 'pluginRoot']
}

struct MarketplaceOwner {
	name  string
	email string
}

struct Marketplace {
	name     string
	owner    MarketplaceOwner
	metadata MarketplaceMeta
	plugins  []MarketplacePlugin
}

struct PluginAuthor {
	name string
}

struct PluginManifest {
	name        string
	version     string
	description string
	author      PluginAuthor
	license     string
}

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

fn main() {
	root := repo_root()
	mut errors := []string{}
	println('\n🔍 Validating marketplace and plugin manifests...\n')
	println('── Claude Code ──')
	validate_marketplace(root, join_path(root, '.claude-plugin', 'marketplace.json'), 'Claude Code', mut
		errors)
	println('\n── Cursor ──')
	validate_marketplace(root, join_path(root, '.cursor-plugin', 'marketplace.json'), 'Cursor', mut errors)
	println('')
	if errors.len > 0 {
		println('❌ ${errors.len} error(s) found')
		exit(1)
	}
	println('✅ All manifests valid!')
}

fn validate_marketplace(root string, marketplace_path string, tool string, mut errors []string) {
	if !is_file(marketplace_path) {
		msg := 'Missing ${rel_to(root, marketplace_path)}'
		errors << msg
		println('  ✗ ${msg}')
		return
	}
	raw := read_file(marketplace_path) or {
		msg := '${rel_to(root, marketplace_path)}: cannot read'
		errors << msg
		println('  ✗ ${msg}')
		return
	}
	data := json.decode(Marketplace, raw) or {
		msg := '${rel_to(root, marketplace_path)}: invalid JSON: ${err}'
		errors << msg
		println('  ✗ ${msg}')
		return
	}
	if data.name.len == 0 {
		errors << "${tool} marketplace.json: missing 'name'"
		println("  ✗ ${tool} marketplace.json: missing 'name'")
	}
	if data.owner.name.len == 0 {
		errors << "${tool} marketplace.json: missing 'owner'"
		println("  ✗ ${tool} marketplace.json: missing 'owner'")
	}
	if data.plugins.len == 0 {
		errors << "${tool} marketplace.json: missing 'plugins'"
		println("  ✗ ${tool} marketplace.json: missing 'plugins'")
	}
	plugin_root := if data.metadata.plugin_root.len > 0 {
		data.metadata.plugin_root.trim_string_left('./')
	} else {
		'plugins'
	}
	plugin_root_path := join_path(root, plugin_root)
	manifest_key := if tool == 'Claude Code' { '.claude-plugin' } else { '.cursor-plugin' }
	for plugin in data.plugins {
		pname := if plugin.name.len > 0 { plugin.name } else { '?' }
		psource := plugin.source
		plugin_dir := if psource.starts_with('./') {
			join_path(root, psource.trim_string_left('./'))
		} else {
			join_path(plugin_root_path, psource.trim_string_left('/'))
		}
		plugin_json := join_path(plugin_dir, manifest_key, 'plugin.json')
		if !is_file(plugin_json) {
			msg := "${tool} plugin '${pname}': ${rel_to(root, plugin_json)} not found"
			errors << msg
			println('  ✗ ${msg}')
			continue
		}
		praw := read_file(plugin_json) or {
			msg := "${tool} plugin '${pname}': cannot read plugin.json"
			errors << msg
			println('  ✗ ${msg}')
			continue
		}
		pdata := json.decode(PluginManifest, praw) or {
			msg := "${tool} plugin '${pname}': invalid plugin.json: ${err}"
			errors << msg
			println('  ✗ ${msg}')
			continue
		}
		if pdata.name != pname {
			msg := "${tool} plugin '${pname}': name mismatch (marketplace='${pname}' vs plugin.json='${pdata.name}')"
			errors << msg
			println('  ✗ ${msg}')
		}
		if pdata.name.len == 0 {
			errors << "${tool} plugin '${pname}': plugin.json missing 'name'"
			println("  ✗ ${tool} plugin '${pname}': plugin.json missing 'name'")
		}
		if pdata.version.len == 0 {
			errors << "${tool} plugin '${pname}': plugin.json missing 'version'"
			println("  ✗ ${tool} plugin '${pname}': plugin.json missing 'version'")
		}
		if pdata.description.len == 0 {
			errors << "${tool} plugin '${pname}': plugin.json missing 'description'"
			println("  ✗ ${tool} plugin '${pname}': plugin.json missing 'description'")
		}
		if pdata.author.name.len == 0 {
			errors << "${tool} plugin '${pname}': plugin.json missing 'author'"
			println("  ✗ ${tool} plugin '${pname}': plugin.json missing 'author'")
		}
		if pdata.license.len == 0 {
			errors << "${tool} plugin '${pname}': plugin.json missing 'license'"
			println("  ✗ ${tool} plugin '${pname}': plugin.json missing 'license'")
		}
		println("  ✓ ${tool} plugin '${pname}' OK")
	}
}
