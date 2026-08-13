module agent_toolkit_core

import os

fn test_doctor_version_matches_resolve_toolkit_version() {
	assert doctor_version() == resolve_toolkit_version()
}

fn test_run_doctor_readonly_has_observability_fields() {
	snap := run_doctor_readonly()
	assert snap.engine == 'v'
	assert snap.version.len > 0
	assert snap.version == resolve_toolkit_version()
	assert snap.platform.contains('/')
	assert !snap.fix_applied
	r := doctor_result(snap)
	assert r.data['engine'] == 'v'
	assert r.data['version'] == snap.version
	assert r.data['commit'].len > 0
	assert r.data['platform'] == snap.platform
	assert r.data['fix_applied'] == 'false'
}

fn test_doctor_fix_refreshes_missing_cursor_profile() {
	base := os.join_path(os.temp_dir(), 'at-doc-fix-${os.getpid()}')
	home := os.join_path(base, 'home')
	data := os.join_path(base, 'data')
	os.mkdir_all(os.join_path(home, '.cursor')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'profiles', 'cursor', 'rules', 'assistant.mdc'), 'fixed\n') or {
		assert false, err.msg()
		return
	}
	// Missing rules/ → warn; --fix should create it
	readonly := run_doctor(DoctorOptions{
		home_dir:          home
		data_root:         data
		skip_data_refresh: true
	})
	assert !readonly.fix_applied
	assert readonly.checks.any(it.category == 'profiles' && it.status == 'warn')

	fixed := run_doctor(DoctorOptions{
		fix:               true
		home_dir:          home
		data_root:         data
		skip_data_refresh: true
	})
	assert fixed.fix_applied
	assert fixed.fix_action == 'update_profiles'
	assert os.is_file(os.join_path(home, '.cursor', 'rules', 'assistant.mdc'))
	assert doctor_result(fixed).data['fix_applied'] == 'true'
}

fn test_doctor_fix_noop_when_profiles_ok() {
	base := os.join_path(os.temp_dir(), 'at-doc-ok-${os.getpid()}')
	home := os.join_path(base, 'home')
	os.mkdir_all(os.join_path(home, '.cursor', 'rules')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(home, '.cursor', 'rules', 'x.mdc'), 'x\n') or {
		assert false, err.msg()
		return
	}
	snap := run_doctor(DoctorOptions{
		fix:               true
		home_dir:          home
		data_root:         base
		skip_data_refresh: true
	})
	assert !snap.fix_applied
	assert snap.message.contains('No profile issues')
}

fn test_doctor_includes_provenance_category() {
	snap := run_doctor(DoctorOptions{ provenance: true })
	assert snap.checks.any(it.category == 'provenance')
	assert snap.message.contains('Provenance') || snap.checks.any(it.name.contains('upstream.lock'))
}

fn test_doctor_skips_provenance_without_flag() {
	snap := run_doctor_readonly()
	assert !snap.checks.any(it.category == 'provenance')
}
