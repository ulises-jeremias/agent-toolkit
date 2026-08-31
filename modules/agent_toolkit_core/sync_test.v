module agent_toolkit_core

import os

fn restore_env_sync(key string, old string) {
	if old.len > 0 {
		os.setenv(key, old, true)
	} else {
		os.unsetenv(key)
	}
}

fn test_ensure_data_offline_never_hits_network() {
	home := os.join_path(os.temp_dir(), 'at-sync-off-${os.getpid()}')
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(home) or {}
	}
	old := os.getenv('XDG_DATA_HOME')
	os.setenv('XDG_DATA_HOME', home, true)
	defer {
		restore_env_sync('XDG_DATA_HOME', old)
	}
	s := DataSync{
		net: NetworkClient{
			offline: true
		}
		fs:  new_fs()
	}
	s.ensure_data('1.10.0', true, false) or {
		assert err.msg().contains('offline')
		assert !is_valid_data_root(s.data_dir())
		return
	}
	assert false, 'expected offline miss error'
}

fn test_promote_staging_rejects_invalid_tree() {
	home := os.join_path(os.temp_dir(), 'at-sync-bad-${os.getpid()}')
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(home) or {}
	}
	old := os.getenv('XDG_DATA_HOME')
	os.setenv('XDG_DATA_HOME', home, true)
	defer {
		restore_env_sync('XDG_DATA_HOME', old)
	}
	src := os.join_path(home, 'src')
	os.mkdir_all(src) or { assert false, err.msg() }
	s := new_data_sync()
	s.promote_staging(src, '1.10.0') or {
		assert err.msg().contains('not a valid data root')
		assert !os.exists(s.data_dir())
		return
	}
	assert false, 'expected invalid staging error'
}

fn test_promote_staging_activates_valid_tree() {
	home := os.join_path(os.temp_dir(), 'at-sync-ok-${os.getpid()}')
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(home) or {}
	}
	old := os.getenv('XDG_DATA_HOME')
	os.setenv('XDG_DATA_HOME', home, true)
	defer {
		restore_env_sync('XDG_DATA_HOME', old)
	}
	src := os.join_path(home, 'src')
	os.mkdir_all(os.join_path(src, 'profiles')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(src, 'skills')) or { assert false, err.msg() }
	os.write_file(os.join_path(src, 'skills', 'marker.txt'), 'ok') or { assert false, err.msg() }
	s := DataSync{
		net: NetworkClient{
			offline: true
		}
		fs:  new_fs()
	}
	dest := s.promote_staging(src, 'v1.10.0') or {
		assert false, err.msg()
		return
	}
	assert is_valid_data_root(dest)
	assert s.cached_data_version() == '1.10.0'
	assert os.is_file(os.join_path(dest, 'skills', 'marker.txt'))
	got := s.ensure_data('1.10.0', true, false) or {
		assert false, err.msg()
		return
	}
	assert got == dest
}

fn test_download_data_offline_does_not_activate() {
	s := DataSync{
		net: NetworkClient{
			offline: true
		}
		fs:  new_fs()
	}
	s.download_data('1.10.0') or {
		assert err.msg().contains('offline')
		return
	}
	assert false, 'expected offline download error'
}
