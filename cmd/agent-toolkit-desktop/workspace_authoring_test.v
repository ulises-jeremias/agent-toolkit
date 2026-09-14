module main

// workspace_authoring_test.v — Slice D workspace UI copy + layout budgets
// (issue #1231). Pure helpers only: no window is opened.

import desktop_engine

fn test_workspace_git_unavailable_copy_names_each_state() {
	// no workspace
	no_ws := desktop_engine.GitWorkspaceStatus{
		root: ''
		is_repo: false
		backend_available: false
	}
	head, detail := workspace_git_unavailable(no_ws)
	assert head == 'No workspace yet'
	assert detail.contains('Choose a workspace')

	// not a repo
	plain := desktop_engine.GitWorkspaceStatus{
		root: '/tmp/ws'
		is_repo: false
		backend_available: false
	}
	head2, _ := workspace_git_unavailable(plain)
	assert head2 == 'Not a git repository'

	// repo without backend
	waiting := desktop_engine.GitWorkspaceStatus{
		root: '/tmp/ws'
		is_repo: true
		backend_available: false
	}
	head3, detail3 := workspace_git_unavailable(waiting)
	assert head3 == 'Git backend unavailable'
	assert detail3.contains('no git reader')

	// backend wired — rails can render, no fallback copy
	ready := desktop_engine.GitWorkspaceStatus{
		root: '/tmp/ws'
		is_repo: true
		backend_available: true
	}
	head4, detail4 := workspace_git_unavailable(ready)
	assert head4 == '' && detail4 == ''
}

fn test_workspace_run_summary_copy() {
	assert workspace_run_summary(0) == 'No agents running.'
	assert workspace_run_summary(1) == '1 agent running.'
	assert workspace_run_summary(3) == '3 agents running.'
}

fn test_workspace_worktrees_line_copy() {
	assert workspace_worktrees_line(0) == 'No known workspaces.'
	assert workspace_worktrees_line(1) == '1 known workspace.'
	assert workspace_worktrees_line(4) == '4 known workspaces.'
}

fn test_workspace_memory_idle_row_copy() {
	assert workspace_memory_idle_row('Deploy notes', 'learning', 80) == 'Deploy notes [learning]'
	assert workspace_memory_idle_row('', 'todo', 80) == '(untitled) [todo]'
	assert workspace_memory_idle_row('Notes', '', 80) == 'Notes [general]'
	truncated := workspace_memory_idle_row('A very long memory title here', 'process', 12)
	assert truncated.ends_with('…'), 'long rows must ellipsize: ${truncated}'
	assert workspace_memory_idle_row('Tiny', 'todo', 3) == 'Tiny [todo]', 'tiny budgets never truncate'
}

fn test_workspace_git_visible_row_budgets() {
	assert workspace_git_changes_visible(200) == (200 - 30 - 20) / 20
	assert workspace_git_changes_visible(10) == 0, 'short rails show no rows, never negative'
	assert workspace_git_history_visible(200) == (200 - 30 - 40) / 22
	assert workspace_git_history_visible(10) == 0
}
