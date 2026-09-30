module agent_toolkit_server

import os
import time

fn test_new_job_runner_hydrate_completed_and_running() {
	dir := os.join_path(os.temp_dir(), 'test_hydrate_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer { os.rmdir_all(dir) or {} }
	// Simulate persisted jobs.json with 1 completed, 1 running
	json_str := '{"job_completed": {"id": "job_completed", "cmd": "build", "args": [], "status": "completed", "started_at": "2026-08-31T00:00:00Z", "ended_at": "2026-08-31T00:01:00Z", "exit_code": 0, "workspace": "/tmp"}, "job_running": {"id": "job_running", "cmd": "build", "args": [], "status": "running", "started_at": "2026-08-31T00:02:00Z", "ended_at": "", "exit_code": -1, "workspace": "/tmp"}}'
	os.write_file(os.join_path(dir, 'jobs.json'), json_str) or { panic(err.msg()) }
	mut runner := new_job_runner(dir)
	assert runner.jobs.len == 2
	assert runner.jobs['job_completed'].status == 'completed'
	// running should be reconciled to failed
	assert runner.jobs['job_running'].status == 'failed'
	assert runner.jobs['job_running'].ended_at.len > 0
	assert runner.running == 0
	// New jobs should be creatable without phantom capacity
	assert runner.running < runner.max_running
}

fn test_new_job_runner_missing_file_ok() {
	dir := os.join_path(os.temp_dir(), 'test_missing_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer { os.rmdir_all(dir) or {} }
	mut runner := new_job_runner(dir)
	assert runner.jobs.len == 0
	assert runner.running == 0
}

fn test_new_job_runner_malformed_json_graceful() {
	dir := os.join_path(os.temp_dir(), 'test_malformed_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer { os.rmdir_all(dir) or {} }
	os.write_file(os.join_path(dir, 'jobs.json'), '{ truncated json') or { panic(err.msg()) }
	mut runner := new_job_runner(dir)
	// Should not panic, start empty
	assert runner.jobs.len == 0
}

fn test_persist_atomic_no_half_write() {
	dir := os.join_path(os.temp_dir(), 'test_atomic_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer { os.rmdir_all(dir) or {} }
	mut runner := new_job_runner(dir)
	runner.jobs['a'] = Job{ id: 'a', status: 'completed', exit_code: 0 }
	runner.persist_locked()
	// File should exist and be valid JSON, no .tmp left
	data := os.read_file(os.join_path(dir, 'jobs.json')) or { panic(err.msg()) }
	assert data.contains('"a"')
	assert !os.exists(os.join_path(dir, 'jobs.json.tmp'))
}

fn test_is_valid_job_id_rejects_traversal() {
	assert is_valid_job_id('job_abc123') == true
	assert is_valid_job_id('job_123_abc-XYZ') == true
	assert is_valid_job_id('job_../etc/passwd') == false
	assert is_valid_job_id('job_..%2fsecret') == false
	assert is_valid_job_id('job_%2e%2e%2fsecret') == false
	assert is_valid_job_id('job_%2e%2e/secret') == false
	assert is_valid_job_id('job_../../etc/passwd') == false
	assert is_valid_job_id('/etc/passwd') == false
	assert is_valid_job_id('job_/absolute') == false
	assert is_valid_job_id('job_abc/def') == false
	assert is_valid_job_id('job_abc\\def') == false
	assert is_valid_job_id('job_abc%2fdef') == false
	assert is_valid_job_id('') == false
	assert is_valid_job_id('job_') == false
	assert is_valid_job_id('notjob_123') == false
}

fn test_is_valid_job_id_rejects_encoded() {
	assert is_valid_job_id('job_abc%2e') == false
	assert is_valid_job_id('job_abc%00') == false
	assert is_valid_job_id('job_abc%2F') == false
}

fn test_log_path_safe_rejects_traversal() {
	dir := os.join_path(os.temp_dir(), 'test_log_traversal_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer { os.rmdir_all(dir) or {} }
	mut runner := new_job_runner(dir)
	assert runner.is_log_path_safe('job_valid123') == true
	assert runner.is_log_path_safe('../etc/passwd') == false
	assert runner.is_log_path_safe('job_../traversal') == false
	assert runner.is_log_path_safe('job_%2e%2e/evil') == false
}

fn test_log_path_symlink_escape_blocked() {
	dir := os.join_path(os.temp_dir(), 'test_log_symlink_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer { os.rmdir_all(dir) or {} }
	mut runner := new_job_runner(dir)
	// Create a valid log file
	valid_id := 'job_symtest123'
	lp := runner.log_path(valid_id)
	os.write_file(lp, 'hello') or { panic(err.msg()) }
	assert runner.is_log_path_safe(valid_id) == true
	// Now replace with symlink to /etc/passwd (if exists)
	os.rm(lp) or {}
	// Try to symlink outside; if not permitted, skip
	target := '/etc/passwd'
	if os.exists(target) {
		os.execute('ln -sf ${target} ${lp}')
		if os.is_link(lp) {
			assert runner.is_log_path_safe(valid_id) == false
		}
		os.rm(lp) or {}
	}
}

fn test_workspace_path_validation() {
	valid := os.getwd()
	assert is_valid_workspace_path(valid) == true
	assert is_valid_workspace_path('/nonexistent_path_967_should_fail') == false
	assert is_valid_workspace_path('/tmp/../etc') == false
	assert is_valid_workspace_path('/etc%2fpasswd') == false
}

fn cancel_test_runner(tag string) (string, &JobRunner) {
	dir := os.join_path(os.temp_dir(), 'test_cancel_' + tag + '_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	return dir, new_job_runner(dir)
}

fn test_cancel_unknown_job_not_found() {
	dir, mut runner := cancel_test_runner('unknown')
	defer {
		os.rmdir_all(dir) or {}
	}
	runner.cancel('job_nope_missing') or {
		assert err.msg().starts_with('job not found')
		return
	}
	assert false, 'expected not-found error'
}

fn test_cancel_terminal_job_conflicts() {
	dir, mut runner := cancel_test_runner('terminal')
	defer {
		os.rmdir_all(dir) or {}
	}
	runner.jobs['job_done_x1'] = Job{
		id: 'job_done_x1'
		cmd: 'version'
		status: 'completed'
		exit_code: 0
	}
	runner.cancel('job_done_x1') or {
		assert err.msg().starts_with('job already')
		return
	}
	assert false, 'expected already-terminal error'
}

fn test_cancel_running_without_proc_marks_canceled() {
	dir, mut runner := cancel_test_runner('norproc')
	defer {
		os.rmdir_all(dir) or {}
	}
	runner.jobs['job_run_x1'] = Job{
		id: 'job_run_x1'
		cmd: 'version'
		status: 'running'
	}
	runner.running = 1
	os.write_file(os.join_path(dir, 'job_run_x1.log'), '[running]\npartial output\n') or {
		panic(err.msg())
	}
	job := runner.cancel('job_run_x1') or { panic(err.msg()) }
	assert job.status == 'canceled'
	assert job.ended_at.len > 0
	assert runner.running == 0
	// prior log output preserved, cancel marker appended
	log := os.read_file(os.join_path(dir, 'job_run_x1.log')) or { panic(err.msg()) }
	assert log.contains('partial output')
	assert log.contains('[canceled]')
	// second cancel conflicts: exactly-once terminal transition
	runner.cancel('job_run_x1') or {
		assert err.msg().starts_with('job already')
		return
	}
	assert false, 'expected already-terminal error'
}

fn test_delete_completed_removes_entry_and_log() {
	dir, mut runner := cancel_test_runner('del')
	defer {
		os.rmdir_all(dir) or {}
	}
	runner.jobs['job_gone_x1'] = Job{
		id: 'job_gone_x1'
		cmd: 'version'
		status: 'failed'
		exit_code: 1
	}
	os.write_file(os.join_path(dir, 'job_gone_x1.log'), '[exit 1]\n') or { panic(err.msg()) }
	runner.delete('job_gone_x1', false) or { panic(err.msg()) }
	assert !('job_gone_x1' in runner.jobs)
	assert !os.is_file(os.join_path(dir, 'job_gone_x1.log'))
}

fn test_delete_unknown_job_not_found() {
	dir, mut runner := cancel_test_runner('delunknown')
	defer {
		os.rmdir_all(dir) or {}
	}
	runner.delete('job_nope_missing', false) or {
		assert err.msg().starts_with('job not found')
		return
	}
	assert false, 'expected not-found error'
}

fn test_delete_running_needs_force() {
	dir, mut runner := cancel_test_runner('delforce')
	defer {
		os.rmdir_all(dir) or {}
	}
	runner.jobs['job_live_x1'] = Job{
		id: 'job_live_x1'
		cmd: 'version'
		status: 'running'
	}
	runner.running = 1
	mut conflicted := false
	runner.delete('job_live_x1', false) or {
		assert err.msg().starts_with('job is running')
		conflicted = true
	}
	assert conflicted, 'expected running conflict'
	assert 'job_live_x1' in runner.jobs
	// force cancels first, then removes
	runner.delete('job_live_x1', true) or { panic(err.msg()) }
	assert !('job_live_x1' in runner.jobs)
	assert runner.running == 0
}

// Live kill proof (unix only; V module CI is ubuntu/macos): a fake
// `agent-toolkit` that sleeps is canceled, and the watcher reaps the dead
// child within seconds — impossible if the kill silently no-ops, since the
// sleeper would hold the job running for 30s.
fn test_cancel_kills_live_job() {
	$if windows {
		return
	}
	dir := os.join_path(os.temp_dir(), 'test_cancellive_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	fake := os.join_path(dir, 'agent-toolkit')
	os.write_file(fake, '#!/bin/sh\nexec sleep 30\n') or { panic(err.msg()) }
	os.chmod(fake, 0o755) or { panic(err.msg()) }
	old_path := os.getenv('PATH')
	os.setenv('PATH', dir + ':' + old_path, true)
	defer {
		os.setenv('PATH', old_path, true)
	}
	runs := os.join_path(dir, 'runs')
	mut runner := new_job_runner(runs)
	job := runner.create('version', [], '') or { panic(err.msg()) }
	assert runner.get(job.id)!.status == 'running'
	canceled := runner.cancel(job.id) or { panic(err.msg()) }
	assert canceled.status == 'canceled'
	// watcher must reap the killed child quickly (bounded: would take 30s
	// if the process survived) and never overwrite canceled
	deadline := time.now().add(15 * time.second)
	for {
		runner.mut.lock()
		tracked := job.id in runner.procs
		runner.mut.unlock()
		if !tracked {
			break
		}
		assert time.now().unix_milli() <= deadline.unix_milli(), 'watcher never reaped canceled job'
		time.sleep(100 * time.millisecond)
	}
	final := runner.get(job.id) or { panic(err.msg()) }
	assert final.status == 'canceled'
	// the watcher's final log write keeps exactly one canceled marker
	log := os.read_file(os.join_path(runs, job.id + '.log')) or { panic(err.msg()) }
	assert log.count('[canceled]') == 1
}
