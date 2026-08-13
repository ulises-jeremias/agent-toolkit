module agent_toolkit_core

import os

fn test_install_tx_commit_and_receipt() {
	base := os.join_path(os.temp_dir(), 'at-tx-${os.getpid()}')
	dest_root := os.join_path(base, 'dst')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(dest_root) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	dest := os.join_path(dest_root, 'rules', 'a.mdc')
	mut tx := new_install_transaction('cursor', InstallTxOptions{
		receipt_dir:   receipt_dir
		toolkit_root:  base
		version:       '1.0.0'
		source_digest: 'srcdig'
	})
	tx.stage_write(dest, '# hello\n') or {
		assert false, err.msg()
		return
	}
	path := tx.commit() or {
		assert false, err.msg()
		return
	}
	assert path.len > 0
	assert os.is_file(dest)
	assert os.read_file(dest) or { '' } == '# hello\n'
	loaded := load_install_receipt('cursor', profiles_product, receipt_dir) or {
		assert false, 'receipt missing'
		return
	}
	assert loaded.artifacts.len == 1
	assert loaded.artifacts[0].ownership == 'created'
	assert loaded.version == '1.0.0'
}

fn test_install_tx_rejects_path_escape_at_stage() {
	base := os.join_path(os.temp_dir(), 'at-tx-rb-${os.getpid()}')
	dest_root := os.join_path(base, 'dst')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(dest_root) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	ok_path := os.join_path(dest_root, 'ok.md')
	bad_path := os.join_path(dest_root, '..', '..', 'etc', 'passwd')
	mut tx := new_install_transaction('cursor', InstallTxOptions{
		receipt_dir:   receipt_dir
		version:       '1.0.0'
		source_digest: 'x'
	})
	tx.stage_write(ok_path, 'one\n') or {
		assert false, err.msg()
		return
	}
	tx.stage_write(bad_path, 'nope\n') or {
		assert err.msg().contains('path escape')
		path := tx.commit() or {
			assert false, err.msg()
			return
		}
		assert path.len > 0
		assert os.is_file(ok_path)
		return
	}
	assert false, 'expected stage to refuse escape'
}

fn test_install_tx_commit_failure_rolls_back_created() {
	base := os.join_path(os.temp_dir(), 'at-tx-fail-${os.getpid()}')
	dest_root := os.join_path(base, 'dst')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(dest_root) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	a := os.join_path(dest_root, 'a.md')
	b := os.join_path(dest_root, 'b.md')
	mut tx := new_install_transaction('cursor', InstallTxOptions{
		receipt_dir:   receipt_dir
		version:       '1.0.0'
		source_digest: 'x'
		force:         true
	})
	tx.stage_write(a, 'A\n') or {
		assert false, err.msg()
		return
	}
	tx.stage_write(b, 'B\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(receipt_dir, 'not-a-dir') or {
		assert false, err.msg()
		return
	}
	tx.commit() or {
		assert !os.is_file(a), 'a should be rolled back'
		assert !os.is_file(b), 'b should be rolled back'
		return
	}
	assert false, 'expected commit failure'
}

fn test_install_tx_dry_run_no_writes() {
	base := os.join_path(os.temp_dir(), 'at-tx-dry-${os.getpid()}')
	dest := os.join_path(base, 'f.md')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	mut tx := new_install_transaction('cursor', InstallTxOptions{
		dry_run:       true
		receipt_dir:   receipt_dir
		version:       '1.0.0'
		source_digest: 'x'
	})
	tx.stage_write(dest, 'x\n') or {
		assert false, err.msg()
		return
	}
	path := tx.commit() or {
		assert false, err.msg()
		return
	}
	assert path == ''
	assert !os.is_file(dest)
	assert load_install_receipt('cursor', profiles_product, receipt_dir) == none
}

fn test_install_tx_preserve_without_force_and_restore_on_rollback() {
	base := os.join_path(os.temp_dir(), 'at-tx-force-${os.getpid()}')
	dest := os.join_path(base, 'f.md')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(dest, 'user\n') or {
		assert false, err.msg()
		return
	}
	mut tx := new_install_transaction('cursor', InstallTxOptions{
		receipt_dir:   receipt_dir
		version:       '1.0.0'
		source_digest: 'x'
		force:         false
	})
	tx.stage_write(dest, 'toolkit\n') or {
		assert false, err.msg()
		return
	}
	path := tx.commit() or {
		assert false, err.msg()
		return
	}
	assert path == ''
	assert os.read_file(dest) or { '' } == 'user\n'

	mut tx2 := new_install_transaction('cursor', InstallTxOptions{
		receipt_dir:   receipt_dir
		version:       '1.0.0'
		source_digest: 'x'
		force:         true
	})
	tx2.stage_write(dest, 'toolkit\n') or {
		assert false, err.msg()
		return
	}
	path2 := tx2.commit() or {
		assert false, err.msg()
		return
	}
	assert path2.len > 0
	assert os.read_file(dest) or { '' } == 'toolkit\n'
	tx2.rollback() or {
		assert false, err.msg()
		return
	}
	assert os.read_file(dest) or { '' } == 'user\n'
	assert load_install_receipt('cursor', profiles_product, receipt_dir) == none
}

fn test_save_install_receipt_roundtrip() {
	dir := os.join_path(os.temp_dir(), 'at-save-${os.getpid()}')
	os.mkdir_all(dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	mut r := new_install_receipt('agent-toolkit-core', 'cursor', 'project', '1.1.0', 'abc')
	r.config_patches_json = '[{"op":"add","path":"/toolkit","value":true}]'
	r.artifacts << ArtifactEntry{
		path:      '/tmp/at-ok/file.mdc'
		digest:    'def456'
		ownership: 'created'
	}
	path := save_install_receipt(mut r, dir) or {
		assert false, err.msg()
		return
	}
	text := os.read_file(path) or {
		assert false, err.msg()
		return
	}
	assert text.contains('"configPatches"')
	assert text.contains('"schemaVersion"')
	loaded := parse_install_receipt(text) or {
		assert false, err.msg()
		return
	}
	assert loaded.config_patches_json.contains('/toolkit')
}
