module desktop_engine

// Thin typed Engine adapter over the core receipt-based
// uninstall domain operation. Desktop actions never shell out to the CLI:
// core's run_uninstall removes ONLY toolkit-owned (`created`) artifacts
// recorded in real install receipts, explicitly skips `merged` (user-touched)
// files with a reason, refuses path escapes, supports a real dry-run, and
// returns a structured report with partial-failure detail.

import agent_toolkit_core

// uninstall_candidates returns the targets that currently have real install
// receipts under the default receipt authority. Availability truth for the
// registry's uninstall action comes from here, not from assumptions.
pub fn (mut e Engine) uninstall_candidates() []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	return agent_toolkit_core.discover_uninstall_tools('')
}

// uninstall_targets runs the core receipt-based uninstall for the given
// targets (empty = discover all). dry_run produces the real preview without
// deleting anything. The structured report is passed through unchanged —
// partial failures are never translated into full success by the Engine.
pub fn (mut e Engine) uninstall_targets(tools []string, dry_run bool) agent_toolkit_core.UninstallReport {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	return agent_toolkit_core.run_uninstall(agent_toolkit_core.UninstallOptions{
		tools: tools
		dry_run: dry_run
	})
}
