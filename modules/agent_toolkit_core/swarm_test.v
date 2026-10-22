module agent_toolkit_core

import os
import x.json2

fn test_swarm_role_execution_root_requires_recorded_writer_worktree() {
	base := os.join_path(os.temp_dir(), 'at-swarm-role-root-${os.getpid()}')
	run_dir := os.join_path(base, 'run')
	repo_root := os.join_path(base, 'project')
	wt_path := os.join_path(run_dir, 'worktrees', 'implementer')
	os.mkdir_all(base) or { panic(err) }
	defer { os.rmdir_all(base) or {} }
	git_init := swarm_git_run(['init', repo_root], base)
	assert git_init.exit_code == 0, git_init.stderr
	for args in [
		['-C', repo_root, 'config', 'user.name', 'Agent Toolkit Tests'],
		['-C', repo_root, 'config', 'user.email', 'tests@agent-toolkit.invalid'],
		['-C', repo_root, 'commit', '--allow-empty', '-m', 'test base'],
	] {
		res := swarm_git_run(args, base)
		assert res.exit_code == 0, res.stderr
	}
	wt := swarm_create_worktree(repo_root, run_dir, 'implementer', 'run-test', 'HEAD') or {
		panic(err)
	}
	state := SwarmStateFile{
		run_id:   'run-test'
		recipe:   'pair'
		worktrees: [wt]
	}
	writer_root := swarm_role_execution_root(state, run_dir, repo_root, 'implementer') or { panic(err) }
	planner_root := swarm_role_execution_root(state, run_dir, repo_root, 'planner') or { panic(err) }
	assert writer_root == wt_path
	assert planner_root == repo_root
	ordinary_run := os.join_path(base, 'ordinary-run')
	ordinary_role_path := os.join_path(ordinary_run, 'worktrees', 'implementer')
	os.mkdir_all(ordinary_role_path) or { panic(err) }
	if _ := swarm_create_worktree(repo_root, ordinary_run, 'implementer', 'run-test', 'HEAD') {
		assert false
	} else {
		assert err.msg().contains('not the registered swarm Git worktree')
	}
	if _ := swarm_role_execution_root(SwarmStateFile{ run_id: 'run-test', recipe: 'pair' }, run_dir, repo_root,
		'implementer') {
		assert false
	} else {
		assert err.msg().contains('refusing to launch')
	}
	if _ := swarm_role_execution_root(SwarmStateFile{
		run_id:   'run-test'
		recipe:   'pair'
		worktrees: [SwarmWorktree{ ...wt, path: os.join_path(base, 'not-a-worktree') }]
	}, run_dir, repo_root, 'implementer') {
		assert false
	} else {
		assert err.msg().contains('refusing to launch')
	}
	ordinary_dir := os.join_path(base, 'ordinary-directory')
	os.mkdir_all(ordinary_dir) or { panic(err) }
	if _ := swarm_role_execution_root(SwarmStateFile{
		run_id: 'run-test'
		recipe: 'pair'
		worktrees: [SwarmWorktree{ ...wt, path: ordinary_dir }]
	}, run_dir, repo_root, 'implementer') {
		assert false
	} else {
		assert err.msg().contains('refusing to launch')
	}
	$if !windows {
		unsafe_run := os.join_path(base, 'unsafe-run')
		os.mkdir_all(unsafe_run) or { panic(err) }
		unsafe_worktrees := os.join_path(base, 'unsafe-worktrees')
		os.mkdir_all(unsafe_worktrees) or { panic(err) }
		os.symlink(unsafe_worktrees, os.join_path(unsafe_run, 'worktrees')) or {
			panic(err)
		}
		if _ := swarm_create_worktree(repo_root, unsafe_run, 'implementer', 'run-test', 'HEAD') {
			assert false
		} else {
			assert err.msg().contains('through a symlink')
		}
		unsafe_state := SwarmStateFile{
			run_id:   'run-test'
			recipe:   'pair'
			worktrees: [SwarmWorktree{ ...wt, path: os.join_path(unsafe_run, 'worktrees', 'implementer') }]
		}
		if _ := swarm_role_execution_root(unsafe_state, unsafe_run, repo_root, 'implementer') {
			assert false
		} else {
			assert err.msg().contains('symlink')
		}
	}
}

fn test_swarm_started_marker_survives_concurrent_trace_rewrite() {
	run_dir := os.join_path(os.temp_dir(), 'at-swarm-start-marker-${os.getpid()}')
	ensure_swarm_run_dirs(run_dir) or { panic(err) }
	defer { os.rmdir_all(run_dir) or {} }
	marker := swarm_reserve_role_start(run_dir, 'implementer') or { panic(err) }
	os.write_file(marker, 'started\n') or { panic(err) }
	append_swarm_trace(run_dir, 'role_autostarted', 'reviewer=opencode')
	assert swarm_role_already_started(run_dir, 'implementer') or { panic(err) }
	if _ := swarm_reserve_role_start(run_dir, 'implementer') {
		assert false
	} else {
		assert err.msg().contains('startup reservation')
	}
}

fn test_interrupted_swarm_role_start_fails_closed_for_review() {
	run_dir := os.join_path(os.temp_dir(), 'at-swarm-interrupted-marker-${os.getpid()}')
	ensure_swarm_run_dirs(run_dir) or { panic(err) }
	defer { os.rmdir_all(run_dir) or {} }
	marker := swarm_reserve_role_start(run_dir, 'reviewer') or { panic(err) }
	assert os.read_file(marker) or { panic(err) } == 'starting\n'
	if _ := swarm_role_already_started(run_dir, 'reviewer') {
		assert false
	} else {
		assert err.msg().contains('inspect its terminal')
		assert err.msg().contains('duplicate work')
	}
}

fn test_swarm_run_listing_deduplicates_workspace_project_symlink() {
	workspace := os.join_path(os.temp_dir(), 'at-swarm-list-dedupe-${os.getpid()}')
	os.mkdir_all(workspace) or { panic(err) }
	defer { os.rmdir_all(workspace) or {} }
	run_dir := swarm_run_dir(workspace, 'run-test')
	ensure_swarm_run_dirs(run_dir) or { panic(err) }
	projects_dir := os.join_path(workspace, 'projects')
	os.mkdir_all(projects_dir) or { panic(err) }
	os.symlink(workspace, os.join_path(projects_dir, 'workspace-alias')) or { panic(err) }

	runs := list_all_swarm_runs(workspace)
	assert runs.len == 1
	assert runs[0] == os.real_path(run_dir)
}

fn test_swarm_help() {
	r := run_swarm(SwarmOptions{
		subcommand: 'help'
	})
	assert r.ok
	assert r.message.contains('start')
	assert r.message.contains('approve')
	assert r.message.contains('ADR-008')
}

fn test_swarm_recipes() {
	r := run_swarm(SwarmOptions{
		subcommand: 'recipes'
	})
	assert r.ok
	assert r.data['recipes'].contains('pair')
	one := run_swarm(SwarmOptions{
		subcommand: 'recipes'
		run_id: 'pair'
	})
	assert one.ok
	assert one.data['roles'].contains('implementer')
}

fn test_swarm_headless_start_refuses_requested_role_process_launch() {
	base := os.join_path(os.temp_dir(), 'at-swarm-headless-${os.getpid()}')
	os.mkdir_all(os.join_path(base, '.git')) or { panic(err) }
	defer { os.rmdir_all(base) or {} }
	report := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		recipe: 'pair'
		backend: 'headless'
		launch_sessions: true
		task: 'check adapter guard'
	})
	assert !report.ok
	assert report.message.contains('cannot launch role sessions')
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))
}

fn test_reconcile_swarm_person_sessions_closes_only_terminal_runs() {
	ws := os.join_path(os.temp_dir(), 'at-swarm-reconcile-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	os.mkdir_all(os.join_path(ws, 'projects', 'demo')) or { panic(err) }
	os.write_file(os.join_path(ws, 'AGENTS.md'), '# Swarm reconcile test workspace') or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	save_person(ws, '{"spec":"agent-toolkit/person@1","id":"lina","name":"Lina","role":"reviewer","goal":"Review changes","archived":false}', true) or {
		panic(err)
	}
	mut store := new_person_session_store()
	run_id := 's20261021T220000Z'
	store.record_swarm_person_session(SwarmPersonSessionRequest{
		workspace: ws
		run_id: run_id
		role: 'reviewer'
		person_id: 'lina'
		provider: 'opencode'
		model: 'auto'
		cwd: os.join_path(ws, 'projects', 'demo')
	}) or { panic(err) }
	rd := swarm_run_dir(ws, run_id)
	// A live or paused run is not evidence the worker is gone.
	reconcile_swarm_person_sessions(ws, rd, run_id, 'running')
	reconcile_swarm_person_sessions(ws, rd, run_id, 'paused')
	mut listed := store.list_person_sessions(ws) or { panic(err) }
	assert listed.sessions.len == 1
	assert listed.sessions[0].status == 'running'
	// A terminal run state closes the orphaned record truthfully.
	reconcile_swarm_person_sessions(ws, rd, run_id, 'completed')
	listed = store.list_person_sessions(ws) or { panic(err) }
	assert listed.sessions[0].status == 'completed'
	assert listed.sessions[0].ended_at.len > 0
}

fn test_tmux_session_missing_requires_tmuxs_own_words() {
	assert tmux_session_missing(RunResult{ exit_code: 1, stderr: 'no server running on /tmp/tmux-1000/default' })
	assert tmux_session_missing(RunResult{ exit_code: 1, stderr: "can't find session: swarm-s1" })
	assert tmux_session_missing(RunResult{
		exit_code: 1
		stderr: 'error connecting to /tmp/tmux-1000/agent-toolkit-swarm-s1 (No such file or directory)'
	})
	assert !tmux_session_missing(RunResult{ exit_code: 0 })
	assert !tmux_session_missing(RunResult{ exit_code: 1, stderr: 'no server running on /tmp/tmux-1000/default', timed_out: true })
	assert !tmux_session_missing(RunResult{ exit_code: 1, stderr: 'failed to connect to server' })
	assert !tmux_session_missing(RunResult{ exit_code: -1 })
}

fn test_swarm_role_already_started_ignores_waiting_roles() {
	ws := os.join_path(os.temp_dir(), 'at-swarm-waiting-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	run_id := 's20261021T231500Z'
	rd := swarm_run_dir(ws, run_id)
	os.mkdir_all(rd) or { panic(err) }
	// A waiting tmux window traces agent_waiting, never a started agent:
	// the handoff autostart gate must still launch its runner.
	os.write_file(os.join_path(rd, 'trace.jsonl'), '{"kind":"agent_waiting","detail":"reviewer:implementer"}\n{"kind":"tmux_agent_started","detail":"implementer=skeleton model=auto"}\n') or {
		panic(err)
	}
	assert swarm_role_already_started(rd, 'implementer') or { panic(err) }
	assert !(swarm_role_already_started(rd, 'reviewer') or { panic(err) })
	// Once the reviewer really launches, the gate closes.
	os.write_file(os.join_path(rd, 'trace.jsonl'), '{"kind":"agent_waiting","detail":"reviewer:implementer"}\n{"kind":"role_autostarted","detail":"reviewer=skeleton"}\n') or {
		panic(err)
	}
	assert swarm_role_already_started(rd, 'reviewer') or { panic(err) }
}

fn test_reconcile_dead_tmux_swarm_sessions_closes_only_proven_dead_workers() {
	if os.execute('command -v tmux').exit_code != 0 {
		// Without tmux the probe cannot prove a worker surface is gone;
		// the Electron swarm spec covers the real path on tmux hosts.
		return
	}
	ws := os.join_path(os.temp_dir(), 'at-swarm-dead-worker-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	os.mkdir_all(os.join_path(ws, 'projects', 'demo')) or { panic(err) }
	os.write_file(os.join_path(ws, 'AGENTS.md'), '# Swarm dead-worker test workspace') or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	save_person(ws, '{"spec":"agent-toolkit/person@1","id":"lina","name":"Lina","role":"reviewer","goal":"Review changes","archived":false}', true) or {
		panic(err)
	}
	mut store := new_person_session_store()
	run_id := 's20261021T230000Z'
	store.record_swarm_person_session(SwarmPersonSessionRequest{
		workspace: ws
		run_id: run_id
		role: 'reviewer'
		person_id: 'lina'
		provider: 'skeleton'
		model: 'auto'
		cwd: os.join_path(ws, 'projects', 'demo')
	}) or { panic(err) }
	rd := swarm_run_dir(ws, run_id)
	// Other backends and non-running runs are not probed: no evidence of loss.
	reconcile_dead_tmux_swarm_sessions(ws, rd, run_id, 'running', 'headless')
	reconcile_dead_tmux_swarm_sessions(ws, rd, run_id, 'paused', 'tmux')
	mut listed := store.list_person_sessions(ws) or { panic(err) }
	assert listed.sessions.len == 1
	assert listed.sessions[0].status == 'running'
	// No tmux session exists for this run id, so a running tmux run's
	// recorded worker surface is provably gone and must not stay `running`.
	reconcile_dead_tmux_swarm_sessions(ws, rd, run_id, 'running', 'tmux')
	listed = store.list_person_sessions(ws) or { panic(err) }
	assert listed.sessions[0].status == 'interrupted'
	assert listed.sessions[0].ended_at.len > 0
}

fn test_swarm_person_environment_hint_is_role_specific_and_shell_quoted() {
	bindings := {
		'reviewer': "lina's-review"
	}
	assert swarm_person_env('reviewer', bindings) == " && export AGENT_TOOLKIT_PERSON_ID='lina'\\''s-review'"
	assert swarm_person_env('implementer', bindings) == ''
}

fn test_swarm_role_execution_uses_person_preferences_and_validated_overrides() {
	base := os.join_path(os.temp_dir(), 'at-swarm-role-execution-${os.getpid()}')
	os.mkdir_all(os.join_path(base, '.git')) or { panic(err) }
	defer { os.rmdir_all(base) or {} }
	save_person(base, '{"spec":"agent-toolkit/person@1","id":"lina","name":"Lina","role":"reviewer","goal":"Review changes","archived":false,"preferred_provider":"opencode","preferred_model":"sonnet"}', true) or { panic(err) }
	person_default := resolve_swarm_role_execution(base, 'team', {'reviewer': 'lina'}, {}, {}, 'claude', 'quality') or {
		panic(err)
	}
	assert person_default['reviewer'].runner == 'opencode'
	assert person_default['reviewer'].model == 'sonnet'
	assert person_default['planner'].runner == 'claude'
	assert person_default['planner'].model == 'opus'
	overridden := resolve_swarm_role_execution(base, 'team', {'reviewer': 'lina'}, {'reviewer': 'codex'}, {}, 'claude', 'quality') or {
		panic(err)
	}
	assert overridden['reviewer'].runner == 'codex'
	assert overridden['reviewer'].model == 'o4-mini'
	selected_model := resolve_swarm_role_execution(base, 'team', {'reviewer': 'lina'}, {'reviewer': 'codex'}, {'reviewer': 'o3-mini'}, 'claude', 'quality') or {
		panic(err)
	}
	assert selected_model['reviewer'].model == 'o3-mini'
	if _ := resolve_swarm_role_execution(base, 'team', {'reviewer': 'lina'}, {}, {'reviewer': 'o3-mini'}, 'claude', 'quality') {
		assert false, 'model for a different runner was accepted'
	} else {
		assert err.msg().contains('not available')
	}
	if _ := resolve_swarm_role_execution(base, 'team', {}, {'not-a-role': 'claude'}, {}, 'claude', 'quality') {
		assert false, 'runner override for an unknown role was accepted'
	} else {
		assert err.msg().contains('outside recipe')
	}
}

fn test_swarm_start_preview_reports_resolved_role_execution() {
	base := os.join_path(os.temp_dir(), 'at-swarm-role-preview-${os.getpid()}')
	os.mkdir_all(os.join_path(base, '.git')) or { panic(err) }
	defer { os.rmdir_all(base) or {} }
	save_person(base, '{"spec":"agent-toolkit/person@1","id":"lina","name":"Lina","role":"reviewer","goal":"Review changes","archived":false,"preferred_provider":"opencode","preferred_model":"sonnet"}', true) or { panic(err) }
	preview := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		recipe: 'team'
		backend: 'headless'
		dry_run: true
		task: 'inspect role configuration'
		person_bindings: {'reviewer': 'lina'}
		role_runners: {'planner': 'codex'}
		role_models: {'planner': 'o3-mini'}
	})
	assert preview.ok, preview.message
	assert preview.data['role_execution'].contains('"reviewer":{"runner":"opencode","model":"sonnet"}')
	assert preview.data['role_execution'].contains('"planner":{"runner":"codex","model":"o3-mini"}')
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))
}

fn test_swarm_start_preview_targets_the_selected_workspace_project() {
	base := os.join_path(os.temp_dir(), 'at-swarm-project-${os.getpid()}')
	repo := os.join_path(os.temp_dir(), 'at-swarm-project-repo-${os.getpid()}')
	os.mkdir_all(os.join_path(base, 'projects')) or { panic(err) }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# workspace\n') or { panic(err) }
	os.mkdir_all(os.join_path(repo, '.git')) or { panic(err) }
	os.symlink(repo, os.join_path(base, 'projects', 'agent-toolkit')) or { panic(err) }
	defer {
		os.rmdir_all(base) or {}
		os.rmdir_all(repo) or {}
	}

	preview := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		project_id: 'agent-toolkit'
		recipe: 'pair'
		backend: 'headless'
		dry_run: true
		task: 'inspect project selection'
	})
	assert preview.ok, preview.message
	assert preview.data['project_id'] == 'agent-toolkit'
	assert preview.data['project_path'] == os.real_path(repo)
	changed := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		project_id: 'agent-toolkit'
		expected_project_path: base
		recipe: 'pair'
		backend: 'headless'
		dry_run: true
		task: 'reject a project whose reviewed path changed'
	})
	assert !changed.ok
	assert changed.message.contains('changed after preview')
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))
	resolved := swarm_repository_root(base, 'agent-toolkit') or { panic(err) }
	assert resolved == os.real_path(repo)
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))

	bad := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		project_id: 'missing'
		recipe: 'pair'
		backend: 'headless'
		dry_run: true
		task: 'must not select the workspace root'
	})
	assert !bad.ok
	assert bad.message.contains('project not found')
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))
}

fn test_swarm_recipe_catalog_exposes_canonical_topology_and_backends() {
	catalog := list_swarm_recipes_typed()
	assert catalog.ok
	assert catalog.recipes.len == 3
	team := catalog.recipes.filter(it.name == 'team')[0]
	assert team.roles.len > 1
	assert team.max_concurrency > 0
	assert team.budget.max_total_tokens > 0
	assert team.roles.any(it.name == 'implementer' && it.persona.len > 0)
	assert team.require_plan_approval
	pair := catalog.recipes.filter(it.name == 'pair')[0]
	assert pair.roles.len == 3
	assert pair.description.contains('Three-role')
	assert pair.workspace_strategy == 'worktree-per-writer'
	assert pair.keep_on_failure
	assert !pair.allow_direct_base_merge
	assert !pair.allow_push
	assert pair.max_wall_seconds > 0
	assert catalog.backends.any(it.name == 'auto' && it.available)
	assert catalog.backends.any(it.name == 'headless' && it.available)
}

fn test_swarm_start_status_approve_cancel() {
	old_h := os.getenv('HARNESS_DIR')
	old_ws := os.getenv('AGENT_TOOLKIT_WORKSPACE')
	os.unsetenv('HARNESS_DIR')
	os.unsetenv('AGENT_TOOLKIT_WORKSPACE')
	base := os.join_path(os.temp_dir(), 'at-swarm-${os.getpid()}')
	os.mkdir_all(os.join_path(base, '.git')) or { assert false, err.msg() }
	defer {
		if old_h.len > 0 {
			os.setenv('HARNESS_DIR', old_h, true)
		}
		if old_ws.len > 0 {
			os.setenv('AGENT_TOOLKIT_WORKSPACE', old_ws, true)
		}
		os.rmdir_all(base) or {}
	}
	save_person(base, '{"spec":"agent-toolkit/person@1","id":"lina","name":"Lina","role":"reviewer","goal":"Review changes","archived":false}', true) or { panic(err) }

	dry := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		recipe: 'team'
		backend: 'headless'
		dry_run: true
		task: 'demo'
		person_bindings: {
			'planner': 'lina'
		}
	})
	assert dry.ok, dry.message
	assert dry.data['mode'] == 'dry-run'
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))

	start := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		recipe: 'team'
		backend: 'headless'
		task: 'demo'
		person_bindings: {
			'planner': 'lina'
		}
	})
	assert start.ok, start.message
	assert start.data['run_state'] == 'awaiting_plan_approval'
	rid := start.data['run_id']
	assert swarm_valid_run_id(rid)
	assert os.is_file(os.join_path(base, '.agent-toolkit', 'swarm', 'runs', rid, 'state.json'))
	detail := get_swarm_run_typed(base, rid) or { panic(err) }
	assert detail.run.person_bindings['planner'] == 'lina'

	st := run_swarm(SwarmOptions{
		subcommand: 'status'
		workspace_path: base
		run_id: rid
	})
	assert st.ok, st.message
	assert st.data['gates'].contains('plan:pending')

	ap := run_swarm(SwarmOptions{
		subcommand: 'approve'
		workspace_path: base
		run_id: rid
		gate_id: 'plan'
	})
	assert ap.ok, ap.message
	assert ap.data['run_state'] == 'running'

	rej := run_swarm(SwarmOptions{
		subcommand: 'reject'
		workspace_path: base
		run_id: rid
		gate_id: 'final'
		reason: 'not yet'
	})
	assert rej.ok, rej.message

	can := run_swarm(SwarmOptions{
		subcommand: 'cancel'
		workspace_path: base
		run_id: rid
	})
	assert can.ok, can.message
	assert can.data['run_state'] == 'cancelled'

	doc := run_swarm(SwarmOptions{
		subcommand: 'doctor'
		workspace_path: base
	})
	assert doc.ok, doc.message
	assert doc.data['git'] == 'true'
	assert doc.data['recipes'].contains('pair')
}

fn test_clamp_swarm_concurrency_bounds() {
	assert clamp_swarm_concurrency(2) == 2
	assert clamp_swarm_concurrency(1) == 1
	assert clamp_swarm_concurrency(6) == 6
	assert clamp_swarm_concurrency(0) == 1
	assert clamp_swarm_concurrency(-3) == 1
	assert clamp_swarm_concurrency(7) == 6
	assert clamp_swarm_concurrency(99) == 6
}

fn test_swarm_budget_violations_names_each_limit() {
	b := Budget{
		max_total_tokens: 100
		max_cost_usd: 4.0
		max_wall_seconds: 60
		max_concurrency: 2
	}
	// clean run violates nothing
	assert swarm_budget_violations(b, BudgetConsumed{}, 0) == []
	// boundary trips (>= parity with Python check_limits)
	assert swarm_budget_violations(b, BudgetConsumed{ total_tokens: 100 }, 0) == [
		'max_total_tokens',
	]
	assert swarm_budget_violations(b, BudgetConsumed{ total_cost: 4.0 }, 0) == [
		'max_cost_usd',
	]
	assert swarm_budget_violations(b, BudgetConsumed{}, 60) == ['max_wall_seconds']
	// just under the limit is clean
	assert swarm_budget_violations(b, BudgetConsumed{ total_tokens: 99 }, 0) == []
	// several limits can trip together, in stable order
	assert swarm_budget_violations(b, BudgetConsumed{
		total_tokens: 200
		total_cost: 9.5
	}, 500) == ['max_total_tokens', 'max_cost_usd', 'max_wall_seconds']
	// zero max means unset and is skipped
	unset := Budget{}
	assert swarm_budget_violations(unset, BudgetConsumed{
		total_tokens: 1000000
		total_cost: 999.0
	}, 100000) == []
}

fn test_resolve_swarm_config_keeps_valid_concurrency() {
	r := resolve_swarm_config('', 'pair', '', '', '') or {
		assert false, err.msg()
		return
	}
	assert r.execution.max_concurrency == 2
	assert r.spec.execution.max_concurrency == 2
}

fn semantics_run(workspace string, run_id string, recipe string) string {
	rd := swarm_run_dir(workspace, run_id)
	ensure_swarm_run_dirs(rd) or { panic(err) }
	write_swarm_state(rd, SwarmStateFile{
		run_id: run_id
		recipe: recipe
		run_state: 'running'
		backend: 'headless'
	}) or { panic(err) }
	return rd
}

fn semantics_create(workspace string, run_id string, from_role string, to_role string, act string, max_hops int) SwarmReport {
	return run_swarm(SwarmOptions{
		subcommand: 'handoff'
		handoff_sub: 'create'
		workspace_path: workspace
		run_id: run_id
		htype: 'decision_request'
		from_role: from_role
		to_role: to_role
		act: act
		max_hops: max_hops
	})
}

fn test_swarm_handoff_act_validation_and_legacy_records() {
	workspace := os.join_path(os.temp_dir(), 'at-swarm-act-${os.getpid()}')
	os.mkdir_all(workspace) or { panic(err) }
	defer { os.rmdir_all(workspace) or {} }
	rd := semantics_run(workspace, 'run-act', 'pair')

	bad := semantics_create(workspace, 'run-act', 'implementer', 'reviewer', 'bogus-act', 0)
	assert !bad.ok
	assert bad.message.contains('act must be one of')

	good := semantics_create(workspace, 'run-act', 'implementer', 'reviewer', 'propose', 0)
	assert good.ok, good.message
	queued := list_handoffs(rd, 'queued')
	assert queued.len == 1
	assert queued[0].act == 'propose'
	assert queued[0].hops == 0
	assert queued[0].max_hops == handoff_default_max_hops

	// A record written before acts/hops existed must still decode and validate.
	legacy := '{"version":1,"type":"decision_request","from":"reviewer","to":"implementer","priority":0,"artifact":"","commit":"","branch":"","blocking":false}'
	legacy_rec := json2.decode[HandoffRecord](legacy) or { panic(err) }
	assert legacy_rec.act == ''
	assert legacy_rec.hops == 0
	assert validate_handoff(legacy_rec, rd, ['implementer', 'reviewer']).len == 0
}

fn test_swarm_handoff_hop_cap_routes_to_human_and_resolves() {
	workspace := os.join_path(os.temp_dir(), 'at-swarm-hops-${os.getpid()}')
	os.mkdir_all(workspace) or { panic(err) }
	defer { os.rmdir_all(workspace) or {} }
	rd := semantics_run(workspace, 'run-hops', 'pair')

	first := semantics_create(workspace, 'run-hops', 'implementer', 'reviewer', 'propose', 1)
	assert first.ok, first.message
	move_handoff(rd, first.data['handoff_id'], 'queued', 'active') or { panic('move to active failed') }

	reply := semantics_create(workspace, 'run-hops', 'reviewer', 'implementer', 'review', 1)
	assert reply.ok, reply.message
	assert reply.data['state'] != 'awaiting_human'
	move_handoff(rd, reply.data['handoff_id'], 'queued', 'active') or { panic('move reply to active failed') }

	capped := semantics_create(workspace, 'run-hops', 'implementer', 'reviewer', 'propose', 1)
	assert capped.ok, capped.message
	assert capped.data['state'] == 'awaiting_human'
	assert capped.data['hops'] == '2'
	waiting := list_handoffs(rd, 'awaiting_human')
	assert waiting.len == 1
	assert waiting[0].act == 'request_decision'
	assert list_handoffs(rd, 'queued').len == 0

	resolved := run_swarm(SwarmOptions{
		subcommand: 'task'
		handoff_sub: 'complete'
		workspace_path: workspace
		run_id: 'run-hops'
		handoff_id: capped.data['handoff_id']
	})
	assert resolved.ok, resolved.message
	assert list_handoffs(rd, 'awaiting_human').len == 0
	assert list_handoffs(rd, 'completed').len == 3
}

fn test_swarm_handoff_broadcast_fans_out_per_role() {
	workspace := os.join_path(os.temp_dir(), 'at-swarm-broadcast-${os.getpid()}')
	os.mkdir_all(workspace) or { panic(err) }
	defer { os.rmdir_all(workspace) or {} }
	rd := semantics_run(workspace, 'run-broadcast', 'pair')

	report := semantics_create(workspace, 'run-broadcast', 'implementer', 'all', 'inform', 0)
	assert report.ok, report.message
	assert report.data['broadcast'] == 'true'
	assert report.data['recipients'] == '2'
	queued := list_handoffs(rd, 'queued')
	assert queued.len == 2
	mut recipients := []string{}
	for h in queued {
		recipients << h.to_role
		assert h.act == 'inform'
	}
	recipients.sort()
	assert recipients == ['integrator', 'reviewer']
}

fn test_swarm_effective_task_derives_from_issue_ref() {
	assert swarm_effective_task(SwarmOptions{ task: 'Custom', issue_ref: 'o/r#1' }) == 'Custom'
	assert swarm_effective_task(SwarmOptions{ issue_ref: 'o/r#42' }) == 'Implement issue o/r#42'
	assert swarm_effective_task(SwarmOptions{}) == ''
}
