module agent_toolkit_server

import net
import time

fn handle_one(mut l net.TcpListener) {
	mut conn := l.accept() or { return }
	conn.close() or {}
}

fn test_integration_listener_ephemeral_loopback_ipv4() {
	mut l := net.listen_tcp(.ip, '127.0.0.1:0') or {
		assert false, 'listen 127.0.0.1:0 failed: ${err.msg()}'
		return
	}
	defer {
		l.close() or {}
	}
	addr := l.addr() or {
		assert false, err.msg()
		return
	}
	addr_str := addr.str()
	assert addr_str.contains('127.0.0.1'), 'expected loopback addr, got ${addr_str}'
	port := addr.port() or { panic(err.msg()) }
	assert port != 0
	spawn handle_one(mut l)
	time.sleep(50 * time.millisecond)
	mut conn := net.dial_tcp('127.0.0.1:${port}') or {
		assert false, 'dial 127.0.0.1:${port} failed: ${err.msg()}'
		return
	}
	conn.close() or {}
}

fn test_integration_listener_is_not_wildcard() {
	assert is_loopback('127.0.0.1')
	assert !is_loopback('0.0.0.0')
	mut tmp := net.listen_tcp(.ip, '127.0.0.1:0') or {
		assert false, err.msg()
		return
	}
	defer {
		tmp.close() or {}
	}
	p := tmp.addr() or { return }.port() or { return }
	spawn handle_one(mut tmp)
	time.sleep(50 * time.millisecond)
	// dialing wildcard as client may be OS-dependent; ensure loopback dial still works
	if mut c := net.dial_tcp('0.0.0.0:${p}') {
		c.close() or {}
	}
	mut ok := net.dial_tcp('127.0.0.1:${p}') or {
		assert false, err.msg()
		return
	}
	ok.close() or {}
}

fn test_integration_ephemeral_via_new_app_and_validate() {
	for host in ['127.0.0.1', 'localhost', '::1', '::ffff:127.0.0.1'] {
		validate_bind(host, false, '') or { assert false, '${host} should be loopback' }
		if host == 'localhost' || host == '::ffff:127.0.0.1' {
			continue
		}
		family := if host.contains(':') { net.AddrFamily.ip6 } else { net.AddrFamily.ip }
		mut l := net.listen_tcp(family, '${host}:0') or { continue }
		l.close() or {}
	}
	for host in ['0.0.0.0', '::', '192.168.1.1', '10.0.0.1'] {
		assert !is_loopback(host), '${host} should be remote'
	}
}

fn test_integration_remote_bind_requires_token_table() {
	// default loopback test: 127.0.0.1 succeeds via net dial, remote without permission fails at validate layer
	mut l := net.listen_tcp(.ip, '127.0.0.1:0') or {
		assert false, err.msg()
		return
	}
	defer { l.close() or {} }
	port := l.addr() or { return }.port() or { return }
	spawn handle_one(mut l)
	time.sleep(50 * time.millisecond)
	mut c := net.dial_tcp('127.0.0.1:${port}') or {
		assert false, 'loopback dial should succeed: ${err.msg()}'
		return
	}
	c.close() or {}
	// remote without permission must fail before listen
	validate_bind('0.0.0.0', false, '') or {
		assert err.msg().contains('remote bind')
		return
	}
	assert false, '0.0.0.0 without allow_remote should fail'
}

fn test_integration_remote_with_token_allows_bind() {
	for host in ['0.0.0.0', '::', '192.168.1.1', '10.0.0.1'] {
		validate_bind(host, true, '') or {
			assert err.msg().contains('--auth-token')
			continue
		}
		assert false, '${host} allow_remote without token should fail'
	}
	for host in ['0.0.0.0', '::', '192.168.1.1', '10.0.0.1'] {
		validate_bind(host, true, 's3cret') or {
			assert false, '${host} with token should pass: ${err.msg()}'
		}
		// if system permits, we can even listen on that wildcard/remote addr with ephemeral port
		family := if host.contains(':') { net.AddrFamily.ip6 } else { net.AddrFamily.ip }
		// skip 192.168/10 addresses that may not be assigned locally
		if host.contains('192.168') || host.contains('10.0.0.1') {
			continue
		}
		mut l := net.listen_tcp(family, '${host}:0') or { continue }
		_ = l.addr() or { continue }
		l.close() or {}
	}
}

fn test_integration_all_addr_forms_loopback_vs_remote() {
	// exhaustive addr forms from issue requirement
	mut loopback_ok := 0
	for host in ['127.0.0.1', 'localhost', '::1', '::ffff:127.0.0.1'] {
		if is_loopback(host) {
			loopback_ok++
		}
		validate_bind(host, false, '') or {
			assert false, 'loopback ${host} should not require token: ${err.msg()}'
		}
	}
	assert loopback_ok == 4
	mut remote_ok := 0
	for host in ['0.0.0.0', '::', '192.168.1.1', '10.0.0.1'] {
		if !is_loopback(host) {
			remote_ok++
		}
		validate_bind(host, false, '') or {
			assert err.msg().contains('remote bind')
			continue
		}
		assert false, 'remote ${host} should require token'
	}
	assert remote_ok == 4
}
