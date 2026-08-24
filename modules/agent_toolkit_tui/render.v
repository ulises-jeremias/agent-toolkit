module agent_toolkit_tui

import agent_toolkit_core
import os

// render_screen dispatches to the appropriate screen renderer.
pub fn render_screen(current string, loops []LoopInfo, workspace string, selected int) string {
	return match current {
		'loops' { render_loops_detail(loops, workspace, selected) }
		'skills' { render_skills(workspace, selected) }
		'doctor' { render_doctor(workspace) }
		'help' { render_help(workspace) }
		else { render_dashboard(loops, workspace) }
	}
}

// render_loops_detail shows loop list with selection highlight and detail pane.
pub fn render_loops_detail(loops []LoopInfo, workspace string, selected int) string {
	ver := agent_toolkit_core.resolve_toolkit_version()
	mut lines := []string{}
	lines << ansi('╭─ Loops ─────────────────────────────────────────────╮', '35')
	lines << '│  workspace: ${pad_right(workspace, 38)} │'
	lines << '│  toolkit: ${pad_right(ver, 40)} │'
	lines << '├─────────────────────────────────────────────────────┤'
	if loops.len == 0 {
		lines << '│  (no loops found — run `agent-toolkit loop init <pattern>`) │'
	} else {
		for idx, lp in loops {
			tier_c := ansi(pad_right(lp.tier, 4), color_for_tier(lp.tier))
			name_d := pad_right(lp.name, 20)
			cad_d := pad_right(lp.cadence, 8)
			status_d := pad_right(lp.last_status, 12)
			mut row := '│  ${name_d} ${tier_c} ${cad_d} ${status_d} │'
			if idx == selected {
				row = '\x1b[7m${row}\x1b[0m'
			}
			lines << row
		}
		lines << '├─────────────────────────────────────────────────────┤'
		if selected >= 0 && selected < loops.len {
			sel := loops[selected]
			lines << '│  Selected: ${ansi(sel.name, "36")} (${sel.tier} • ${sel.cadence})            │'
			lines << '│  Status: ${sel.last_status}  Runs: ${sel.runs_count}                         │'
			loop_dir := os.join_path(workspace, 'loops', sel.name)
			yaml_path := os.join_path(loop_dir, 'loop.yaml')
			md_path := os.join_path(loop_dir, 'LOOP.md')
			mut text_path := ''
			if os.is_file(yaml_path) {
				text_path = yaml_path
			} else if os.is_file(md_path) {
				text_path = md_path
			}
			if text_path.len > 0 {
				text := os.read_file(text_path) or { '' }
				mut goal := ''
				for line in text.split_into_lines() {
					t := line.trim_space()
					if t.starts_with('goal:') {
						goal = t.all_after('goal:').trim_space().trim('|').trim_space()
						if goal.len > 42 {
							goal = goal[..42] + '...'
						}
						break
					}
				}
				if goal.len > 0 {
					lines << '│  Goal: ${pad_right(goal, 42)} │'
				}
			}
			lines << '│  ${ansi("r:run (no-llm)  enter:detail  j/k:nav", "90")}          │'
		}
	}
	lines << '│  ${ansi("[1]dash [2]loops [3]skills [4]doctor [h]elp [q]uit", "90")} │'
	lines << ansi('╰─────────────────────────────────────────────────────╯', '35')
	return lines.join('\n')
}

// render_skills shows inventory summary grouped by domain.
pub fn render_skills(workspace string, selected int) string {
	mut lines := []string{}
	lines << ansi('╭─ Skills ────────────────────────────────────────────╮', '35')
	lines << '│  workspace: ${pad_right(workspace, 38)} │'
	lines << '├─────────────────────────────────────────────────────┤'
	// Try toolkit root lookup first, then workspace
	mut root := agent_toolkit_core.lookup_checkout_root()
	if root.len == 0 {
		root = workspace
	}
	// If still not found, try to walk up from workspace
	if !os.is_dir(os.join_path(root, 'skills')) {
		if os.is_dir(os.join_path(workspace, 'skills')) {
			root = workspace
		}
	}
	if !os.is_dir(os.join_path(root, 'skills')) {
		lines << '│  (skills not found — check AGENT_TOOLKIT_ROOT)        │'
	} else {
		snap := agent_toolkit_core.load_inventory_at(root) or {
			lines << '│  error: ${pad_right(err.msg(), 42)} │'
			lines << ansi('╰─────────────────────────────────────────────────────╯', '35')
			return lines.join('\n')
		}
		lines << '│  Skills: ${snap.skill_count} across ${snap.domain_count} domains                │'
		lines << '│  Agents: ${snap.agent_count}  Products: ${snap.product_count}                    │'
		lines << '├─────────────────────────────────────────────────────┤'
		// Show message lines truncated to box
		for raw in snap.message.split_into_lines() {
			if raw.trim_space().len == 0 {
				continue
			}
			if raw.contains('═══') || raw.contains('──') {
				continue
			}
			mut clean := raw.trim_space()
			if clean.len > 52 {
				clean = clean[..52]
			}
			lines << '│  ${pad_right(clean, 52)} │'
			if lines.len > 22 {
				lines << '│  ... (truncated, use `skills list` for full)         │'
				break
			}
		}
	}
	lines << '│                                                     │'
	lines << '│  ${ansi("[1]dash [2]loops [3]skills [4]doctor [h]elp [q]uit", "90")} │'
	lines << ansi('╰─────────────────────────────────────────────────────╯', '35')
	return lines.join('\n')
}

// render_doctor shows doctor checks with colored status.
pub fn render_doctor(workspace string) string {
	snap := agent_toolkit_core.run_doctor_readonly()
	mut lines := []string{}
	lines << ansi('╭─ Doctor ────────────────────────────────────────────╮', '35')
	lines << '│  ${ansi("agent-toolkit doctor", "36")}  v${snap.version}  ${snap.platform} │'
	lines << '├─────────────────────────────────────────────────────┤'
	if snap.ok {
		lines << '│  ${ansi("✓ All checks passed", "32")}                                   │'
	} else {
		lines << '│  ${ansi("✗ Issues detected", "31")}                                    │'
	}
	lines << '├─────────────────────────────────────────────────────┤'
	for c in snap.checks {
		status_c := match c.status {
			'ok' { ansi('✓', '32') }
			'warn' { ansi('!', '33') }
			'err' { ansi('✗', '31') }
			else { c.status }
		}
		name_d := pad_right(c.name, 14)
		detail := truncate(c.detail, 30)
		lines << '│  ${status_c} ${name_d} ${pad_right(detail, 30)} │'
	}
	lines << '│                                                     │'
	// Show message excerpt
	for raw in snap.message.split_into_lines() {
		mut t := raw.trim_space()
		if t.len == 0 || t.starts_with('──') || t.starts_with('══') {
			continue
		}
		if t.contains('agent-toolkit doctor') {
			continue
		}
		if t.len > 52 {
			t = t[..52]
		}
		if t.len > 0 && lines.len < 30 {
			// avoid duplicating check lines already shown
		}
	}
	lines << '│  ${ansi("[1]dash [2]loops [3]skills [4]doctor [h]elp [q]uit", "90")} │'
	lines << ansi('╰─────────────────────────────────────────────────────╯', '35')
	return lines.join('\n')
}

// render_help shows key bindings and navigation.
pub fn render_help(workspace string) string {
	mut lines := []string{}
	lines << ansi('╭─ Help ──────────────────────────────────────────────╮', '35')
	lines << '│  ${ansi("agent-toolkit TUI — Keyboard Reference", "36")}           │'
	lines << '├─────────────────────────────────────────────────────┤'
	lines << '│  Screens:                                           │'
	lines << '│    ${ansi("1", "33")}  dashboard  (overview + header)                    │'
	lines << '│    ${ansi("2", "33")}  loops      (browser + detail + run)              │'
	lines << '│    ${ansi("3", "33")}  skills     (inventory grouped by domain)         │'
	lines << '│    ${ansi("4", "33")}  doctor     (health checks)                       │'
	lines << '│    ${ansi("h", "33")}, ${ansi("?", "33")}  help (this screen)                                │'
	lines << '│                                                     │'
	lines << '│  Navigation:                                        │'
	lines << '│    ${ansi("j / down", "32")}  next item                                  │'
	lines << '│    ${ansi("k / up", "32")}    previous item                              │'
	lines << '│    ${ansi("r / enter", "32")} run selected loop (no-llm, safe)          │'
	lines << '│    ${ansi("q / quit / exit", "31")}  quit TUI                               │'
	lines << '│                                                     │'
	lines << '│  Workspace:                                         │'
	lines << '│    ${pad_right(workspace, 52)} │'
	lines << '│  Flag: --workspace PATH (else AGENT_TOOLKIT_       │'
	lines << '│  WORKSPACE / HARNESS_DIR / walk-up loops/.git)    │'
	lines << '│  Loops: loop.yaml or legacy LOOP.md; empty →      │'
	lines << '│  bundled loops                                     │'
	lines << '│                                                     │'
	lines << '│  Tips:                                              │'
	lines << '│    • Colors: L1 ${ansi("green", "32")} L2 ${ansi("yellow", "33")} L3 ${ansi("red", "31")}                         │'
	lines << '│    • Selection uses reverse video (highlight)       │'
	lines << '│    • Use CLI for full control: --json, --workspace │'
	lines << '│                                                     │'
	lines << '│  ${ansi("[1]dash [2]loops [3]skills [4]doctor [h]elp [q]uit", "90")} │'
	lines << ansi('╰─────────────────────────────────────────────────────╯', '35')
	return lines.join('\n')
}
