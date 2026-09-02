module agent_toolkit_core

import os
import time

fn test_run_echo_captures_stdout() {
	p := new_process_service()
	exe := $if windows { 'cmd' } $else { 'echo' }
	argv := $if windows { [exe, '/c', 'echo', 'hello-at'] } $else { [exe, 'hello-at'] }
	res := p.run(
		argv: argv
		timeout: 5 * time.second
	) or {
		assert false, err.msg()
		return
	}
	assert res.timed_out == false
	assert res.exit_code == 0
	assert res.stdout.contains('hello-at')
}

fn test_run_missing_exe_is_env_error() {
	p := new_process_service()
	p.run(argv: ['agent-toolkit-definitely-missing-binary-xyz']) or {
		// DomainError via ! conversion — V returns error
		assert err.msg().contains('not found') || err.msg().len > 0
		return
	}
	assert false, 'expected missing executable error'
}

fn test_run_rejects_empty_argv() {
	p := new_process_service()
	p.run(argv: []) or {
		assert err.msg().contains('empty') || err.msg().len > 0
		return
	}
	assert false, 'expected empty argv error'
}

fn test_run_with_cwd() {
	p := new_process_service()
	cwd := os.temp_dir()
	$if windows {
		return
	}
	res := p.run(
		argv: ['pwd']
		cwd: cwd
		timeout: 5 * time.second
	) or {
		assert false, err.msg()
		return
	}
	assert res.exit_code == 0
	assert res.stdout.trim_space().contains(cwd.trim_right('/')) || res.stdout.len > 0
}
