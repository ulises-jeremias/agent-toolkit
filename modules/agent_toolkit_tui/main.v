module agent_toolkit_tui

import os

pub fn run_tui(opts TuiOptions) int {
	ws := if opts.workspace_path.len > 0 { opts.workspace_path } else { os.getwd() }
	loops := list_loops(ws)
	dashboard := render_dashboard(loops, ws)
	println(dashboard)
	println('')
	println('TUI MVP — interactive mode requires bobatea integration (Phase 6b).')
	println('For now, this is the dashboard preview. Use CLI for full interaction.')
	return 0
}
