module agent_toolkit_core

import os

fn test_uninstall_removes_created_keeps_merged() {
	base := os.join_path(os.temp_dir(), 'at-un-${os.getpid()}')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(receipt_dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	created := os.join_path(base, 'created.md')
	merged := os.join_path(base, 'merged.md')
	os.write_file(created, 'c\n') or { assert false, err.msg() }
	os.write_file(merged, 'm\n') or { assert false, err.msg() }
	mut r := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'x')
	r.artifacts << ArtifactEntry{
		path:      created
		digest:    'aa'
		ownership: 'created'
	}
	r.artifacts << ArtifactEntry{
		path:      merged
		digest:    'bb'
		ownership: 'merged'
	}
	save_install_receipt(mut r, receipt_dir) or {
		assert false, err.msg()
		return
	}
	report := run_uninstall(UninstallOptions{
		tools:       ['cursor']
		receipt_dir: receipt_dir
	})
	assert report.ok
	assert !os.is_file(created)
	assert os.is_file(merged)
	assert load_install_receipt('cursor', profiles_product, receipt_dir) == none
}

fn test_uninstall_dry_run_preserves_files() {
	base := os.join_path(os.temp_dir(), 'at-un-dry-${os.getpid()}')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(receipt_dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	created := os.join_path(base, 'created.md')
	os.write_file(created, 'c\n') or { assert false, err.msg() }
	mut r := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'x')
	r.artifacts << ArtifactEntry{
		path:      created
		digest:    'aa'
		ownership: 'created'
	}
	save_install_receipt(mut r, receipt_dir) or {
		assert false, err.msg()
		return
	}
	report := run_uninstall(UninstallOptions{
		tools:       ['cursor']
		dry_run:     true
		receipt_dir: receipt_dir
	})
	assert report.ok
	assert os.is_file(created)
	assert load_install_receipt('cursor', profiles_product, receipt_dir) != none
	assert report.message.contains('DRY RUN')
}

fn test_uninstall_no_receipts() {
	base := os.join_path(os.temp_dir(), 'at-un-empty-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	report := run_uninstall(UninstallOptions{
		receipt_dir: base
	})
	assert !report.ok
	assert report.message.contains('No install receipts')
}

fn test_discover_uninstall_tools() {
	base := os.join_path(os.temp_dir(), 'at-un-disc-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	mut r := new_install_receipt(profiles_product, 'opencode', 'user-home', '1.0.0', 'x')
	r.artifacts << ArtifactEntry{
		path:      '/tmp/at-ok/x'
		digest:    'aa'
		ownership: 'created'
	}
	save_install_receipt(mut r, base) or {
		assert false, err.msg()
		return
	}
	tools := discover_uninstall_tools(base)
	assert tools == ['opencode']
}
