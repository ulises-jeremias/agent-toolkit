module agent_toolkit_core

import os

fn test_embedded_data_candidates_wheel_layout() {
	cands := embedded_data_candidates('/opt/pkg/bin')
	assert cands.len == 2
	assert cands[0].ends_with('/bin/data') || cands[0].ends_with('\\bin\\data')
	assert cands[1].contains('..')
	base := os.join_path(os.temp_dir(), 'at-embed-${os.getpid()}')
	pkg_data := os.join_path(base, 'data')
	os.mkdir_all(os.join_path(pkg_data, 'skills')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	assert is_valid_toolkit_root(pkg_data)
}

fn test_is_valid_toolkit_root_profiles() {
	dir := os.join_path(os.temp_dir(), 'at-paths-profiles-${os.getpid()}')
	os.mkdir_all(os.join_path(dir, 'profiles')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	assert is_valid_toolkit_root(dir)
}

fn test_override_env_wins() {
	dir := os.join_path(os.temp_dir(), 'at-paths-override-${os.getpid()}')
	os.mkdir_all(os.join_path(dir, 'skills')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	old := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', dir, true)
	defer {
		restore_env('AGENT_TOOLKIT_ROOT', old)
	}
	root := find_toolkit_root() or {
		assert false, err.msg()
		return
	}
	assert root.tier == 'override'
	assert root.path == dir
}

fn test_offline_does_not_require_network() {
	old := os.getenv('AGENT_TOOLKIT_OFFLINE')
	os.setenv('AGENT_TOOLKIT_OFFLINE', '1', true)
	defer {
		restore_env('AGENT_TOOLKIT_OFFLINE', old)
	}
	assert is_offline()
	root := find_toolkit_root() or {
		assert false, err.msg()
		return
	}
	assert root.path.len > 0
	assert root.tier in ['override', 'xdg_data', 'xdg_cache', 'embedded', 'checkout', 'cwd']
}

fn test_checkout_from_cwd_when_no_override() {
	old_root := os.getenv('AGENT_TOOLKIT_ROOT')
	old_ws := os.getenv('AI_WORKSPACE')
	os.unsetenv('AGENT_TOOLKIT_ROOT')
	os.unsetenv('AI_WORKSPACE')
	defer {
		restore_env('AGENT_TOOLKIT_ROOT', old_root)
		restore_env('AI_WORKSPACE', old_ws)
	}
	root := find_toolkit_root() or {
		assert false, err.msg()
		return
	}
	// With full-embed, fresh checkout may resolve to embedded (path == 'embedded') which is not a filesystem dir
	assert is_valid_toolkit_root(root.path) || root.path == 'embedded' || embedded_is_valid_root()
	assert root.tier in ['override', 'xdg_data', 'xdg_cache', 'embedded', 'checkout', 'cwd']
}

fn restore_env(key string, old string) {
	if old.len > 0 {
		os.setenv(key, old, true)
	} else {
		os.unsetenv(key)
	}
}
