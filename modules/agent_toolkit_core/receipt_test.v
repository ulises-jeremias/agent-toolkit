module agent_toolkit_core

import os

fn test_parse_install_receipt_roundtrip_fields() {
	text := '{
  "schemaVersion": 1,
  "product": "agent-toolkit-core",
  "target": "cursor",
  "scope": "project",
  "version": "1.1.0",
  "installedAt": "2026-08-12T00:00:00+00:00",
  "sourceDigest": "abc123",
  "artifacts": [
    {"path": ".cursor/rules/assistant.mdc", "digest": "def456", "ownership": "created"}
  ],
  "configPatches": [{"op": "add", "path": "/toolkit", "value": true}],
  "secrets": []
}
'
	r := parse_install_receipt(text) or {
		assert false, err.msg()
		return
	}
	assert r.schema_version == 1
	assert r.product == 'agent-toolkit-core'
	assert r.target == 'cursor'
	assert r.secrets.len == 0
	assert r.artifacts.len == 1
	assert r.artifacts[0].ownership == 'created'
	assert r.config_patches_json.contains('"op"')
}

fn test_parse_rejects_secrets_and_bad_ownership() {
	bad_secrets := '{"schemaVersion":1,"product":"p","target":"t","version":"1","artifacts":[],"secrets":["x"]}'
	parse_install_receipt(bad_secrets) or {
		assert err.msg().contains('secrets')
		return
	}
	assert false, 'expected secrets rejection'
}

fn test_parse_rejects_path_escape() {
	bad := '{"schemaVersion":1,"product":"p","target":"t","version":"1","artifacts":[{"path":"../../etc/passwd","digest":"x","ownership":"created"}],"secrets":[]}'
	parse_install_receipt(bad) or {
		assert err.msg().contains('path escape')
		return
	}
	assert false, 'expected path escape rejection'
}

fn test_load_and_list_receipts() {
	dir := os.join_path(os.temp_dir(), 'at-receipt-${os.getpid()}')
	os.mkdir_all(dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, receipt_filename('cursor', 'agent-toolkit-core'))
	os.write_file(path, '{
  "schemaVersion": 1,
  "product": "agent-toolkit-core",
  "target": "cursor",
  "version": "1.1.0",
  "artifacts": [{"path": "/tmp/at-ok/file.mdc", "digest": "aabb", "ownership": "merged"}],
  "secrets": []
}
') or { assert false, err.msg() }
	r := load_install_receipt('cursor', 'agent-toolkit-core', dir) or {
		assert false, 'load failed'
		return
	}
	assert r.version == '1.1.0'
	assert load_install_receipt('missing', 'product', dir) == none
	listed := list_install_receipts(dir)
	assert listed.len == 1
}

fn test_new_receipt_and_digest() {
	r := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'src')
	assert r.schema_version == 1
	assert r.secrets.len == 0
	assert receipt_filename('cursor', profiles_product) == 'cursor-agent-toolkit-profiles.json'
	path := os.join_path(os.temp_dir(), 'at-dig-${os.getpid()}.txt')
	os.write_file(path, 'abc') or { assert false, err.msg() }
	defer {
		os.rm(path) or {}
	}
	d := receipt_artifact_digest(path)
	assert d.len == 16
}

fn test_receipt_dir_under_config() {
	fs := FsService{
		home_dir: '/tmp/at-home-receipt'
	}
	assert fs.receipt_dir().ends_with(os.join_path('.config', 'agent-toolkit', 'receipts')) || fs.receipt_dir().contains('agent-toolkit')
}
