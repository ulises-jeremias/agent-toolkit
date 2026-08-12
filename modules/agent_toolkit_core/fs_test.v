module agent_toolkit_core

import os

fn test_join_uses_os_join_path() {
	fs := FsService{
		home_dir: '/home/test'
	}
	p := fs.join(fs.home(), '.cache', 'agent-toolkit')
	assert p.contains('agent-toolkit')
	assert p.starts_with('/home/test') || p.starts_with('C:') // allow Windows CI later
}

fn test_xdg_cache_default() {
	fs := FsService{
		home_dir: '/home/test'
	}
	// Clear override for this process if set — save/restore
	old := os.getenv('XDG_CACHE_HOME')
	os.unsetenv('XDG_CACHE_HOME')
	defer {
		if old.len > 0 {
			os.setenv('XDG_CACHE_HOME', old, true)
		}
	}
	assert fs.xdg_cache_home() == fs.join('/home/test', '.cache')
	assert fs.toolkit_cache_dir() == fs.join('/home/test', '.cache', 'agent-toolkit')
}

fn test_write_atomic_roundtrip() {
	fs := new_fs()
	dir := os.join_path(os.temp_dir(), 'at-fs-test-${os.getpid()}')
	path := os.join_path(dir, 'receipt.json')
	fs.write_atomic(path, '{"ok":true}')!
	assert fs.exists(path)
	text := fs.read_text(path)!
	assert text == '{"ok":true}'
	os.rmdir_all(dir) or {}
}
