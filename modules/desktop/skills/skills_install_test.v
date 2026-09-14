module skills

import os
import desktop_engine

// Library skill install lifecycle (slice C): preview/apply/verify/receipt,
// with failure/recovery paths and never-claims-installed.

fn new_skill_lifecycle_test_engine(suffix string) (string, &desktop_engine.Engine) {
	tmp := os.join_path(os.temp_dir(), 'skills-install-${suffix}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut e := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { panic(err.msg()) }
	e.start() or { panic(err.msg()) }
	return tmp, e
}

fn test_skill_toggle_unknown_id_fails_without_mutating() {
	tmp, mut e := new_skill_lifecycle_test_engine('unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_skill_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.toggle('definitely-not-a-skill-xyz') {
		assert false, 'toggle of an unknown skill must fail'
	} else {
		assert err.msg().contains('not found'), 'failure must explain the cause for recovery: ${err.msg()}'
	}
	assert e.revision() == rev_before, 'failed toggle must not advance the revision'
	assert vm.lifecycle_state('definitely-not-a-skill-xyz') == 'unavailable'
}

fn test_skill_bulk_install_empty_fails_with_recovery_hint() {
	tmp, mut e := new_skill_lifecycle_test_engine('bulk-empty')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_skill_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.bulk_install([]) {
		assert false, 'bulk install of nothing must fail'
	} else {
		assert err.msg().contains('no skills selected'), 'failure must say what to do instead: ${err.msg()}'
	}
	assert e.revision() == rev_before
}

fn test_skill_preview_is_dry_run_and_names_the_change() {
	tmp, mut e := new_skill_lifecycle_test_engine('preview')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_skill_viewmodel(mut e)
	cat := e.skills_catalog()
	if cat.len == 0 {
		assert vm.preview_summary('any-skill').starts_with('cannot preview:'), 'empty catalog previews nothing'
		return
	}
	id := cat[0].id
	rev_before := e.revision()
	summary := vm.preview_summary(id)
	assert summary.starts_with('preview:'), 'preview must render the dry-run diff: ${summary}'
	assert e.revision() == rev_before, 'preview must never mutate'
	assert vm.preview_summary('definitely-not-a-skill-xyz').starts_with('cannot preview:'),
		'preview of unknown skill must explain, not invent a diff'
}

fn test_skill_selection_is_configured_never_verified() {
	tmp, mut e := new_skill_lifecycle_test_engine('select')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_skill_viewmodel(mut e)
	cat := e.skills_catalog()
	if cat.len == 0 {
		assert vm.verify_summary('any-skill').starts_with('unavailable:')
		return
	}
	id := cat[0].id
	rev := vm.install(id) or { panic(err.msg()) }
	assert rev > 0
	st := vm.lifecycle_state(id)
	assert st != 'installed', 'the selection flag must never be called installed'
	if st == 'verified' {
		assert vm.verify_summary(id).contains('verified'), 'verified state carries receipt evidence'
	} else {
		assert st == 'configured', 'selection without receipt is configured, got ${st}'
		msg := vm.verify_summary(id)
		assert msg.contains('unverified'), 'verify must name the next step: ${msg}'
	}
	_ := vm.remove(id) or { panic(err.msg()) }
	after := vm.lifecycle_state(id)
	assert after == 'available' || after == 'verified', 'after remove the flag must be gone, got ${after}'
}

fn test_skill_verify_unknown_id_reports_unavailable() {
	tmp, mut e := new_skill_lifecycle_test_engine('verify-unknown')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_skill_viewmodel(mut e)
	assert vm.verify_summary('definitely-not-a-skill-xyz').starts_with('unavailable:'),
		'verify of unknown skill must report unavailable with evidence'
}
