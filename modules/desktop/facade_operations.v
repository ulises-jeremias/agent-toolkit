module desktop

import desktop_engine

// facade_operations — Slice B: Operations run control + queued guidance.
//
// Thin Desktop proxies over Engine typed APIs. Every method delegates to the
// Engine (single writer via Transaction→Revision→EventBus); the facade never
// shells out, never invents state, and returns Engine errors verbatim so the
// Operations view can report real outcomes.
//
// Deliberately absent: pause / steer / halt. The Engine proves no such
// operation (no pause/resume/steer/halt exists in desktop_engine), so the
// view omits those controls rather than drawing dead buttons. Tracked as a
// backend dependency, not a facade gap.
// Deliberately absent: scheduler installation. toggle_loop_cron flips a
// configuration flag only — there is no scheduler daemon, and the view must
// render the cron value as a flag, never as an installed timer.
// Deliberately absent: CI providers and currency. Budgets render in tokens.

// ── jobs ────────────────────────────────────────────────────────────────────

// engine_spawn_job queues a supervised job and returns its Engine id.
pub fn (mut d Desktop) engine_spawn_job(cmd string, args []string) !string {
	return d.engine.spawn_job(cmd, args)
}

// ── swarms: run control ─────────────────────────────────────────────────────

// swarm_stop cancels a run via the Engine (worktree hygiene kept by Engine).
pub fn (mut d Desktop) swarm_stop(run_id string) !u64 {
	return d.engine.swarm_stop(run_id)
}

// swarm_cancel_run is the cancel alias via the Engine.
pub fn (mut d Desktop) swarm_cancel_run(run_id string) !u64 {
	return d.engine.swarm_cancel(run_id)
}

// swarm_report builds the typed per-run report (none when unknown).
pub fn (mut d Desktop) swarm_report(run_id string) ?desktop_engine.SwarmReportView {
	return d.engine.swarm_report_view(run_id)
}

// swarm_graph derives the role graph from recorded handoffs.
pub fn (mut d Desktop) swarm_graph(run_id string) desktop_engine.SwarmGraphView {
	return d.engine.swarm_graph_view(run_id)
}

// swarm_watch renders the one-line status snapshot for a run.
pub fn (mut d Desktop) swarm_watch(run_id string) string {
	return d.engine.swarm_watch_line(run_id)
}

// swarm_promote raises a run one recipe step (pair→team→full).
pub fn (mut d Desktop) swarm_promote(run_id string, to_recipe string) !u64 {
	return d.engine.swarm_promote_run(run_id, to_recipe)
}

// swarm_prune_preview lists terminal runs older than the cutoff.
pub fn (mut d Desktop) swarm_prune_preview(older_than_days int) []string {
	return d.engine.swarm_prune_preview(older_than_days)
}

// swarm_prune reclaims one terminal run (worktrees removed, artifacts kept).
pub fn (mut d Desktop) swarm_prune(run_id string) !u64 {
	return d.engine.swarm_prune_run(run_id)
}

// swarm_pruned_at returns the recorded prune stamp ('' when never pruned).
pub fn (mut d Desktop) swarm_pruned_at(run_id string) string {
	return d.engine.swarm_pruned_at(run_id)
}

// swarm_task_next returns the oldest queued handoff touching a role.
pub fn (mut d Desktop) swarm_task_next(run_id string, role string) ?desktop_engine.SwarmTaskView {
	return d.engine.swarm_task_next(run_id, role)
}

// swarm_queued_tasks lists the mailbox task backlog shown per run.
pub fn (mut d Desktop) swarm_queued_tasks(run_id string) []desktop_engine.SwarmTaskView {
	return d.engine.swarm_queued_tasks(run_id)
}

// swarm_task_done marks a queued handoff complete via the Engine.
pub fn (mut d Desktop) swarm_task_done(run_id string, handoff_id string) !u64 {
	return d.engine.swarm_task_complete(run_id, handoff_id)
}

// swarm_budget_line renders the human budget string for a run.
pub fn (mut d Desktop) swarm_budget_line(run_id string) string {
	return d.engine.swarm_budget_display(run_id)
}

// swarm_run_artifacts lists artifacts+handoffs+approvals+provenance per run.
pub fn (mut d Desktop) swarm_run_artifacts(run_id string) map[string][]string {
	return d.engine.swarm_artifacts_display(run_id)
}

// ── loops ───────────────────────────────────────────────────────────────────

// engine_create_loop creates a loop template (cron flag off at creation).
pub fn (mut d Desktop) engine_create_loop(name string, tier string, cadence string, goal string) !u64 {
	return d.engine.create_loop(name, tier, cadence, goal)
}

// engine_delete_loop deletes a loop template via the Engine.
pub fn (mut d Desktop) engine_delete_loop(name string) !u64 {
	return d.engine.delete_loop(name)
}

// engine_loop_validate runs the Engine validator and returns diagnostics.
pub fn (mut d Desktop) engine_loop_validate(name string, content string) []desktop_engine.BuildDiagnostic {
	return d.engine.loop_validate(name, content)
}

// engine_loop_audit returns the Engine audit ledger for a loop.
pub fn (mut d Desktop) engine_loop_audit(name string) []desktop_engine.LoopAudit {
	return d.engine.loops_audit(name)
}

// engine_loop_cost returns the Engine cost view (none when unknown).
pub fn (mut d Desktop) engine_loop_cost(name string) ?desktop_engine.LoopCost {
	return d.engine.loops_cost(name)
}

// engine_loop_budget_line renders the human budget string for a loop.
pub fn (mut d Desktop) engine_loop_budget_line(name string) string {
	return d.engine.loops_budget_display(name)
}

// engine_loop_receipts returns provenance receipts attributed to a loop.
pub fn (mut d Desktop) engine_loop_receipts(name string) []desktop_engine.ProvenanceEntry {
	return d.engine.loop_receipts(name)
}

// engine_loop_start starts a supervised loop run via the Engine.
pub fn (mut d Desktop) engine_loop_start(name string) !string {
	return d.engine.loops_start(name)
}

// engine_loop_stop stops a loop run via the Engine.
pub fn (mut d Desktop) engine_loop_stop(name string) !u64 {
	return d.engine.loops_stop(name)
}

// engine_loop_schedule_state renders the cron value as a configuration flag.
// There is no scheduler daemon: 'scheduled' always means the flag is set,
// never that a timer is installed.
pub fn (mut d Desktop) engine_loop_schedule_state(name string) string {
	for e in d.engine.loops_catalog() {
		if e.name == name {
			if e.cron_enabled {
				return 'cron ${e.schedule} · flag only (no scheduler daemon)'
			}
			return 'On demand'
		}
	}
	return 'unknown loop: ${name}'
}
