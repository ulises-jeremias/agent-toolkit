module agent_toolkit_core

import os

fn restore_env_ver(key string, old string) {
	if old.len > 0 {
		os.setenv(key, old, true)
	} else {
		os.unsetenv(key)
	}
}

fn test_embedded_version_semver_shape() {
	parts := embedded_version.split('.')
	assert parts.len >= 3
}

fn test_resolve_reads_version_file_via_env() {
	dir := os.join_path(os.temp_dir(), 'at-ver-${os.getpid()}')
	os.mkdir_all(os.join_path(dir, 'skills')) or { assert false, err.msg() }
	os.write_file(os.join_path(dir, 'VERSION'), '9.9.9\n') or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	old := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', dir, true)
	defer {
		restore_env_ver('AGENT_TOOLKIT_ROOT', old)
	}
	assert resolve_toolkit_version() == '9.9.9'
}

fn test_resolve_returns_nonempty() {
	v := resolve_toolkit_version()
	assert v.len > 0
}

fn test_resolve_commit_env_override() {
	old := os.getenv('AGENT_TOOLKIT_COMMIT')
	os.setenv('AGENT_TOOLKIT_COMMIT', 'deadbeef', true)
	defer {
		restore_env_ver('AGENT_TOOLKIT_COMMIT', old)
	}
	assert resolve_commit() == 'deadbeef'
}

fn test_version_result_json_fields_not_in_message() {
	r := version_result('1.2.3')
	assert r.ok
	assert r.message == 'agent-toolkit 1.2.3'
	assert r.data['engine'] == 'v'
	assert r.data['version'] == '1.2.3'
	assert r.data['commit'].len > 0
}
