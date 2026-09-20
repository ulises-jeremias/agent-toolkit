module agent_toolkit_core

import os
import time

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
	old_h := os.getenv('HARNESS_DIR')
	old_ws := os.getenv('AGENT_TOOLKIT_WORKSPACE')
	os.unsetenv('HARNESS_DIR')
	os.unsetenv('AGENT_TOOLKIT_WORKSPACE')
	base := os.join_path(os.temp_dir(), 'at-loop-sched-${os.getpid()}')
	os.mkdir_all(base) or { panic(err.msg()) }
	defer {
		if old_h.len > 0 {
			os.setenv('HARNESS_DIR', old_h, true)
		}
		if old_ws.len > 0 {
			os.setenv('AGENT_TOOLKIT_WORKSPACE', old_ws, true)
		}
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'AGENTS.md'), '# ws\n') or { panic(err.msg()) }
	tpl := os.join_path(base, 'templates', 'loops')
	os.mkdir_all(tpl) or { panic(err.msg()) }
	os.write_file(os.join_path(tpl, 'daily.yaml'), 'name: daily\ntier: L1\ncadence: 1d\ngoal: |\n  observe\nrequest: |\n  report status\n') or {
		panic(err.msg())
	}
	init := run_loop(LoopOptions{
		subcommand: 'init'
		workspace_path: base
		name: 'daily'
	})
	assert init.ok, init.message
	r := run_loop(LoopOptions{
		subcommand: 'schedule'
		workspace_path: base
		name: 'daily'
		dry_run: true
	})
	assert r.ok, r.message
	assert r.message.contains('dry-run')
	$if linux {
		assert r.message.contains('OnCalendar=')
	}
	$if macos {
		assert r.message.contains('launchd')
	}
}

fn test_schedule_cron_to_oncalendar() {
	assert schedule_cron_to_oncalendar('hourly')! == 'hourly'
	assert schedule_cron_to_oncalendar('daily')! == 'daily'
	assert schedule_cron_to_oncalendar('weekly')! == 'weekly'
	assert schedule_cron_to_oncalendar('* * * * *')! == '*-*-* *:*:00'
	assert schedule_cron_to_oncalendar('*/15 * * * *')! == '*-*-* *:00,15,30,45:00'
	assert schedule_cron_to_oncalendar('0 * * * *')! == '*-*-* *:00:00'
	assert schedule_cron_to_oncalendar('0 */4 * * *')! == '*-*-* 00,04,08,12,16,20:00:00'
	assert schedule_cron_to_oncalendar('0 0 * * *')! == '*-*-* 00:00:00'
	assert schedule_cron_to_oncalendar('0 0 */2 * *')! == '*-*-01,03,05,07,09,11,13,15,17,19,21,23,25,27,29,31 00:00:00'
	assert schedule_cron_to_oncalendar('0 0 * * 0')! == 'Sun *-*-* 00:00:00'
	assert schedule_cron_to_oncalendar('0 9 * * 1')! == 'Mon *-*-* 09:00:00'
	// unknown shapes fail instead of writing timers systemd would reject
	if _ := schedule_cron_to_oncalendar('0 0 * 5 *') {
		assert false, 'month-restricted cron must fail'
	}
	if _ := schedule_cron_to_oncalendar('0 0 1 * 0') {
		assert false, 'dom+dow cron must fail'
	}
	if _ := schedule_cron_to_oncalendar('nonsense') {
		assert false, 'non-cron must fail'
	}
}

fn test_schedule_cadence_interval_secs() {
	assert schedule_cadence_interval_secs('15m')! == 900
	assert schedule_cadence_interval_secs('4h')! == 14400
	assert schedule_cadence_interval_secs('1d')! == 86400
	assert schedule_cadence_interval_secs('1w')! == 604800
	if _ := schedule_cadence_interval_secs('x') {
		assert false, 'bad cadence must fail'
	}
	if _ := schedule_cadence_interval_secs('0d') {
		assert false, 'zero cadence must fail'
	}
}

fn test_schedule_emit_units() {
	svc := emit_systemd_service('daily', '/ws', '')
	assert svc.contains('Description=agent-toolkit loop daily')
	assert svc.contains('WorkingDirectory=/ws')
	assert svc.contains('ExecStart=agent-toolkit loop run daily')
	timer := emit_systemd_timer('daily', 'daily')
	assert timer.contains('OnCalendar=daily')
	assert timer.contains('Persistent=true')
	plist := emit_launchd_plist('com.agent-toolkit.daily', '/bin/atk', ['loop', 'run', 'daily'], '/ws', 86400)
	assert plist.contains('<string>com.agent-toolkit.daily</string>')
	assert plist.contains('<integer>86400</integer>')
	assert plist.contains('<false/>')
	assert schedule_run_argv('daily', ' --runner opencode') == ['loop', 'run', 'daily', '--runner', 'opencode']
}

fn test_schedule_remove_and_list_isolated_home() {
	$if windows {
		return
	}
	$if macos {
		return
	}
	home := os.join_path(os.temp_dir(), 'at-sched-home-${os.getpid()}')
	dir := os.join_path(home, '.config', 'systemd', 'user')
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer {
		os.rmdir_all(home) or {}
	}
	os.write_file(os.join_path(dir, 'agent-toolkit-loop-x.service'), 'svc') or { panic(err.msg()) }
	os.write_file(os.join_path(dir, 'agent-toolkit-loop-x.timer'), 'tmr') or { panic(err.msg()) }
	lst := loop_schedule_list(home)
	assert lst.ok
	assert lst.message.contains('x')
	assert lst.data['count'] == '1'
	dry := loop_schedule_remove('x', home, true)
	assert dry.ok
	assert dry.message.contains('Would remove')
	assert os.is_file(os.join_path(dir, 'agent-toolkit-loop-x.timer'))
	rm := loop_schedule_remove('x', home, false)
	assert rm.ok, rm.message
	assert rm.message.contains('Removed schedule: x')
	assert !os.is_file(os.join_path(dir, 'agent-toolkit-loop-x.service'))
	assert !os.is_file(os.join_path(dir, 'agent-toolkit-loop-x.timer'))
	lst2 := loop_schedule_list(home)
	assert lst2.message.contains('No scheduled loops')
}

fn test_schedule_install_systemd_dry_run() {
	r := loop_schedule_install_systemd('daily', '/ws', '0 0 * * *', '', os.join_path(os.temp_dir(), 'at-sched-nobody-${os.getpid()}'), true)
	assert r.ok, r.message
	assert r.message.contains('OnCalendar=*-*-* 00:00:00')
	assert r.message.contains('Would enable: systemctl --user enable agent-toolkit-loop-daily.timer')
	bad := loop_schedule_install_systemd('daily', '/ws', '0 0 * 5 *', '', os.temp_dir(), true)
	assert !bad.ok
}

fn test_schedule_run_suffix() {
	assert schedule_run_suffix(LoopOptions{}) == ''
	assert schedule_run_suffix(LoopOptions{runner: 'opencode'}) == ' --runner opencode'
	assert schedule_run_suffix(LoopOptions{runner: 'skeleton'}) == ' --runner skeleton'
	assert schedule_run_suffix(LoopOptions{runner: 'opencode', no_llm: true}) == ' --no-llm'
	assert schedule_run_suffix(LoopOptions{no_llm: true}) == ' --no-llm'
}

fn test_schedule_dry_run_bakes_runner() {
	$if windows {
		return
	}
	old_h := os.getenv('HARNESS_DIR')
	old_ws := os.getenv('AGENT_TOOLKIT_WORKSPACE')
	os.unsetenv('HARNESS_DIR')
	os.unsetenv('AGENT_TOOLKIT_WORKSPACE')
	base := os.join_path(os.temp_dir(), 'at-loop-suffix-${os.getpid()}')
	os.mkdir_all(base) or { panic(err.msg()) }
	defer {
		if old_h.len > 0 {
			os.setenv('HARNESS_DIR', old_h, true)
		}
		if old_ws.len > 0 {
			os.setenv('AGENT_TOOLKIT_WORKSPACE', old_ws, true)
		}
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'AGENTS.md'), '# ws\n') or { panic(err.msg()) }
	tpl := os.join_path(base, 'templates', 'loops')
	os.mkdir_all(tpl) or { panic(err.msg()) }
	os.write_file(os.join_path(tpl, 'daily.yaml'), 'name: daily\ntier: L1\ncadence: 1d\ngoal: |\n  observe\nrequest: |\n  report status\n') or {
		panic(err.msg())
	}
	init := run_loop(LoopOptions{
		subcommand: 'init'
		workspace_path: base
		name: 'daily'
	})
	assert init.ok, init.message
	r := run_loop(LoopOptions{
		subcommand: 'schedule'
		workspace_path: base
		name: 'daily'
		dry_run: true
		runner: 'opencode'
	})
	assert r.ok, r.message
	assert r.message.contains('ExecStart=agent-toolkit loop run daily --runner opencode')
	assert r.message.contains('WorkingDirectory=')
	r2 := run_loop(LoopOptions{
		subcommand: 'schedule'
		workspace_path: base
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
		assert resolve_loop_runner('copilot') == 'copilot'
		assert resolve_loop_runner('muse') == 'muse'
		assert resolve_loop_runner('pi') == 'pi'
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
		assert note2.contains('not on PATH')
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

fn test_loop_runner_aliases() {
	// explicit names never read the environment, so no clean-env wrapper
	assert resolve_loop_runner('cursor-agent') == 'cursor'
	assert resolve_loop_runner('github-copilot') == 'copilot'
	assert resolve_loop_runner('openai-codex') == 'codex'
	assert resolve_loop_runner('muse-code') == 'muse'
	// underscore forms normalize to the alias (Python _normalize parity)
	assert resolve_loop_runner('openai_codex') == 'codex'
	assert resolve_loop_runner('github_copilot') == 'copilot'
	// near-miss names are NOT aliases: fail closed like any unknown runner
	assert resolve_loop_runner('open_ai_codex') == ''
}

fn test_runner_argv_shapes() {
	with_clean_runner_env(fn () {
		c := runner_argv('claude', 'do things', 'sys here', resolve_loop_model(''))
		assert c[0] == 'claude' && c[1] == '--print'
		assert c.contains('do things')
		o := runner_argv('opencode', 'do things', '', resolve_loop_model(''))
		assert o == ['opencode', 'run', 'do things']
		os.setenv('AGENT_TOOLKIT_LOOP_MODEL', 'big-model', true)
		om := runner_argv('opencode', 'do things', '', resolve_loop_model(''))
		assert om == ['opencode', 'run', '--model', 'big-model', 'do things']
		os.unsetenv('AGENT_TOOLKIT_LOOP_MODEL')
		x := runner_argv('codex', 'do things', 'sys here', resolve_loop_model(''))
		assert x[0] == 'codex' && x[1] == 'exec'
		assert x[2].contains('sys here') && x[2].contains('do things')
		assert runner_argv('nope', 'x', '', resolve_loop_model('')) == []
	})
}

fn test_runner_argv_phase2_shapes() {
	with_clean_runner_env(fn () {
		assert runner_argv('copilot', 'do things', 'sys here', resolve_loop_model('')) == ['copilot', '-p', 'do things',
			'-s', '--no-ask-user', '--allow-all']
		assert runner_argv('muse', 'do things', 'sys here', resolve_loop_model('')) == ['muse', 'exec', '--approval-mode',
			'never', 'do things']
		assert runner_argv('pi', 'do things', 'sys here', resolve_loop_model('')) == ['pi', '--append-system-prompt',
			'sys here', '-p', 'do things']
		assert runner_argv('pi', 'do things', '', resolve_loop_model('')) == ['pi', '-p', 'do things']
		os.setenv('AGENT_TOOLKIT_LOOP_MODEL', 'big-model', true)
		assert runner_argv('claude', 'do things', 'sys here', resolve_loop_model('')) == ['claude', '--print', '--allowedTools',
			'Bash(gh *) Bash(git *) Edit Read Write Glob Grep', '--append-system-prompt', 'sys here',
			'--model', 'big-model', 'do things']
		assert runner_argv('codex', 'do things', 'sys here', resolve_loop_model('')) == ['codex', 'exec', '--model',
			'big-model', 'sys here\n\n---\n\ndo things']
		assert runner_argv('copilot', 'do things', '', resolve_loop_model('')) == ['copilot', '-p', 'do things',
			'-s', '--no-ask-user', '--allow-all', '--model', 'big-model']
		assert runner_argv('muse', 'do things', '', resolve_loop_model('')) == ['muse', 'exec', '--approval-mode',
			'never', '--model', 'big-model', 'do things']
		assert runner_argv('pi', 'do things', 'sys here', resolve_loop_model('')) == ['pi', '--append-system-prompt',
			'sys here', '--model', 'big-model', '-p', 'do things']
		os.unsetenv('AGENT_TOOLKIT_LOOP_MODEL')
	})
}

fn test_cursor_probe_chain() {
	with_clean_runner_env(fn () {
		fake := os.join_path(os.temp_dir(), 'at-cursor-${os.getpid()}')
		os.mkdir_all(fake) or { assert false, err.msg() }
		defer {
			os.rmdir_all(fake) or {}
		}
		// only the middle of the chain exists: cursor-agent missing
		os.write_file(os.join_path(fake, 'agent'), '#!/bin/sh\necho hi\n') or {
			assert false, err.msg()
		}
		os.chmod(os.join_path(fake, 'agent'), 0o755) or { assert false, err.msg() }
		os.setenv('PATH', fake, true)
		assert runner_binary('cursor') == 'cursor-agent'
		assert runner_is_available('cursor')
		assert auto_select_runner() == 'cursor'
		assert runner_argv('cursor', 'do things', '', resolve_loop_model('')) == ['agent', '--print', '--force',
			'--trust', '--output-format', 'text', 'do things']
		os.setenv('AGENT_TOOLKIT_LOOP_MODEL', 'sonnet-4-thinking', true)
		assert runner_argv('cursor', 'do things', '', resolve_loop_model('')) == ['agent', '--print', '--force',
			'--trust', '--output-format', 'text', '--model', 'sonnet-4-thinking', 'do things']
		os.unsetenv('AGENT_TOOLKIT_LOOP_MODEL')
		// explicit --model wins over the environment
		os.setenv('AGENT_TOOLKIT_LOOP_MODEL', 'env-model', true)
		assert resolve_loop_model('flag-model') == 'flag-model'
		assert runner_argv('cursor', 'do things', '', resolve_loop_model('flag-model')) == ['agent', '--print', '--force',
			'--trust', '--output-format', 'text', '--model', 'flag-model', 'do things']
		os.unsetenv('AGENT_TOOLKIT_LOOP_MODEL')
		assert resolve_loop_model('') == ''
		name, note := select_loop_runner('cursor')
		assert name == 'cursor'
		assert note == ''
	})
}

fn test_auto_select_prefers_first_available() {
	with_clean_runner_env(fn () {
		fake := os.join_path(os.temp_dir(), 'at-auto2-${os.getpid()}')
		os.mkdir_all(fake) or { assert false, err.msg() }
		defer {
			os.rmdir_all(fake) or {}
		}
		os.write_file(os.join_path(fake, 'pi'), '#!/bin/sh\necho hi\n') or {
			assert false, err.msg()
		}
		os.chmod(os.join_path(fake, 'pi'), 0o755) or { assert false, err.msg() }
		os.setenv('PATH', fake, true)
		assert auto_select_runner() == 'pi'
	})
}

fn test_execute_copilot_fake_e2e() {
	$if windows {
		return
	}
	fake := os.join_path(os.temp_dir(), 'at-exec-copilot-${os.getpid()}')
	os.mkdir_all(fake) or { assert false, err.msg() }
	defer {
		os.rmdir_all(fake) or {}
	}
	os.write_file(os.join_path(fake, 'copilot'), '#!/bin/sh\necho "ran: $@"\n') or {
		assert false, err.msg()
	}
	os.chmod(os.join_path(fake, 'copilot'), 0o755) or { assert false, err.msg() }
	old_path := os.getenv('PATH')
	os.setenv('PATH', fake + ':' + old_path, true)
	defer {
		os.setenv('PATH', old_path, true)
	}
	name, note := select_loop_runner('copilot')
	assert name == 'copilot'
	assert note == ''
	run_dir := os.join_path(fake, 'run')
	os.mkdir_all(run_dir) or { assert false, err.msg() }
	policy := GatePolicy{
		tier:      'L1'
		allowlist: []string{}
		deny:      []string{}
		run_dir:   run_dir
		run_id:    'test-run-copilot'
	}
	res := execute_loop_runner('copilot', 'hello world', '', fake, run_dir, 30, policy, '')
	assert res.ok
	assert !res.timed_out
	assert res.exit_code == 0
	assert res.runner == 'copilot'
	out := os.read_file(res.transcript) or { '' }
	assert out.contains('ran:')
	assert out.contains('-p')
	assert out.contains('hello world')
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
	res := execute_loop_runner('claude', 'hello world', '', fake, run_dir, 30, policy, '')
	assert res.ok
	assert !res.timed_out
	assert res.exit_code == 0
	out := os.read_file(res.transcript) or { '' }
	assert out.contains('ran:')
	assert out.contains('hello world')
	// timeout path: replace the fake with a sleeper, tiny wall
	os.write_file(claude_sh, '#!/bin/sh\nsleep 30\n') or { assert false, err.msg() }
	res2 := execute_loop_runner('claude', 'x', '', fake, run_dir, 1, policy, '')
	assert res2.ok
	assert res2.timed_out
	out2 := os.read_file(res2.transcript) or { '' }
	assert out2.contains('wall timeout')
}

fn test_tokens_from_trace_text_kind_aware() {
	// token_usage lines count once via total_tokens (or total fallback)
	assert tokens_from_trace_text('{"kind":"token_usage","total_tokens":100}\n') == 100
	assert tokens_from_trace_text('{"kind":"token_usage","total":55}\n') == 55
	assert tokens_from_trace_text('{"kind":"token_usage","prompt_tokens":5,"completion_tokens":7,"total_tokens":12}\n') == 12
	// prompt/completion lines sum their parts
	assert tokens_from_trace_text('{"kind":"prompt","prompt_tokens":10,"completion_tokens":20}\n') == 30
	// run_end marker lines (incl. our own budget_exhausted markers) never count
	assert tokens_from_trace_text('{"kind":"run_end","status":"budget_exhausted","tokens_used":100,"max_tokens":10}\n') == 0
	assert tokens_from_trace_text('{"kind":"run_end","status":"completed"}\n') == 0
	// undecodable lines are skipped, not parsed by substring
	assert tokens_from_trace_text('not json\ntotal_tokens: 999\n') == 0
	assert tokens_from_trace_text('') == 0
}

fn test_total_tokens_for_loop_day_filter() {
	base := os.join_path(os.temp_dir(), 'at-loop-day-${os.getpid()}')
	loop_dir := os.join_path(base, 'loops', 'tiny')
	os.mkdir_all(os.join_path(loop_dir, 'runs', 'today')) or { panic(err.msg()) }
	os.mkdir_all(os.join_path(loop_dir, 'runs', 'old')) or { panic(err.msg()) }
	defer {
		os.rmdir_all(base) or {}
	}
	ts := time.utc().format_rfc3339()
	os.write_file(os.join_path(loop_dir, 'runs', 'today', 'trace.jsonl'),
		'{"kind":"token_usage","ts":"${ts}","total_tokens":40}\n') or { panic(err.msg()) }
	os.write_file(os.join_path(loop_dir, 'runs', 'old', 'trace.jsonl'),
		'{"kind":"token_usage","ts":"2020-01-01T00:00:00Z","total_tokens":9999}\n') or {
		panic(err.msg())
	}
	assert total_tokens_for_loop(loop_dir) == 40
}

fn test_wall_timeout_seconds_default_and_floor() {
	assert wall_timeout_seconds(0) == 900
	assert wall_timeout_seconds(-5) == 900
	assert wall_timeout_seconds(5) == 30
	assert wall_timeout_seconds(30) == 30
	assert wall_timeout_seconds(600) == 600
}

fn test_loop_force_never_bypasses_token_budget() {
	old_h := os.getenv('HARNESS_DIR')
	old_ws := os.getenv('AGENT_TOOLKIT_WORKSPACE')
	os.unsetenv('HARNESS_DIR')
	os.unsetenv('AGENT_TOOLKIT_WORKSPACE')
	base := os.join_path(os.temp_dir(), 'at-loop-force-${os.getpid()}')
	os.mkdir_all(base) or { panic(err.msg()) }
	defer {
		if old_h.len > 0 {
			os.setenv('HARNESS_DIR', old_h, true)
		}
		if old_ws.len > 0 {
			os.setenv('AGENT_TOOLKIT_WORKSPACE', old_ws, true)
		}
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'AGENTS.md'), '# ws\n') or { panic(err.msg()) }
	tpl := os.join_path(base, 'templates', 'loops')
	os.mkdir_all(tpl) or { panic(err.msg()) }
	os.write_file(os.join_path(tpl, 'tiny.yaml'), 'name: tiny\ntier: L1\ncadence: 1d\nmax_tokens: 10\ngoal: |\n  observe\nrequest: |\n  report status\n') or {
		panic(err.msg())
	}
	init := run_loop(LoopOptions{
		subcommand: 'init'
		workspace_path: base
		name: 'tiny'
	})
	assert init.ok, init.message
	// plant today's exhausted token trace: the budget is already spent
	ts := time.utc().format_rfc3339()
	rundir := os.join_path(base, 'loops', 'tiny', 'runs', 'planted')
	os.mkdir_all(rundir) or { panic(err.msg()) }
	os.write_file(os.join_path(rundir, 'trace.jsonl'),
		'{"kind":"token_usage","ts":"${ts}","total_tokens":100}\n') or { panic(err.msg()) }
	plain := run_loop(LoopOptions{
		subcommand: 'run'
		workspace_path: base
		name: 'tiny'
		no_llm: true
	})
	assert plain.data['status'] == 'budget_exhausted', plain.message
	// --force bypasses max_runs_per_day only: token exhaustion still blocks
	forced := run_loop(LoopOptions{
		subcommand: 'run'
		workspace_path: base
		name: 'tiny'
		no_llm: true
		force: true
	})
	assert forced.data['status'] == 'budget_exhausted', forced.message
}

fn test_loop_verifier_meta_and_pack_override() {
	assert parse_loop_meta_text('name: x\ntier: L3\nverifier: alice\n', 'x').verifier == 'alice'
	assert parse_loop_meta_text('name: x\ntier: L1\n', 'x').verifier == ''
	assert parse_pack_overrides('loops:\n  x:\n    verifier: bob\n', 'x').verifier == 'bob'
	// a verifier-only pack must still invoke the patcher and persist (#1265)
	base := os.join_path(os.temp_dir(), 'at-loop-verifier-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	yaml_path := os.join_path(base, 'loop.yaml')
	os.write_file(yaml_path, 'name: x\ntier: L1\n') or { assert false, err.msg() }
	overrides := parse_pack_overrides('loops:\n  x:\n    verifier: bob\n', 'x')
	patch_loop_yaml_with_overrides(yaml_path, overrides)
	patched := os.read_file(yaml_path) or { '' }
	assert patched.contains('verifier: bob'), 'verifier-only pack persists, got: ${patched}'
	// an existing verifier line is replaced, not duplicated
	os.write_file(yaml_path, 'name: x\ntier: L1\nverifier: alice\n') or { assert false, err.msg() }
	patch_loop_yaml_with_overrides(yaml_path, overrides)
	repatched := os.read_file(yaml_path) or { '' }
	assert repatched.contains('verifier: bob') && !repatched.contains('alice')
	sysp := loop_runner_sysprompt('x', 'r1', 'L3', '/runs/r1', '/loops/x', 'alice')
	assert sysp.contains('Verifier for mutating actions: alice')
	sysp_none := loop_runner_sysprompt('x', 'r1', 'L1', '/runs/r1', '/loops/x', '')
	assert sysp_none.contains('treat all mutating actions as escalations')
}
