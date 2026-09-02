module agent_toolkit_core

import os

fn test_file_digest_missing_and_roundtrip() {
	assert file_digest('/nonexistent/at-prov-missing') == 'missing'
	path := os.join_path(os.temp_dir(), 'at-prov-${os.getpid()}.txt')
	os.write_file(path, 'abc') or { assert false, err.msg() }
	defer {
		os.rm(path) or {}
	}
	d := file_digest(path)
	assert d.len == 12
	assert d == 'ba7816bf8f01'
}

fn test_write_load_verify_provenance() {
	dir := os.join_path(os.temp_dir(), 'at-prov-dir-${os.getpid()}')
	os.mkdir_all(dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	art := os.join_path(dir, 'plugin.json')
	os.write_file(art, '{"ok":true}') or { assert false, err.msg() }
	rec := ArtifactRecord{
		path: 'plugin.json'
		source_file: 'skills/core/assistant/SKILL.md'
		source_digest: file_digest(art)
		generated_digest: file_digest(art)
	}
	p := write_provenance(dir, 'agent-toolkit-core', 'cursor', [rec]) or {
		assert false, err.msg()
		return
	}
	assert os.file_name(p) == '.provenance.json'
	raw := os.read_file(p) or {
		assert false, err.msg()
		return
	}
	assert raw.contains('"generatorVersion"')
	assert raw.contains('"sourceFile"')
	assert raw.contains('"sourceDigest"')
	assert raw.contains('"generatedDigest"')
	m := load_provenance(p) or {
		assert false, 'load failed'
		return
	}
	assert m.product == 'agent-toolkit-core'
	assert m.target == 'cursor'
	assert m.generator_version.len > 0
	assert m.artifacts.len == 1
	assert m.artifacts[0].source_file == 'skills/core/assistant/SKILL.md'
	assert verify_generated_digests(dir, p).len == 0
	os.write_file(art, '{"ok":false}') or { assert false, err.msg() }
	drift := verify_generated_digests(dir, p)
	assert drift.len == 1
	assert drift[0].contains('plugin.json')
}

fn test_load_provenance_missing() {
	assert load_provenance('/nonexistent/.provenance.json') == none
}
