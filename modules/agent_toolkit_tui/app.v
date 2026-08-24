module agent_toolkit_tui

// Interactive TUI with polling-based screens. No external deps needed.
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

pub struct SkillInfo {
pub:
	name   string
	domain string
}

fn loops_dir(workspace string) string {
	return os.join_path(workspace, 'loops')
}

pub fn list_loops(workspace string) []LoopInfo {
	mut out := []LoopInfo{}
	dir := loops_dir(workspace)
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
		mut runs := 0
		if os.is_file(state_path) {
			state_text := os.read_file(state_path) or { '' }
			for sl in state_text.split_into_lines() {
				st := sl.trim_space()
				if st.starts_with('last_run_status:') {
					status = st.all_after('last_run_status:').trim_space()
				}
			}
		}
		runs_dir := os.join_path(loop_dir, 'runs')
		if os.is_dir(runs_dir) {
			runs = os.ls(runs_dir) or { []string{} }.len
		}
		out << LoopInfo{
			name:        entry
			tier:        tier
			cadence:     cadence
			last_status: status
			runs_count:  runs
		}
	}
	return out
}

pub fn list_skills(workspace string) []SkillInfo {
	mut out := []SkillInfo{}
	skills_dir := os.join_path(workspace, 'skills')
	if !os.is_dir(skills_dir) {
		return out
	}
	for domain in os.ls(skills_dir) or { []string{} } {
		domain_path := os.join_path(skills_dir, domain)
		if !os.is_dir(domain_path) {
			continue
		}
		for skill in os.ls(domain_path) or { []string{} } {
			if os.is_file(os.join_path(domain_path, skill, 'SKILL.md')) {
				out << SkillInfo{ name: skill, domain: domain }
			}
		}
	}
	out.sort(lambda a, b SkillInfo { a.domain < b.domain || (a.domain == b.domain && a.name < b.name) })
	return out
}

pub fn doctor_summary() string {
	snap := agent_toolkit_core.run_doctor_readonly()
	return snap.message
}

fn read_loop_detail(workspace string, name string) string {
	yaml := os.join_path(loops_dir(workspace), name, 'loop.yaml')
	return os.read_file(yaml) or { 'loop.yaml not found' }
}

fn pad(s string, width int) string {
	if s.len >= width {
		return s[..width]
	}
	return s + ' '.repeat(width - s.len)
}

// ---------- Screens ----------

fn screen_dashboard(ver string, workspace string, loops []LoopInfo) string {
	now := time.utc().format_rfc3339()[..16]
	mut lines := []string{}
	lines << '╔══════════════════════════════════════════════════════════╗'
	lines << '║  agent-toolkit TUI — ${pad('${ver} (${now})', 47)} ║'
	lines << '║  workspace: ${pad(workspace, 42)} ║'
	lines << '╠══════════════════════════════════════════════════════════╣'
	lines << '║  LOOPS                                                   ║'
	lines << '╠──────────────────────────────────────────────────────────╣'
	lines << '║  ${pad('Name', 20)} ${pad('Tier', 5)}${pad('Cadence', 9)} ${pad('Status', 12)} Runs'
	lines << '║  ${pad('─' * 20, 20)} ${pad('─' * 4, 5)}${pad('─' * 8, 9)} ${pad('─' * 11, 12)} ────'
	for lp in loops {
		lines << '║  ${pad(lp.name, 20)} ${pad(lp.tier, 5)}${pad(lp.cadence, 9)} ${pad(lp.last_status, 12)} ${lp.runs_count}'
	}
	lines << '╠──────────────────────────────────────────────────────────╣'
	lines << '║  Keys: [1] Loops  [2] Skills  [3] Doctor  [r] Run  [q] Quit ║'
	lines << '╚══════════════════════════════════════════════════════════╝'
	return lines.join('\n')
}

fn screen_skills(skills []SkillInfo) string {
	mut lines := []string{}
	lines << '╔══════════════════════════════════════════════════════════╗'
	lines << '║  SKILLS                                                  ║'
	lines << '╠══════════════════════════════════════════════════════════╣'
	lines << '║  ${pad('Domain', 22)} ${pad('Skill', 32)}'
	lines << '║  ${pad('─' * 21, 22)} ${pad('─' * 31, 32)}'
	prev_domain := ''
	for sk in skills {
		if sk.domain != prev_domain && prev_domain.len > 0 {
			lines << '║'
		}
		lines << '║  ${pad(sk.domain + '/', 22)} ${sk.name}'
	}
	lines << '╠──────────────────────────────────────────────────────────╣'
	lines << '║  [b]ack to dashboard                                     ║'
	lines << '╚══════════════════════════════════════════════════════════╝'
	return lines.join('\n')
}

fn screen_doctor(summary string) string {
	mut lines := []string{}
	lines << '╔══════════════════════════════════════════════════════════╗'
	lines << '║  DOCTOR                                                  ║'
	lines << '╠══════════════════════════════════════════════════════════╣'
	for line in summary.split_into_lines() {
		lines << '║  ${line}'
	}
	lines << '╠══════════════════════════════════════════════════════════╣'
	lines << '║  [b]ack to dashboard                                     ║'
	lines << '╚══════════════════════════════════════════════════════════╝'
	return lines.join('\n')
}

fn screen_loop_detail(workspace string, loop_name string) string {
	detail := read_loop_detail(workspace, loop_name)
	mut lines := []string{}
	lines << '╔══════════════════════════════════════════════════════════╗'
	lines << '║  LOOP: ${loop_name}'
	lines << '╠══════════════════════════════════════════════════════════╣'
	for line in detail.split_into_lines() {
		lines << '║  ${line}'
	}
	lines << '╠══════════════════════════════════════════════════════════╣'
	lines << '║  [r]un  [b]ack                                           ║'
	lines << '╚══════════════════════════════════════════════════════════╝'
	return lines.join('\n')
}

// ---------- Main interactive loop ----------

pub fn run_tui_interactive(opts TuiOptions) int {
	ws := if opts.workspace_path.len > 0 { opts.workspace_path } else { os.getwd() }
	ver := agent_toolkit_core.resolve_toolkit_version()

	println('agent-toolkit TUI v${ver}')
	println('')

	for {
		loops := list_loops(ws)
		print(screen_dashboard(ver, ws, loops))
		print('> ')
		input := os.input('').trim_space()

		match input {
			'q', 'quit', 'exit' {
				println('Bye!')
				return 0
			}
			'2', 'skills' {
				skills := list_skills(ws)
				println(screen_skills(skills))
				os.input('Press Enter to go back...')
			}
			'3', 'doctor' {
				summary := doctor_summary(ws)
				println(screen_doctor(summary))
				os.input('Press Enter to go back...')
			}
			'r', 'run' {
				println('Enter loop name:')
				print('> ')
				loop_name := os.input('').trim_space()
				if loop_name.len > 0 {
					println('Running ${loop_name}...')
					res := agent_toolkit_core.run_loop(agent_toolkit_core.LoopOptions{
						subcommand:     'run'
						workspace_path: ws
						name:           loop_name
						no_llm:         true
					})
					println(res.message)
				}
			}
			else {
				// Check if input matches a loop name → show detail
				loop_names := loops.map(it.name)
				if input in loop_names {
					println(screen_loop_detail(ws, input))
					os.input('Press Enter to go back...')
				} else if input == '1' || input == 'loops' || input.len == 0 {
					continue // re-render dashboard
				} else if input.starts_with('run ') {
					run_name := input.all_after('run ').trim_space()
					if run_name.len > 0 {
						println('Running ${run_name}...')
						res := agent_toolkit_core.run_loop(agent_toolkit_core.LoopOptions{
							subcommand:     'run'
							workspace_path: ws
							name:           run_name
							no_llm:         true
						})
						println(res.message)
					}
				}
			}
		}
	}
	return 0
}
