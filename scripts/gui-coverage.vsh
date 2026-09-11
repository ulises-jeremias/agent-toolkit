#!/usr/bin/env -S v run
// gui-coverage.vsh — critical product workflow coverage report for the Desktop.
//
// Since S4 (#1119), the typed registry (modules/desktop/palette/registry.v +
// actions.v) is the sole palette/search authority: the static palette_items()
// command list was deleted. This report therefore no longer asserts CLI→palette
// row parity. It reports how each **critical product workflow** is reachable
// through the registry, by consuming the registry/action definitions themselves.
//
// The authority is the V reachability gate:
//     cmd/agent-toolkit-desktop/registry_reachability_test.v
// run by `./make.vsh test` inside Required CI (Check V Modules). This script is
// an advisory, human-readable view of the same contract — it never gates.
//
// Usage:
//   ./scripts/gui-coverage.vsh            # print report
//   ./scripts/gui-coverage.vsh --check    # exit 1 if a workflow is unbacked

import os

struct Workflow {
	name    string
	needs   []string
	gate_fn string
}

// Critical product workflow → (registry constructs that must exist, the
// reachability-gate function that proves it). Tokens are V identifiers as
// they literally appear in the registry/action definitions.
fn workflows() []Workflow {
	return [
		Workflow{'discover skill', ['build_skill_entries', 'skills_catalog'], 'test_workflow_skill_discovery_install'},
		Workflow{'inspect skill (deep link)', ['deep_link_select'], 'test_workflow_skill_discovery_install'},
		Workflow{'install skill where supported', ['skill_install'], 'test_workflow_skill_discovery_install'},
		Workflow{'remove skill (config truth)', ['skill_remove'], 'test_workflow_skill_discovery_install'},
		Workflow{'discover agent', ['build_agent_entries', 'agents_catalog'], 'test_workflow_agent_discovery'},
		Workflow{'inspect agent', ['build_agent_entries'], 'test_workflow_agent_discovery'},
		Workflow{'discover target', ['build_target_entries'], 'test_workflow_target_discovery_install_toggle'},
		Workflow{'install target where supported', ['target_install', 'target_install_supported'], 'test_workflow_target_discovery_install_toggle'},
		Workflow{'enable/disable target', ['target_enable', 'target_disable', 'set_target_enabled'], 'test_workflow_target_discovery_install_toggle'},
		Workflow{'discover MCP provider', ['build_mcp_entries'], 'test_workflow_mcp_discovery_toggle_probe'},
		Workflow{'enable/disable provider', ['mcp_enable', 'mcp_disable'], 'test_workflow_mcp_discovery_toggle_probe'},
		Workflow{'probe provider', ['mcp_probe'], 'test_workflow_mcp_discovery_toggle_probe'},
		Workflow{'Doctor preview repair', ['doctor_fix_preview'], 'test_workflow_doctor_preview_repair'},
		Workflow{'Doctor execute repair', ['doctor_repair', 'doctor_fix('], 'test_workflow_doctor_preview_repair'},
		Workflow{'run loop', ['loop_run', 'run_loop('], 'test_workflow_loop_run'},
		Workflow{'toggle loop schedule', ['loop_schedule_toggle', 'toggle_loop_cron('], 'test_workflow_loop_run'},
		Workflow{'launch/request swarm', ['swarm_launch('], 'test_workflow_swarm_launch'},
		Workflow{'navigate primary surfaces', ['production_nav_panels', 'build_nav_entries'], 'test_workflow_skill_discovery_install'},
		Workflow{'application: theme', ['app_theme_cycle'], 'test_workflow_app_level_actions'},
		Workflow{'application: update (honest unavailability)', ['app_update_check'], 'test_workflow_app_level_actions'},
		Workflow{'application: uninstall (preview+confirm)', ['app_uninstall', 'uninstall_targets'], 'test_workflow_app_level_actions'},
	]
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

fn read_or_empty(path string) string {
	return os.read_file(path) or { '' }
}

// strip_v_comments removes // line comments so removed-name mentions in
// comments never count as code (mirrors the retired .py split('//')[0]).
fn strip_v_comments(src string) string {
	mut out := []string{}
	for line in src.split_into_lines() {
		out << line.split('//')[0]
	}
	return out.join('\n')
}

fn is_ident(s string) bool {
	if s.len == 0 {
		return false
	}
	for c in s {
		if !(c.is_alnum() || c == `_`) {
			return false
		}
	}
	return true
}

fn is_lower_ident(s string) bool {
	if s.len == 0 {
		return false
	}
	for c in s {
		if !(c >= `a` && c <= `z`) && !(c >= `0` && c <= `9`) && c != `_` {
			return false
		}
	}
	return true
}

// v_declarations collects actual V function declarations, enum members and
// consts — declarations, not arbitrary substrings, so commented-out code
// (stripped beforehand) can never satisfy the report.
fn v_declarations(src string) map[string]bool {
	mut out := map[string]bool{}
	for line in src.split_into_lines() {
		mut s := line.trim_space()
		if s.starts_with('pub ') {
			s = s['pub '.len..].trim_space()
		}
		if s.starts_with('fn ') {
			rest := s['fn '.len..].trim_space()
			after_recv := if rest.starts_with('(') {
				recv_end := rest.index(')') or { -1 }
				if recv_end < 0 {
					continue
				}
				rest[recv_end + 1..].trim_space()
			} else {
				rest
			}
			paren_at := after_recv.index('(') or { continue }
			name := after_recv[..paren_at].trim_space()
			// V method shorthand `fn (r T) name(` — Python's regex also
			// captures the receiver-adjacent name; keep parity: the token
			// before `(` after an optional receiver is the declaration.
			if is_ident(name) {
				out[name] = true
			}
			continue
		}
		// enum member: `name,` or `name`
		core := if s.ends_with(',') { s[..s.len - 1] } else { s }
		if is_lower_ident(core) && !s.contains(' ') && !s.contains('\t') {
			out[core] = true
			continue
		}
		if s.starts_with('const ') {
			rest := s['const '.len..].trim_space()
			eq := rest.index('=') or { continue }
			name := rest[..eq].trim_space()
			if is_lower_ident(name) {
				out[name] = true
			}
		}
	}
	return out
}

fn main() {
	root := repo_root()
	reg_path := os.join_path(root, 'modules', 'desktop', 'palette', 'registry.v')
	act_path := os.join_path(root, 'modules', 'desktop', 'palette', 'actions.v')
	main_path := os.join_path(root, 'cmd', 'agent-toolkit-desktop', 'main.v')
	gate_path := os.join_path(root, 'cmd', 'agent-toolkit-desktop', 'registry_reachability_test.v')
	reg_raw := read_or_empty(reg_path)
	act_raw := read_or_empty(act_path)
	gate_raw := read_or_empty(gate_path)
	main_src := strip_v_comments(read_or_empty(main_path))
	if reg_raw == '' || act_raw == '' {
		eprintln('error: registry/action definitions not found')
		exit(2)
	}
	// declarations/members only — commented-out code never counts. The
	// backing universe includes the typed Engine seams the actions invoke.
	mut backing := map[string]bool{}
	mut calls := ''
	mut seam_files := []string{}
	for f in (os.ls(os.join_path(root, 'modules', 'desktop_engine')) or { []string{} }) {
		if f.ends_with('.v') {
			seam_files << os.join_path(root, 'modules', 'desktop_engine', f)
		}
	}
	seam_files.sort()
	for p in [reg_path, act_path, main_path, ...seam_files] {
		src := read_or_empty(p)
		for name in v_declarations(src).keys() {
			backing[name] = true
		}
		calls += strip_v_comments(src) + '\n'
	}

	mut names := []string{}
	mut by_name := map[string]Workflow{}
	for wf in workflows() {
		names << wf.name
		by_name[wf.name] = wf
	}
	names.sort()
	gate_fns := v_declarations(gate_raw)
	mut rows := [][]string{}
	mut missing := []string{}
	for name in names {
		wf := by_name[name]
		mut unbacked := []string{}
		for n in wf.needs {
			if n.ends_with('(') {
				if !calls.contains(n) {
					unbacked << n
				}
			} else if n !in backing {
				unbacked << n
			}
		}
		gated := wf.gate_fn in gate_fns
		mut status := ''
		mut via := ''
		if unbacked.len > 0 {
			status = 'MISSING'
			via = unbacked.join(',')
			missing << name
		} else if gated {
			status = 'covered'
			via = 'reachability gate'
		} else {
			status = 'backed'
			via = 'registry definitions (gate function missing)'
			missing << name
		}
		rows << [name, status, via]
	}

	total := rows.len
	covered := total - missing.len
	println('# Critical workflow coverage — ${covered}/${total} workflows backed\n')
	println('| Workflow | Status | Via |')
	println('|---|---|---|')
	for row in rows {
		mark := if row[1] != 'MISSING' { '✅' } else { '⚠️' }
		println('| ${mark} ${row[0]} | ${row[1]} | ${row[2]} |')
	}

	// The production shell must consume the registry — no static command authority.
	mut legacy_found := []string{}
	for legacy in ['palette_items', 'struct PaletteItem', 'palette_best_score'] {
		if main_src.contains(legacy) {
			legacy_found << legacy
		}
	}
	if legacy_found.len > 0 {
		legacy_found.sort()
		println('\n⚠️ legacy palette authority still present in production: ' +
			legacy_found.join(', '))
		missing << 'legacy authority retirement'
	} else {
		println('\n✅ static palette authority fully retired from the production shell')
	}

	if '--check' in os.args && missing.len > 0 {
		eprintln('\nFAIL: ${missing.len} workflow coverage gap(s)')
		exit(1)
	}
}
