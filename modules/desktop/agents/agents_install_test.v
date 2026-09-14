module agents

import os
import desktop_engine

// Library agent install lifecycle (slice C): validate → preview → apply →
// verify → receipt, with failure/recovery paths and never-claims-installed.

fn new_lifecycle_test_engine(suffix string) (string, &desktop_engine.Engine) {
	tmp := os.join_path(os.temp_dir(), 'agents-install-${suffix}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut e := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { panic(err.msg()) }
	e.start() or { panic(err.msg()) }
	return tmp, e
}

fn test_agent_install_unknown_id_fails_without_mutating() {
	tmp, mut e := new_lifecycle_test_engine('unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_agents_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.install('definitely-not-an-agent-xyz') {
		assert false, 'install of an unknown agent must fail'
	} else {
		assert err.msg().contains('not found'), 'failure must explain the cause for recovery: ${err.msg()}'
	}
	assert e.revision() == rev_before, 'failed install must not advance the revision'
	assert vm.lifecycle_state('definitely-not-an-agent-xyz') == 'unavailable'
}

fn test_agent_preview_unknown_id_explains_unavailable() {
	tmp, mut e := new_lifecycle_test_engine('preview-unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_agents_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.preview_install('definitely-not-an-agent-xyz') {
		assert false, 'preview of an unknown agent must fail'
	} else {
		assert err.msg().contains('not found'), 'preview failure must name the cause: ${err.msg()}'
	}
	assert e.revision() == rev_before, 'preview must never mutate'
}

fn test_agent_verify_unknown_id_reports_unavailable() {
	tmp, mut e := new_lifecycle_test_engine('verify-unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_agents_viewmodel(mut e)
	ok, msg := vm.verify_install('definitely-not-an-agent-xyz')
	assert !ok, 'verify of an unknown agent is never ok'
	assert msg.starts_with('unavailable:'), 'verify must report unavailable with evidence: ${msg}'
}

fn test_agent_install_selection_is_configured_never_verified() {
	tmp, mut e := new_lifecycle_test_engine('select')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_agents_viewmodel(mut e)
	cat := e.agents_catalog()
	if cat.len == 0 {
		assert vm.lifecycle_state('any-agent') == 'unavailable'
		return
	}
	id := cat[0].id
	assert vm.lifecycle_state(id) == 'available', 'fresh engine must show ${id} as available'
	// preview is a dry run: it must not mutate the revision
	rev_before := e.revision()
	preview := vm.preview_install(id) or { panic(err.msg()) }
	assert preview.contains('agents:installed:${id}=true'), 'preview must state the exact flag it would set: ${preview}'
	assert e.revision() == rev_before, 'preview must never mutate'
	rev := vm.install(id) or { panic(err.msg()) }
	assert rev > 0
	// install_agent records a selection flag only — no receipt is written —
	// so the state is configured, never verified and never 'installed'
	st := vm.lifecycle_state(id)
	if st == 'verified' {
		ok, msg := vm.verify_install(id)
		assert ok, 'verified state must verify ok: ${msg}'
		assert msg.contains('verified'), 'verify message must carry evidence: ${msg}'
	} else {
		assert st == 'configured', 'selection without receipt is configured, got ${st}'
		assert st != 'installed', 'the flag alone must never be called installed'
		ok, msg := vm.verify_install(id)
		assert !ok, 'configured without receipt must not verify ok'
		assert msg.contains('unverified'), 'verify must name the next step: ${msg}'
	}
	assert id in vm.configured_ids(), 'configured agent must be listed by configured_ids'
	// recovery: removing clears the flag; a receipt (if any) is retained evidence
	_ := vm.remove_agent(id) or { panic(err.msg()) }
	after := vm.lifecycle_state(id)
	assert after == 'available' || after == 'verified', 'after remove the flag must be gone, got ${after}'
	assert id !in vm.configured_ids()
}

fn test_agent_remove_unknown_id_is_safe_noop() {
	tmp, mut e := new_lifecycle_test_engine('remove-unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_agents_viewmodel(mut e)
	_ := vm.remove_agent('definitely-not-an-agent-xyz') or {
		panic('remove of unknown agent must be a safe no-op: ${err.msg()}')
	}
	assert vm.lifecycle_state('definitely-not-an-agent-xyz') == 'unavailable'
}
