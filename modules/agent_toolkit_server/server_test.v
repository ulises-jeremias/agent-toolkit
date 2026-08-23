module agent_toolkit_server

fn test_validate_bind_local_ok() {
	validate_bind('127.0.0.1', false, '') or { assert false, err.msg() }
}

fn test_validate_bind_remote_requires_token() {
	validate_bind('0.0.0.0', true, '') or {
		assert err.msg().contains('--auth-token')
		return
	}
	assert false, 'expected error'
}

fn test_validate_bind_remote_with_token_ok() {
	validate_bind('0.0.0.0', true, 'secret') or { assert false, err.msg() }
}

fn test_new_app_defaults_port_and_host() {
	app := new_app(ServeOptions{})
	assert app.opts.host == '127.0.0.1'
	assert app.opts.port == 3847
}

fn test_result_to_http_mapping() {
	res_ok := agent_toolkit_core.version_result('9.9.9')
	code_ok, body_ok := result_to_http(res_ok)
	assert code_ok == 200
	assert body_ok.contains('"ok":true')

	res_bad := agent_toolkit_core.not_implemented_result('zzz')
	code_bad, body_bad := result_to_http(res_bad)
	assert code_bad == 422
	assert body_bad.contains('"ok":false')
}
