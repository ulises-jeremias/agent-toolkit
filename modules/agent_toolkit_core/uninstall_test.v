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
		path: created
		digest: receipt_artifact_digest(created)
		ownership: 'created'
	}
	r.artifacts << ArtifactEntry{
		path: merged
		digest: receipt_artifact_digest(merged)
		ownership: 'merged'
	}
	save_install_receipt(mut r, receipt_dir) or {
		assert false, err.msg()
		return
	}
	report := run_uninstall(UninstallOptions{
		tools: ['cursor']
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
		path: created
		digest: receipt_artifact_digest(created)
		ownership: 'created'
	}
	save_install_receipt(mut r, receipt_dir) or {
		assert false, err.msg()
		return
	}
	report := run_uninstall(UninstallOptions{
		tools: ['cursor']
		dry_run: true
		receipt_dir: receipt_dir
	})
	assert report.ok
	assert os.is_file(created)
	assert load_install_receipt('cursor', profiles_product, receipt_dir) != none
	assert report.message.contains('DRY RUN')
}

fn test_uninstall_preserves_created_file_changed_after_install() {
	base := os.join_path(os.temp_dir(), 'at-un-modified-${os.getpid()}')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(receipt_dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	created := os.join_path(base, 'created.md')
	os.write_file(created, 'edited by the user\n') or { assert false, err.msg() }
	mut r := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'x')
	r.artifacts << ArtifactEntry{
		path: created
		digest: 'not-the-installed-digest'
		ownership: 'created'
	}
	save_install_receipt(mut r, receipt_dir) or { assert false, err.msg() }

	report := run_uninstall(UninstallOptions{
		tools: ['cursor']
		receipt_dir: receipt_dir
	})
	assert report.ok
	assert report.message.contains('Preserving file changed since Toolkit installed it: ${created}')
	assert os.read_file(created) or { '' } == 'edited by the user\n'
}

fn test_uninstall_review_token_rejects_changed_plan_before_removal() {
	base := os.join_path(os.temp_dir(), 'at-un-review-${os.getpid()}')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(receipt_dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	created := os.join_path(base, 'created.md')
	os.write_file(created, 'original\n') or { assert false, err.msg() }
	mut receipt := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'x')
	receipt.artifacts << ArtifactEntry{
		path: created
		digest: receipt_artifact_digest(created)
		ownership: 'created'
	}
	save_install_receipt(mut receipt, receipt_dir) or { assert false, err.msg() }
	preview := run_uninstall(UninstallOptions{
		tools: ['cursor']
		dry_run: true
		receipt_dir: receipt_dir
	})
	assert preview.ok
	assert preview.review_token.len == 64
	os.write_file(created, 'user edit after preview\n') or { assert false, err.msg() }

	result := run_uninstall(UninstallOptions{
		tools: ['cursor']
		receipt_dir: receipt_dir
		review_token: preview.review_token
	})
	assert !result.ok
	assert result.message.contains('Nothing was removed')
	assert os.read_file(created) or { '' } == 'user edit after preview\n'
	assert load_install_receipt('cursor', profiles_product, receipt_dir) != none
}

fn test_uninstall_preserves_symbolic_link_without_touching_target() {
	base := os.join_path(os.temp_dir(), 'at-un-link-${os.getpid()}')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(receipt_dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	target := os.join_path(base, 'target.md')
	link := os.join_path(base, 'owned.md')
	os.write_file(target, 'user data\n') or { assert false, err.msg() }
	os.symlink(target, link) or { assert false, err.msg() }
	mut receipt := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'x')
	receipt.artifacts << ArtifactEntry{
		path: link
		digest: 'anything'
		ownership: 'created'
	}
	save_install_receipt(mut receipt, receipt_dir) or { assert false, err.msg() }

	result := run_uninstall(UninstallOptions{
		tools: ['cursor']
		receipt_dir: receipt_dir
	})
	assert result.ok
	assert result.message.contains('Preserving symbolic link: ${link}')
	assert os.is_link(link)
	assert os.read_file(target) or { '' } == 'user data\n'
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
		path: '/tmp/at-ok/x'
		digest: 'aa'
		ownership: 'created'
	}
	save_install_receipt(mut r, base) or {
		assert false, err.msg()
		return
	}
	tools := discover_uninstall_tools(base)
	assert tools == ['opencode']
}
