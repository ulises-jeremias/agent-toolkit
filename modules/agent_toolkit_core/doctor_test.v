module agent_toolkit_core

fn test_run_doctor_readonly_has_observability_fields() {
	snap := run_doctor_readonly()
	assert snap.engine == 'v'
	assert snap.version.len > 0
	assert snap.platform.contains('/')
	r := doctor_result(snap)
	assert r.data['engine'] == 'v'
	assert r.data['version'] == snap.version
	assert r.data['platform'] == snap.platform
}
