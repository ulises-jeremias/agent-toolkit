#!/usr/bin/env -S v run
// Bump all version sources atomically.
// Usage: v run scripts/bump-version.vsh [--check] X.Y.Z

import json
import regex

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

fn bump_regex(root string, path string, pattern string, replacement string, check bool) bool {
	p := join_path(root, path)
	if !is_file(p) {
		return false
	}
	t := read_file(p) or { return false }
	mut re := regex.regex_opt(pattern) or { return false }
	new_t := re.replace_simple(t, replacement)
	if new_t == t {
		return false
	}
	if check {
		println('would bump ${path}')
		return true
	}
	write_file(p, new_t) or { return false }
	println('bumped ${path}')
	return true
}

struct NpmPkg {
mut:
	name                  string
	version               string
	optional_dependencies map[string]string @[json: 'optionalDependencies']
}

fn main() {
	root := repo_root()
	mut check := false
	mut version := ''
	for a in args[1..] {
		if a == '--check' {
			check = true
		} else if !a.starts_with('-') && version.len == 0 {
			version = a
		}
	}
	if version.len == 0 {
		eprintln('Usage: bump-version.vsh [--check] X.Y.Z')
		exit(2)
	}
	mut ver_re := regex.regex_opt(r'^\d+\.\d+\.\d+') or { exit(2) }
	if !ver_re.matches_string(version) {
		eprintln('invalid version ${version}')
		exit(2)
	}
	mut changed := 0
	vp := join_path(root, 'VERSION')
	if is_file(vp) {
		old := (read_file(vp) or { '' }).trim_space()
		if old != version {
			println('VERSION ${old} -> ${version}')
			if !check {
				write_file(vp, version + '\n') or {}
			}
			changed++
		}
	}
	if bump_regex(root, 'packages/pypi/agent-toolkit-cli/src/agent_toolkit/__init__.py',
		r'__version__ = ".*"', '__version__ = "${version}"', check) {
		changed++
	}
	if bump_regex(root, 'modules/agent_toolkit_core/version.v',
		r"pub const embedded_version = '.*'", "pub const embedded_version = '${version}'", check) {
		changed++
	}
	if bump_regex(root, 'package.json', r'"version"\s*:\s*"[^"]*"', '"version": "${version}"',
		check) {
		changed++
	}
	npm_root := join_path(root, 'packages', 'npm')
	if is_dir(npm_root) {
		children := ls(npm_root) or { []string{} }
		for child in children.sorted() {
			pkg_path := join_path(npm_root, child, 'package.json')
			if !is_file(pkg_path) {
				continue
			}
			raw := read_file(pkg_path) or { continue }
			mut data := json.decode(NpmPkg, raw) or { continue }
			mut dirty := false
			if data.version != version {
				data.version = version
				dirty = true
			}
			if data.optional_dependencies.len > 0 {
				mut opts := map[string]string{}
				for k, _ in data.optional_dependencies {
					opts[k] = version
				}
				if opts.str() != data.optional_dependencies.str() {
					data.optional_dependencies = opts.clone()
					dirty = true
				}
			}
			if dirty {
				println('bumped ${rel_to(root, pkg_path)}')
				changed++
				if !check {
					// Preserve full package.json via regex for version + optionalDeps keys
					mut t := raw
					mut vre := regex.regex_opt(r'"version"\s*:\s*"[^"]*"') or { continue }
					t = vre.replace_simple(t, '"version": "${version}"')
					for k, _ in data.optional_dependencies {
						mut ore := regex.regex_opt('"${k}"\\s*:\\s*"[^"]*"') or { continue }
						t = ore.replace_simple(t, '"${k}": "${version}"')
					}
					write_file(pkg_path, t) or {}
				}
			}
		}
	}
	for mp in ['.claude-plugin/marketplace.json', '.cursor-plugin/marketplace.json'] {
		mp_path := join_path(root, mp)
		if !is_file(mp_path) {
			continue
		}
		raw := read_file(mp_path) or { continue }
		mut vre := regex.regex_opt(r'"version"\s*:\s*"[^"]*"') or { continue }
		new_t := vre.replace_simple(raw, '"version": "${version}"')
		if new_t != raw {
			println('bumped ${mp}')
			changed++
			if !check {
				write_file(mp_path, new_t) or {}
			}
		}
	}
	plugins_dir := join_path(root, 'plugins')
	if is_dir(plugins_dir) {
		plugins := ls(plugins_dir) or { []string{} }
		for plugin in plugins.sorted() {
			for rel in [
				join_path(plugin, 'plugin.json'),
				join_path(plugin, '.claude-plugin', 'plugin.json'),
				join_path(plugin, '.cursor-plugin', 'plugin.json'),
			] {
				pl := join_path(plugins_dir, rel)
				if !is_file(pl) {
					continue
				}
				raw := read_file(pl) or { continue }
				mut dirty := false
				mut t := raw
				mut vre := regex.regex_opt(r'"version"\s*:\s*"[^"]*"') or { continue }
				new_t := vre.replace_simple(t, '"version": "${version}"')
				if new_t != t {
					println('bumped ${rel_to(root, pl)}')
					dirty = true
					t = new_t
				}
				// Top-level Agent Plugins plugin.json: ensure $schema
				if rel.ends_with('${plugin}/plugin.json') && !t.contains('"\$schema"') {
					println('fixing \$schema for ${rel_to(root, pl)}')
					dirty = true
					t = t.replace_once('{',
						'{\n  "\$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",')
				}
				if dirty {
					changed++
					if !check {
						write_file(pl, t) or {}
					}
				}
			}
		}
	}
	if check && changed > 0 {
		eprintln('${changed} files would change')
		exit(1)
	}
	if !check {
		println('bumped ${changed} files to ${version}')
	}
}
