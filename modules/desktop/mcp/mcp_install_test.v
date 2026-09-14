module mcp

import os
import desktop_engine

// Library MCP lifecycle (slice C): setup/health/uninstall with honesty —
// health is a probe result, never a default for being enabled.

fn new_mcp_lifecycle_test_engine(suffix string) (string, &desktop_engine.Engine) {
	tmp := os.join_path(os.temp_dir(), 'mcp-install-${suffix}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut e := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { panic(err.msg()) }
	e.start() or { panic(err.msg()) }
	return tmp, e
}

fn test_mcp_probe_unknown_provider_fails_with_recovery() {
	tmp, mut e := new_mcp_lifecycle_test_engine('probe-unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_mcp_viewmodel(mut e)
	if _ := vm.engine.mcp_probe('definitely-not-a-provider-xyz') {
		assert false, 'probe of an unknown provider must fail'
	} else {
		assert err.msg().contains('not found'), 'failure must name the cause for recovery: ${err.msg()}'
	}
	unknown_stage, _ := vm.stage('definitely-not-a-provider-xyz')
	assert unknown_stage == 'unknown'
}

fn test_mcp_validate_unknown_provider_reports_diagnostic() {
	tmp, mut e := new_mcp_lifecycle_test_engine('validate-unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_mcp_viewmodel(mut e)
	summary := vm.validate_summary('definitely-not-a-provider-xyz')
	assert summary.contains('unknown_provider') || summary.contains('not in packaged catalog'),
		'validate must report the unknown provider with evidence: ${summary}'
}

fn test_mcp_setup_rejects_invalid_json_without_mutating() {
	tmp, mut e := new_mcp_lifecycle_test_engine('setup-json')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_mcp_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.setup('definitely-not-a-provider-xyz', '{"broken"') {
		assert false, 'setup with invalid JSON must fail'
	} else {
		assert err.msg().contains('not valid JSON'), 'failure must explain the cause: ${err.msg()}'
	}
	assert e.revision() == rev_before, 'rejected setup must not advance the revision'
}

fn test_mcp_setup_rejects_raw_secret_without_mutating() {
	tmp, mut e := new_mcp_lifecycle_test_engine('setup-secret')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_mcp_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.setup('definitely-not-a-provider-xyz', '{"token":"sk-abc123"}') {
		assert false, 'setup with a raw token must fail the secret guard'
	} else {
		assert err.msg().contains('secret guard'), 'failure must cite the guard + recovery: ${err.msg()}'
	}
	assert e.revision() == rev_before, 'rejected setup must not advance the revision'
}

fn test_mcp_uninstall_unknown_provider_is_safe_noop() {
	tmp, mut e := new_mcp_lifecycle_test_engine('uninstall-unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_mcp_viewmodel(mut e)
	_ := vm.uninstall('definitely-not-a-provider-xyz') or {
		panic('uninstall of unknown provider must be a safe no-op: ${err.msg()}')
	}
	assert vm.health_detailed('definitely-not-a-provider-xyz') == 'unconfigured'
}

fn test_mcp_setup_enable_is_configured_never_healthy() {
	tmp, mut e := new_mcp_lifecycle_test_engine('roundtrip')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_mcp_viewmodel(mut e)
	cat := e.mcp_catalog()
	if cat.len == 0 {
		empty_stage, _ := vm.stage('any-provider')
		assert empty_stage == 'unknown'
		return
	}
	id := cat[0].id
	content, from_file := e.mcp_template_json(id)
	if !from_file || content == '' || desktop_engine.has_raw_secret(content) {
		// no real packaged template to set up with — setup cannot be proven
		return
	}
	rev_before := e.revision()
	rev := vm.setup(id, content) or { panic('setup with packaged template must succeed: ${err.msg()}') }
	assert rev > rev_before
	// enabling records config — health stays configured until a probe
	// succeeds; it is never claimed healthy by default
	health := vm.health_detailed(id)
	assert health != 'healthy' || vm.engine.mcp_health(id) == 'healthy',
		'healthy is a probe result, never a setup default: ${health}'
	stage, _ := vm.stage(id)
	assert stage == 'configured' || stage == 'healthy', 'enabled provider is configured, got ${stage}'
	// install preview never mutates
	_ = vm.install_preview(id)
	assert e.revision() == rev, 'preview must never mutate'
	// uninstall clears enable state; recorded config is left for evidence
	_ := vm.uninstall(id) or { panic(err.msg()) }
	assert vm.health_detailed(id) != 'healthy', 'uninstalled provider must not read healthy'
}
