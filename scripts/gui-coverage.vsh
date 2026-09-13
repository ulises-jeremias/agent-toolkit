#!/usr/bin/env -S v run
// gui-coverage.vsh — critical product workflow coverage report for the
// Desktop (V port of scripts/gui-coverage.py).
//
// Since the shared action/entity registry (#1119), the typed registry (modules/desktop/palette/registry.v +
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
//   v run scripts/gui-coverage.vsh            # print report
//   v run scripts/gui-coverage.vsh --check    # exit 1 if a workflow is unbacked
import os

struct Workflow {
	needs   []string
	gate_fn string
}

fn workflows() map[string]Workflow {
	return {
		'discover skill': Workflow{['build_skill_entries', 'skills_catalog'], 'test_workflow_skill_discovery_install'}
		'inspect skill (deep link)': Workflow{['deep_link_select'], 'test_workflow_skill_discovery_install'}
		'install skill where supported': Workflow{['skill_install'], 'test_workflow_skill_discovery_install'}
		'remove skill (config truth)': Workflow{['skill_remove'], 'test_workflow_skill_discovery_install'}
		'discover agent': Workflow{['build_agent_entries', 'agents_catalog'], 'test_workflow_agent_discovery'}
		'inspect agent': Workflow{['build_agent_entries'], 'test_workflow_agent_discovery'}
		'discover target': Workflow{['build_target_entries'], 'test_workflow_target_discovery_install_toggle'}
		'install target where supported': Workflow{['target_install', 'target_install_supported'], 'test_workflow_target_discovery_install_toggle'}
		'enable/disable target': Workflow{['target_enable', 'target_disable', 'set_target_enabled'], 'test_workflow_target_discovery_install_toggle'}
		'discover MCP provider': Workflow{['build_mcp_entries'], 'test_workflow_mcp_discovery_toggle_probe'}
		'enable/disable provider': Workflow{['mcp_enable', 'mcp_disable'], 'test_workflow_mcp_discovery_toggle_probe'}
		'probe provider': Workflow{['mcp_probe'], 'test_workflow_mcp_discovery_toggle_probe'}
		'Doctor preview repair': Workflow{['doctor_fix_preview'], 'test_workflow_doctor_preview_repair'}
		'Doctor execute repair': Workflow{['doctor_repair', 'doctor_fix('], 'test_workflow_doctor_preview_repair'}
		'run loop': Workflow{['loop_run', 'run_loop('], 'test_workflow_loop_run'}
		'toggle loop schedule': Workflow{['loop_schedule_toggle', 'toggle_loop_cron('], 'test_workflow_loop_run'}
		'launch/request swarm': Workflow{['swarm_launch('], 'test_workflow_swarm_launch'}
		'navigate primary surfaces': Workflow{['production_nav_panels', 'build_nav_entries'], 'test_workflow_skill_discovery_install'}
		'application: theme': Workflow{['app_theme_cycle'], 'test_workflow_app_level_actions'}
		'application: update (honest unavailability)': Workflow{['app_update_check'], 'test_workflow_app_level_actions'}
		'application: uninstall (preview+confirm)': Workflow{['app_uninstall', 'uninstall_targets'], 'test_workflow_app_level_actions'}
	}
}

fn read_file(path string) string {
	return os.read_file(path) or { '' }
}

// strip_v_comments removes // line comments so removed-name mentions in
// comments don't count as code.
fn strip_v_comments(src string) string {
	mut out := []string{}
	for line in src.split('\n') {
		out << line.split('//')[0]
	}
	return out.join('\n')
}

fn is_ident_char(c u8) bool {
	return c.is_letter() || (c >= `0` && c <= `9`) || c == `_`
}

fn is_lower_ident(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `_`
}

// v_declarations collects actual V function declarations, enum members and
// consts. It works on comment-stripped source and matches declarations —
// not arbitrary substrings — so a commented-out function can never satisfy
// the report.
fn v_declarations(src string) map[string]bool {
	mut out := map[string]bool{}
	for line in src.split('\n') {
		s := line.trim_space()
		rest := if s.starts_with('pub fn ') {
			s[7..]
		} else if s.starts_with('fn ') {
			s[3..]
		} else {
			''
		}
		if rest != '' {
			// skip a receiver: fn (mut a App) name(
			name_src := if rest.starts_with('(') {
				closing := rest.index(')') or { -1 }
				if closing < 0 {
					continue
				}
				rest[closing + 1..].trim_space()
			} else {
				rest
			}
			mut name := ''
			for c in name_src {
				if is_ident_char(c) {
					name += c.ascii_str()
				} else {
					break
				}
			}
			if name != '' && name_src[name.len..].trim_space().starts_with('(') {
				out[name] = true
				continue
			}
		}
		// enum members are bare `name` lines with an optional trailing comma
		// (matches the oracle's `([a-z_0-9]+),?` fullmatch, quirks included)
		ecand := if s.ends_with(',') { s[..s.len - 1].trim_space() } else { s }
		if ecand != '' && !ecand.contains(' ') && !ecand.contains('\t') && !ecand.contains('(') {
			mut eok := true
			for c in ecand {
				if !is_lower_ident(c) {
					eok = false
					break
				}
			}
			if eok {
				out[ecand] = true
				continue
			}
		}
		if s.starts_with('const ') {
			cand := s[6..].split('=')[0].trim_space().split(' ')[0].trim_space()
			mut ok := cand != ''
			for c in cand {
				if !is_lower_ident(c) {
					ok = false
					break
				}
			}
			if ok {
				out[cand] = true
			}
		}
	}
	return out
}

fn run() int {
	root := os.dir(os.dir(os.real_path(@FILE)))
	reg_raw := read_file(os.join_path(root, 'modules', 'desktop', 'palette', 'registry.v'))
	act_raw := read_file(os.join_path(root, 'modules', 'desktop', 'palette', 'actions.v'))
	gate_raw := read_file(os.join_path(root, 'cmd', 'agent-toolkit-desktop', 'registry_reachability_test.v'))
	main_src := strip_v_comments(read_file(os.join_path(root, 'cmd', 'agent-toolkit-desktop',
		'main.v')))
	if reg_raw == '' || act_raw == '' {
		eprintln('error: registry/action definitions not found')
		return 2
	}
	// declarations/members only — commented-out code never counts. The
	// backing universe includes the typed Engine seams the actions invoke.
	mut backing := map[string]bool{}
	mut calls := ''
	mut seam_files := [os.join_path(root, 'modules', 'desktop', 'palette', 'registry.v'),
		os.join_path(root, 'modules', 'desktop', 'palette', 'actions.v'),
		os.join_path(root, 'cmd', 'agent-toolkit-desktop', 'main.v')]
	entries := os.ls(os.join_path(root, 'modules', 'desktop_engine')) or { []string{} }
	for e in entries {
		if e.ends_with('.v') {
			seam_files << os.join_path(root, 'modules', 'desktop_engine', e)
		}
	}
	for p in seam_files {
		src := read_file(p)
		for k, _ in v_declarations(strip_v_comments(src)) {
			backing[k] = true
		}
		calls += strip_v_comments(src) + '\n'
	}

	wf := workflows()
	mut names := wf.keys()
	names.sort()
	mut rows := []string{}
	mut missing := []string{}
	gate_fns := v_declarations(strip_v_comments(gate_raw))
	for name in names {
		w := wf[name]
		mut unbacked := []string{}
		for n in w.needs {
			if n.ends_with('(') {
				if !calls.contains(n) {
					unbacked << n
				}
			} else if n !in backing {
				unbacked << n
			}
		}
		mut status := ''
		mut via := ''
		if unbacked.len > 0 {
			status = 'MISSING'
			via = unbacked.join(',')
			missing << name
		} else if w.gate_fn in gate_fns {
			status = 'covered'
			via = 'reachability gate'
		} else {
			status = 'backed'
			via = 'registry definitions (gate function missing)'
			missing << name
		}
		mark := if status != 'MISSING' { '✅' } else { '⚠️' }
		rows << '| ${mark} ${name} | ${status} | ${via} |'
	}

	total := rows.len
	covered := total - missing.len
	println('# Critical workflow coverage — ${covered}/${total} workflows backed\n')
	println('| Workflow | Status | Via |')
	println('|---|---|---|')
	for row in rows {
		println(row)
	}

	// The production shell must consume the registry — no static command authority.
	mut legacy := []string{}
	for token in ['palette_items', 'struct PaletteItem', 'palette_best_score'] {
		if main_src.contains(token) {
			legacy << token
		}
	}
	if legacy.len > 0 {
		legacy.sort()
		println('\n⚠️ legacy palette authority still present in production: ' + legacy.join(', '))
		missing << 'legacy authority retirement'
	} else {
		println('\n✅ static palette authority fully retired from the production shell')
	}

	raw := os.args.clone()
	if raw.contains('--check') && missing.len > 0 {
		eprintln('\nFAIL: ${missing.len} workflow coverage gap(s)')
		return 1
	}
	return 0
}

fn main() {
	exit(run())
}
