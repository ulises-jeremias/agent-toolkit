module main

import desktop
import desktop_engine

// Office attention surface (slice A): domain projection + viewmodel + input.
// Empty/loading/success/partial/failure/recovery, all from real Engine
// record shapes — nothing fabricated.

fn office_test_jobs() []desktop_engine.JobRecord {
	return [
		desktop_engine.JobRecord{
			id: 'job-run-1'
			cmd: 'make build'
			status: .running
			work_dir: '/tmp/shop'
		},
		desktop_engine.JobRecord{
			id: 'job-wait-1'
			cmd: 'make serve'
			status: .queued
		},
		desktop_engine.JobRecord{
			id: 'job-fail-1'
			cmd: 'make test'
			args: ['--fast']
			status: .failed
			exit_code: 2
			duration_ms: 4200
		},
		desktop_engine.JobRecord{
			id: 'job-done-1'
			cmd: 'make lint'
			status: .done
			exit_code: 0
			duration_ms: 900
			finished_at: 200
			started_at: 100
			logs: ['ok']
		},
	]
}

fn office_test_swarms() []desktop_engine.SwarmRun {
	return [
		desktop_engine.SwarmRun{
			id: 'run-gated'
			recipe: .pair
			backend: .herdr
			task: 'fix checkout'
			status: .awaiting_approval
			worktree: '/tmp/shop/wt1'
		},
		desktop_engine.SwarmRun{
			id: 'run-live'
			recipe: .team
			backend: .tmux
			task: 'nightly triage'
			status: .running
			created_at: 300
		},
	]
}

fn office_test_approvals() []desktop_engine.SwarmApproval {
	return [
		desktop_engine.SwarmApproval{
			id: 'appr-1'
			run_id: 'run-gated'
			kind: .spend
			message: 'spend 4 credits'
			status: .pending
			budget_cost: 4
		},
		desktop_engine.SwarmApproval{
			id: 'appr-old'
			run_id: 'run-live'
			kind: .scope
			message: 'widen scope'
			status: .approved
		},
	]
}

fn test_office_empty_engine_projects_nothing() {
	rows := desktop.office_project_runs([], [], [], [], true)
	assert rows.len == 0
	assert desktop.office_pending_approvals([], fn (run_id string) string {
		return run_id
	}).len == 0
	assert desktop.office_recent_completions([], [], [], 5).len == 0
}

fn test_office_loading_state_without_desktop() {
	mut app := &GuiApp{}
	snap := office_attention_snapshot(mut app)
	assert !snap.engine_live
	assert snap.rows.len == 0
	assert snap.approvals.len == 0
	assert snap.completions.len == 0
	assert office_selected_row(app, snap.rows) == -1
}

fn test_office_job_states_resolve_from_engine_status() {
	rows := desktop.office_project_runs(office_test_jobs(), [], [], [], true)
	mut by_id := map[string]desktop.OfficeRunRow{}
	for r in rows {
		by_id[r.id] = r
	}
	assert by_id['job-run-1'].state.key() == 'running'
	assert by_id['job-wait-1'].state.key() == 'waiting'
	assert by_id['job-fail-1'].state.key() == 'failed'
	assert by_id['job-done-1'].state.key() == 'idle'
	// only the failed run wants attention
	assert by_id['job-fail-1'].attention
	assert !by_id['job-run-1'].attention
	assert !by_id['job-wait-1'].attention
	assert !by_id['job-done-1'].attention
}

fn test_office_waiting_is_not_blocked_is_not_needs_me() {
	swarms := [
		desktop_engine.SwarmRun{
			id: 's-wait'
			recipe: .pair
			backend: .auto
			status: .requested
		},
		desktop_engine.SwarmRun{
			id: 's-need'
			recipe: .pair
			backend: .auto
			status: .awaiting_approval
		},
		desktop_engine.SwarmRun{
			id: 's-blocked'
			recipe: .team
			backend: .tmux
			status: .running
			budget_total: 10
			budget_spent: 10
		},
		desktop_engine.SwarmRun{
			id: 's-fail'
			recipe: .team
			backend: .tmux
			status: .failed
			budget_total: 10
			budget_spent: 10
		},
	]
	appr := [
		desktop_engine.SwarmApproval{
			id: 'a-x'
			run_id: 's-fail'
			kind: .destructive
			status: .pending
		},
	]
	rows := desktop.office_project_runs([], swarms, [], appr, true)
	mut by_id := map[string]desktop.OfficeRunRow{}
	for r in rows {
		by_id[r.id] = r
	}
	assert by_id['s-wait'].state.key() == 'waiting'
	assert by_id['s-need'].state.key() == 'needs-me'
	assert by_id['s-blocked'].state.key() == 'blocked'
	// failure outranks budget and approval noise
	assert by_id['s-fail'].state.key() == 'failed'
	assert by_id['s-need'].approval_id == ''
	assert by_id['s-blocked'].attention && by_id['s-need'].attention
	assert !by_id['s-wait'].attention
}

fn test_office_pending_approval_gates_running_swarm() {
	swarms := [
		desktop_engine.SwarmRun{
			id: 'run-live'
			recipe: .team
			backend: .tmux
			status: .running
		},
	]
	appr := [
		desktop_engine.SwarmApproval{
			id: 'a-9'
			run_id: 'run-live'
			kind: .scope
			message: 'touch refunds'
			status: .pending
		},
	]
	rows := desktop.office_project_runs([], swarms, [], appr, true)
	assert rows.len == 1
	assert rows[0].state.key() == 'needs-me'
	assert rows[0].approval_id == 'a-9'
	assert rows[0].attention
}

fn test_office_unknown_stays_unknown() {
	// unrecognized loop history statuses are unknown, never guessed
	histories := [
		desktop_engine.LoopHistory{
			run_id: 'h-1'
			loop_name: 'nightly'
			status: 'mystery-status'
		},
	]
	rows := desktop.office_project_runs([], [], histories, [], true)
	assert rows.len == 1
	assert rows[0].state.key() == 'unknown'
	assert !rows[0].attention
	assert desktop.office_run_actions(rows[0]).len == 0
	assert desktop.office_no_actions_hint(rows[0]).contains('unknown')
	// a running claim the supervisor does not back is unknown, not running
	jobs := [
		desktop_engine.JobRecord{
			id: 'ghost'
			cmd: 'serve'
			status: .running
		},
	]
	ghost := desktop.office_project_runs(jobs, [], [], [], false)
	assert ghost[0].state.key() == 'unknown'
	assert !ghost[0].attention
}

fn test_office_run_rows_carry_only_proven_attribution() {
	rows := desktop.office_project_runs(office_test_jobs(), office_test_swarms(), [], office_test_approvals(), true)
	for r in rows {
		// no Engine record carries agent or provider/model attribution
		assert r.agent == ''
		assert r.provider_model == ''
	}
	mut by_id := map[string]desktop.OfficeRunRow{}
	for r in rows {
		by_id[r.id] = r
	}
	assert by_id['job-run-1'].workspace == '/tmp/shop'
	assert by_id['job-fail-1'].activity.contains('--fast')
	assert by_id['run-gated'].workspace == '/tmp/shop/wt1'
	assert by_id['run-gated'].activity.contains('pair')
	assert by_id['run-live'].title == 'nightly triage'
}

fn test_office_approvals_are_projection_over_queue() {
	items := desktop.office_pending_approvals(office_test_approvals(), fn (run_id string) string {
		return 'title:${run_id}'
	})
	// decided gates stay in the domain; only pending projects
	assert items.len == 1
	assert items[0].id == 'appr-1'
	assert items[0].kind == 'spend'
	assert items[0].run_title == 'title:run-gated'
	assert items[0].budget_cost == 4
	// an approval for a run that no longer lists still surfaces
	stray := [
		desktop_engine.SwarmApproval{
			id: 'a-stray'
			run_id: 'gone'
			kind: .scope
			status: .pending
		},
	]
	stray_items := desktop.office_pending_approvals(stray, fn (run_id string) string {
		return run_id
	})
	assert stray_items.len == 1 && stray_items[0].run_id == 'gone'
}

fn test_office_attention_orders_hot_first_stable() {
	rows := desktop.office_project_runs(office_test_jobs(), office_test_swarms(), [], office_test_approvals(), true)
	assert rows.len == 6
	// hot first: failed job, gated swarm — Engine order kept within bands
	assert rows[0].id == 'job-fail-1'
	assert rows[1].id == 'run-gated'
	assert rows[0].attention && rows[1].attention
	for r in rows[2..] {
		assert !r.attention
	}
}

fn test_office_recent_completions_have_evidence_newest_first() {
	comps := desktop.office_recent_completions(office_test_jobs(), office_test_swarms(), [], 5)
	// only successes complete: done job (failed/running/queued excluded)
	assert comps.len == 1
	assert comps[0].id == 'job-done-1'
	assert comps[0].detail.contains('done')
	assert comps[0].evidence.join(' ').contains('exit 0')
	// limit honored
	mut many := []desktop_engine.JobRecord{}
	for i in 0 .. 8 {
		many << desktop_engine.JobRecord{
			id: 'j-${i}'
			cmd: 'build'
			status: .done
			started_at: i
			finished_at: i
		}
	}
	capped := desktop.office_recent_completions(many, [], [], 5)
	assert capped.len == 5
	assert capped[0].id == 'j-7'
	assert capped[4].id == 'j-3'
}

fn test_office_loop_history_completions_and_failures() {
	histories := [
		desktop_engine.LoopHistory{
			run_id: 'h-ok'
			loop_name: 'nightly'
			status: 'completed'
			exit_condition: 'all green'
			duration_ms: 61000
			started_at: 50
		},
		desktop_engine.LoopHistory{
			run_id: 'h-bad'
			loop_name: 'nightly'
			status: 'failed'
			exit_condition: 'verifier red'
			started_at: 60
		},
	]
	comps := desktop.office_recent_completions([], [], histories, 5)
	assert comps.len == 1 && comps[0].id == 'h-ok'
	assert comps[0].detail == 'all green'
	rows := desktop.office_project_runs([], [], histories, [], true)
	mut by_id := map[string]desktop.OfficeRunRow{}
	for r in rows {
		by_id[r.id] = r
	}
	assert by_id['h-ok'].state.key() == 'idle'
	assert by_id['h-bad'].state.key() == 'failed'
	assert by_id['h-bad'].attention
}

fn test_office_actions_offer_only_currently_valid() {
	rows := desktop.office_project_runs(office_test_jobs(), office_test_swarms(), [], office_test_approvals(), true)
	mut by_id := map[string]desktop.OfficeRunRow{}
	for r in rows {
		by_id[r.id] = r
	}
	running := desktop.office_run_actions(by_id['job-run-1'])
	assert running.len == 1 && running[0].kind == 'cancel'
	assert running[0].engine_op == 'cancel_job'
	failed := desktop.office_run_actions(by_id['job-fail-1'])
	assert failed.len == 1 && failed[0].kind == 'retry'
	done := desktop.office_run_actions(by_id['job-done-1'])
	assert done.len == 1 && done[0].kind == 'retry'
	gated := desktop.office_run_actions(by_id['run-gated'])
	assert gated.len == 2
	assert gated[0].kind == 'approve' && gated[1].kind == 'reject'
	assert gated[0].engine_op == 'swarm_approve'
	// live swarm without a Desktop stop op: hidden, with the reason named
	live := desktop.office_run_actions(by_id['run-live'])
	assert live.len == 0
	assert desktop.office_no_actions_hint(by_id['run-live']).contains('engine_swarm_cancel')
	// rows with actions need no hint
	assert desktop.office_no_actions_hint(by_id['job-fail-1']) == ''
}

fn test_office_recovery_clears_needs_me_and_lands_completion() {
	swarms := [
		desktop_engine.SwarmRun{
			id: 'run-live'
			recipe: .team
			backend: .tmux
			status: .running
		},
	]
	appr := [
		desktop_engine.SwarmApproval{
			id: 'a-9'
			run_id: 'run-live'
			kind: .scope
			status: .pending
		},
	]
	gated := desktop.office_project_runs([], swarms, [], appr, true)
	assert gated[0].state.key() == 'needs-me'
	// approval resolved in the Engine → back to running
	clear := desktop.office_project_runs([], swarms, [], [], true)
	assert clear[0].state.key() == 'running'
	assert !clear[0].attention
	// run finishes → completion with evidence
	done_swarm := [
		desktop_engine.SwarmRun{
			id: 'run-live'
			recipe: .team
			backend: .tmux
			task: 'nightly triage'
			status: .completed
			created_at: 300
		},
	]
	comps := desktop.office_recent_completions([], done_swarm, [], 5)
	assert comps.len == 1 && comps[0].detail == 'completed'
}

fn test_office_selection_revalidates_against_live_rows() {
	mut app := &GuiApp{}
	rows := desktop.office_project_runs(office_test_jobs(), office_test_swarms(), [], [], true)
	assert office_selected_row(app, rows) == -1
	// job selection maps by Engine index, not row position
	mut job_at := -1
	for i, r in rows {
		if r.kind == 'job' && r.ref_idx == 0 {
			job_at = i
		}
	}
	app.jobs_selected = 0
	assert office_selected_row(app, rows) == job_at
	// stale indices never select
	app.jobs_selected = 99
	app.swarm_selected = 99
	app.selected_loop = 3
	assert office_selected_row(app, rows) == -1
	// swarm selection maps the same way
	mut swarm_at := -1
	for i, r in rows {
		if r.kind == 'swarm' && r.ref_idx == 1 {
			swarm_at = i
		}
	}
	app.jobs_selected = -1
	app.swarm_selected = 1
	assert office_selected_row(app, rows) == swarm_at
}

fn test_office_select_run_reports_evidence_and_hints() {
	mut app := &GuiApp{}
	rows := desktop.office_project_runs(office_test_jobs(), [], [], [], true)
	mut failed := desktop.OfficeRunRow{}
	for r in rows {
		if r.id == 'job-fail-1' {
			failed = r
		}
	}
	office_select_run(mut app, failed)
	assert app.jobs_selected == failed.ref_idx
	assert app.inspector_msg.contains('make test')
	assert app.inspector_msg.contains('Failed')
	assert app.inspector_msg.contains('exit 2')
	// a row with no valid action explains why instead of a dead button
	unknown_row := desktop.OfficeRunRow{
		kind: 'loop'
		id: 'h-1'
		title: 'nightly'
		state: .unknown
		loop_name: 'nightly'
	}
	office_select_run(mut app, unknown_row)
	assert app.inspector_msg.contains('State unknown')
}

fn test_office_attention_layout_caps_and_hit_rects() {
	l := OfficeLayout{
		side_x: 900
		side_w: 264
	}
	al := office_attention_layout(100, 600, 6, 4, 5, true)
	assert al.runs_cap == 4 && al.appr_cap == 3 && al.comp_cap == 3
	// run rects stay inside the column and do not overlap
	for i in 0 .. al.runs_cap {
		rx, ry, rw, rh := office_run_rect(l, al.y0, i)
		assert rx == 904 && rw == 256
		assert ry >= al.y0 && ry + rh <= al.y0 + al.runs_h
		if i > 0 {
			_, prev_y, _, prev_h := office_run_rect(l, al.y0, i - 1)
			assert ry >= prev_y + prev_h
		}
	}
	// action zone sits inside the runs section the draw path reserves
	ay := office_actions_y(al.y0, al.runs_cap)
	assert ay + 22 <= al.y0 + al.runs_h
	ax, _, aw, _ := office_action_rect(l, ay, 0, 2)
	assert ax >= l.side_x && ax + aw <= l.side_x + l.side_w
	// short windows shed completions first, then approvals overflow
	small := office_attention_layout(100, 200, 6, 4, 5, false)
	assert small.comp_cap < 3
	assert small.runs_cap >= 1
	assert small.appr_cap >= 1
	// sections never overlap
	assert small.appr_y >= small.y0 + small.runs_h
	assert small.comp_y >= small.appr_y + small.appr_h
}

fn test_office_partial_inputs_still_project() {
	// jobs only, no swarms or histories
	rows := desktop.office_project_runs(office_test_jobs(), [], [], [], true)
	assert rows.len == 4
	// approvals without runs still surface
	items := desktop.office_pending_approvals(office_test_approvals(), fn (run_id string) string {
		return run_id
	})
	assert items.len == 1
	text := office_approval_inspector_text(items[0])
	assert text.contains('spend') && text.contains('spend 4 credits')
	// completion evidence line renders
	comps := desktop.office_recent_completions(office_test_jobs(), [], [], 5)
	assert office_completion_inspector_text(comps[0]).contains('exit 0')
}

fn test_office_state_keys_cover_every_pill() {
	assert desktop.OfficeRunState.unknown.key() == 'unknown'
	assert desktop.OfficeRunState.idle.key() == 'idle'
	assert desktop.OfficeRunState.running.key() == 'running'
	assert desktop.OfficeRunState.waiting.key() == 'waiting'
	assert desktop.OfficeRunState.blocked.key() == 'blocked'
	assert desktop.OfficeRunState.needs_me.key() == 'needs-me'
	assert desktop.OfficeRunState.failed.key() == 'failed'
	assert desktop.office_job_state(.queued).key() == 'waiting'
	assert desktop.office_job_state(.canceled).key() == 'idle'
	assert desktop.office_swarm_state(.pending, false, false).key() == 'waiting'
	assert desktop.office_swarm_state(.canceled, false, false).key() == 'idle'
	assert desktop.office_format_ms(0) == '—'
	assert desktop.office_format_ms(4200) == '4s'
}
