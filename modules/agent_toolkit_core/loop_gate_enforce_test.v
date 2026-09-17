module agent_toolkit_core

import os

fn test_gate_evaluate_matrix() {
	l1 := GatePolicy{
		tier:      'L1'
		allowlist: ['comment', 'merge']
		deny:      []string{}
	}
	ok, _ := gate_evaluate(l1, 'comment', false)
	assert !ok
	ok2, reason2 := gate_evaluate(l1, 'merge', true)
	assert !ok2
	assert reason2.contains('read-only')
	l3 := GatePolicy{
		tier:      'L3'
		allowlist: ['comment', 'merge']
		deny:      []string{}
	}
	ok3, _ := gate_evaluate(l3, 'comment', false)
	assert ok3
	// merge needs a receipt even when allowlisted
	ok4, reason4 := gate_evaluate(l3, 'merge', false)
	assert !ok4
	assert reason4.contains('receipt')
	ok5, _ := gate_evaluate(l3, 'merge', true)
	assert ok5
	// deny list wins
	l3d := GatePolicy{
		tier:      'L3'
		allowlist: ['comment', 'merge']
		deny:      ['merge']
	}
	ok6, _ := gate_evaluate(l3d, 'merge', true)
	assert !ok6
	// empty allowlist denies everything (except read-only '')
	l3e := GatePolicy{
		tier:      'L3'
		allowlist: []string{}
		deny:      []string{}
	}
	ok7, _ := gate_evaluate(l3e, 'comment', false)
	assert !ok7
	ok8, _ := gate_evaluate(l3e, '', false)
	assert ok8
	// L2 cannot merge
	l2 := GatePolicy{
		tier:      'L2'
		allowlist: ['comment', 'merge']
		deny:      []string{}
	}
	ok9, reason9 := gate_evaluate(l2, 'merge', true)
	assert !ok9
	assert reason9.contains('L3')
}

fn test_gate_canonical_payload_python_compat() {
	got := gate_canonical_payload('merge', 'bot', '2026-09-17T10:00:00Z', '2026-09-17T11:00:00Z', 'n1')
	assert got == '{"action":"merge","actor":"bot","expires_at":"2026-09-17T11:00:00Z","issued_at":"2026-09-17T10:00:00Z","nonce":"n1"}'
	assert gate_json_escape('a"b\\c') == '"a\\"b\\\\c"'
}

fn test_gate_receipt_roundtrip_and_tamper() {
	base := os.join_path(os.temp_dir(), 'at-gate-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	// unsigned roundtrip (no secret configured)
	rec := gate_issue_receipt(base, 'merge', 'verifier', 3600, '') or {
		assert false, err.msg()
		return
	}
	assert rec.action == 'merge'
	found := gate_find_receipt(base, 'merge', '') or {
		assert false, 'receipt should be found'
		return
	}
	assert found.actor == 'verifier'
	// wrong action does not match
	miss := gate_find_receipt(base, 'close', '') or { GateReceipt{} }
	assert miss.action == ''
	// HMAC roundtrip
	rec2 := gate_issue_receipt(base, 'close', 'v2', 3600, 's3cr3t') or {
		assert false, err.msg()
		return
	}
	assert rec2.signature != ''
	found2 := gate_find_receipt(base, 'close', 's3cr3t') or {
		assert false, 'signed receipt should verify'
		return
	}
	assert found2.actor == 'v2'
	// tampered file fails closed under a secret
	raw := os.read_file(gate_receipt_path(base)) or { '' }
	os.write_file(gate_receipt_path(base), raw.replace('"close"', '"merge"')) or {}
	tampered := gate_find_receipt(base, 'merge', 's3cr3t') or { GateReceipt{} }
	assert tampered.action == ''
	// expired fixture fails closed
	os.write_file(gate_receipt_path(base), '{"action":"merge","actor":"v","issued_at":"2020-01-01T00:00:00Z","expires_at":"2020-01-01T01:00:00Z","nonce":"old","signature":""}\n') or {}
	stale := gate_find_receipt(base, 'merge', '') or { GateReceipt{} }
	assert stale.action == ''
}

fn test_gate_attribution() {
	p := gate_attribution_prefix('bot', 'run-1')
	assert p.contains('> 🤖 AI-assisted')
	assert p.contains('@bot')
	once := gate_apply_attribution('hello', 'bot', 'run-1')
	assert once.contains('> 🤖 AI-assisted')
	twice := gate_apply_attribution(once, 'bot', 'run-1')
	assert twice == once
}

fn test_gate_rewrite_argv() {
	out := gate_rewrite_argv(['pr', 'comment', '1', '--body', 'hi'], 'bot', 'r1')
	assert out[4].contains('> 🤖 AI-assisted')
	assert out[4].contains('hi')
	// -f untouched
	out2 := gate_rewrite_argv(['pr', 'comment', '1', '-f', 'file.txt'], 'bot', 'r1')
	assert out2 == ['pr', 'comment', '1', '-f', 'file.txt']
	// --body-file rewritten on disk
	base := os.join_path(os.temp_dir(), 'at-body-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	bf := os.join_path(base, 'body.md')
	os.write_file(bf, 'original\n') or { assert false, err.msg() }
	_ = gate_rewrite_argv(['issue', 'comment', '--body-file', bf], 'bot', 'r9')
	after := os.read_file(bf) or { '' }
	assert after.contains('> 🤖 AI-assisted')
}

fn test_gate_denial_log_and_redaction() {
	base := os.join_path(os.temp_dir(), 'at-deny-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	gate_write_denial(base, 'merge', 'L1', ['pr', 'merge', '1', '--token', 'sekret'], 'tier L1 is read-only')
	line := os.read_file(gate_denials_path(base)) or { '' }
	assert line.contains('"action":"merge"')
	assert line.contains('[redacted]')
	assert !line.contains('sekret')
}

fn test_gate_shim_generation() {
	base := os.join_path(os.temp_dir(), 'at-shim-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	gate_write_shim(os.join_path(base, 'gate-bin'), '/usr/bin/agent-toolkit', '/usr/bin/gh') or {
		assert false, err.msg()
	}
	script := os.read_file(os.join_path(base, 'gate-bin', 'gh')) or { '' }
	assert script.contains('loop gate-exec')
	assert script.contains('ATK_REAL_GH=')
	assert script.contains('GH_ARGV')
	assert script.contains('/usr/bin/gh')
}

fn test_gate_exec_end_to_end() {
	$if windows {
		return
	}
	base := os.join_path(os.temp_dir(), 'at-exec2-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	fake := os.join_path(base, 'real-gh')
	os.write_file(fake, '#!/bin/sh\necho "forwarded: $@"\n') or { assert false, err.msg() }
	os.chmod(fake, 0o755) or { assert false, err.msg() }
	old_real := os.getenv('ATK_REAL_GH')
	os.setenv('ATK_REAL_GH', fake, true)
	defer {
		os.setenv('ATK_REAL_GH', old_real, true)
	}
	// read-only passes through (repo/release verbs are push-classified)
	ro := GatePolicy{
		tier:      'L1'
		allowlist: []string{}
		deny:      []string{}
		run_dir:   base
	}
	r1 := gate_exec_with(ro, ['status'], '')
	assert r1.ok, r1.message
	assert r1.message.contains('forwarded:')
	// L1 merge denied + audit-logged
	r2 := gate_exec_with(ro, ['pr', 'merge', '1'], '')
	assert !r2.ok
	assert r2.message.contains('denied')
	denials := os.read_file(gate_denials_path(base)) or { '' }
	assert denials.contains('"merge"')
	// L3 merge without receipt denied; with receipt forwarded
	l3 := GatePolicy{
		tier:      'L3'
		allowlist: ['merge']
		deny:      []string{}
		run_dir:   base
	}
	r3 := gate_exec_with(l3, ['pr', 'merge', '2'], '')
	assert !r3.ok
	assert r3.message.contains('receipt')
	_ = gate_issue_receipt(base, 'merge', 'verifier', 3600, '') or {
		assert false, err.msg()
		return
	}
	r4 := gate_exec_with(l3, ['pr', 'merge', '2'], '')
	assert r4.ok, r4.message
}
