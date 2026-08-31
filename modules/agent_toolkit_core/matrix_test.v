module agent_toolkit_core

import os

fn test_matrix_result_at_found() {
	root := os.join_path(os.temp_dir(), 'at-matrix-${os.getpid()}')
	dir := os.join_path(root, 'docs', 'research')
	os.mkdir_all(dir) or { assert false, err.msg() }
	path := os.join_path(dir, 'platform-capability-matrix.md')
	os.write_file(path, '# Capability Matrix\nClaude Code\n') or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	r := matrix_result_at(root)
	assert r.ok
	assert r.data['found'] == 'true'
	assert r.message.contains('Capability Matrix')
}

fn test_matrix_result_at_missing() {
	root := os.join_path(os.temp_dir(), 'at-matrix-miss-${os.getpid()}')
	os.mkdir_all(root) or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	r := matrix_result_at(root)
	assert r.ok
	assert r.data['found'] == 'false'
	assert r.message.contains('Matrix not found')
}
