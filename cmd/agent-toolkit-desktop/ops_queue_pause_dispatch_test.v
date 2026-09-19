module main

import desktop_engine

// WS4 Ops+QA: queue bulk control, loop run-control pause, and kanban
// dispatch. Behavior-named; no GUI boot required.

fn ws4_jobs(queued int, running int, done int) []desktop_engine.JobRecord {
	mut out := []desktop_engine.JobRecord{}
	for i in 0 .. queued {
		out << desktop_engine.JobRecord{ id: 'q${i}', cmd: 'nightly-${i}', status: .queued }
	}
	for i in 0 .. running {
		out << desktop_engine.JobRecord{ id: 'r${i}', cmd: 'build-${i}', status: .running }
	}
	for i in 0 .. done {
		out << desktop_engine.JobRecord{ id: 'd${i}', cmd: 'old-${i}', status: .done, finished_at: i64(1000 + i) }
	}
	return out
}

fn test_cancelable_counts_live_jobs_only() {
	assert ops_cancelable_job_count(ws4_jobs(2, 1, 3)) == 3
	assert ops_cancelable_job_count(ws4_jobs(0, 0, 2)) == 0
	assert ops_cancelable_job_count([]desktop_engine.JobRecord{}) == 0
}

fn test_cancel_all_needs_two_live_jobs() {
	assert ops_cancel_all_visible(ws4_jobs(1, 1, 0)) == true
	assert ops_cancel_all_visible(ws4_jobs(2, 0, 5)) == true
	assert ops_cancel_all_visible(ws4_jobs(1, 0, 0)) == false, 'single live job has its own Cancel'
	assert ops_cancel_all_visible(ws4_jobs(0, 0, 4)) == false, 'idle queue offers no bulk destruction'
}

fn test_loop_stop_gates() {
	assert ops_loop_can_stop(true, []desktop_engine.JobRecord{}, 'nightly') == true, 'scheduling loop can stop'
	running := [desktop_engine.JobRecord{ id: 'r0', cmd: 'run nightly loop', status: .running }]
	assert ops_loop_can_stop(false, running, 'nightly') == true, 'live loop work can stop'
	unrelated := [desktop_engine.JobRecord{ id: 'r1', cmd: 'other work', status: .queued }]
	assert ops_loop_can_stop(false, unrelated, 'nightly') == false
	finished := [desktop_engine.JobRecord{ id: 'd0', cmd: 'run nightly loop', status: .done }]
	assert ops_loop_can_stop(false, finished, 'nightly') == false, 'finished work is not stoppable'
	assert ops_loop_can_stop(false, running, '') == false, 'empty name never matches'
	assert ops_loop_can_stop(false, []desktop_engine.JobRecord{}, 'nightly') == false, 'idle loop has no Stop'
}

fn ws4_swarms() []desktop_engine.SwarmRun {
	return [
		desktop_engine.SwarmRun{ id: 's-wait', task: 'review me', status: .awaiting_approval },
		desktop_engine.SwarmRun{ id: 's-run', task: 'building', status: .running },
	]
}

fn test_snapshot_empty_stays_empty() {
	cards := kanban_snapshot([]desktop_engine.JobRecord{}, []desktop_engine.SwarmRun{})
	assert cards.len == 0, 'clean launch shows zero cards, never seeded work'
}

fn test_snapshot_columns_from_live_records() {
	jobs := ws4_jobs(1, 1, 1)
	cards := kanban_snapshot(jobs, ws4_swarms())
	todo := kanban_col_cards(cards, 'todo')
	doing := kanban_col_cards(cards, 'doing')
	done := kanban_col_cards(cards, 'done')
	assert todo.len == 2, 'queued job + awaiting swarm, got ${todo.len}'
	assert doing.len == 2, 'running job + running swarm, got ${doing.len}'
	assert done.len == 1
	assert todo[0].id == 'job:q0'
	assert todo[1].id == 'swarm:s-wait'
	assert todo[1].pri == 'high', 'awaiting approval needs a human'
}

fn test_snapshot_done_capped_newest_first() {
	mut jobs := []desktop_engine.JobRecord{}
	for i in 0 .. 12 {
		jobs << desktop_engine.JobRecord{ id: 'd${i}', cmd: 'old-${i}', status: .done, finished_at: i64(1000 + i) }
	}
	done := kanban_col_cards(kanban_snapshot(jobs, []desktop_engine.SwarmRun{}), 'done')
	assert done.len == kanban_done_cap, 'done is recent history, not an archive'
	assert done[0].id == 'job:d11', 'newest finished first'
}

fn test_snapshot_retry_marks_high() {
	jobs := [desktop_engine.JobRecord{ id: 'q9', cmd: 'flaky', status: .queued, retry_count: 2 }]
	todo := kanban_col_cards(kanban_snapshot(jobs, []desktop_engine.SwarmRun{}), 'todo')
	assert todo.len == 1 && todo[0].pri == 'high'
}

fn test_dispatch_job_and_swarm() {
	jobs := ws4_jobs(1, 1, 0)
	swarms := ws4_swarms()
	cards := kanban_snapshot(jobs, swarms)
	panel, idx, ok := kanban_dispatch('todo', cards, jobs, swarms)
	assert ok && panel == 6 && idx == 0, 'todo job opens Jobs at its live index'
	// card order: todo(job q0, swarm s-wait), doing(job r0, swarm s-run)
	panel3, idx3, ok3 := kanban_dispatch('doing', [cards[3]], jobs, swarms)
	assert ok3 && panel3 == 8 && idx3 == 1, 'doing swarm opens Swarms at its live index'
}

fn test_dispatch_empty_and_stale() {
	jobs := ws4_jobs(0, 0, 0)
	_, _, ok := kanban_dispatch('todo', []KanbanTask{}, jobs, []desktop_engine.SwarmRun{})
	assert ok == false, 'empty column is idle — nothing to open'
	stale := [KanbanTask{'job:gone', 'gone', 'todo', 'jobs', 'low'}]
	panel, idx, ok2 := kanban_dispatch('todo', stale, jobs, []desktop_engine.SwarmRun{})
	assert ok2 && panel == 6 && idx == -1, 'cleared record still opens the panel, honestly'
}

fn test_deck_geometry_shared() {
	x, y, w, h := kanban_deck_rect(0, 100, 600, 400)
	assert x == 8 && y == 432 && w == 584 && h == 48
	assert kanban_deck_visible(600, 400) == true
	assert kanban_deck_visible(200, 100) == false
	assert kanban_col_at(8, 180, 20) == 'todo'
	assert kanban_col_at(8, 180, 100) == 'doing'
	assert kanban_col_at(8, 180, 160) == 'done'
	assert kanban_col_at(8, 180, 200) == '', 'fleet third never dispatches'
	assert kanban_col_at(8, 180, 0) == '', 'left of board never dispatches'
	assert kanban_col_at(8, 0, 20) == ''
}
