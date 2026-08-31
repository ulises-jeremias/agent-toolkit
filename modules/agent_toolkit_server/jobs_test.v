module agent_toolkit_server

import os

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
