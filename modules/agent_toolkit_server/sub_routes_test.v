module agent_toolkit_server

import os

fn sub_test_dir(tag string) string {
	dir := os.join_path(os.temp_dir(), 'test_sub_routes_' + tag + '_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	return dir
}

// no_error marks a builder call that unexpectedly succeeded.
const no_error = SubRouteError{
	status: .ok
	reason: 'no error'
}

fn as_sub_error(e IError) SubRouteError {
	if e is SubRouteError {
		return e
	}
	return SubRouteError{
		status: .internal_server_error
		reason: 'not a SubRouteError: ${e.msg()}'
	}
}

fn expect_sub_error(e SubRouteError, status int, contains string) {
	assert int(e.status) == status, 'status ${int(e.status)} != ${status}: ${e.reason}'
	assert e.reason.contains(contains), 'reason "${e.reason}" lacks "${contains}"'
}

fn memory_ok(sub string, body string) SubRouteError {
	build_memory_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

fn skills_ok(sub string, body string) SubRouteError {
	build_skills_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

fn loops_ok(sub string, body string) SubRouteError {
	build_loops_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

fn swarms_ok(sub string, body string) SubRouteError {
	build_swarms_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

fn workspace_ok(sub string, body string) SubRouteError {
	build_workspace_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

fn project_ok(sub string, body string) SubRouteError {
	build_project_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

fn plugin_ok(sub string, body string) SubRouteError {
	build_plugin_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

fn dc_ok(sub string, body string) SubRouteError {
	build_dc_options(sub, body) or { return as_sub_error(err) }
	return no_error
}

// --- the route path is authoritative ---------------------------------------

fn test_body_subcommand_cannot_override_route() {
	mem := build_memory_options('search', '{"subcommand":"add","query":"veb"}') or {
		panic(err.msg())
	}
	assert mem.subcommand == 'search'
	assert mem.query == 'veb'
	sk := build_skills_options('list', '{"subcommand":"sync"}') or { panic(err.msg()) }
	assert sk.subcommand == 'list'
	lp := build_loops_options('status', '{"subcommand":"gate-issue-receipt","name":"triage"}') or {
		panic(err.msg())
	}
	assert lp.subcommand == 'status'
	sw := build_swarms_options('status', '{"subcommand":"attach","run_id":"run-abc"}') or {
		panic(err.msg())
	}
	assert sw.subcommand == 'status'
	pl := build_plugin_options('check', '{"subcommand":"sync"}') or { panic(err.msg()) }
	assert pl.subcommand == 'check'
}

// --- typed fields are forwarded ---------------------------------------------

fn test_memory_fields_forwarded() {
	ws := sub_test_dir('memws')
	defer {
		os.rmdir_all(ws) or {}
	}
	body := '{"workspace":"${ws}","entry_type":"learning","title":"T","content":"line1\\nline2","stale_after":30,"fix":true,"show_done":true}'
	opts := build_memory_options('add', body) or { panic(err.msg()) }
	assert opts.subcommand == 'add'
	assert opts.workspace_path == ws
	assert opts.entry_type == 'learning'
	assert opts.title == 'T'
	assert opts.content == 'line1\nline2'
	assert opts.stale_after == 30
	assert opts.fix
	assert opts.show_done
}

fn test_skills_mcp_fields_forwarded() {
	sk := build_skills_options('sync', '{"domain":"core","tools":["cursor","claude-code"]}') or {
		panic(err.msg())
	}
	assert sk.domain == 'core'
	assert sk.tools == ['cursor', 'claude-code']
	mc := build_mcp_options('health', '{"provider":"github","offline":true}') or {
		panic(err.msg())
	}
	assert mc.subcommand == 'health'
	assert mc.provider == 'github'
	assert mc.offline
}

fn test_loops_fields_forwarded() {
	opts := build_loops_options('schedule', '{"name":"oss-triage","cron":"0 9 * * 1-5","platform":"local","runner":"cursor","model":"anthropic/claude-sonnet:latest","dry_run":true}') or {
		panic(err.msg())
	}
	assert opts.name == 'oss-triage'
	assert opts.cron == '0 9 * * 1-5'
	assert opts.platform == 'local'
	assert opts.runner == 'cursor'
	assert opts.model == 'anthropic/claude-sonnet:latest'
	assert opts.dry_run
	// no body workspace → server default (workspace root or cwd), as before
	assert opts.workspace_path.len > 0
}

fn test_swarms_fields_forwarded_and_never_attach() {
	opts := build_swarms_options('approve', '{"run_id":"run-123","gate_id":"plan","reason":"looks good","priority":2,"commit":"abc1234","branch":"feat/x"}') or {
		panic(err.msg())
	}
	assert opts.subcommand == 'approve'
	assert opts.run_id == 'run-123'
	assert opts.gate_id == 'plan'
	assert opts.reason == 'looks good'
	assert opts.priority == 2
	assert opts.commit == 'abc1234'
	assert opts.branch == 'feat/x'
	assert opts.no_attach
	assert !opts.attach
	// attach is not a DTO field: a body cannot turn it on
	start := build_swarms_options('start', '{"attach":true,"no_attach":false,"launch_sessions":true,"recipe":"pair"}') or {
		panic(err.msg())
	}
	assert start.no_attach
	assert !start.attach
	assert start.recipe == 'pair'
	assert start.launch_sessions
}

fn test_swarm_person_bindings_map_is_typed_and_forwarded() {
	start := build_swarms_options('start', '{"person_bindings":{"planner":"maya","reviewer":"lina"},"role_runners":{"planner":"claude"},"role_models":{"planner":"opus"},"launch_sessions":true}') or {
		panic(err.msg())
	}
	assert start.person_bindings['planner'] == 'maya'
	assert start.person_bindings['reviewer'] == 'lina'
	assert start.role_runners['planner'] == 'claude'
	assert start.role_models['planner'] == 'opus'
	assert start.launch_sessions
	assert start.no_attach
	assert !start.attach
}

fn test_workspace_project_dc_fields_forwarded() {
	ws := sub_test_dir('wsfields')
	defer {
		os.rmdir_all(ws) or {}
	}
	w := build_workspace_options('use-persona', '{"workspace":"${ws}","arg":"reviewer","explain":true}') or {
		panic(err.msg())
	}
	assert w.workspace_path == ws
	assert w.arg == 'reviewer'
	assert w.explain
	h := build_workspace_options('history', '{"arg":"20"}') or { panic(err.msg()) }
	assert h.arg == '20'
	p := build_project_options('clone', '{"workspace":"${ws}","arg":"owner/repo","ssh":true}') or {
		panic(err.msg())
	}
	assert p.arg == 'owner/repo'
	assert p.ssh
	assert p.workspace_path == ws
	d := build_dc_options('queue', '{"arg":"my-project","template":"code-review","request":"review auth","no_llm":true}') or {
		panic(err.msg())
	}
	assert d.arg == 'my-project'
	assert d.template == 'code-review'
	assert d.request == 'review auth'
	assert d.no_llm
}

fn test_empty_body_keeps_defaults() {
	mem := build_memory_options('inject', '') or { panic(err.msg()) }
	assert mem.subcommand == 'inject'
	assert mem.workspace_path == ''
	assert mem.query == ''
	ws := build_workspace_options('context', '  ') or { panic(err.msg()) }
	assert ws.subcommand == 'context'
	pl := build_plugin_options('check', '{}') or { panic(err.msg()) }
	assert pl.subcommand == 'check'
}

// --- allowlist ---------------------------------------------------------------

fn test_unknown_subcommand_is_not_found() {
	expect_sub_error(memory_ok('drop-all', ''), 404, 'unknown memory subcommand')
	expect_sub_error(skills_ok('rm', ''), 404, 'unknown skills subcommand')
	expect_sub_error(plugin_ok('list', ''), 404, 'unknown plugin subcommand')
}

fn test_process_scoped_and_interactive_subs_not_exposed() {
	for sub in ['gate-exec', 'gate-issue-receipt', 'gate-check', 'run'] {
		expect_sub_error(loops_ok(sub, ''), 404, 'unknown loops subcommand')
	}
	expect_sub_error(swarms_ok('attach', '{"run_id":"run-123"}'), 404, 'unknown swarms subcommand')
}

// --- malformed bodies ------------------------------------------------------

fn test_malformed_json_is_bad_request() {
	expect_sub_error(memory_ok('search', '{"query":'), 400, 'invalid JSON body')
	expect_sub_error(memory_ok('search', '["search"]'), 400, 'JSON object')
	expect_sub_error(plugin_ok('check', 'not json'), 400, 'JSON object')
	expect_sub_error(dc_ok('status', '{bad'), 400, 'invalid JSON body')
}

// --- containment and validators ----------------------------------------------

fn test_workspace_containment() {
	expect_sub_error(memory_ok('add', '{"workspace":"/tmp/../etc"}'), 400, 'invalid workspace')
	expect_sub_error(memory_ok('add', '{"workspace":"/nonexistent/at-sub-routes"}'), 404, 'workspace not found')
	expect_sub_error(memory_ok('add', '{"workspace":"/etc"}'), 403, 'outside allowed roots')
	expect_sub_error(workspace_ok('init', '{"dir":"/usr"}'), 403, 'outside allowed roots')
}

fn test_workspace_symlink_escape_rejected() {
	$if windows {
		return
	}
	dir := sub_test_dir('symlink')
	defer {
		os.rmdir_all(dir) or {}
	}
	link := os.join_path(dir, 'escape')
	os.symlink('/etc', link) or { panic(err.msg()) }
	expect_sub_error(loops_ok('status', '{"workspace":"${link}"}'), 403, 'outside allowed roots')
}

fn test_path_refs_rejected_when_escaping() {
	expect_sub_error(loops_ok('init', '{"pack":"../../secrets.yaml"}'), 400, 'invalid pack')
	expect_sub_error(loops_ok('init', '{"pack":"/etc/passwd"}'), 403, 'pack outside allowed roots')
	expect_sub_error(workspace_ok('load', '{"arg":"~/.ssh/config"}'), 400, 'invalid arg')
	expect_sub_error(project_ok('add', '{"arg":"/etc"}'), 403, 'arg outside allowed roots')
	expect_sub_error(swarms_ok('artifacts', '{"artifact":"../x"}'), 400, 'invalid artifact')
	// relative refs without traversal are left to core resolution
	opts := build_loops_options('init', '{"pack":"packs/triage.yaml"}') or { panic(err.msg()) }
	assert opts.pack == 'packs/triage.yaml'
}

fn test_name_and_id_validators() {
	expect_sub_error(loops_ok('status', '{"name":"../escape"}'), 400, 'invalid name')
	expect_sub_error(loops_ok('status', '{"name":"--force"}'), 400, 'invalid name')
	expect_sub_error(swarms_ok('status', '{"run_id":"../../etc"}'), 400, 'invalid run_id')
	expect_sub_error(swarms_ok('approve', '{"run_id":"run-1","gate_id":"-x"}'), 400, 'invalid gate_id')
	expect_sub_error(swarms_ok('start', '{"base_ref":"--upload-pack=evil"}'), 400, 'invalid base_ref')
	expect_sub_error(swarms_ok('handoff', '{"commit":"not-a-sha"}'), 400, 'invalid commit')
	expect_sub_error(swarms_ok('task', '{"priority":-1}'), 400, 'invalid priority')
	expect_sub_error(skills_ok('sync', '{"tools":["cursor","../x"]}'), 400, 'invalid tools')
	expect_sub_error(project_ok('clone', '{"arg":"a/b/c"}'), 400, 'invalid arg')
	expect_sub_error(dc_ok('done', '{"job_id":"x;rm"}'), 400, 'invalid job_id')
	expect_sub_error(workspace_ok('history', '{"arg":"-5"}'), 400, 'invalid arg')
	expect_sub_error(memory_ok('add', '{"title":"a\\nb"}'), 400, 'invalid title')
	expect_sub_error(memory_ok('review', '{"stale_after":-3}'), 400, 'invalid stale_after')
}

fn test_cron_and_platform_validated() {
	expect_sub_error(loops_ok('schedule', '{"name":"x","cron":"* * * * *\\nExecStart=/bin/sh"}'), 400, 'invalid cron')
	expect_sub_error(loops_ok('schedule', '{"name":"x","platform":"k8s"}'), 400, 'invalid platform')
}

// --- GET read-only guard is unchanged ------------------------------------------

fn test_get_guard_still_classifies_mutations() {
	// Mutating subs stay POST-only (405 on GET) regardless of the body.
	assert !is_read_subcommand('memory', 'add')
	assert !is_read_subcommand('skills', 'sync')
	assert !is_read_subcommand('mcp', 'setup')
	assert !is_read_subcommand('workspace', 'init')
	assert !is_read_subcommand('project', 'clone')
	assert is_read_subcommand('memory', 'search')
	assert is_read_subcommand('memory', 'list')
	assert is_read_subcommand('memory', 'show')
	assert is_read_subcommand('memory', 'get')
	assert is_read_subcommand('memory', 'inject')
	assert is_read_subcommand('memory', 'todo')
	assert is_read_subcommand('skills', 'list')
	assert is_read_subcommand('mcp', 'health')
}
