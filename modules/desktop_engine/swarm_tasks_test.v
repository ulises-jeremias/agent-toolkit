module desktop_engine

import os
import time

// Slice H task board: queued/done listing, complete seam, refusals.

fn seed_handoff(mut eng &Engine, id string, status string) {
	mut repo := eng.state_repo()
	mut tx := repo.begin('task-board-test')
	tx.set('swarm/handoffs/${id}/from', 'planner')
	tx.set('swarm/handoffs/${id}/to', 'worker')
	tx.set('swarm/handoffs/${id}/payload', 'do ${id}')
	tx.set('swarm/handoffs/${id}/status', status)
	if status == 'completed' {
		tx.set('swarm/handoffs/${id}/completed_by', 'run-1')
	}
	eng.put_transaction(mut tx) or { panic(err.msg()) }
}

fn task_board_engine() (&Engine, string) {
	tmp := os.join_path(os.temp_dir(), 'atk-tb-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return eng, tmp
}

fn test_task_board_queued_and_done_columns() {
	mut eng, tmp := task_board_engine()
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	seed_handoff(mut eng, 'h-1', 'queued')
	seed_handoff(mut eng, 'h-2', 'completed')
	queued := eng.swarm_queued_tasks('run-1')
	done := eng.swarm_done_tasks('run-1')
	assert queued.len == 1 && queued[0].handoff_id == 'h-1'
	assert queued[0].status == 'queued'
	assert done.len == 1 && done[0].handoff_id == 'h-2'
	assert done[0].status == 'completed'
	assert done[0].run_id == 'run-1', 'completion attribution survives'
}

fn test_task_complete_moves_queued_to_done() {
	mut eng, tmp := task_board_engine()
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	seed_handoff(mut eng, 'h-9', 'queued')
	rev := eng.swarm_task_complete('run-7', 'h-9') or { panic('complete must succeed: ${err.msg()}') }
	assert rev > 0
	assert eng.swarm_queued_tasks('run-7').len == 0
	done := eng.swarm_done_tasks('run-7')
	assert done.len == 1 && done[0].handoff_id == 'h-9'
	assert done[0].run_id == 'run-7'
}

fn test_task_complete_refuses_unknown_and_double() {
	mut eng, tmp := task_board_engine()
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	if _ := eng.swarm_task_complete('run-1', 'nope') {
		assert false, 'unknown handoff must be refused'
	} else {
		assert err.msg().contains('not found'), 'refusal names the cause: ${err.msg()}'
	}
	seed_handoff(mut eng, 'h-d', 'completed')
	if _ := eng.swarm_task_complete('run-1', 'h-d') {
		assert false, 'double completion must be refused, never rewritten'
	} else {
		assert err.msg().contains('completed'), 'refusal cites current state: ${err.msg()}'
	}
}
