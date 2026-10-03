module agent_toolkit_core

import os

fn setup_copilot_project_install_test() (string, string, string) {
	base := os.join_path(os.temp_dir(), 'atk-copilot-project-${os.getpid()}')
	os.rmdir_all(base) or {}
	workspace := os.join_path(base, 'workspace')
	project := os.join_path(base, 'repo')
	os.mkdir_all(os.join_path(workspace, 'projects')) or { panic(err) }
	os.mkdir_all(project) or { panic(err) }
	os.symlink(project, os.join_path(workspace, 'projects', 'demo')) or { panic(err) }
	return base, workspace, project
}

fn test_copilot_project_install_reviews_then_writes_real_profile() {
	base, workspace, project := setup_copilot_project_install_test()
	defer { os.rmdir_all(base) or {} }
	receipts := os.join_path(base, 'receipts')
	preview := copilot_project_install(workspace, 'demo', '', false, receipts)
	assert preview.ok
	assert preview.status == 'ready'
	assert preview.review_token.len > 0
	assert preview.path == '.github/copilot-instructions.md'
	assert preview.content.contains('# Copilot Instructions Template')
	assert !os.exists(os.join_path(project, '.github'))

	installed := copilot_project_install(workspace, 'demo', preview.review_token, true, receipts)
	assert installed.ok
	assert installed.status == 'installed'
	assert installed.files_written == 1
	content := os.read_file(os.join_path(project, '.github', 'copilot-instructions.md')) or { panic(err) }
	assert content.contains('# Copilot Instructions Template')
	current := copilot_project_install(workspace, 'demo', '', false, receipts)
	assert current.ok
	assert current.status == 'current'
}

fn test_copilot_project_install_preserves_existing_instructions_and_symlinks() {
	base, workspace, project := setup_copilot_project_install_test()
	defer { os.rmdir_all(base) or {} }
	github := os.join_path(project, '.github')
	os.mkdir_all(github) or { panic(err) }
	dest := os.join_path(github, 'copilot-instructions.md')
	os.write_file(dest, 'my own rules') or { panic(err) }
	conflict := copilot_project_install(workspace, 'demo', '', false, os.join_path(base, 'receipts'))
	assert conflict.ok
	assert conflict.status == 'preserved-existing'
	assert os.read_file(dest) or { '' } == 'my own rules'

	unsafe_base, unsafe_workspace, unsafe_project := setup_copilot_project_install_test()
	defer { os.rmdir_all(unsafe_base) or {} }
	os.symlink(base, os.join_path(unsafe_project, '.github')) or { panic('symlink failed') }
	blocked := copilot_project_install(unsafe_workspace, 'demo', '', false, os.join_path(unsafe_base, 'receipts'))
	assert !blocked.ok
	assert blocked.status == 'unsafe-path'
}

fn test_copilot_project_install_rejects_stale_review_and_unlinked_project() {
	base, workspace, project := setup_copilot_project_install_test()
	defer { os.rmdir_all(base) or {} }
	preview := copilot_project_install(workspace, 'demo', '', false, os.join_path(base, 'receipts'))
	os.mkdir_all(os.join_path(project, '.github')) or { panic(err) }
	os.write_file(os.join_path(project, '.github', 'copilot-instructions.md'), 'user file') or { panic(err) }
	stale := copilot_project_install(workspace, 'demo', preview.review_token, true, os.join_path(base, 'receipts'))
	assert stale.status == 'stale-review'
	assert os.read_file(os.join_path(project, '.github', 'copilot-instructions.md')) or { '' } == 'user file'
	missing := copilot_project_install(workspace, 'not-linked', '', false, os.join_path(base, 'receipts'))
	assert !missing.ok
}

fn test_copilot_project_removal_requires_receipt_and_preserves_edits() {
	base, workspace, project := setup_copilot_project_install_test()
	defer { os.rmdir_all(base) or {} }
	receipts := os.join_path(base, 'receipts')
	preview := copilot_project_install(workspace, 'demo', '', false, receipts)
	installed := copilot_project_install(workspace, 'demo', preview.review_token, true, receipts)
	assert installed.status == 'installed'

	remove_preview := copilot_project_remove(workspace, 'demo', '', false, receipts)
	assert remove_preview.ok
	assert remove_preview.status == 'ready-remove'
	assert remove_preview.review_token.len > 0
	removed := copilot_project_remove(workspace, 'demo', remove_preview.review_token, true, receipts)
	assert removed.ok
	assert removed.status == 'removed'
	assert removed.files_removed == 1
	assert !os.exists(os.join_path(project, '.github', 'copilot-instructions.md'))
	assert list_install_receipts(receipts).len == 0

	second_preview := copilot_project_install(workspace, 'demo', '', false, receipts)
	second_install := copilot_project_install(workspace, 'demo', second_preview.review_token, true, receipts)
	assert second_install.status == 'installed'
	dest := os.join_path(project, '.github', 'copilot-instructions.md')
	os.write_file(dest, 'edited after install') or { panic(err) }
	modified := copilot_project_remove(workspace, 'demo', '', false, receipts)
	assert modified.ok
	assert modified.status == 'modified'
	assert os.read_file(dest) or { '' } == 'edited after install'
}

fn test_copilot_project_removal_rejects_stale_review_and_symlink_destination() {
	base, workspace, project := setup_copilot_project_install_test()
	defer { os.rmdir_all(base) or {} }
	receipts := os.join_path(base, 'receipts')
	install_preview := copilot_project_install(workspace, 'demo', '', false, receipts)
	installed := copilot_project_install(workspace, 'demo', install_preview.review_token, true, receipts)
	assert installed.status == 'installed'

	remove_preview := copilot_project_remove(workspace, 'demo', '', false, receipts)
	dest := os.join_path(project, '.github', 'copilot-instructions.md')
	os.write_file(dest, 'changed after review') or { panic(err) }
	stale := copilot_project_remove(workspace, 'demo', remove_preview.review_token, true, receipts)
	assert !stale.ok
	assert stale.status == 'stale-review'
	assert os.read_file(dest) or { '' } == 'changed after review'
	assert list_install_receipts(receipts).len == 1

	unsafe_base, unsafe_workspace, unsafe_project := setup_copilot_project_install_test()
	defer { os.rmdir_all(unsafe_base) or {} }
	unsafe_receipts := os.join_path(unsafe_base, 'receipts')
	unsafe_preview := copilot_project_install(unsafe_workspace, 'demo', '', false, unsafe_receipts)
	unsafe_install := copilot_project_install(unsafe_workspace, 'demo', unsafe_preview.review_token, true, unsafe_receipts)
	assert unsafe_install.status == 'installed'
	installed_github := os.join_path(unsafe_project, '.github')
	os.rmdir_all(installed_github) or { panic(err) }
	os.symlink(base, installed_github) or { panic('symlink failed') }
	unsafe_remove := copilot_project_remove(unsafe_workspace, 'demo', '', false, unsafe_receipts)
	assert !unsafe_remove.ok
	assert unsafe_remove.status == 'unsafe-path'
}
