module agent_toolkit_core

fn test_exit_code_ok_is_zero() {
	assert ErrorClass.ok.exit_code() == 0
}

fn test_exit_code_usage_flags_is_two() {
	assert ErrorClass.usage_flags.exit_code() == 2
	e := err_usage_flags('parse', 'unknown flag')
	assert e.exit_code() == 2
}

fn test_exit_code_other_classes_are_one() {
	classes := [
		ErrorClass.user,
		ErrorClass.config,
		ErrorClass.env,
		ErrorClass.external,
		ErrorClass.network,
		ErrorClass.internal,
	]
	for c in classes {
		assert c.exit_code() == 1
	}
}

fn test_err_constructors_set_class_and_message() {
	e := err_env('offline', 'AGENT_TOOLKIT_OFFLINE set')
	assert e.class == .env
	assert e.code == 'offline'
	assert e.msg() == 'AGENT_TOOLKIT_OFFLINE set'
}
