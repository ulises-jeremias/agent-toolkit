module agent_toolkit_core

import os

fn test_parse_git_status_v2_buckets_changes() {
	text := '# branch.head main\n' +
		'1 M. N... 100644 100644 100644 abc1234 abc1234 staged.txt\n' +
		'1 .M N... 100644 100644 100644 abc1234 abc1234 dirty.txt\n' +
		'1 MM N... 100644 100644 100644 abc1234 abc1234 both.txt\n' +
		'2 R. N... 100644 100644 100644 abc1234 abc1234 R100 renamed.txt\toriginal.txt\n' +
		'? new file.txt\n'
	resp := parse_git_status_v2('demo', text)
	assert resp.ok
	assert resp.branch == 'main'
	assert resp.staged.map(it.path) == ['staged.txt', 'both.txt', 'renamed.txt']
	assert resp.unstaged.map(it.path) == ['dirty.txt', 'both.txt']
	assert resp.untracked.map(it.path) == ['new file.txt']
	assert resp.untracked[0].code == '??'
}

fn test_valid_repo_relative_path_rejects_escapes() {
	assert valid_repo_relative_path('src/main.v')
	assert valid_repo_relative_path('a b/c.txt')
	assert !valid_repo_relative_path('')
	assert !valid_repo_relative_path('/etc/passwd')
	assert !valid_repo_relative_path('../outside.txt')
	assert !valid_repo_relative_path('src/../../outside.txt')
}

fn git_fixture(args []string, cwd string) {
	res := new_process_service().run(RunOptions{
		argv: args
		cwd: cwd
	}) or { panic(err.msg()) }
	assert res.exit_code == 0, 'git fixture failed: ${args} → ${res.stderr}'
}

fn test_project_git_round_trip_stage_unstage_commit() {
	git_path := os.find_abs_path_of_executable('git') or { return } // git unavailable: skip
	_ := git_path
	base := os.join_path(os.real_path(os.temp_dir()), 'at-projgit-${os.getpid()}')
	os.mkdir_all(base) or { panic(err.msg()) }
	defer {
		os.rmdir_all(base) or {}
	}
	git_fixture(['git', 'init', '-q', '-b', 'main'], base)
	git_fixture(['git', 'config', 'user.email', 'test@example.com'], base)
	git_fixture(['git', 'config', 'user.name', 'Test'], base)
	os.write_file(os.join_path(base, 'a.txt'), 'one\n') or { panic(err.msg()) }
	git_fixture(['git', 'add', 'a.txt'], base)
	git_fixture(['git', 'commit', '-q', '-m', 'initial'], base)

	// One unstaged edit, one staged new file, one untracked file.
	os.write_file(os.join_path(base, 'a.txt'), 'one\ntwo\n') or { panic(err.msg()) }
	os.write_file(os.join_path(base, 'b.txt'), 'bee\n') or { panic(err.msg()) }
	os.write_file(os.join_path(base, 'c.txt'), 'see\n') or { panic(err.msg()) }
	staged := project_git_stage_typed(base, 'demo', ['b.txt'])
	assert staged.ok, staged.detail
	assert staged.staged.map(it.path) == ['b.txt']
	assert staged.unstaged.map(it.path) == ['a.txt']
	assert staged.untracked.map(it.path) == ['c.txt']
	assert staged.branch == 'main'

	// Diff for the unstaged edit shows the added line; staged diff is empty for it.
	diff := project_git_diff_typed(base, 'demo', 'a.txt', false)
	assert diff.ok, diff.detail
	assert diff.diff.contains('+two')
	staged_diff := project_git_diff_typed(base, 'demo', 'a.txt', true)
	assert staged_diff.ok
	assert staged_diff.diff == ''

	// Path escapes are rejected before git sees them.
	escaped := project_git_stage_typed(base, 'demo', ['../outside.txt'])
	assert !escaped.ok
	assert escaped.detail.contains('invalid repository-relative path')

	// Unstage returns b.txt to untracked; stage all and commit clears the tree.
	unstaged := project_git_unstage_typed(base, 'demo', ['b.txt'])
	assert unstaged.ok, unstaged.detail
	assert unstaged.staged.len == 0
	assert unstaged.untracked.map(it.path) == ['b.txt', 'c.txt']
	restaged := project_git_stage_typed(base, 'demo', ['a.txt', 'b.txt', 'c.txt'])
	assert restaged.ok, restaged.detail
	committed := project_git_commit_typed(base, 'demo', 'add the letters')
	assert committed.ok, committed.detail
	assert committed.staged.len == 0
	assert committed.unstaged.len == 0
	assert committed.untracked.len == 0
	assert committed.detail.contains('add the letters')

	// Committing with nothing staged fails with a real message.
	empty := project_git_commit_typed(base, 'demo', 'nothing here')
	assert !empty.ok
}

fn test_split_diff_hunks_keeps_header_per_patch() {
	diff := 'diff --git a/a.txt b/a.txt\n--- a/a.txt\n+++ b/a.txt\n@@ -1,2 +1,3 @@\n one\n+two\n@@ -5,2 +6,2 @@\n five\n-six\n+sixx\n'
	hunks := split_diff_hunks(diff)
	assert hunks.len == 2
	assert hunks[0].starts_with('diff --git a/a.txt b/a.txt')
	assert hunks[0].contains('+two')
	assert !hunks[0].contains('sixx')
	assert hunks[1].contains('-six')
	assert split_diff_hunks('').len == 0
}

fn test_project_git_stage_and_unstage_single_hunk() {
	git_path := os.find_abs_path_of_executable('git') or { return }
	_ := git_path
	base := os.join_path(os.real_path(os.temp_dir()), 'at-projhunk-${os.getpid()}')
	os.mkdir_all(base) or { panic(err.msg()) }
	defer {
		os.rmdir_all(base) or {}
	}
	git_fixture(['git', 'init', '-q', '-b', 'main'], base)
	git_fixture(['git', 'config', 'user.email', 'test@example.com'], base)
	git_fixture(['git', 'config', 'user.name', 'Test'], base)
	original := 'l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nl10\n'
	os.write_file(os.join_path(base, 'a.txt'), original) or { panic(err.msg()) }
	git_fixture(['git', 'add', 'a.txt'], base)
	git_fixture(['git', 'commit', '-q', '-m', 'initial'], base)

	// Two well-separated edits => two hunks.
	os.write_file(os.join_path(base, 'a.txt'), 'ONE\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nTEN\n') or {
		panic(err.msg())
	}

	// Stage only the first hunk: index has ONE, not TEN.
	after_stage := project_git_stage_hunk_typed(base, 'demo', 'a.txt', false, 0)
	assert after_stage.ok, after_stage.detail
	staged := project_git_diff_typed(base, 'demo', 'a.txt', true)
	assert staged.diff.contains('+ONE'), staged.diff
	assert !staged.diff.contains('+TEN'), staged.diff
	// The file stays in both buckets (other hunk still unstaged).
	assert after_stage.staged.map(it.path) == ['a.txt']
	assert after_stage.unstaged.map(it.path) == ['a.txt']

	// Bad index fails closed.
	bad := project_git_stage_hunk_typed(base, 'demo', 'a.txt', false, 9)
	assert !bad.ok
	assert bad.detail.contains('out of range')

	// Unstage the one staged hunk again: index diff becomes empty.
	after_unstage := project_git_stage_hunk_typed(base, 'demo', 'a.txt', true, 0)
	assert after_unstage.ok, after_unstage.detail
	staged2 := project_git_diff_typed(base, 'demo', 'a.txt', true)
	assert staged2.diff == '', staged2.diff
	assert after_unstage.staged.len == 0
}

fn test_parse_git_log_lines() {
	text := 'abc1234full\x1fab1234\x1fDocument the garden\x1fTest\x1f2026-10-23\n' +
		'def5678full\x1fdef5678\x1fInitial commit\x1fTest\x1f2026-10-22\n'
	commits := parse_git_log('demo', text)
	assert commits.ok
	assert commits.commits.len == 2
	assert commits.commits[0].hash == 'abc1234full'
	assert commits.commits[0].subject == 'Document the garden'
	assert commits.commits[1].date == '2026-10-22'
	assert parse_git_log('demo', '').commits.len == 0
}
