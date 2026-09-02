module agent_toolkit_core

import os

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
	dst := os.join_path(home, '.config', 'opencode', 'opencode.json')
	os.mkdir_all(os.dir(dst)) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
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
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
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
