module agent_toolkit_core

import os

fn test_offline_short_circuits_get() {
	c := NetworkClient{
		offline: true
	}
	c.get('https://example.com') or {
		assert err.msg().contains('offline')
		return
	}
	assert false, 'expected offline error'
}

fn test_offline_short_circuits_download() {
	c := NetworkClient{
		offline: true
	}
	c.download('https://example.com/x', os.join_path(os.temp_dir(), 'at-net-x')) or {
		assert err.msg().contains('offline')
		return
	}
	assert false, 'expected offline error'
}

fn test_auto_offline_from_env() {
	old := os.getenv('AGENT_TOOLKIT_OFFLINE')
	os.setenv('AGENT_TOOLKIT_OFFLINE', '1', true)
	defer {
		if old.len > 0 {
			os.setenv('AGENT_TOOLKIT_OFFLINE', old, true)
		} else {
			os.unsetenv('AGENT_TOOLKIT_OFFLINE')
		}
	}
	c := new_network_client(true)
	assert c.offline == true
}

fn test_verify_sha256_roundtrip() {
	c := new_network_client(false)
	path := os.join_path(os.temp_dir(), 'at-net-sha-${os.getpid()}.txt')
	os.write_file(path, 'abc') or { assert false, err.msg() }
	defer {
		os.rm(path) or {}
	}
	// sha256("abc")
	expected := 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
	c.verify_sha256(path, expected) or {
		assert false, err.msg()
		return
	}
}
