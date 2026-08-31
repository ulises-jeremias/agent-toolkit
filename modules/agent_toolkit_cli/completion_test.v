module agent_toolkit_cli

fn test_completion_bash_registers_complete() {
	script := completion_bash()
	assert script.contains('complete -F _agent_toolkit_completions agent-toolkit')
	assert script.contains('install')
	assert script.len > 100
}

fn test_completion_zsh_compdef() {
	script := completion_zsh()
	assert script.contains('#compdef agent-toolkit')
	assert script.contains('install')
}

fn test_completion_fish_complete_c() {
	script := completion_fish()
	assert script.contains('complete -c agent-toolkit')
	assert script.contains('install')
}

fn test_completion_powershell_register() {
	script := completion_powershell()
	assert script.contains('Register-ArgumentCompleter')
	assert script.contains('agent-toolkit')
}

fn test_run_completion_help() {
	assert run_completion(['--help']) == 0
	assert run_completion([]) == 0
}

fn test_run_completion_unknown_shell() {
	assert run_completion(['csh']) == 2
}

fn test_run_completion_each_shell() {
	for shell in completion_shells {
		assert run_completion([shell]) == 0
	}
}

fn test_dispatch_completion_help() {
	assert dispatch(['agent-toolkit', 'completion', '--help']) == 0
}

fn test_dispatch_completion_bash() {
	assert dispatch(['agent-toolkit', 'completion', 'bash']) == 0
}
