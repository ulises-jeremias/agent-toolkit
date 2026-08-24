module agent_toolkit_tui

// TUI MVP — Dashboard + Loop Detail + Doctor screens.
// In-process core calls (no HTTP), offline-first per ADR-494.

import agent_toolkit_core
import os
import time

pub struct TuiOptions {
pub:
	workspace_path string
}

pub struct LoopInfo {
pub:
	name        string
	tier        string
	cadence     string
	last_status string
	runs_count  int
}

pub fn list_loops(workspace string) []LoopInfo {
	mut out := []LoopInfo{}
	dir := os.join_path(workspace, 'loops')
	if !os.is_dir(dir) {
		return out
	}
	for entry in os.ls(dir) or { []string{} } {
		loop_dir := os.join_path(dir, entry)
		yaml_path := os.join_path(loop_dir, 'loop.yaml')
		if !os.is_file(yaml_path) {
			continue
		}
		text := os.read_file(yaml_path) or { continue }
		mut tier := 'L1'
		mut cadence := '?'
		for line in text.split_into_lines() {
			t := line.trim_space()
			if t.starts_with('tier:') {
				tier = t.all_after('tier:').trim_space()
			} else if t.starts_with('cadence:') {
				cadence = t.all_after('cadence:').trim_space().trim('"')
			}
		}
		state_path := os.join_path(loop_dir, 'STATE.md')
		mut status := 'not_run'
		if os.is_file(state_path) {
			state_text := os.read_file(state_path) or { '' }
			for sl in state_text.split_into_lines() {
				if sl.trim_space().starts_with('last_run_status:') {
					status = sl.all_after('last_run_status:').trim_space()
					break
				}
			}
		}
		out << LoopInfo{
			name:        entry
			tier:        tier
			cadence:     cadence
			last_status: status
		}
	}
	return out
}

pub fn doctor_summary(workspace string) string {
	snap := agent_toolkit_core.run_doctor_readonly()
	return snap.message
}

pub fn render_dashboard(loops []LoopInfo, workspace string) string {
	ver := agent_toolkit_core.resolve_toolkit_version()
	now := time.utc().format_rfc3339()[..10]
	mut lines := []string{}
	lines << '╭─────────────────────────────────────────────────────╮'
	lines << '│  agent-toolkit TUI — ${ver}  (${now})'
	lines << '│  workspace: ${workspace}'
	lines << '├─────────────────────────────────────────────────────┤'
	lines << '│  Loops                                              │'
	lines << '│  ─────                                              │'
	for lp in loops {
		name_pad := lp.name + ' '.repeat(20 - lp.name.len)
		tier_pad := lp.tier + ' '.repeat(4 - lp.tier.len)
		cad_pad := lp.cadence + ' '.repeat(8 - lp.cadence.len)
		lines << '│  ${name_pad} ${tier_pad} ${cad_pad} ${lp.last_status}'
	}
	lines << '│                                                     │'
	lines << '│  [r]un  [s]tatus  [a]udit  [q]uit                   │'
	lines << '╰─────────────────────────────────────────────────────╯'
	return lines.join('\n')
}
