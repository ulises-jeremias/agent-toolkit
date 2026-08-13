module agent_toolkit_core

import os

fn dc_ws(suffix string) string {
	base := os.join_path(os.temp_dir(), 'at-dc-${suffix}-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# test\n') or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'knowledge', 'todos')) or { assert false, err.msg() }
	return base
}

fn test_dc_help_lists_family() {
	h := dc_help_text()
	assert h.contains('queue')
	assert h.contains('run-once')
	assert h.contains('status')
	assert h.contains('sync-todos')
	assert h.contains('agent-toolkit dc')
}

fn test_dc_queue_run_once_no_llm_status_done() {
	$if windows {
		return
	}
	base := dc_ws('q')
	defer {
		os.rmdir_all(base) or {}
	}
	repo := os.join_path(base, 'repos', 'demo')
	os.mkdir_all(repo) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'projects')) or { assert false, err.msg() }
	os.symlink(repo, os.join_path(base, 'projects', 'demo')) or { assert false, err.msg() }
	q := run_devcompanion(DevcompanionOptions{
		subcommand:     'queue'
		workspace_path: base
		arg:            'demo'
		request:        'review the README'
		job_id:         'demo-test-1'
	})
	assert q.ok, q.message
	assert q.data['job_id'] == 'demo-test-1'
	jf := os.join_path(base, '.devcompanion', 'queue', 'demo-test-1.json')
	assert os.is_file(jf)
	st := run_devcompanion(DevcompanionOptions{
		subcommand:     'status'
		workspace_path: base
	})
	assert st.ok, st.message
	assert st.data['count'] == '1'
	assert st.message.contains('demo-test-1')
	run := run_devcompanion(DevcompanionOptions{
		subcommand:     'run-once'
		workspace_path: base
		no_llm:         true
	})
	assert run.ok, run.message
	plan := os.join_path(base, '.devcompanion', 'runs', 'demo-test-1', 'plan.md')
	assert os.is_file(plan)
	text := os.read_file(plan) or { '' }
	assert text.contains('skeleton')
	assert text.contains('review the README')
	job := os.read_file(jf) or { '' }
	assert job.contains('"status":"done"') || job.contains('"status": "done"')
	sync := run_devcompanion(DevcompanionOptions{
		subcommand:     'sync-todos'
		workspace_path: base
	})
	assert sync.ok, sync.message
	assert sync.data['count'] != '0'
	todos := os.read_file(os.join_path(base, 'knowledge', 'todos', 'pending.md')) or { '' }
	assert todos.contains('Synced from devcompanion')
}

fn test_dc_queue_requires_request() {
	base := dc_ws('noreq')
	defer {
		os.rmdir_all(base) or {}
	}
	os.mkdir_all(os.join_path(base, 'projects')) or {}
	os.mkdir_all(os.join_path(base, 'repos', 'demo')) or {}
	$if !windows {
		os.symlink(os.join_path(base, 'repos', 'demo'), os.join_path(base, 'projects', 'demo')) or {}
		r := run_devcompanion(DevcompanionOptions{
			subcommand:     'queue'
			workspace_path: base
			arg:            'demo'
		})
		assert !r.ok
		assert r.message.contains('--request') || r.message.contains('--template')
	}
}

fn test_dc_done_missing_job() {
	base := dc_ws('done')
	defer {
		os.rmdir_all(base) or {}
	}
	r := run_devcompanion(DevcompanionOptions{
		subcommand:     'done'
		workspace_path: base
		arg:            'nope'
	})
	assert !r.ok
}

fn test_dc_unknown_subcommand() {
	r := run_devcompanion(DevcompanionOptions{
		subcommand: 'nope'
	})
	assert !r.ok
	assert r.message.contains('Unknown subcommand')
}
