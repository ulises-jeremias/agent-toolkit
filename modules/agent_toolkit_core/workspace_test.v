module agent_toolkit_core

import os

fn test_workspace_init_in_temp_dir() {
	base := os.join_path(os.temp_dir(), 'at-ws-init-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	report := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert report.ok, report.message
	assert os.is_file(os.join_path(base, 'AGENTS.md'))
	assert os.is_file(os.join_path(base, 'knowledge', 'todos', 'pending.md'))
	assert os.is_file(os.join_path(base, 'personas', 'implementer.md'))
	assert os.is_dir(os.join_path(base, 'projects'))
	assert report.message.contains('Workspace initialized')
	again := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert again.ok
	assert again.message.contains('skip')
}

fn test_workspace_context_json_schema() {
	base := os.join_path(os.temp_dir(), 'at-ws-ctx-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert init.ok, init.message
	report := run_workspace(WorkspaceOptions{
		subcommand: 'context'
		workspace_path: base
		json_out: true
	})
	assert report.ok, report.message
	assert report.data['workspace'] == base
	assert report.data['subcommand'] == 'context'
	assert report.message.contains('"workspace"')
	assert report.message.contains('"sources"')
	assert report.message.contains('AGENTS.md@')
}

fn test_workspace_sync_noop_without_loops() {
	base := os.join_path(os.temp_dir(), 'at-ws-sync-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert init.ok, init.message
	report := run_workspace(WorkspaceOptions{
		subcommand: 'sync'
		workspace_path: base
	})
	assert report.ok, report.message
	assert report.data['added'] == '0'
	assert report.message.contains('No loops') || report.message.contains('No escalations')
}

fn test_workspace_sync_idempotent_escalation() {
	base := os.join_path(os.temp_dir(), 'at-ws-sync2-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert init.ok, init.message
	loop_dir := os.join_path(base, 'loops', 'daily')
	os.mkdir_all(loop_dir) or { assert false, err.msg() }
	os.write_file(os.join_path(loop_dir, 'report.md'), '# Action required: follow up with owner\n') or {
		assert false, err.msg()
		return
	}
	first := run_workspace(WorkspaceOptions{
		subcommand: 'sync'
		workspace_path: base
	})
	assert first.ok, first.message
	assert first.data['added'] == '1'
	second := run_workspace(WorkspaceOptions{
		subcommand: 'sync'
		workspace_path: base
	})
	assert second.ok, second.message
	assert second.data['added'] == '0'
}

fn test_workspace_use_persona_and_handoff() {
	base := os.join_path(os.temp_dir(), 'at-ws-per-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert init.ok, init.message
	use := run_workspace(WorkspaceOptions{
		subcommand: 'use-persona'
		workspace_path: base
		arg: 'implementer'
	})
	assert use.ok, use.message
	assert read_strip(os.join_path(base, '.active-persona')) == 'implementer'
	bad := run_workspace(WorkspaceOptions{
		subcommand: 'handoff'
		workspace_path: base
		arg: 'architect'
	})
	assert !bad.ok
	ok := run_workspace(WorkspaceOptions{
		subcommand: 'handoff'
		workspace_path: base
		arg: 'reviewer'
	})
	assert ok.ok, ok.message
	assert read_strip(os.join_path(base, '.active-persona')) == 'reviewer'
}

fn test_find_workspace_root_override_and_walk() {
	base := os.join_path(os.temp_dir(), 'at-ws-root-${os.getpid()}')
	os.mkdir_all(os.join_path(base, 'nested')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'AGENTS.md'), '# ws\n') or {
		assert false, err.msg()
		return
	}
	found := find_workspace_root(base) or {
		assert false, 'override should find dir'
		return
	}
	assert found == base
	missing := find_workspace_root(os.join_path(base, 'nope'))
	assert missing == none
}

fn test_workspace_missing_root_fails() {
	report := run_workspace(WorkspaceOptions{
		subcommand: 'context'
		workspace_path: os.join_path(os.temp_dir(), 'at-ws-missing-${os.getpid()}')
	})
	assert !report.ok
	assert report.message.contains('workspace not found')
}
