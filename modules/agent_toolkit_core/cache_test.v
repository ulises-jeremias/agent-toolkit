module agent_toolkit_core

import os

fn restore_env_cache(key string, old string) {
	if old.len > 0 {
		os.setenv(key, old, true)
	} else {
		os.unsetenv(key)
	}
}

fn test_content_cache_hit_miss_offline() {
	home := os.join_path(os.temp_dir(), 'at-cache-${os.getpid()}')
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(home) or {}
	}
	old_xdg := os.getenv('XDG_CACHE_HOME')
	os.setenv('XDG_CACHE_HOME', home, true)
	defer {
		restore_env_cache('XDG_CACHE_HOME', old_xdg)
	}
	c := new_content_cache()
	assert c.resolve_local('1.10.0', false) == none
	os.mkdir_all(c.fs.join(c.dir(), 'profiles')) or { assert false, err.msg() }
	c.write_meta(CacheMeta{
		version: '1.10.0'
		source: 'test'
		url: ''
	}) or { assert false, err.msg() }
	hit := c.resolve_local('1.10.0', false) or {
		assert false, 'expected cache hit'
		return
	}
	assert hit == c.dir()
	assert c.is_current('1.10.0')
	assert c.resolve_local('9.9.9', false) == none
	offline_hit := c.resolve_local('9.9.9', true) or {
		assert false, 'expected offline hit'
		return
	}
	assert offline_hit == c.dir()
}
