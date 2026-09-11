#!/usr/bin/env -S v run
// generate_surface.vsh — emit OpenAPI + CLI help from cli-contract.yaml SSOT.
//
// Part of feature-complete serve epic (#831, Phase 0), ADR-030 canonical.
// Usage:
//   ./scripts/generate_surface.vsh            # write artifacts
//   ./scripts/generate_surface.vsh --check    # fail if stale
// Outputs (idempotent, canonical per ADR-030):
//   docs/surface/openapi.json  (embedded by server, parity-gated)
//   docs/surface/cli-help.md   (docs/reference)
// Legacy dist/surface/cli-help.md is deprecated — canonical is docs/surface;
// dist is kept as symlink or removed (checked in --check).

import os
import yaml

// ---------------------------------------------------------------------------
// Contract model (docs/compatibility/cli-contract.yaml)
// ---------------------------------------------------------------------------

struct Effects {
	filesystem string
}

struct Cmd {
	name    string
	surface string
	summary string
	flags   []string
	effects Effects
	// api is optional: absent means True (Python `cmd.get("api", True)`).
	api ?bool
}

struct Contract {
	commands []Cmd
}

fn cmd_api(cmd Cmd) bool {
	return cmd.api or { true }
}

// ---------------------------------------------------------------------------
// Ordered JSON emitter — byte-identical to Python `json.dumps(indent=2)`.
// V maps do not preserve insertion order, so the document is built as an
// ordered tree (paths follow contract-command order, like the retired .py).
// ---------------------------------------------------------------------------

type JVal = JObj | JArr | JStr | JBool

struct JObj {
mut:
	keys []string
	vals []JVal
}

struct JArr {
	items []JVal
}

struct JStr {
	s string
}

struct JBool {
	b bool
}

fn jobj() JObj {
	return JObj{}
}

fn (mut o JObj) put(key string, val JVal) {
	idx := o.keys.index(key)
	if idx == -1 {
		o.keys << key
		o.vals << val
	} else {
		o.vals[idx] = val
	}
}

fn (o JObj) has(key string) bool {
	return o.keys.index(key) != -1
}

fn (o JObj) get(key string) ?JVal {
	idx := o.keys.index(key)
	if idx == -1 {
		return none
	}
	return o.vals[idx]
}

// hex_n renders the low `width` hex digits (lowercase, Python-style).
fn hex_n(code u32, width int) string {
	digits := '0123456789abcdef'
	mut out := []u8{cap: width}
	for i := width - 1; i >= 0; i-- {
		out << digits[int((code >> u32(i * 4)) & 0xF)]
	}
	return out.bytestr()
}

fn escape_json(s string) string {
	mut out := []u8{cap: s.len + 2}
	out << `"`
	for r in s.runes() {
		code := u32(r)
		match code {
			0x22 { out << '\\"'.bytes() }
			0x5C { out << '\\\\'.bytes() }
			0x0A { out << '\\n'.bytes() }
			0x0D { out << '\\r'.bytes() }
			0x09 { out << '\\t'.bytes() }
			0x08 { out << '\\b'.bytes() }
			0x0C { out << '\\f'.bytes() }
			else {
				if code < 0x20 {
					// C0 controls — Python emits lowercase \u00XX.
					out << '\\u00'.bytes()
					out << hex_n(code, 2).bytes()
				} else if code < 0x80 {
					// Printable ASCII + DEL (Python leaves 0x7F raw).
					out << u8(code)
				} else if code <= 0xFFFF {
					// ensure_ascii: BMP non-ASCII → \uXXXX (lowercase hex).
					out << '\\u'.bytes()
					out << hex_n(code, 4).bytes()
				} else {
					// Astral: UTF-16 surrogate pair, Python-style.
					v := code - 0x10000
					out << '\\u'.bytes()
					out << hex_n(0xD800 + (v >> 10), 4).bytes()
					out << '\\u'.bytes()
					out << hex_n(0xDC00 + (v & 0x3FF), 4).bytes()
				}
			}
		}
	}
	out << `"`
	return out.bytestr()
}

fn enc(val JVal, level int) string {
	pad := '  '.repeat(level)
	child := '  '.repeat(level + 1)
	match val {
		JObj {
			if val.keys.len == 0 {
				return '{}'
			}
			mut parts := []string{}
			for i, k in val.keys {
				parts << '${child}${escape_json(k)}: ${enc(val.vals[i], level + 1)}'
			}
			return '{\n' + parts.join(',\n') + '\n' + pad + '}'
		}
		JArr {
			if val.items.len == 0 {
				return '[]'
			}
			mut parts := []string{}
			for item in val.items {
				parts << '${child}${enc(item, level + 1)}'
			}
			return '[\n' + parts.join(',\n') + '\n' + pad + ']'
		}
		JStr {
			return escape_json(val.s)
		}
		JBool {
			return if val.b { 'true' } else { 'false' }
		}
	}
}

// ---------------------------------------------------------------------------
// Surface rules (ADR-029 scopes, ADR-030 routes)
// ---------------------------------------------------------------------------

fn scope_by_effect(key string) string {
	return match key {
		'write-profiles-receipts', 'update-profiles-cache', 'delete-owned-files', 'optional-fix-writes' {
			'write:fs'
		}
		'write-catalog' { 'write:catalog' }
		'write-plugins' { 'write:plugins' }
		'write-loops' { 'write:loops' }
		'write-swarm' { 'write:swarm' }
		'write-memory' { 'write:memory' }
		'write-projects' { 'write:projects' }
		'write-dc' { 'write:dc' }
		'write-mcp' { 'write:mcp' }
		'write-workspace' { 'write:workspace' }
		else { '' }
	}
}

const mutating_substrings = ['run', 'start', 'schedule', 'sync', 'add', 'queue', 'setup', 'clone',
	'remove', 'install', 'update', 'uninstall', 'scan', 'emit']
const destructive = ['uninstall', 'install', 'plugin', 'build', 'doctor', 'mcp', 'skills', 'project',
	'devcompanion', 'swarm', 'workspace']
const read_only = ['help', 'version', 'inventory', 'matrix', 'diff', 'doctor']

fn is_mutating(cmd Cmd) bool {
	if cmd.name in read_only {
		return false
	}
	fs := cmd.effects.filesystem
	if fs.contains('write') || fs.contains('delete') || fs.contains('update') {
		return true
	}
	for s in mutating_substrings {
		if cmd.name.contains(s) {
			return true
		}
	}
	return cmd.name in destructive
}

fn scope_for(cmd Cmd) string {
	if !is_mutating(cmd) {
		return 'read:*'
	}
	fs := cmd.effects.filesystem
	for key in ['write-profiles-receipts', 'update-profiles-cache', 'delete-owned-files', 'optional-fix-writes', 'write-catalog', 'write-plugins', 'write-loops', 'write-swarm', 'write-memory', 'write-projects', 'write-dc', 'write-mcp', 'write-workspace'] {
		if fs.contains(key) {
			return scope_by_effect(key)
		}
	}
	// fallback by command group
	return match cmd.name {
		'loop' { 'write:loops' }
		'swarm' { 'write:swarm' }
		'memory' { 'write:memory' }
		'project' { 'write:projects' }
		'devcompanion' { 'write:dc' }
		'mcp' { 'write:mcp' }
		'plugin' { 'write:plugins' }
		'skills' { 'write:catalog' }
		'build' { 'write:plugins' }
		'workspace' { 'write:workspace' }
		'install' { 'write:fs' }
		'update' { 'write:fs' }
		'uninstall' { 'write:fs' }
		'doctor' { 'write:fs' }
		else { 'write:*' }
	}
}

fn needs_confirm(cmd Cmd) bool {
	return is_mutating(cmd) && cmd.name in destructive
}

struct Route {
	method string
	path   string
}

fn route_for(cmd Cmd) Route {
	n := cmd.name
	if n == 'help' {
		return Route{'GET', '/api/v1/help'}
	}
	if n == 'version' {
		return Route{'GET', '/api/v1/version'}
	}
	if n == 'completion' {
		return Route{'GET', '/api/v1/completion/{shell}'}
	}
	if n == 'loop' {
		return Route{'POST', '/api/v1/loops/{sub}'}
	}
	if n == 'swarm' {
		return Route{'POST', '/api/v1/swarms/{sub}'}
	}
	if n == 'workspace' {
		if is_mutating(cmd) {
			return Route{'POST', '/api/v1/workspace/{sub}'}
		}
		return Route{'GET', '/api/v1/workspace/context'}
	}
	if n == 'project' {
		return Route{'POST', '/api/v1/project/{sub}'}
	}
	if n == 'devcompanion' {
		return Route{'POST', '/api/v1/dc/{sub}'}
	}
	if n == 'memory' {
		return Route{'POST', '/api/v1/memory/{sub}'}
	}
	if n == 'mcp' {
		return Route{'POST', '/api/v1/mcp/{sub}'}
	}
	if n == 'plugin' {
		return Route{'POST', '/api/v1/plugin/{sub}'}
	}
	if n == 'skills' {
		return Route{'POST', '/api/v1/skills/{sub}'}
	}
	if is_mutating(cmd) {
		return Route{'POST', '/api/v1/${n}'}
	}
	return Route{'GET', '/api/v1/${n}'}
}

fn op_object(operation_id string, summary string, tag string, scope string, confirm bool, responses JObj) JObj {
	mut op := jobj()
	op.put('operationId', JStr{operation_id})
	op.put('summary', JStr{summary})
	op.put('tags', JArr{[JVal(JStr{tag})]})
	op.put('x-scope', JStr{scope})
	op.put('x-confirm-required', JBool{confirm})
	op.put('responses', responses)
	return op
}

fn std_responses() JObj {
	mut r := jobj()
	for code, desc in {'200': 'ok', '403': 'scope denied', '428': 'confirm required'} {
		mut o := jobj()
		o.put('description', JStr{desc})
		r.put(code, o)
	}
	return r
}

fn gen_openapi(contract Contract, version string) JObj {
	mut paths := jobj()
	for cmd in contract.commands {
		if !cmd_api(cmd) {
			// Human/CLI-only capability (ADR-030): no programmatic surface.
			continue
		}
		route := route_for(cmd)
		summary := if cmd.summary.len > 0 { cmd.summary } else { cmd.name }
		tag := if cmd.surface.len > 0 { cmd.surface } else { 'misc' }
		op := op_object(cmd.name, summary, tag, scope_for(cmd), needs_confirm(cmd),
			std_responses())
		if paths.has(route.path) {
			mut existing := paths.get(route.path) or { jobj() }
			if mut existing is JObj {
				existing.put(route.method.to_lower(), op)
				paths.put(route.path, existing)
			}
		} else {
			mut methods := jobj()
			methods.put(route.method.to_lower(), op)
			paths.put(route.path, methods)
		}
	}
	// Server-native infrastructure endpoints (ADR-030): capabilities of the
	// API itself, not mirrors of CLI contract commands.
	native := [
		['/api/v1/health', 'get', 'health'],
		['/api/v1/openapi.json', 'get', 'get_openapi'],
		['/api/v1/selfcheck', 'get', 'selfcheck'],
		['/api/v1/jobs', 'post', 'create_job'],
		['/api/v1/jobs/{id}/log', 'get', 'get_job_log'],
		['/api/v1/jobs/{id}/events', 'get', 'stream_job_events'],
		['/api/v1/doctor/fix', 'post', 'doctor_fix'],
		['/api/v1/loops/{name}/status', 'get', 'loop_status_by_name'],
		['/api/v1/loops/{name}/run', 'post', 'run_loop_by_name'],
		['/api/v1/loops/{name}/schedule', 'post', 'schedule_loop_by_name'],
		['/api/v1/swarms', 'get', 'list_swarms'],
		['/api/v1/loops', 'get', 'list_loops'],
	]
	for entry in native {
		path, method, op_id := entry[0], entry[1], entry[2]
		if paths.has(path) {
			continue
		}
		mut r := jobj()
		mut ok := jobj()
		ok.put('description', JStr{'OK'})
		r.put('200', ok)
		scope := if method == 'get' { 'read:*' } else { 'write:*' }
		// Native ops carry no tags key (mirrors the retired generator).
		mut bare := jobj()
		bare.put('operationId', JStr{op_id})
		bare.put('summary', JStr{'Server-native endpoint (${op_id})'})
		bare.put('x-scope', JStr{scope})
		bare.put('x-confirm-required', JBool{false})
		bare.put('responses', r)
		mut methods := jobj()
		methods.put(method, bare)
		paths.put(path, methods)
	}
	mut doc := jobj()
	doc.put('openapi', JStr{'3.1.0'})
	mut info := jobj()
	info.put('title', JStr{'agent-toolkit serve API'})
	info.put('version', JStr{version})
	info.put('description', JStr{'Generated from docs/compatibility/cli-contract.yaml — do not hand-edit.'})
	doc.put('info', info)
	doc.put('paths', paths)
	return doc
}

// ---------------------------------------------------------------------------
// CLI help markdown
// ---------------------------------------------------------------------------

fn gen_help_md(contract Contract) string {
	mut groups := map[string][]Cmd{}
	mut group_order := []string{}
	for cmd in contract.commands {
		g := if cmd.surface.len > 0 { cmd.surface } else { 'misc' }
		if g !in groups {
			groups[g] = []Cmd{}
			group_order << g
		}
		groups[g] << cmd
	}
	mut lines := [
		'# agent-toolkit CLI reference',
		'',
		'_Generated from docs/compatibility/cli-contract.yaml — do not hand-edit._',
		'',
	]
	mut order := ['meta', 'consumer', 'advanced']
	for g in group_order {
		if g !in order {
			order << g
		}
	}
	for g in order {
		if g !in groups {
			continue
		}
		mut cmds := groups[g].clone()
		cmds.sort(a.name < b.name)
		if cmds.len == 0 {
			continue
		}
		lines << '## ${g}'
		lines << ''
		lines << '| Command | Summary | Flags | Scope |'
		lines << '|---|---|---|---|'
		for c in cmds {
			flags := if c.flags.len > 0 { '`${c.flags.join('` `')}`' } else { '—' }
			lines << '| `${c.name}` | ${c.summary} | ${flags} | `${scope_for(c)}` |'
		}
		lines << ''
	}
	return lines.join('\n') + '\n'
}

// ---------------------------------------------------------------------------
// CLI_SURFACES.md cross-check (#969): every contract command must appear as
// a `| `name` |` table cell. Mirrors the retired regex \| `([^`]+)` \|.
// ---------------------------------------------------------------------------

fn surfaces_cells(text string) map[string]bool {
	mut found := map[string]bool{}
	for line in text.split_into_lines() {
		// Exact scan for every `| `name` |` cell on the line.
		mut idx := 0
		for idx < line.len {
			rel := line[idx..].index('| `') or { break }
			name_start := idx + rel + '| `'.len
			name_end_rel := line[name_start..].index('`') or { break }
			name_end := name_start + name_end_rel
			after := line[name_end + 1..]
			if after.starts_with(' |') {
				found[line[name_start..name_end]] = true
			}
			idx = name_end + 1
		}
	}
	return found
}

fn repo_root() string {
	mut d := os.dir(@FILE)
	// scripts/ -> repo root
	d = os.dir(d)
	if os.is_file(os.join_path(d, 'VERSION')) {
		return d
	}
	return os.getwd()
}

fn main() {
	check := '--check' in os.args
	root := repo_root()
	contract_path := os.join_path(root, 'docs', 'compatibility', 'cli-contract.yaml')
	contract_text := os.read_file(contract_path) or {
		eprintln('cannot read ${contract_path}: ${err}')
		exit(2)
	}
	contract := yaml.decode[Contract](contract_text) or {
		eprintln('cannot parse ${contract_path}: ${err}')
		exit(2)
	}
	out_dir := os.join_path(root, 'docs', 'surface')
	os.mkdir_all(out_dir) or {}

	mut stale := []string{}

	// Validate CLI_SURFACES.md contains every contract command (SSOT #969).
	mut contract_names := map[string]bool{}
	for c in contract.commands {
		contract_names[c.name] = true
	}
	surfaces_path := os.join_path(root, 'docs', 'CLI_SURFACES.md')
	if os.is_file(surfaces_path) {
		surfaces_text := os.read_file(surfaces_path) or { '' }
		found := surfaces_cells(surfaces_text)
		mut missing := []string{}
		for name in contract_names.keys() {
			if name !in found {
				missing << name
			}
		}
		missing.sort()
		if missing.len > 0 {
			stale << 'docs/CLI_SURFACES.md (missing contract commands: ${missing.join(', ')})'
			if !check {
				println('warning: docs/CLI_SURFACES.md missing ${missing} — update manually or regenerate')
			}
		}
	}

	version := os.read_file(os.join_path(root, 'VERSION')) or { '' }.trim_space()
	openapi_text := enc(gen_openapi(contract, version), 0) + '\n'
	artifacts := {
		os.join_path(out_dir, 'openapi.json'): openapi_text
		os.join_path(out_dir, 'cli-help.md'):  gen_help_md(contract)
	}
	for path, content in artifacts {
		os.mkdir_all(os.dir(path)) or {}
		current := os.read_file(path) or { '' }
		has := os.is_file(path) || os.is_link(path)
		if !has || current != content {
			stale << rel_to_root(root, path)
			if !check {
				os.write_file(path, content) or {
					eprintln('cannot write ${path}: ${err}')
					exit(1)
				}
				println('wrote ${rel_to_root(root, path)}')
			}
		}
	}
	// Legacy dist/surface handling: canonical is docs/surface per ADR-030.
	// Any file under dist/surface that is not a symlink to canonical must go.
	dist_surface := os.join_path(root, 'dist', 'surface')
	retired := os.join_path(dist_surface, 'web_nav.json')
	if os.is_file(retired) || os.is_link(retired) {
		stale << rel_to_root(root, retired) + ' (retired per ADR-030)'
		if !check {
			os.rm(retired) or {}
			println('removed retired ${rel_to_root(root, retired)}')
		}
	}
	legacy_files := [
		[os.join_path(dist_surface, 'cli-help.md'), os.join_path(out_dir, 'cli-help.md')],
		[os.join_path(dist_surface, 'openapi.json'), os.join_path(out_dir, 'openapi.json')],
	]
	for pair in legacy_files {
		legacy, canonical := pair[0], pair[1]
		if !(os.is_file(legacy) || os.is_link(legacy)) {
			continue
		}
		if os.is_link(legacy) {
			target := os.readlink(legacy) or { '' }
			resolved := if os.is_abs_path(target) {
				target
			} else {
				os.join_path(os.dir(legacy), target)
			}
			if os.real_path(resolved) != os.real_path(canonical) {
				stale << rel_to_root(root, legacy) + ' (symlink target mismatch)'
				if !check && os.is_file(canonical) {
					os.rm(legacy) or {}
					os.symlink('../../docs/surface/${os.file_name(canonical)}', legacy) or {}
					println('fixed symlink ${rel_to_root(root, legacy)} -> ../../docs/surface/${os.file_name(canonical)}')
				}
			}
		} else if os.is_file(canonical) {
			legacy_content := os.read_file(legacy) or { '' }
			canonical_content := os.read_file(canonical) or { '###missing###' }
			if legacy_content != canonical_content {
				stale << rel_to_root(root, legacy) + ' (diverged from docs/surface/${os.file_name(canonical)})'
				if !check {
					os.rm(legacy) or {}
					println('removed stale ${rel_to_root(root, legacy)} (canonical is docs/surface/${os.file_name(canonical)})')
				}
			}
		}
	}
	if stale.len > 0 {
		mode := if check { 'stale' } else { 'updated' }
		println('${mode}: ${stale.join(', ')}')
		if check {
			println('Run: ./scripts/generate_surface.vsh')
			exit(1)
		}
	} else {
		println('surface artifacts up to date')
	}
}

fn rel_to_root(root string, path string) string {
	if path.starts_with(root + os.path_separator) {
		return path[root.len + 1..]
	}
	return path
}
