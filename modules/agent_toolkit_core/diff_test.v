module agent_toolkit_core

import os

fn test_diff_file_digest_stable() {
	path := os.join_path(os.temp_dir(), 'at-diff-dig-${os.getpid()}.txt')
	os.write_file(path, 'abc') or {
		assert false, err.msg()
		return
	}
	defer {
		os.rm(path) or {}
	}
	d := diff_file_digest(path)
	assert d.len == 12
	assert d == diff_file_digest(path)
}

fn test_diff_product_trees_added_and_changed() {
	base := os.join_path(os.temp_dir(), 'at-diff-${os.getpid()}')
	built := os.join_path(base, 'built')
	current := os.join_path(base, 'current')
	os.mkdir_all(os.join_path(built, 'skills', 'a')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(current, 'skills', 'a')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(built, 'skills', 'a', 'SKILL.md'), 'new\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(os.join_path(current, 'skills', 'a', 'SKILL.md'), 'old\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(os.join_path(built, 'skills', 'b', 'SKILL.md'), 'only-built\n') or {
		// parent missing
		os.mkdir_all(os.join_path(built, 'skills', 'b')) or {}
		os.write_file(os.join_path(built, 'skills', 'b', 'SKILL.md'), 'only-built\n') or {
			assert false, err.msg()
			return
		}
	}
	changes := diff_product_trees(built, current)
	assert 'skills/a/SKILL.md' in changes.changed
	assert 'skills/b/SKILL.md' in changes.added
}

fn test_run_diff_unknown_product() {
	report := run_diff(DiffOptions{
		product: 'not-a-real-product-xyz'
	})
	assert !report.ok
	assert report.message.len > 0
}
