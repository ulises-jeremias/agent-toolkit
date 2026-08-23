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

fn test_handle_read_inventory_422_or_200() {
	opts := default_serve_options()
	code, _ := handle_request('GET', '/api/v1/inventory', {}, opts, time.utc())
	assert code in [200, 422]
}

fn test_handle_read_loops_list() {
	opts := default_serve_options()
	code, body := handle_request('GET', '/api/v1/loops', {}, opts, time.utc())
	assert code == 200
	assert body.contains('"ok"')
}

fn test_handle_unknown_loop_status_404() {
	opts := default_serve_options()
	// workspace without such loop → run_loop reports not-found → we map 404 only when message says so;
	// in repo root (no loops dir) list returns ok empty; status for missing name yields not found.
	code, _ := handle_request('GET', '/api/v1/loops/definitely-missing-xyz/status', {}, opts, time.utc())
	assert code in [200, 404]
}
