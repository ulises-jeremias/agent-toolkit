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
