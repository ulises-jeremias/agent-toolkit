module agent_toolkit_core

import os

fn test_plan_and_apply_cursor_update_check_and_write() {
	base := os.join_path(os.temp_dir(), 'at-upd-${os.getpid()}')
	data := os.join_path(base, 'data')
	home := os.join_path(base, 'home')
	os.mkdir_all(os.join_path(data, 'profiles', 'cursor', 'rules')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	src := os.join_path(data, 'profiles', 'cursor', 'rules', 'assistant.mdc')
	os.write_file(src, 'v2\n') or {
		assert false, err.msg()
		return
	}
	dst := os.join_path(home, '.cursor', 'rules', 'assistant.mdc')
	os.mkdir_all(os.dir(dst)) or {}
	os.write_file(dst, 'v1\n') or {
		assert false, err.msg()
		return
	}

	check_report := run_update(UpdateOptions{
		tools:             ['cursor']
		check_only:        true
		home_dir:          home
		data_root:         data
		skip_data_refresh: true
	})
	assert check_report.files_updated == 1
	assert os.read_file(dst) or { '' } == 'v1\n'
	assert !check_report.ok // pending changes → non-zero like Python --check

	write_report := run_update(UpdateOptions{
		tools:             ['cursor']
		home_dir:          home
		data_root:         data
		skip_data_refresh: true
	})
	assert write_report.files_updated == 1
	assert os.read_file(dst) or { '' } == 'v2\n'
	assert write_report.ok

	again := run_update(UpdateOptions{
		tools:             ['cursor']
		home_dir:          home
		data_root:         data
		skip_data_refresh: true
	})
	assert again.files_updated == 0
	assert again.ok
}

fn test_update_unknown_tool() {
	base := os.join_path(os.temp_dir(), 'at-upd-unk-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	report := run_update(UpdateOptions{
		tools:             ['not-a-tool']
		home_dir:          base
		data_root:         base
		skip_data_refresh: true
	})
	assert !report.ok
	assert report.message.contains('Unknown tool')
}
