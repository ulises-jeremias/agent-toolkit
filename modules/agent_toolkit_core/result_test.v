module agent_toolkit_core

fn test_version_result_shape() {
	r := version_result('1.10.0')
	assert r.ok
	assert r.message == 'agent-toolkit 1.10.0'
	assert r.data['version'] == '1.10.0'
}

fn test_not_implemented_result() {
	r := not_implemented_result('inventory')
	assert r.ok == false
	assert r.data['status'] == 'not_implemented'
}
