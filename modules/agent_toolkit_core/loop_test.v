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

fn test_schedule_run_suffix() {
	assert schedule_run_suffix(LoopOptions{}) == ''
	assert schedule_run_suffix(LoopOptions{runner: 'opencode'}) == ' --runner opencode'
	assert schedule_run_suffix(LoopOptions{runner: 'skeleton'}) == ' --runner skeleton'
	assert schedule_run_suffix(LoopOptions{runner: 'opencode', no_llm: true}) == ' --no-llm'
	assert schedule_run_suffix(LoopOptions{no_llm: true}) == ' --no-llm'
}

fn test_schedule_dry_run_bakes_runner() {
	r := run_loop(LoopOptions{
		subcommand: 'schedule'
		name: 'daily'
		dry_run: true
		runner: 'opencode'
	})
	assert r.ok, r.message
	assert r.message.contains('ExecStart=agent-toolkit loop run daily --runner opencode')
	r2 := run_loop(LoopOptions{
		subcommand: 'schedule'
		name: 'daily'
		dry_run: true
	})
	assert r2.ok, r2.message
	assert r2.message.contains('ExecStart=agent-toolkit loop run daily\n')
}

fn with_clean_runner_env(f fn ()) {
	old_runner := os.getenv('AGENT_TOOLKIT_LOOP_RUNNER')
	old_model := os.getenv('AGENT_TOOLKIT_LOOP_MODEL')
	old_path := os.getenv('PATH')
	os.unsetenv('AGENT_TOOLKIT_LOOP_RUNNER')
	os.unsetenv('AGENT_TOOLKIT_LOOP_MODEL')
	defer {
		if old_runner.len > 0 {
			os.setenv('AGENT_TOOLKIT_LOOP_RUNNER', old_runner, true)
		}
		if old_model.len > 0 {
			os.setenv('AGENT_TOOLKIT_LOOP_MODEL', old_model, true)
		}
		os.setenv('PATH', old_path, true)
	}
	f()
}

fn test_loop_runner_resolution() {
	with_clean_runner_env(fn () {
		assert resolve_loop_runner('claude') == 'claude'
		assert resolve_loop_runner('OpEnCoDe') == 'opencode'
		assert resolve_loop_runner('') == 'auto'
		assert resolve_loop_runner('nope') == ''
		assert resolve_loop_runner('cursor') == 'cursor'
		os.setenv('AGENT_TOOLKIT_LOOP_RUNNER', 'codex', true)
		assert resolve_loop_runner('') == 'codex'
		assert resolve_loop_runner('claude') == 'claude'
	})
}

fn test_loop_runner_auto_probe() {
	with_clean_runner_env(fn () {
		fake := os.join_path(os.temp_dir(), 'at-runners-${os.getpid()}')
		os.mkdir_all(fake) or { assert false, err.msg() }
		defer {
			os.rmdir_all(fake) or {}
		}
		os.write_file(os.join_path(fake, 'opencode'), '#!/bin/sh\necho hi\n') or {
			assert false, err.msg()
		}
		os.chmod(os.join_path(fake, 'opencode'), 0o755) or { assert false, err.msg() }
		os.setenv('PATH', fake, true)
		assert runner_is_available('opencode')
		assert !runner_is_available('claude')
		assert auto_select_runner() == 'opencode'
	})
}

fn test_loop_runner_select_fail_closed() {
	with_clean_runner_env(fn () {
		fake := os.join_path(os.temp_dir(), 'at-runners2-${os.getpid()}')
		os.mkdir_all(fake) or { assert false, err.msg() }
		defer {
			os.rmdir_all(fake) or {}
		}
		os.setenv('PATH', fake, true)
		name, note := select_loop_runner('mystery')
		assert name == 'skeleton'
		assert note.contains('unknown runner')
		name2, note2 := select_loop_runner('cursor')
		assert name2 == 'skeleton'
		assert note2.contains('not implemented yet')
		name3, note3 := select_loop_runner('claude')
		assert name3 == 'skeleton'
		assert note3.contains('not on PATH')
		name4, note4 := select_loop_runner('auto')
		assert name4 == 'skeleton'
		assert note4.contains('no LLM runner on PATH')
		name5, note5 := select_loop_runner('skeleton')
		assert name5 == 'skeleton'
		assert note5 == ''
	})
}

fn test_loop_run_prompt_prefers_request_md() {
	base := os.join_path(os.temp_dir(), 'at-prompt-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	assert loop_run_prompt(base, 'yaml fallback') == 'yaml fallback'
	os.write_file(os.join_path(base, 'request.md'), '# full runbook\n') or {
		assert false, err.msg()
	}
	assert loop_run_prompt(base, 'yaml fallback') == '# full runbook\n'
}

fn test_sh_quote() {
	assert sh_quote('simple') == 'simple'
	assert sh_quote('a/b-c_d.txt') == 'a/b-c_d.txt'
	assert sh_quote('') == "''"
	assert sh_quote('two words') == "'two words'"
	assert sh_quote("it's") == "'it'\\''s'"
}

fn test_runner_argv_shapes() {
	with_clean_runner_env(fn () {
		c := runner_argv('claude', 'do things', 'sys here')
		assert c[0] == 'claude' && c[1] == '--print'
		assert c.contains('do things')
		o := runner_argv('opencode', 'do things', '')
		assert o == ['opencode', 'run', 'do things']
		os.setenv('AGENT_TOOLKIT_LOOP_MODEL', 'big-model', true)
		om := runner_argv('opencode', 'do things', '')
		assert om == ['opencode', 'run', '--model', 'big-model', 'do things']
		x := runner_argv('codex', 'do things', 'sys here')
		assert x[0] == 'codex' && x[1] == 'exec'
		assert x[2].contains('sys here') && x[2].contains('do things')
		assert runner_argv('nope', 'x', '') == []
	})
}

fn test_execute_loop_runner_echo_and_timeout() {
	$if windows {
		return
	}
	fake := os.join_path(os.temp_dir(), 'at-exec-${os.getpid()}')
	os.mkdir_all(fake) or { assert false, err.msg() }
	defer {
		os.rmdir_all(fake) or {}
	}
	claude_sh := os.join_path(fake, 'claude')
	os.write_file(claude_sh, '#!/bin/sh\necho "ran: $@"\n') or { assert false, err.msg() }
	os.chmod(claude_sh, 0o755) or { assert false, err.msg() }
	old_path := os.getenv('PATH')
	os.setenv('PATH', fake + ':' + old_path, true)
	defer {
		os.setenv('PATH', old_path, true)
	}
	run_dir := os.join_path(fake, 'run')
	os.mkdir_all(run_dir) or { assert false, err.msg() }
	policy := GatePolicy{
		tier:      'L1'
		allowlist: []string{}
		deny:      []string{}
		run_dir:   run_dir
		run_id:    'test-run'
	}
	res := execute_loop_runner('claude', 'hello world', '', fake, run_dir, 30, policy)
	assert res.ok
	assert !res.timed_out
	assert res.exit_code == 0
	out := os.read_file(res.transcript) or { '' }
	assert out.contains('ran:')
	assert out.contains('hello world')
	// timeout path: replace the fake with a sleeper, tiny wall
	os.write_file(claude_sh, '#!/bin/sh\nsleep 30\n') or { assert false, err.msg() }
	res2 := execute_loop_runner('claude', 'x', '', fake, run_dir, 1, policy)
	assert res2.ok
	assert res2.timed_out
	out2 := os.read_file(res2.transcript) or { '' }
	assert out2.contains('wall timeout')
}
