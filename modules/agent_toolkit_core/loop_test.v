module agent_toolkit_core

import os

fn test_loop_help() {
	r := run_loop(LoopOptions{
		subcommand: 'help'
	})
	assert r.ok
	assert r.message.contains('init')
	assert r.message.contains('run')
	assert r.message.contains('schedule')
	assert r.message.contains('ADR-020')
}

fn test_loop_init_run_status_audit_sync() {
	old_h := os.getenv('HARNESS_DIR')
	old_ws := os.getenv('AGENT_TOOLKIT_WORKSPACE')
	os.unsetenv('HARNESS_DIR')
	os.unsetenv('AGENT_TOOLKIT_WORKSPACE')
	base := os.join_path(os.temp_dir(), 'at-loop-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		if old_h.len > 0 {
			os.setenv('HARNESS_DIR', old_h, true)
		}
		if old_ws.len > 0 {
			os.setenv('AGENT_TOOLKIT_WORKSPACE', old_ws, true)
		}
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'AGENTS.md'), '# ws\n') or { assert false, err.msg() }
	tpl := os.join_path(base, 'templates', 'loops')
	os.mkdir_all(tpl) or { assert false, err.msg() }
	os.write_file(os.join_path(tpl, 'daily.yaml'), 'name: daily\ntier: L1\ncadence: 1d\nmax_runs_per_day: 1\nmax_wall_seconds: 60\ngoal: |\n  observe\nrequest: |\n  report status\n') or {
		assert false, err.msg()
	}

	init := run_loop(LoopOptions{
		subcommand: 'init'
		workspace_path: base
		name: 'daily'
	})
	assert init.ok, init.message
	assert os.is_file(os.join_path(base, 'loops', 'daily', 'loop.yaml'))

	run := run_loop(LoopOptions{
		subcommand: 'run'
		workspace_path: base
		name: 'daily'
		no_llm: true
	})
	assert run.ok, run.message
	assert run.data['status'] == 'completed'
	assert os.is_file(os.join_path(base, 'loops', 'daily', 'STATE.md'))

	skip := run_loop(LoopOptions{
		subcommand: 'run'
		workspace_path: base
		name: 'daily'
		no_llm: true
	})
	assert skip.ok, skip.message
	assert skip.data['status'] == 'budget_skip'

	st := run_loop(LoopOptions{
		subcommand: 'status'
		workspace_path: base
	})
	assert st.ok, st.message
	assert st.message.contains('daily')

	aud := run_loop(LoopOptions{
		subcommand: 'audit'
		workspace_path: base
		name: 'daily'
	})
	assert aud.ok, aud.message

	cost := run_loop(LoopOptions{
		subcommand: 'cost'
		workspace_path: base
		name: 'daily'
	})
	assert cost.ok, cost.message
	assert cost.data['tier'] == 'L1'

	lst := run_loop(LoopOptions{
		subcommand: 'list'
		workspace_path: base
	})
	assert lst.ok
	assert lst.data['count'] == '1'

	// seed an escalation and sync
	write_state_md(os.join_path(base, 'loops', 'daily'), 'never', 'not_run', '', 0, [
		'needs human',
	])
	sync := run_loop(LoopOptions{
		subcommand: 'sync'
		workspace_path: base
	})
	assert sync.ok, sync.message
	todos := os.read_file(os.join_path(base, 'knowledge', 'todos', 'pending.md')) or { '' }
	assert todos.contains('loop-escalation')
}

fn test_loop_schedule_dry_run() {
	$if windows {
		r := run_loop(LoopOptions{
			subcommand: 'schedule'
			name: 'daily'
		})
		assert !r.ok
		assert r.message.contains('Windows')
		return
	}
	r := run_loop(LoopOptions{
		subcommand: 'schedule'
		name: 'daily'
		dry_run: true
	})
	assert r.ok, r.message
	assert r.message.contains('systemd')
}
