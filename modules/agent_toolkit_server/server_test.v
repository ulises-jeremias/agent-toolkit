module agent_toolkit_server

import time

fn test_handle_health() {
	opts := default_serve_options()
	started := time.utc()
	code, body := handle_request('GET', '/api/v1/health', {}, opts, started)
	assert code == 200
	assert body.contains('"ok":true')
	assert body.contains('version')
}

fn test_handle_version() {
	opts := default_serve_options()
	code, body := handle_request('GET', '/api/v1/version', {}, opts, time.utc())
	assert code == 200
	assert body.contains('"ok":true')
}

fn test_unknown_route_404() {
	opts := default_serve_options()
	code, _ := handle_request('GET', '/nope', {}, opts, time.utc())
	assert code == 404
}

fn test_method_not_allowed() {
	opts := default_serve_options()
	code, _ := handle_request('POST', '/api/v1/version', {}, opts, time.utc())
	assert code == 405
}

fn test_remote_requires_token() {
	mut opts := default_serve_options()
	opts.host = '0.0.0.0'
	// no token set → any request unauthorized
	code, body := handle_request('GET', '/api/v1/health', {}, opts, time.utc())
	assert code == 401
	assert body.contains('unauthorized')
	// with token
	opts.auth_token = 'secret123'
	hdrs := {'authorization': 'Bearer secret123'}
	code2, _ := handle_request('GET', '/api/v1/health', hdrs, opts, time.utc())
	assert code2 == 200
}
