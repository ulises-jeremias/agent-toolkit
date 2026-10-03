module agent_toolkit_core

import crypto.sha256
import os

fn test_install_claude_previews_complete_skills_and_preserves_user_conflicts() {
	base := os.join_path(os.temp_dir(), 'at-ins-skills-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	skill_src := os.join_path(data, 'skills', 'review', 'reviewer')
	os.mkdir_all(os.join_path(data, 'profiles', 'claude-code')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(data, 'profiles', 'opencode')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(data, 'catalogs')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(skill_src, 'references')) or { assert false, err.msg() }
	conflict := os.join_path(home, '.claude', 'skills', 'reviewer', 'SKILL.md')
	os.mkdir_all(os.dir(conflict)) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'catalogs', 'skills-layout.json'), '{"skills":[{"id":"review/reviewer","name":"reviewer","domain":"review"}]}') or { assert false, err.msg() }
	os.write_file(os.join_path(skill_src, 'SKILL.md'), '---\nname: reviewer\n---\nToolkit skill\n') or { assert false, err.msg() }
	os.write_file(os.join_path(skill_src, 'references', 'checklist.md'), 'Toolkit checklist\n') or { assert false, err.msg() }
	os.write_file(conflict, 'User-edited skill\n') or { assert false, err.msg() }

	preview := run_install(InstallOptions{
		tools: ['claude-code']
		dry_run: true
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert preview.ok, preview.message
	assert preview.message.contains('Would preserve existing file (no overwrite): ${conflict}')
	assert preview.message.contains('Would install: ${os.join_path(home, '.claude', 'skills', 'reviewer', 'references', 'checklist.md')}')
	assert !os.is_file(os.join_path(home, '.claude', 'skills', 'reviewer', 'references', 'checklist.md'))

	installed := run_install(InstallOptions{
		tools: ['claude-code']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert installed.ok, installed.message
	assert os.read_file(conflict) or { '' } == 'User-edited skill\n'
	checklist := os.join_path(home, '.claude', 'skills', 'reviewer', 'references', 'checklist.md')
	assert os.read_file(checklist) or { '' } == 'Toolkit checklist\n'
	assert load_install_receipt('claude-code', profiles_product, receipt_dir) != none

	opencode_home := os.join_path(home, '.config', 'opencode', 'skills')
	opencode_preview := run_install(InstallOptions{
		tools: ['opencode']
		dry_run: true
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert opencode_preview.ok, opencode_preview.message
	assert opencode_preview.message.contains('Would install: ${os.join_path(opencode_home, 'reviewer', 'references', 'checklist.md')}')
	opencode_install := run_install(InstallOptions{
		tools: ['opencode']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert opencode_install.ok, opencode_install.message
	assert os.read_file(os.join_path(opencode_home, 'reviewer', 'references', 'checklist.md')) or { '' } == 'Toolkit checklist\n'
	assert load_install_receipt('opencode', profiles_product, receipt_dir) != none
}

fn test_install_invalid_skill_layout_aborts_before_stale_cleanup() {
	base := os.join_path(os.temp_dir(), 'at-ins-bad-layout-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	stale := os.join_path(home, '.claude', 'agents', 'retired.md')
	os.mkdir_all(os.join_path(data, 'profiles', 'claude-code')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(data, 'catalogs')) or { assert false, err.msg() }
	os.mkdir_all(os.dir(stale)) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'catalogs', 'skills-layout.json'), '{invalid json') or {
		assert false, err.msg()
		return
	}
	os.write_file(stale, 'Toolkit-owned previous install\n') or { assert false, err.msg() }
	mut receipt := new_install_receipt(profiles_product, 'claude-code', 'user-home', '1.0.0', 'old')
	receipt.artifacts << ArtifactEntry{
		path: stale
		digest: receipt_artifact_digest(stale)
		ownership: 'created'
	}
	save_install_receipt(mut receipt, receipt_dir) or { assert false, err.msg() }
	old_receipt := os.read_file(os.join_path(receipt_dir, receipt_filename('claude-code', profiles_product))) or {
		assert false, err.msg()
		return
	}

	result := run_install(InstallOptions{
		tools: ['claude-code']
		force: true
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert !result.ok
	assert result.message.contains('Cannot parse skills-layout.json')
	assert os.read_file(stale) or { '' } == 'Toolkit-owned previous install\n'
	assert os.read_file(os.join_path(receipt_dir, receipt_filename('claude-code', profiles_product))) or {
		''
	} == old_receipt
}

fn test_install_cursor_dry_run_writes_nothing() {
	base := os.join_path(os.temp_dir(), 'at-ins-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	src := os.join_path(data, 'profiles', 'cursor', 'rules', 'assistant.mdc')
	os.write_file(src, 'rule\n') or {
		assert false, err.msg()
		return
	}
	report := run_install(InstallOptions{
		tools: ['cursor']
		dry_run: true
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert report.ok
	assert report.dry_run
	assert report.message.contains('DRY RUN')
	dst := os.join_path(home, '.cursor', 'rules', 'assistant.mdc')
	assert !os.is_file(dst)
	assert !os.is_dir(receipt_dir) || os.ls(receipt_dir) or { []string{} }.len == 0
}

fn test_install_cursor_writes_file_and_receipt() {
	base := os.join_path(os.temp_dir(), 'at-ins-w-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	src := os.join_path(data, 'profiles', 'cursor', 'rules', 'assistant.mdc')
	os.write_file(src, 'rule-v1\n') or {
		assert false, err.msg()
		return
	}
	report := run_install(InstallOptions{
		tools: ['cursor']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert report.ok, report.message
	dst := os.join_path(home, '.cursor', 'rules', 'assistant.mdc')
	assert os.read_file(dst) or { '' } == 'rule-v1\n'
	loaded := load_install_receipt('cursor', profiles_product, receipt_dir) or {
		assert false, 'receipt missing'
		return
	}
	assert loaded.artifacts.len == 1
	assert loaded.artifacts[0].ownership == 'created'
}

fn test_install_preserves_without_force() {
	base := os.join_path(os.temp_dir(), 'at-ins-p-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	dst := os.join_path(home, '.cursor', 'rules', 'assistant.mdc')
	os.mkdir_all(os.dir(dst)) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'profiles', 'cursor', 'rules', 'assistant.mdc'), 'new\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(dst, 'user\n') or {
		assert false, err.msg()
		return
	}
	preview := run_install(InstallOptions{
		tools: ['cursor']
		dry_run: true
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert preview.ok, preview.message
	assert preview.dry_run
	assert preview.message.contains('Would preserve existing file (no overwrite): ${dst}')
	assert !preview.message.contains('Would install: ${dst}')
	assert os.read_file(dst) or { '' } == 'user\n'
	assert !os.is_dir(receipt_dir) || os.ls(receipt_dir) or { []string{} }.len == 0
	report := run_install(InstallOptions{
		tools: ['cursor']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert report.ok, report.message
	assert os.read_file(dst) or { '' } == 'user\n'
	assert report.message.contains('Preserving user-owned file')
}

fn test_install_force_overwrites() {
	base := os.join_path(os.temp_dir(), 'at-ins-f-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	dst := os.join_path(home, '.cursor', 'rules', 'assistant.mdc')
	os.mkdir_all(os.dir(dst)) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'profiles', 'cursor', 'rules', 'assistant.mdc'), 'new\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(dst, 'user\n') or {
		assert false, err.msg()
		return
	}
	report := run_install(InstallOptions{
		tools: ['cursor']
		force: true
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert report.ok, report.message
	assert os.read_file(dst) or { '' } == 'new\n'
}

fn test_install_preview_reports_stale_owned_files_without_removing_them() {
	base := os.join_path(os.temp_dir(), 'at-ins-stale-preview-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'profiles', 'cursor', 'rules', 'current.mdc'), 'current\n') or {
		assert false, err.msg()
		return
	}
	stale := os.join_path(home, '.cursor', 'rules', 'retired.mdc')
	os.mkdir_all(os.dir(stale)) or { assert false, err.msg() }
	os.write_file(stale, 'toolkit-owned\n') or { assert false, err.msg() }
	mut prior := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'old')
	prior.artifacts << ArtifactEntry{
		path: stale
		digest: sha256.hexhash('toolkit-owned\n')[..16]
		ownership: 'created'
	}
	save_install_receipt(mut prior, receipt_dir) or {
		assert false, err.msg()
		return
	}
	preview := run_install(InstallOptions{
		tools: ['cursor']
		dry_run: true
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert preview.ok, preview.message
	assert preview.message.contains('Would remove stale Toolkit-owned file: ${stale}')
	assert os.is_file(stale)
}

fn test_install_skips_changed_stale_owned_file() {
	base := os.join_path(os.temp_dir(), 'at-ins-stale-changed-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'profiles', 'cursor', 'rules', 'current.mdc'), 'current\n') or {
		assert false, err.msg()
		return
	}
	stale := os.join_path(home, '.cursor', 'rules', 'retired.mdc')
	os.mkdir_all(os.dir(stale)) or { assert false, err.msg() }
	os.write_file(stale, 'edited by user\n') or { assert false, err.msg() }
	mut prior := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'old')
	prior.artifacts << ArtifactEntry{
		path: stale
		digest: sha256.hexhash('toolkit-owned\n')[..16]
		ownership: 'created'
	}
	save_install_receipt(mut prior, receipt_dir) or { assert false, err.msg() }
	result := run_install(InstallOptions{
		tools: ['cursor']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert result.ok, result.message
	assert result.message.contains('Skipping stale file changed since Toolkit installed it: ${stale}')
	assert os.read_file(stale) or { '' } == 'edited by user\n'
}

fn test_install_skips_stale_receipt_path_outside_home() {
	base := os.join_path(os.temp_dir(), 'at-ins-stale-outside-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'profiles', 'cursor', 'rules', 'current.mdc'), 'current\n') or {
		assert false, err.msg()
		return
	}
	outside := os.join_path(base, 'outside.mdc')
	os.write_file(outside, 'toolkit-owned\n') or { assert false, err.msg() }
	mut prior := new_install_receipt(profiles_product, 'cursor', 'user-home', '1.0.0', 'old')
	prior.artifacts << ArtifactEntry{
		path: outside
		digest: receipt_artifact_digest(outside)
		ownership: 'created'
	}
	save_install_receipt(mut prior, receipt_dir) or { assert false, err.msg() }
	result := run_install(InstallOptions{
		tools: ['cursor']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert result.ok, result.message
	assert result.message.contains('Skipping stale path outside user home: ${outside}')
	assert os.is_file(outside)
}

fn test_install_unknown_tool_skipped() {
	base := os.join_path(os.temp_dir(), 'at-ins-u-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	report := run_install(InstallOptions{
		tools: ['not-a-tool']
		home_dir: base
		data_root: base
		receipt_dir: os.join_path(base, 'receipts')
	})
	assert report.ok
	assert report.message.contains('Unknown tool')
	assert report.skipped == 1
}

fn test_install_no_tools_detected() {
	base := os.join_path(os.temp_dir(), 'at-ins-n-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	os.mkdir_all(os.join_path(data, 'profiles')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	report := run_install(InstallOptions{
		home_dir: home
		data_root: data
		receipt_dir: os.join_path(base, 'receipts')
	})
	assert !report.ok
	assert report.message.contains('No AI tools detected')
}

fn test_install_opencode_json_merge() {
	base := os.join_path(os.temp_dir(), 'at-ins-j-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'opencode')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(data, 'catalogs')) or { assert false, err.msg() }
	dst := os.join_path(home, '.config', 'opencode', 'opencode.json')
	os.mkdir_all(os.dir(dst)) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'catalogs', 'skills-layout.json'), '{"skills":[]}') or { assert false, err.msg() }
	os.write_file(os.join_path(data, 'profiles', 'opencode', 'opencode.json'), '{"schema":"https://opencode.ai/config.json"}\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(dst, '{"theme":"dark"}\n') or {
		assert false, err.msg()
		return
	}
	report := run_install(InstallOptions{
		tools: ['opencode']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert report.ok, report.message
	got := os.read_file(dst) or { '' }
	assert got.contains('theme')
	assert got.contains('schema')
	loaded := load_install_receipt('opencode', profiles_product, receipt_dir) or {
		assert false, 'receipt missing'
		return
	}
	assert loaded.artifacts.len == 1
	assert loaded.artifacts[0].ownership == 'merged'
}

fn test_install_copilot_skipped_noninteractive() {
	base := os.join_path(os.temp_dir(), 'at-ins-c-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	report := run_install(InstallOptions{
		tools: ['copilot']
		home_dir: base
		data_root: base
		receipt_dir: os.join_path(base, 'receipts')
	})
	assert report.ok
	assert report.skipped == 1
	assert report.message.contains('Copilot')
}

fn test_install_autodetect_cursor_home() {
	base := os.join_path(os.temp_dir(), 'at-ins-d-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(home, '.cursor')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'profiles', 'cursor', 'rules', 'assistant.mdc'), 'r\n') or {
		assert false, err.msg()
		return
	}
	report := run_install(InstallOptions{
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert report.ok, report.message
	assert os.is_file(os.join_path(home, '.cursor', 'rules', 'assistant.mdc'))
}

fn test_install_skips_claude_settings_json() {
	base := os.join_path(os.temp_dir(), 'at-ins-s-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	receipt_dir := os.join_path(base, 'receipts')
	profile := os.join_path(data, 'profiles', 'claude-code')
	os.mkdir_all(profile) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(data, 'catalogs')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(data, 'catalogs', 'skills-layout.json'), '{"skills":[]}') or { assert false, err.msg() }
	os.write_file(os.join_path(profile, 'CLAUDE.md'), '# claude\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(os.join_path(profile, 'settings.json'), '{"permissions":{}}\n') or {
		assert false, err.msg()
		return
	}
	report := run_install(InstallOptions{
		tools: ['claude-code']
		home_dir: home
		data_root: data
		receipt_dir: receipt_dir
	})
	assert report.ok, report.message
	assert os.is_file(os.join_path(home, '.claude', 'CLAUDE.md'))
	assert !os.exists(os.join_path(home, '.claude', 'settings.json'))
}

fn test_merge_json_install_recursive() {
	base := os.join_path(os.temp_dir(), 'at-ins-merge-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	src := os.join_path(base, 'src.json')
	dst := os.join_path(base, 'dst.json')
	// nested objects merge key-by-key; existing user values are preserved
	os.write_file(src, '{"editor":{"fontSize":14,"theme":"dark"},"top":"new"}\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(dst, '{"editor":{"fontSize":12,"userKey":"keep"},"other":true}\n') or {
		assert false, err.msg()
		return
	}
	content, ownership := merge_json_install(src, dst)
	assert ownership == 'merged', ownership
	assert content.contains('"fontSize":12')
	assert content.contains('"userKey":"keep"')
	assert content.contains('"theme":"dark"')
	assert content.contains('"top":"new"')
	assert content.contains('"other":true')
	// identical content is unchanged (original bytes preserved)
	same, ownership2 := merge_json_install(src, src)
	assert ownership2 == 'unchanged'
	assert same.contains('"fontSize":14')
	// non-object JSON is skipped, never half-merged
	os.write_file(dst, '[1,2]\n') or {
		assert false, err.msg()
		return
	}
	_, ownership3 := merge_json_install(src, dst)
	assert ownership3 == 'skipped'
}
