module main

// Slice G worktree rail: binding, existence, shared flags. No GUI boot.

fn wt_exists(paths []string) fn (string) bool {
	return fn [paths] (p string) bool {
		return p in paths
	}
}

fn test_worktree_rows_bind_present_and_missing() {
	rows := git_worktree_rows([
		['swarm abc', '/runs/abc/worktree'],
		['loop nightly/r1', '/runs/gone'],
	], wt_exists(['/runs/abc/worktree']))
	assert rows.len == 2
	assert rows[0].exists && git_worktree_state(rows[0]) == 'present'
	assert !rows[1].exists && git_worktree_state(rows[1]) == 'missing'
}

fn test_worktree_rows_flag_shared_paths() {
	rows := git_worktree_rows([
		['swarm a', '/same/tree'],
		['loop x/r1', '/same/tree'],
		['swarm b', '/own/tree'],
	], wt_exists(['/same/tree', '/own/tree']))
	assert rows[0].shared && rows[1].shared
	assert !rows[2].shared
	assert git_worktree_state(rows[0]) == 'shared', 'shared wins over present'
}

fn test_worktree_rows_withhold_empty_paths() {
	rows := git_worktree_rows([
		['loop x/r9', ''],
	], wt_exists([]))
	assert rows.len == 1
	assert rows[0].path == '(withheld)'
	assert git_worktree_state(rows[0]) == 'withheld'
	assert !rows[0].exists
}

fn test_worktree_rows_empty() {
	rows := git_worktree_rows([][]string{}, wt_exists([]))
	assert rows.len == 0
}
