module agent_toolkit_cli

import agent_toolkit_core

fn test_render_human_ok_exit_zero() {
	r := agent_toolkit_core.version_result('1.0.0')
	code := render(r, .human)
	assert code == 0
}

fn test_render_not_implemented_nonzero() {
	r := agent_toolkit_core.not_implemented_result('doctor')
	code := render(r, .json)
	assert code == 1
}

fn test_render_error_usage_flags() {
	e := agent_toolkit_core.err_usage_flags('parse', 'unknown flag')
	assert render_error(e, .quiet) == 2
}
