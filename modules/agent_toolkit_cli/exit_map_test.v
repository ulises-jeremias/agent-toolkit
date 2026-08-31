module agent_toolkit_cli

import agent_toolkit_core

fn test_map_exit_usage_flags() {
	e := agent_toolkit_core.err_usage_flags('flag', 'bad flag')
	assert map_exit(e) == 2
}

fn test_map_exit_user() {
	e := agent_toolkit_core.err_user('validate', 'bad input')
	assert map_exit(e) == 1
}

fn test_map_exit_ok_class() {
	assert map_exit_class(.ok) == 0
}
