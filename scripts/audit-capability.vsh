#!/usr/bin/env -S v run
// Static supply-chain audit for capabilities (per #378).
// Usage:
//   v run scripts/audit-capability.vsh [path ...]
//   v run scripts/audit-capability.vsh --json skills/design/
//   v run scripts/audit-capability.vsh --fail-on high

import json
import regex

struct Finding {
	file  string
	line  int
	rule  string
	label string
	match string
}

struct Pattern {
	key   string
	pat   string
	label string
}

fn repo_root() string {
	mut d := dir(@FILE)
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

fn should_skip(path string, root string) bool {
	rel := if path.starts_with(root) { path[root.len..].trim_string_left('/') } else { path }
	parts := rel.split('/')
	skip_dirs := ['.git', '.venv', '__pycache__', 'node_modules', '.ruff_cache', '.mypy_cache']
	for p in parts {
		if p in skip_dirs {
			return true
		}
	}
	ext := file_ext(path)
	if ext in ['.pyc', '.png', '.jpg', '.svg'] {
		return true
	}
	return false
}

fn collect_files(path string, root string) []string {
	mut out := []string{}
	if is_file(path) {
		if !should_skip(path, root) {
			out << path
		}
		return out
	}
	if !is_dir(path) {
		return out
	}
	for name in ls(path) or { []string{} } {
		p := join_path(path, name)
		if is_dir(p) {
			if should_skip(p, root) {
				continue
			}
			out << collect_files(p, root)
		} else if is_file(p) && !should_skip(p, root) {
			out << p
		}
	}
	return out
}

fn audit_path(path string, root string, patterns []Pattern) []Finding {
	mut findings := []Finding{}
	files := collect_files(path, root)
	for f in files {
		text := read_file(f) or { continue }
		rel := if f.starts_with(root.trim_right('/') + '/') {
			f[(root.trim_right('/') + '/').len..]
		} else {
			f
		}
		for pat in patterns {
			mut re := regex.regex_opt(pat.pat) or { continue }
			mut start := 0
			for {
				// find next match via replace scan is awkward; use find_all
				m := re.find_all(text[start..])
				if m.len < 2 {
					break
				}
				abs_start := start + m[0]
				abs_end := start + m[1]
				line_no := text[..abs_start].count('\n') + 1
				matched := text[abs_start..abs_end]
				clip := if matched.len > 80 { matched[..80] } else { matched }
				findings << Finding{
					file:  rel
					line:  line_no
					rule:  pat.key
					label: pat.label
					match: clip
				}
				start = abs_end
				if start >= text.len {
					break
				}
			}
		}
	}
	return findings
}

fn main() {
	root := repo_root()
	mut json_out := false
	mut fail_on := 'never'
	mut paths := []string{}
	for a in args[1..] {
		if a == '--json' {
			json_out = true
			continue
		}
		if a == '--fail-on' {
			continue
		}
		if a in ['high', 'never'] && paths.len == 0 && fail_on == 'never' && '--fail-on' in args {
			// handled below
		}
		if a.starts_with('--') {
			continue
		}
		paths << a
	}
	// parse --fail-on value
	for i, a in args {
		if a == '--fail-on' && i + 1 < args.len {
			fail_on = args[i + 1]
		}
	}
	if paths.len == 0 {
		paths = ['skills', 'mcp']
	}

	patterns := [
		Pattern{'shell_curl', r'\bcurl\b', 'network: curl'},
		Pattern{'shell_wget', r'\bwget\b', 'network: wget'},
		Pattern{'shell_npx', r'\bnpx\b', 'network: npx'},
		Pattern{'shell_npm', r'\bnpm\s+(install|exec|run)\b', 'shell: npm'},
		Pattern{'shell_pip', r'\bpip[3]?\b', 'shell: pip'},
		Pattern{'shell_uv', r'\buv\s+(pip|run|exec)\b', 'shell: uv'},
		Pattern{'shell_docker', r'\bdocker\b', 'shell: docker'},
		Pattern{'shell_sh_c', r'\bsh\s+-c\b|\bbash\s+-c\b', 'shell: sh -c'},
		Pattern{'shell_rm_rf', r'rm\s+-rf', 'destructive: rm -rf'},
		Pattern{'shell_git_push', r'git\s+push.*main|push.*default', 'destructive: push to default'},
		Pattern{'network_raw_main', r'raw\.githubusercontent.*main', 'mutable fetch: raw.*main'},
		Pattern{'network_main_fragment', r'ref:\s*main\b', 'mutable ref: main'},
		Pattern{'hook', r'hooks?:', 'hook registration'},
		Pattern{'mcp', r'mcp/registry|mcp\.json', 'MCP reference'},
		Pattern{'env_secret', r'(SECRET|TOKEN|KEY|PASSWORD)\s*[:=]', 'possible credential'},
		Pattern{'dangerous_skip', r'skipDangerousMode|dangerouslySkipPermissions', 'dangerous: skip permission prompt'},
	]

	mut all_findings := []Finding{}
	for p in paths {
		mut path := p
		if !is_abs_path(path) {
			path = join_path(root, p)
		}
		if !exists(path) {
			path = join_path(root, p)
		}
		if !exists(path) {
			println('warn: not found ${p}')
			continue
		}
		all_findings << audit_path(path, root, patterns)
	}

	high_rules := ['shell_rm_rf', 'shell_git_push', 'network_raw_main', 'dangerous_skip']
	mut high := []Finding{}
	for f in all_findings {
		if f.rule in high_rules {
			high << f
		}
	}

	if json_out {
		println(json.encode({
			'findings': all_findings
			'high':     high
		}))
	} else {
		if all_findings.len == 0 {
			println('audit-capability: no static findings (checked patterns: shell/curl/MCP/hooks/env).')
		} else {
			for f in all_findings {
				println('${f.file}:${f.line}: [${f.rule}] ${f.label}: ${f.match}')
			}
			println('\n${all_findings.len} finding(s), ${high.len} high-severity.')
			if high.len > 0 {
				println('High: raw.*main, rm -rf, push default, skip permission prompt — requires human review before merge.')
			}
		}
	}
	if fail_on == 'high' && high.len > 0 {
		exit(2)
	}
}
