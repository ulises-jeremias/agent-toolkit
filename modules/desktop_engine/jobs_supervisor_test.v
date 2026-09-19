module desktop_engine

import os
import time

fn supervisor_test_engine(name string) &Engine {
	tmp := os.join_path(os.temp_dir(), 'jobs-sup-${name}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut e := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { panic(err.msg()) }
	e.start() or { panic(err.msg()) }
	return e
}

fn supervisor_test_spawn_id(cmd string, args []string, mut e Engine) string {
	// portable probe command: prefer bare binary, fall back to /bin path
	return e.spawn_job(cmd, args) or { e.spawn_job('/bin/${cmd}', args) or { panic(err.msg()) } }
}

// No supervisor attached: spawn records the job queued and it never runs.
// This pins the honest contract — the Desktop must attach a supervisor for
// jobs to execute (see attach_process_supervisor).
fn test_spawn_without_supervisor_stays_queued() {
	mut e := supervisor_test_engine('no-sup')
	defer {
		e.stop() or {}
	}
	id := e.spawn_job('echo', ['hello']) or { panic(err.msg()) }
	time.sleep(400 * time.millisecond)
	mut found := false
	for j in e.jobs_catalog() {
		if j.id == id {
			found = true
			assert j.status == .queued
		}
	}
	assert found
}

// With a supervisor attached, a trivial job runs to done with exit 0.
fn test_attach_supervisor_runs_job_to_done() {
	mut e := supervisor_test_engine('run')
	defer {
		e.stop() or {}
	}
	e.attach_process_supervisor()
	id := supervisor_test_spawn_id('echo', ['hello'], mut e)
	mut done := false
	mut code := -99
	deadline := time.now().add(10 * time.second)
	for time.now().unix_milli() < deadline.unix_milli() {
		for j in e.jobs_catalog() {
			if j.id == id && j.status == .done {
				done = true
				code = j.exit_code
				break
			}
		}
		if done {
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert done, 'job ${id} never reached done'
	assert code == 0
}

// Cancel on a running job kills the process and records canceled.
fn test_cancel_kills_running_job() {
	mut e := supervisor_test_engine('cancel')
	defer {
		e.stop() or {}
	}
	e.attach_process_supervisor()
	id := supervisor_test_spawn_id('sleep', ['30'], mut e)
	// wait until the row shows running (spawned, not stuck queued)
	mut running := false
	deadline := time.now().add(10 * time.second)
	for time.now().unix_milli() < deadline.unix_milli() {
		for j in e.jobs_catalog() {
			if j.id == id && j.status == .running {
				running = true
				break
			}
		}
		if running {
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert running, 'job ${id} never reached running'
	e.cancel_job(id) or { panic(err.msg()) }
	mut canceled := false
	for j in e.jobs_catalog() {
		if j.id == id && j.status == .canceled {
			canceled = true
		}
	}
	assert canceled
	// the OS process must actually be dead, not just the row flipped: a
	// second kill against the same handle reports no live termination.
	if mut sup := e.supervisor {
		snap := e.repo.snapshot()
		handle_id := snap.data['jobs/${id}/handle'] or { '' }
		assert handle_id != ''
		assert sup.cancel_job(handle_id) == false
	} else {
		assert false, 'supervisor missing after attach'
	}
}
