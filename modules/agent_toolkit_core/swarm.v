module agent_toolkit_core

import json
import os
import time

// SwarmOptions configures the swarm command family (#524 REDESIGN).
pub struct SwarmOptions {
pub:
	subcommand     string
	workspace_path string
	run_id         string
	gate_id        string
	recipe         string
	backend        string
	runner         string
	model_profile  string
	task           string
	reason         string
	dry_run        bool
	force          bool
	attach         bool
	no_attach      bool
	request_file   string
	issue_ref      string
	base_ref       string
	json_output    bool
	current        bool
	// handoff / task subcommands (swarm handoff create / swarm task next|complete)
	handoff_sub string
	htype       string
	from_role   string
	to_role     string
	priority    int
	artifact    string
	commit      string
	branch      string
	blocking    bool
	role        string
	handoff_id  string
}

// SwarmReport is the domain result for swarm subcommands.
pub struct SwarmReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

struct SwarmStateFile {
	version       int
	run_id        string
	recipe        string
	backend       string
	runner        string
	model_profile string
	run_state     string
	created_at    string
	task          string
}

struct SwarmApprovalsFile {
	gates []SwarmGate
}

// run_swarm implements recipes/backends/doctor/start/list/status/approve/reject/cancel + observability watch/report/artifacts/handoffs/logs/approvals.
pub fn run_swarm(opts SwarmOptions) SwarmReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return SwarmReport{
			ok:      true
			message: swarm_help_text()
			data:    {
				'subcommand': 'help'
			}
		}
	}
	ws := find_swarm_workspace(opts.workspace_path)
	return match sub {
		'recipes' {
			swarm_recipes(opts)
		}
		'backends' {
			swarm_backends()
		}
		'doctor' {
			swarm_doctor(ws)
		}
		'start' {
			swarm_start(ws, opts)
		}
		'list' {
			swarm_list(ws)
		}
		'status' {
			swarm_status(ws, opts)
		}
		'approve' {
			swarm_approve(ws, opts)
		}
		'reject' {
			swarm_reject(ws, opts)
		}
		'cancel' {
			swarm_cancel(ws, opts)
		}
		'handoff' {
			swarm_handoff(ws, opts)
		}
		'task' {
			swarm_task(ws, opts)
		}
		'watch' {
			swarm_watch(ws, opts)
		}
		'report' {
			swarm_report(ws, opts)
		}
		'artifacts' {
			swarm_artifacts(ws, opts)
		}
		'handoffs' {
			swarm_handoffs(ws, opts)
		}
		'logs' {
			swarm_logs(ws, opts)
		}
		'approvals' {
			swarm_approvals(ws, opts)
		}
		else {
			SwarmReport{
				ok:      false
				message: "Unknown command: ${sub}\nRun 'agent-toolkit swarm help' for usage."
				data:    {
					'subcommand': sub
				}
			}
		}
	}
}

pub fn swarm_result(report SwarmReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = ''
	}
	return CommandResult{
		command: 'swarm'
		ok:      report.ok
		message: report.message
		data:    data
	}
}

pub fn swarm_help_text() string {
	return 'swarm — Multi-agent orchestration (REDESIGN: filesystem SoT, ADR-008/ADR-020).

Usage:
    agent-toolkit swarm recipes [name]
    agent-toolkit swarm backends
    agent-toolkit swarm doctor [--json]
    agent-toolkit swarm start [--recipe pair|team|full] [--backend auto|herdr|tmux|headless] [--request-file PATH] [--issue REF] [--base-ref REF] [--workspace PATH] [-C PATH] [--repo PATH] [--json] [--runner NAME] [--model-profile NAME] [--attach|--no-attach] [--dry-run] [task]
    agent-toolkit swarm list
    agent-toolkit swarm status [run-id]
    agent-toolkit swarm approve <run-id> <gate>
    agent-toolkit swarm reject <run-id> <gate> --reason TEXT
    agent-toolkit swarm cancel <run-id>
    agent-toolkit swarm handoff create --type artifact|commit|feedback|decision_request --from ROLE --to ROLE [--priority N] [--artifact PATH] [--commit SHA] [--branch BR] [--blocking] [--run-id ID]
    agent-toolkit swarm task next --role ROLE [--run-id ID] [--json]
    agent-toolkit swarm task complete --handoff HID [--run-id ID]
    agent-toolkit swarm watch [run-id] [--current] [--workspace PATH]
    agent-toolkit swarm report <run-id> [--json] [--workspace PATH]
    agent-toolkit swarm artifacts <run-id> [--json] [--workspace PATH]
    agent-toolkit swarm handoffs <run-id> [--json] [--workspace PATH]
    agent-toolkit swarm logs <run-id> [role] [--json] [--workspace PATH]
    agent-toolkit swarm approvals <run-id> [--json]
    agent-toolkit swarm help

Runners: opencode (default via $SHELL), claude, codex, cursor, copilot, muse, skeleton. Same capability as: agent-toolkit loop run --runner NAME.
Backends: herdr (recommended, auto-focus worktree), tmux (Unix fallback), headless (filesystem only).
Windows: tmux/herdr unsupported; use --backend headless.
Concurrency: process-per-run supervisor; UI spawn is fail-closed without ProcessService stdin.
State: .agent-toolkit/swarm/runs/<run-id>/ (state.json, approvals.json, trace.jsonl).
Attach: herdr attach by default (focus UI); use --no-attach for CI/script mode.
'
}

fn find_swarm_workspace(override string) string {
	if override.len > 0 {
		if os.is_dir(override) {
			return override
		}
		// OWNER/REPO shorthand: search candidate workspace repos like Python find_repo_root.
		if override.contains('/') && !override.starts_with('/') && !override.starts_with('.') {
			for cand in swarm_candidate_repo_paths(override) {
				if os.is_dir(os.join_path(cand, '.git')) || os.is_file(os.join_path(cand, '.git')) {
					return cand
				}
			}
			// Not found locally; return override as fallback for error hint (matches Python find_repo_root returning ws)
			return override
		}
	}
	if ws := find_workspace_root(override) {
		return ws
	}
	if git := find_git_root('') {
		return git
	}
	return os.getwd()
}

fn swarm_candidate_repo_paths(owner_repo string) []string {
	parts := owner_repo.split('/')
	if parts.len < 2 {
		return []
	}
	owner := parts[0]
	repo := parts[1]
	mut candidates := []string{}
	home := os.home_dir()
	if home.len > 0 {
		candidates << os.join_path(home, '.ai-workspace', 'repos', 'github.com', owner, repo)
		candidates << os.join_path(home, '.ai-workspace', 'repos', owner, repo)
	}
	// Search from CWD upwards for .ai-workspace/repos
	mut cur := os.getwd()
	for _ in 0 .. 10 {
		if os.is_dir(os.join_path(cur, 'repos')) && os.file_name(cur) == '.ai-workspace' {
			candidates << os.join_path(cur, 'repos', 'github.com', owner, repo)
			candidates << os.join_path(cur, 'repos', owner, repo)
			break
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	if home.len > 0 {
		candidates << os.join_path(home, '.ai-workspace', 'repos', 'github.com', owner, repo)
	}
	candidates << os.join_path(os.getwd(), repo)
	return candidates
}

fn swarm_root(ws string) string {
	return os.join_path(ws, '.agent-toolkit', 'swarm')
}

fn swarm_runs_dir(ws string) string {
	return os.join_path(swarm_root(ws), 'runs')
}

fn swarm_run_dir(ws string, run_id string) string {
	return os.join_path(swarm_runs_dir(ws), run_id)
}

fn swarm_recipes(opts SwarmOptions) SwarmReport {
	names := ['full', 'pair', 'team']
	if opts.run_id.len > 0 {
		name := opts.run_id
		desc := swarm_recipe_description(name)
		if desc.len == 0 {
			return SwarmReport{
				ok:      false
				message: "Unknown recipe '${name}'. Built-ins: pair, team, full"
			}
		}
		roles := swarm_recipe_roles(name).join(',')
		return SwarmReport{
			ok:      true
			message: '${name}\t${desc}\nroles: ${roles}'
			data:    {
				'subcommand': 'recipes'
				'recipe':     name
				'roles':      roles
			}
		}
	}
	mut lines := []string{}
	for n in names {
		lines << '${n}\t${swarm_recipe_description(n)}'
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'recipes'
			'recipes':    names.join(',')
		}
	}
}

fn swarm_backends() SwarmReport {
	mut lines := []string{}
	mut avail := []string{}
	for n in ['herdr', 'tmux', 'headless'] {
		d := doctor_backend(n)
		status := if d.available { 'available' } else { 'unavailable' }
		detail := if d.version.len > 0 { d.version } else { d.reason }
		lines << '${n}\t${status}\t${detail}'
		if d.available {
			avail << n
		}
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'backends'
			'available':  avail.join(',')
			'herdr':      doctor_flag(doctor_backend('herdr'))
			'tmux':       doctor_flag(doctor_backend('tmux'))
			'headless':   'true'
		}
	}
}

fn doctor_flag(d BackendDoctor) string {
	return if d.available { 'true' } else { 'false' }
}

fn swarm_doctor(ws string) SwarmReport {
	git_root := find_git_root(ws) or { '' }
	git_ok := git_root.len > 0
	h := doctor_backend('herdr')
	t := doctor_backend('tmux')
	recipes := 'full,pair,team'
	mut lines := []string{}
	lines << 'Swarm doctor'
	lines << '  repo: ${ws}'
	lines << '  git: ${if git_ok { 'ok' } else { 'missing' }}'
	lines << '  herdr: ${if h.available { 'pass' } else { 'warning' }} - ${if h.version.len > 0 {
		h.version
	} else {
		h.reason
	}}'
	lines << '  tmux: ${if t.available { 'pass' } else { 'warning' }} - ${if t.version.len > 0 {
		t.version
	} else {
		t.reason
	}}'
	lines << '  recipes: ${recipes}'
	lines << '  apiVersion: agent-toolkit.dev/v1alpha1'
	return SwarmReport{
		ok:      git_ok
		message: lines.join('\n')
		data:    {
			'subcommand': 'doctor'
			'git':        if git_ok { 'true' } else { 'false' }
			'repo':       ws
			'herdr':      doctor_flag(h)
			'tmux':       doctor_flag(t)
			'recipes':    recipes
			'apiVersion': 'agent-toolkit.dev/v1alpha1'
		}
	}
}

fn swarm_start(ws string, opts SwarmOptions) SwarmReport {
	recipe := if opts.recipe.len > 0 { opts.recipe } else { 'pair' }
	if swarm_recipe_description(recipe).len == 0 {
		return SwarmReport{
			ok:      false
			message: "Unknown recipe '${recipe}'. Built-ins: pair, team, full"
		}
	}
	requested := if opts.backend.len > 0 { opts.backend } else { 'auto' }
	if requested !in swarm_backend_names() {
		return SwarmReport{
			ok:      false
			message: "Unknown backend '${requested}'. Use auto|herdr|tmux|headless"
		}
	}
	backend := resolve_swarm_backend(requested)
	doc := doctor_backend(backend)
	if requested in ['herdr', 'tmux'] && !doc.available {
		return SwarmReport{
			ok:      false
			message: '${requested} was requested but is unavailable: ${doc.reason}'
			data:    {
				'subcommand': 'start'
				'backend':    requested
			}
		}
	}
	runner := resolve_swarm_runner(opts.runner)
	model_profile := if opts.model_profile.len > 0 { opts.model_profile } else { 'balanced' }
	if runner !in swarm_runner_names() {
		return SwarmReport{
			ok:      false
			message: "Unknown runner '${runner}'. Use auto|skeleton|opencode|claude|codex|cursor|copilot|muse (same as: agent-toolkit loop run --runner NAME)"
			data:    {
				'subcommand': 'start'
				'runner':     runner
			}
		}
	}
	if model_profile !in ['economy', 'balanced', 'quality', 'private'] {
		return SwarmReport{
			ok:      false
			message: "Unknown model-profile '${model_profile}'. Use economy|balanced|quality|private (see docs/SWARM_MODELS_AND_COSTS.md)"
			data:    {
				'subcommand': 'start'
				'model_profile': model_profile
			}
		}
	}
	rid := swarm_new_run_id()
	if opts.dry_run {
		return SwarmReport{
			ok:      true
			message: '[swarm] dry-run start recipe=${recipe} backend=${backend} runner=${runner} model_profile=${model_profile} run_id=${rid}\n  roles: ${swarm_recipe_roles(recipe).join(', ')}\n  no filesystem writes; UI spawn skipped (ADR-020 fail-closed)'
			data:    {
				'subcommand': 'start'
				'mode':       'dry-run'
				'recipe':     recipe
				'backend':       backend
				'runner':        runner
				'model_profile': model_profile
				'run_id':        rid
			}
		}
	}
	run_dir := swarm_run_dir(ws, rid)
	ensure_swarm_run_dirs(run_dir) or {
		return SwarmReport{
			ok:      false
			message: 'mkdir run failed: ${err}'
		}
	}
	initial := if swarm_require_plan_approval(recipe) {
		'awaiting_plan_approval'
	} else {
		'running'
	}
	st := SwarmStateFile{
		version:       1
		run_id:        rid
		recipe:        recipe
		backend:       backend
		runner:        runner
		model_profile: model_profile
		run_state:     initial
		created_at:    time.utc().format_rfc3339()
		task:          opts.task
	}
	write_swarm_state(run_dir, st) or {
		return SwarmReport{
			ok:      false
			message: 'write state failed: ${err}'
		}
	}
	write_swarm_approvals(run_dir, swarm_default_gates(recipe)) or {
		return SwarmReport{
			ok:      false
			message: 'write approvals failed: ${err}'
		}
	}
	append_swarm_trace(run_dir, 'run_created', rid)
	// Herdr UI spawn (ADR-008: UI is adapter, not engine). Only when --attach and not dry-run.
	mut herdr_note := ''
	if opts.attach && !opts.no_attach && backend == 'herdr' {
		spawn_res := spawn_herdr_workspace(ws, rid, opts.task, recipe, runner, model_profile)
		if spawn_res.ok {
			herdr_note = '\n  Herdr: ' + spawn_res.message
		} else {
			herdr_note = '\n  Herdr spawn warning: ' + spawn_res.message + ' (filesystem state intact; retry: herdr workspace create --cwd ' + ws + ' --label swarm-' + rid + ')'
		}
		append_swarm_trace(run_dir, if spawn_res.ok { 'herdr_workspace_created' } else { 'herdr_workspace_failed' }, spawn_res.message)
	} else if backend == 'herdr' && opts.no_attach {
		herdr_note = '\n  Herdr: --no-attach (CI mode); workspace not created. Create manually: herdr workspace create --cwd ' + ws + ' --label swarm-' + rid
	}
	return SwarmReport{
		ok:      true
		message: '[swarm] started ${rid} recipe=${recipe} backend=${backend} runner=${runner} model_profile=${model_profile} state=${initial}\n  ${run_dir}' + herdr_note + '\n  UI spawn fail-closed (ADR-020); filesystem state is authoritative (ADR-008).'
		data:    {
			'subcommand':    'start'
			'run_id':        rid
			'recipe':        recipe
			'backend':       backend
			'runner':        runner
			'model_profile': model_profile
			'run_state':     initial
			'workspace':  ws
		}
	}
}

fn herdr_workspace_id(stdout string) string {
	if !stdout.contains('workspace_id') { return '' }
	marker := '"workspace_id":"'
	if stdout.contains(marker) {
		after := stdout.all_after(marker)
		end := after.index('"') or { return '' }
		return after[..end]
	}
	// fallback: workspace_id without quotes around value (just in case)
	after := stdout.all_after('workspace_id')
	start := after.index('"') or { return '' }
	rest := after[start+1..]
	if rest.starts_with(':') || rest.starts_with('":"') {
		// handle ":" pattern
		q := rest.index('"') or { return '' }
		rest2 := rest[q+1..]
		end2 := rest2.index('"') or { return '' }
		return rest2[..end2]
	}
	end := rest.index('"') or { return '' }
	return rest[..end]
}

fn herdr_pane_id(stdout string) string {
	marker := '"pane_id":"'
	if stdout.contains(marker) {
		after := stdout.all_after(marker)
		end := after.index('"') or { return '' }
		return after[..end]
	}
	if !stdout.contains('pane_id') { return '' }
	after := stdout.all_after('pane_id')
	start := after.index('"') or { return '' }
	rest := after[start+1..]
	end := rest.index('"') or { return '' }
	if rest.len > 0 && rest[0] == `:` {
		q := rest.index('"') or { return '' }
		rest2 := rest[q+1..]
		end2 := rest2.index('"') or { return '' }
		return rest2[..end2]
	}
	return rest[..end]
}

fn herdr_root_pane_id(stdout string) string {
	if stdout.contains('"root_pane"') {
		after := stdout.all_after('"root_pane"')
		pid := herdr_pane_id(after)
		if pid.len > 0 {
			return pid
		}
	}
	return herdr_pane_id(stdout)
}

fn user_shell() string {
	for cand in [os.getenv('SHELL'), os.getenv('SWARM_SHELL')] {
		if cand.len > 0 && os.is_file(cand) {
			return cand
		}
	}
	for cand in ['/usr/bin/zsh', '/bin/zsh', '/usr/bin/bash', '/bin/bash', '/bin/sh'] {
		if os.is_file(cand) {
			return cand
		}
	}
	return '/bin/sh'
}

fn shell_base_for_user() string {
	sh := user_shell()
	idx := sh.last_index('/') or { return sh }
	if idx < 0 || idx + 1 >= sh.len {
		return sh
	}
	return sh[idx + 1..]
}

fn spawn_herdr_workspace(ws string, run_id string, task string, recipe string, runner string, model_profile string) SwarmReport {
	ps := new_process_service()
	label := 'swarm-' + run_id
	res := ps.run(RunOptions{
		argv: ['herdr', 'workspace', 'create', '--cwd', ws, '--label', label, '--no-focus']
	}) or {
		return SwarmReport{ ok: false, message: err.msg(), data: { 'backend': 'herdr' } }
	}
	if res.exit_code != 0 {
		mut msg := if res.stderr.len > 0 { res.stderr.trim_space() } else { res.stdout.trim_space() }
		if msg.len == 0 { msg = 'exit ' + res.exit_code.str() }
		return SwarmReport{ ok: false, message: msg, data: { 'backend': 'herdr' } }
	}
	if !res.stdout.contains('workspace_created') && !res.stdout.contains('workspace_id') {
		return SwarmReport{ ok: true, message: 'workspace swarm-' + run_id + ' (herdr output: ' + res.stdout.trim_space().all_before('\n') + ')', data: { 'backend': 'herdr', 'run_id': run_id } }
	}
	ws_id := herdr_workspace_id(res.stdout)
	root_pane := herdr_root_pane_id(res.stdout)
	if ws_id.len == 0 {
		return SwarmReport{ ok: true, message: 'workspace swarm-' + run_id + ' created', data: { 'backend': 'herdr', 'run_id': run_id } }
	}
	roles := swarm_recipe_roles(recipe)
	shell := user_shell()
	// Eager tabs: one per role (N-1 extras) with Waiting for handoff placeholder via pane run
	for i, role in roles {
		if i == 0 { continue } // first role owns root pane
		tab_res := ps.run(RunOptions{
			argv: ['herdr', 'tab', 'create', '--workspace', ws_id, '--cwd', ws, '--label', role, '--no-focus']
		}) or { continue }
		if tab_res.exit_code == 0 && tab_res.stdout.contains('tab_id') {
			mut pred := swarm_role_predecessor(recipe, role)
			if pred.len == 0 && i > 0 {
				pred = roles[i - 1]
			}
			if pred.len == 0 {
				pred = 'previous role'
			}
			waiting := 'Waiting for handoff: ' + pred + ' -> ' + role + ' | role: ' + role + ' | run: ' + run_id
			tip := 'Will auto-start ' + role + ' when ' + pred + ' creates artifact handoff'
			hint := 'Tip: agent-toolkit swarm handoffs ' + run_id
			script := 'echo ' + shell_quote(waiting) + ' && echo ' + shell_quote(tip) + ' && echo ' + shell_quote(hint) + ' && exec ' + shell_base()
			tab_json := tab_res.stdout
			pane_id := herdr_pane_id(tab_json)
			if pane_id.len > 0 {
				msg := shell + ' -lc ' + shell_quote(script)
				_ := ps.run(RunOptions{ argv: ['herdr', 'pane', 'run', pane_id, msg] }) or { continue }
				run_dir := swarm_run_dir(ws, run_id)
				append_swarm_trace(run_dir, 'agent_waiting', role + ':' + pred)
			}
		}
	}
	// Eager-first agent: launch runner for first role via herdr pane run (Python fbb2280 eager-first replica)
	first_role := if roles.len > 0 { roles[0] } else { '' }
	if first_role.len > 0 && root_pane.len > 0 {
		run_dir := swarm_run_dir(ws, run_id)
		effective_runner := if runner == 'auto' { 'opencode' } else { runner }
		if effective_runner == 'skeleton' {
			skeleton_inner := "echo '[skeleton:" + first_role + "] ready -- no LLM' && exec " + shell_base_for_user()
			skeleton_cmd := shell + ' -lc ' + shell_quote(skeleton_inner)
			res2 := ps.run(RunOptions{ argv: ['herdr', 'pane', 'run', root_pane, skeleton_cmd] }) or {
				append_swarm_trace(run_dir, 'herdr_agent_failed', first_role + ':' + err.msg())
				RunResult{ exit_code: -1, stdout: '', stderr: err.msg() }
			}
			if res2.exit_code == 0 {
				append_swarm_trace(run_dir, 'herdr_agent_started', first_role + '=' + effective_runner + ' pane=' + root_pane)
			} else if res2.stderr.len > 0 || res2.stdout.len > 0 || res2.exit_code != -1 {
				mut m2 := if res2.stderr.len > 0 { res2.stderr.trim_space() } else { res2.stdout.trim_space() }
				if m2.len == 0 { m2 = 'exit ' + res2.exit_code.str() }
				// Only trace failed if we actually ran something (exit -1 is the error case already traced)
				if res2.exit_code != -1 {
					append_swarm_trace(run_dir, 'herdr_agent_failed', first_role + ':' + m2)
				}
			}
		} else {
			runner_cmd := herdr_runner_cmd(effective_runner, first_role, task, ws, '')
			env_prefix := 'export AGENT_TOOLKIT_SWARM_RUN_ID=' + shell_quote(run_id) + ' && export AGENT_TOOLKIT_SWARM_RUN_DIR=' + shell_quote(run_dir) + ' && export AGENT_TOOLKIT_SWARM_REPO=' + shell_quote(ws) + ' && export SWARMFORGE_ROLE=' + shell_quote(first_role) + ' &&'
			full_inner := env_prefix + ' cd ' + shell_quote(ws) + ' && exec ' + runner_cmd
			full_cmd := shell + ' -lc ' + shell_quote(full_inner)
			res2 := ps.run(RunOptions{ argv: ['herdr', 'pane', 'run', root_pane, full_cmd] }) or {
				append_swarm_trace(run_dir, 'herdr_agent_failed', first_role + ':' + err.msg())
				RunResult{ exit_code: -1, stdout: '', stderr: err.msg() }
			}
			if res2.exit_code == 0 {
				append_swarm_trace(run_dir, 'herdr_agent_started', first_role + '=' + effective_runner + ' pane=' + root_pane)
			} else if res2.exit_code != -1 {
				mut m2 := if res2.stderr.len > 0 { res2.stderr.trim_space() } else { res2.stdout.trim_space() }
				if m2.len == 0 { m2 = 'exit ' + res2.exit_code.str() }
				append_swarm_trace(run_dir, 'herdr_agent_failed', first_role + ':' + m2)
			}
		}
	}
	// Attach: focus the swarm workspace so user sees it in Herdr
	focus_res := ps.run(RunOptions{ argv: ['herdr', 'workspace', 'focus', ws_id] }) or {
		return SwarmReport{ ok: true, message: 'workspace swarm-' + run_id + ' (' + ws_id + ') created; focus warning: ' + err.msg(), data: { 'backend': 'herdr', 'run_id': run_id, 'workspace_id': ws_id } }
	}
	if focus_res.exit_code != 0 {
		return SwarmReport{ ok: true, message: 'workspace swarm-' + run_id + ' (' + ws_id + ') created; focus warning: ' + focus_res.stderr.trim_space(), data: { 'backend': 'herdr', 'run_id': run_id, 'workspace_id': ws_id } }
	}
	if first_role.len > 0 && root_pane.len > 0 {
		eff := if runner == 'auto' { 'opencode' } else { runner }
		return SwarmReport{ ok: true, message: 'workspace swarm-' + run_id + ' (' + ws_id + ') — ' + roles.len.str() + ' tabs, agent ' + first_role + '=' + eff + ' (' + root_pane + '), shell=' + shell + ', focused', data: { 'backend': 'herdr', 'run_id': run_id, 'workspace_id': ws_id } }
	}
	return SwarmReport{ ok: true, message: 'workspace swarm-' + run_id + ' (' + ws_id + ') — ' + roles.len.str() + ' tabs, shell=' + shell + ', focused', data: { 'backend': 'herdr', 'run_id': run_id, 'workspace_id': ws_id } }
}

fn swarm_list(ws string) SwarmReport {
	dir := swarm_runs_dir(ws)
	if !os.is_dir(dir) {
		return SwarmReport{
			ok:      true
			message: 'No swarm runs found.'
			data:    {
				'subcommand': 'list'
				'count':      '0'
			}
		}
	}
	mut names := os.ls(dir) or { []string{} }
	names.sort()
	mut lines := []string{}
	mut count := 0
	for n in names {
		rd := os.join_path(dir, n)
		st := read_swarm_state(rd) or { continue }
		lines << '${st.run_id}\t${st.recipe}\t${st.run_state}\t${st.created_at}'
		count++
	}
	if lines.len == 0 {
		return SwarmReport{
			ok:      true
			message: 'No swarm runs found.'
			data:    {
				'subcommand': 'list'
				'count':      '0'
			}
		}
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'list'
			'count':      '${count}'
		}
	}
}

fn swarm_status(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return swarm_list(ws)
	}
	if !swarm_valid_run_id(opts.run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${opts.run_id}'"
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	gates := read_swarm_approvals(rd)
	mut gtxt := []string{}
	for g in gates {
		mark := if g.approved {
			'approved'
		} else if g.rejected {
			'rejected'
		} else {
			'pending'
		}
		gtxt << '${g.id}:${mark}'
	}
	return SwarmReport{
		ok:      true
		message: 'run ${st.run_id} recipe=${st.recipe} backend=${st.backend} state=${st.run_state}\ngates: ${gtxt.join(', ')}'
		data:    {
			'subcommand': 'status'
			'run_id':     st.run_id
			'recipe':     st.recipe
			'backend':    st.backend
			'run_state':  st.run_state
			'gates':      gtxt.join(',')
		}
	}
}

fn swarm_approve(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 || opts.gate_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm approve <run-id> <gate>'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	mut st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	mut gates := read_swarm_approvals(rd)
	mut found := false
	for mut g in gates {
		if g.id == opts.gate_id {
			g.approved = true
			g.rejected = false
			g.reason = ''
			found = true
		}
	}
	if !found {
		return SwarmReport{
			ok:      false
			message: 'Gate not found: ${opts.gate_id}'
		}
	}
	write_swarm_approvals(rd, gates) or {
		return SwarmReport{
			ok:      false
			message: 'write approvals failed: ${err}'
		}
	}
	if opts.gate_id == 'plan' && st.run_state == 'awaiting_plan_approval' {
		if !swarm_can_transition(st.run_state, 'running') {
			return SwarmReport{
				ok:      false
				message: 'illegal transition ${st.run_state} → running'
			}
		}
		st = SwarmStateFile{
			...st
			run_state: 'running'
		}
		write_swarm_state(rd, st) or {
			return SwarmReport{
				ok:      false
				message: 'write state failed: ${err}'
			}
		}
	}
	append_swarm_trace(rd, 'approval_granted', opts.gate_id)
	return SwarmReport{
		ok:      true
		message: 'Approved ${opts.gate_id} for ${opts.run_id}'
		data:    {
			'subcommand': 'approve'
			'run_id':     opts.run_id
			'gate':       opts.gate_id
			'run_state':  st.run_state
		}
	}
}

fn swarm_reject(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 || opts.gate_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm reject <run-id> <gate> --reason TEXT'
		}
	}
	if opts.reason.len == 0 {
		return SwarmReport{
			ok:      false
			message: '--reason is required for reject'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	mut gates := read_swarm_approvals(rd)
	mut found := false
	for mut g in gates {
		if g.id == opts.gate_id {
			g.approved = false
			g.rejected = true
			g.reason = opts.reason
			found = true
		}
	}
	if !found {
		return SwarmReport{
			ok:      false
			message: 'Gate not found: ${opts.gate_id}'
		}
	}
	write_swarm_approvals(rd, gates) or {
		return SwarmReport{
			ok:      false
			message: 'write approvals failed: ${err}'
		}
	}
	append_swarm_trace(rd, 'approval_rejected', opts.gate_id)
	return SwarmReport{
		ok:      true
		message: 'Rejected ${opts.gate_id} for ${opts.run_id}: ${opts.reason}'
		data:    {
			'subcommand': 'reject'
			'run_id':     opts.run_id
			'gate':       opts.gate_id
		}
	}
}

fn swarm_cancel(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm cancel <run-id>'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	if !swarm_can_transition(st.run_state, 'cancelled') {
		return SwarmReport{
			ok:      false
			message: 'Cannot cancel from state ${st.run_state}'
		}
	}
	next := SwarmStateFile{
		...st
		run_state: 'cancelled'
	}
	write_swarm_state(rd, next) or {
		return SwarmReport{
			ok:      false
			message: 'write state failed: ${err}'
		}
	}
	append_swarm_trace(rd, 'run_cancelled', opts.run_id)
	return SwarmReport{
		ok:      true
		message: 'Cancelled ${opts.run_id}'
		data:    {
			'subcommand': 'cancel'
			'run_id':     opts.run_id
			'run_state':  'cancelled'
		}
	}
}

struct SwarmReportPayload {
	run_id             string   @[json: 'run_id']
	recipe             string   @[json: 'recipe']
	run_state          string   @[json: 'run_state']
	roles              []string @[json: 'roles']
	artifacts          []string @[json: 'artifacts']
	handoffs_completed int      @[json: 'handoffs_completed']
}

struct SwarmArtifactInfo {
	name string @[json: 'name']
	path string @[json: 'path']
	size int    @[json: 'size']
}

fn swarm_watch(ws string, opts SwarmOptions) SwarmReport {
	mut run_id := opts.run_id
	if opts.current {
		resolved := swarm_resolve_run_id(ws, '') or {
			return SwarmReport{
				ok:      false
				message: 'No runs'
				data:    {
					'subcommand': 'watch'
				}
			}
		}
		run_id = resolved
	}
	if run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'No run_id\nUsage: agent-toolkit swarm watch RUN_ID'
			data:    {
				'subcommand': 'watch'
			}
		}
	}
	if !swarm_valid_run_id(run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${run_id}'"
			data:    {
				'subcommand': 'watch'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'watch'
			}
		}
	}
	gates := read_swarm_approvals(rd)
	mut gtxt := []string{}
	for g in gates {
		mark := if g.approved {
			'approved'
		} else if g.rejected {
			'rejected'
		} else {
			'pending'
		}
		gtxt << '${g.id}:${mark}'
	}
	trace_path := os.join_path(rd, 'trace.jsonl')
	trace_content := os.read_file(trace_path) or { '' }
	if opts.json_output {
		mut payload := map[string]string{}
		payload['run_id'] = st.run_id
		payload['recipe'] = st.recipe
		payload['backend'] = st.backend
		payload['run_state'] = st.run_state
		payload['gates'] = gtxt.join(',')
		payload['trace'] = trace_content
		msg := json.encode(payload)
		return SwarmReport{
			ok:      true
			message: msg
			data:    {
				'subcommand': 'watch'
				'run_id':     run_id
				'json':       msg
			}
		}
	}
	mut msg := 'run ${st.run_id} recipe=${st.recipe} backend=${st.backend} state=${st.run_state}\n'
	if gtxt.len > 0 {
		msg += 'gates: ${gtxt.join(', ')}\n'
	}
	for s in handoff_states() {
		cnt := list_handoffs(rd, s).len
		msg += '${s}: ${cnt}\n'
	}
	if trace_content.len > 0 {
		msg += '--- trace.jsonl ---\n' + trace_content
	} else {
		msg += 'No trace.jsonl'
	}
	return SwarmReport{
		ok:      true
		message: msg
		data:    {
			'subcommand': 'watch'
			'run_id':     run_id
		}
	}
}

fn swarm_report(ws string, opts SwarmOptions) SwarmReport {
	run_id := opts.run_id
	if run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'RUN_ID required\nUsage: agent-toolkit swarm report RUN_ID'
			data:    {
				'subcommand': 'report'
			}
		}
	}
	if !swarm_valid_run_id(run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${run_id}'"
			data:    {
				'subcommand': 'report'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	if !os.is_dir(rd) {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'report'
			}
		}
	}
	st := read_swarm_state(rd) or { SwarmStateFile{} }
	art_dir := os.join_path(rd, 'artifacts')
	mut artifacts := []string{}
	if os.is_dir(art_dir) {
		entries := os.ls(art_dir) or { []string{} }
		for e in entries {
			p := os.join_path(art_dir, e)
			if os.is_file(p) {
				artifacts << e
			}
		}
		artifacts.sort()
	}
	handoffs_done := list_handoffs(rd, 'completed')
	roles := if st.recipe.len > 0 { swarm_recipe_roles(st.recipe) } else { []string{} }
	if opts.json_output {
		payload := SwarmReportPayload{
			run_id:             run_id
			recipe:             st.recipe
			run_state:          st.run_state
			roles:              roles
			artifacts:          artifacts
			handoffs_completed: handoffs_done.len
		}
		msg := json.encode(payload)
		return SwarmReport{
			ok:      true
			message: msg
			data:    {
				'subcommand': 'report'
				'run_id':     run_id
				'json':       msg
			}
		}
	}
	final := os.join_path(art_dir, 'final-report.md')
	if os.is_file(final) {
		text := os.read_file(final) or { '' }
		return SwarmReport{
			ok:      true
			message: text
			data:    {
				'subcommand': 'report'
				'run_id':     run_id
			}
		}
	}
	mut msg := 'Report for ${run_id}\n'
	msg += '  recipe: ${st.recipe}\n'
	msg += '  state: ${st.run_state}\n'
	art_str := if artifacts.len > 0 { artifacts.join(', ') } else { 'none' }
	msg += '  artifacts: ${art_str}\n'
	msg += '  handoffs completed: ${handoffs_done.len}\n'
	msg += '\nNo final-report.md yet. Run is not completed.'
	return SwarmReport{
		ok:      true
		message: msg
		data:    {
			'subcommand': 'report'
			'run_id':     run_id
		}
	}
}

fn swarm_artifacts(ws string, opts SwarmOptions) SwarmReport {
	run_id := opts.run_id
	if run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'RUN_ID required\nUsage: agent-toolkit swarm artifacts RUN_ID'
			data:    {
				'subcommand': 'artifacts'
			}
		}
	}
	if !swarm_valid_run_id(run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${run_id}'"
			data:    {
				'subcommand': 'artifacts'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	if !os.is_dir(rd) {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'artifacts'
			}
		}
	}
	art_dir := os.join_path(rd, 'artifacts')
	mut items := []SwarmArtifactInfo{}
	if os.is_dir(art_dir) {
		entries := os.ls(art_dir) or { []string{} }
		mut sorted := entries.clone()
		sorted.sort()
		for e in sorted {
			p := os.join_path(art_dir, e)
			if os.is_file(p) {
				sz := int(os.file_size(p))
				rel := 'artifacts/${e}'
				items << SwarmArtifactInfo{
					name: e
					path: rel
					size: sz
				}
			}
		}
	}
	if opts.json_output {
		msg := json.encode(items)
		return SwarmReport{
			ok:      true
			message: msg
			data:    {
				'subcommand': 'artifacts'
				'run_id':     run_id
				'json':       msg
			}
		}
	}
	if items.len == 0 {
		return SwarmReport{
			ok:      true
			message: 'No artifacts yet.'
			data:    {
				'subcommand': 'artifacts'
				'run_id':     run_id
			}
		}
	}
	mut lines := []string{}
	for it in items {
		pad_name := it.name + ' '.repeat(if 30 - it.name.len > 0 { 30 - it.name.len } else { 1 })
		sz_str := it.size.str()
		pad_sz := ' '.repeat(if 6 - sz_str.len > 0 { 6 - sz_str.len } else { 0 }) + sz_str
		lines << '${pad_name} ${pad_sz} bytes  ${it.path}'
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'artifacts'
			'run_id':     run_id
		}
	}
}

fn swarm_handoffs(ws string, opts SwarmOptions) SwarmReport {
	run_id := opts.run_id
	if run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'RUN_ID required\nUsage: agent-toolkit swarm handoffs RUN_ID'
			data:    {
				'subcommand': 'handoffs'
			}
		}
	}
	if !swarm_valid_run_id(run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${run_id}'"
			data:    {
				'subcommand': 'handoffs'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	if !os.is_dir(rd) {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'handoffs'
			}
		}
	}
	mut all_counts := map[string]int{}
	mut all_items := map[string][]HandoffRecord{}
	for st in handoff_states() {
		recs := list_handoffs(rd, st)
		all_counts[st] = recs.len
		all_items[st] = recs
	}
	if opts.json_output {
		// Encode map state -> list
		msg := json.encode(all_items)
		return SwarmReport{
			ok:      true
			message: msg
			data:    {
				'subcommand': 'handoffs'
				'run_id':     run_id
				'json':       msg
			}
		}
	}
	mut lines := []string{}
	for st in handoff_states() {
		items := all_items[st]
		lines << '${st}: ${items.len}'
		for it in items {
			lines << '  ${it.handoff_id} ${it.htype} ${it.from_role}->${it.to_role} prio=${it.priority}'
		}
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'handoffs'
			'run_id':     run_id
		}
	}
}

fn swarm_logs(ws string, opts SwarmOptions) SwarmReport {
	run_id := opts.run_id
	if run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'RUN_ID required\nUsage: agent-toolkit swarm logs RUN_ID [role]'
			data:    {
				'subcommand': 'logs'
			}
		}
	}
	if !swarm_valid_run_id(run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${run_id}'"
			data:    {
				'subcommand': 'logs'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	if !os.is_dir(rd) {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'logs'
			}
		}
	}
	role := opts.role
	if role.len > 0 {
		// Try to locate backend log — for now we check trace as fallback
		trace_path := os.join_path(rd, 'trace.jsonl')
		trace := os.read_file(trace_path) or { '' }
		if opts.json_output {
			mut payload := map[string]string{}
			payload['run_id'] = run_id
			payload['role'] = role
			payload['trace'] = trace
			payload['note'] = 'Logs for ${role} not available: herdr not available (trace fallback)'
			msg := json.encode(payload)
			return SwarmReport{
				ok:      true
				message: msg
				data:    {
					'subcommand': 'logs'
					'run_id':     run_id
					'role':       role
					'json':       msg
				}
			}
		}
		if trace.len > 0 {
			// For headless we still return trace with a header
			return SwarmReport{
				ok:      true
				message: 'Logs for ${role} not available: herdr not available (trace fallback)\n' + trace
				data:    {
					'subcommand': 'logs'
					'run_id':     run_id
					'role':       role
				}
			}
		}
		return SwarmReport{
			ok:      true
			message: 'Logs for ${role} not available: herdr not available'
			data:    {
				'subcommand': 'logs'
				'run_id':     run_id
				'role':       role
			}
		}
	}
	trace_path := os.join_path(rd, 'trace.jsonl')
	trace_content := os.read_file(trace_path) or { '' }
	if opts.json_output {
		mut payload := map[string]string{}
		payload['run_id'] = run_id
		payload['trace'] = trace_content
		msg := json.encode(payload)
		return SwarmReport{
			ok:      true
			message: msg
			data:    {
				'subcommand': 'logs'
				'run_id':     run_id
				'json':       msg
			}
		}
	}
	if trace_content.len > 0 {
		return SwarmReport{
			ok:      true
			message: trace_content
			data:    {
				'subcommand': 'logs'
				'run_id':     run_id
			}
		}
	}
	return SwarmReport{
		ok:      true
		message: 'No trace.jsonl'
		data:    {
			'subcommand': 'logs'
			'run_id':     run_id
		}
	}
}

fn swarm_approvals(ws string, opts SwarmOptions) SwarmReport {
	run_id := opts.run_id
	if run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'RUN_ID required\nUsage: agent-toolkit swarm approvals RUN_ID'
			data:    {
				'subcommand': 'approvals'
			}
		}
	}
	if !swarm_valid_run_id(run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${run_id}'"
			data:    {
				'subcommand': 'approvals'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	if !os.is_dir(rd) {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'approvals'
			}
		}
	}
	gates := read_swarm_approvals(rd)
	if opts.json_output {
		msg := json.encode(gates)
		return SwarmReport{
			ok:      true
			message: msg
			data:    {
				'subcommand': 'approvals'
				'run_id':     run_id
				'json':       msg
			}
		}
	}
	if gates.len == 0 {
		return SwarmReport{
			ok:      true
			message: 'No approval gates.'
			data:    {
				'subcommand': 'approvals'
				'run_id':     run_id
			}
		}
	}
	mut lines := []string{}
	for g in gates {
		status := if g.approved {
			'approved'
		} else if g.rejected {
			'rejected'
		} else {
			'pending'
		}
		pad_id := g.id + ' '.repeat(if 15 - g.id.len > 0 { 15 - g.id.len } else { 1 })
		pad_status := status + ' '.repeat(if 10 - status.len > 0 { 10 - status.len } else { 1 })
		desc := if g.description.len > 80 { g.description[..80] } else { g.description }
		lines << '${pad_id} ${pad_status} ${desc}'
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'approvals'
			'run_id':     run_id
		}
	}
}

fn swarm_handoff(ws string, opts SwarmOptions) SwarmReport {
	sub := opts.handoff_sub
	if sub in ['', 'help', '-h', '--help'] {
		return SwarmReport{
			ok:      true
			message: swarm_handoff_help_text()
			data:    {
				'subcommand': 'handoff'
			}
		}
	}
	if sub != 'create' {
		return SwarmReport{
			ok:      false
			message: "Unknown handoff command: ${sub}\nRun 'agent-toolkit swarm handoff create --help' for usage."
			data:    {
				'subcommand': 'handoff'
			}
		}
	}
	return swarm_handoff_create(ws, opts)
}

fn swarm_handoff_help_text() string {
	return 'swarm handoff create — durable filesystem handoff queue (ADR-008).

Usage:
    agent-toolkit swarm handoff create --type artifact|commit|feedback|decision_request --from ROLE --to ROLE [--priority N] [--artifact PATH] [--commit SHA] [--branch BR] [--blocking] [--run-id ID]

Types:
    artifact        hand off an artifact under <run>/artifacts (1 MB max)
    commit          hand off a git commit (40-hex SHA + branch, validated via git)
    feedback        reviewer feedback; --blocking enforces the round-trip limit (2)
    decision_request request a decision (no commit/artifact required)

State: handoffs/{outbox,queued,active,completed,failed}/<16-hex>.json.
'
}

fn swarm_handoff_create(ws string, opts SwarmOptions) SwarmReport {
	run_id := swarm_resolve_run_id(ws, opts.run_id) or {
		return SwarmReport{
			ok:      false
			message: err.msg()
			data:    {
				'subcommand': 'handoff'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'handoff'
				'run_id':     run_id
			}
		}
	}
	mut roles := swarm_recipe_roles(st.recipe)
	if roles.len == 0 {
		roles = ['implementer', 'reviewer', 'integrator']
	}
	htype := opts.htype
	from_role := opts.from_role
	to_role := opts.to_role

	mut rec := HandoffRecord{
		version:    handoff_version
		htype:      htype
		from_role:  from_role
		to_role:    to_role
		priority:   opts.priority
		artifact:   ''
		commit:     ''
		branch:     ''
		blocking:   false
		handoff_id: ''
		created_at: ''
	}

	if opts.artifact.len > 0 {
		validate_artifact_path(rd, opts.artifact) or {
			return SwarmReport{
				ok:      false
				message: err.msg()
				data:    {
					'subcommand': 'handoff'
				}
			}
		}
		art_path := os.join_path(rd, opts.artifact)
		if os.is_file(art_path) && os.file_size(art_path) > 1_000_000 {
			return SwarmReport{
				ok:      false
				message: 'Artifact too large (${os.file_size(art_path)} bytes), max 1MB'
				data:    {
					'subcommand': 'handoff'
				}
			}
		}
		rec.artifact = opts.artifact
	}
	if htype == 'commit' {
		if opts.commit.len == 0 || opts.branch.len == 0 {
			return SwarmReport{
				ok:      false
				message: 'commit handoff requires --commit and --branch'
				data:    {
					'subcommand': 'handoff'
				}
			}
		}
		mut sha := opts.commit.trim_space().to_lower()
		if !handoff_sha_valid(sha) {
			resolved := resolve_sha(ws, sha) or {
				return SwarmReport{
					ok:      false
					message: 'Invalid or ambiguous commit SHA: ${opts.commit}'
					data:    {
						'subcommand': 'handoff'
					}
				}
			}
			sha = resolved
		}
		if !validate_commit_exists(ws, sha) {
			return SwarmReport{
				ok:      false
				message: 'Commit not found: ${sha}'
				data:    {
					'subcommand': 'handoff'
				}
			}
		}
		rec.commit = sha
		rec.branch = opts.branch
	}
	if htype == 'feedback' {
		rec.blocking = opts.blocking
		if rec.blocking {
			limit := 2
			mut count := 0
			for state in ['queued', 'active', 'completed'] {
				for h in list_handoffs(rd, state) {
					if h.htype == 'feedback' && h.blocking && h.from_role == from_role
						&& h.to_role == to_role {
						count++
					}
				}
			}
			if count >= limit {
				return SwarmReport{
					ok:      false
					message: 'The reviewer returned blocking feedback ${count} times. The configured round-trip limit (${limit}) has been reached.\n\nInspect:\n  agent-toolkit swarm artifacts ${run_id}\n\nChoose:\n  resume with a higher limit\n  escalate to team\n  request human intervention'
					data:    {
						'subcommand': 'handoff'
					}
				}
			}
		}
	}
	errs := validate_handoff(rec, rd, roles)
	if errs.len > 0 {
		return SwarmReport{
			ok:      false
			message: 'Handoff validation failed: ' + errs.join('; ')
			data:    {
				'subcommand': 'handoff'
			}
		}
	}
	write_handoff_outbox(rd, mut rec) or {
		return SwarmReport{
			ok:      false
			message: 'write handoff failed: ${err}'
			data:    {
				'subcommand': 'handoff'
			}
		}
	}
	append_swarm_trace(rd, 'handoff_created', '${htype}:${from_role}->${to_role}:${rec.handoff_id}')
	hid := rec.handoff_id
	move_handoff(rd, hid, 'outbox', 'queued') or {}
	append_swarm_trace(rd, 'handoff_queued', hid)
	// Auto-complete incoming active handoffs for the sender (Python fbb2280 parity).
	for h in list_handoffs(rd, 'active') {
		if h.to_role == from_role && h.handoff_id.len > 0 {
			move_handoff(rd, h.handoff_id, 'active', 'completed') or {}
			append_swarm_trace(rd, 'handoff_completed', '${h.handoff_id}:auto:handoff_create:${hid}')
		}
	}
	return SwarmReport{
		ok:      true
		message: 'Handoff ${hid} created: ${from_role} -> ${to_role} (${htype})'
		data:    {
			'subcommand': 'handoff'
			'handoff_id': hid
			'type':       htype
			'from':       from_role
			'to':         to_role
		}
	}
}

fn swarm_task(ws string, opts SwarmOptions) SwarmReport {
	sub := opts.handoff_sub
	if sub in ['', 'help', '-h', '--help'] {
		return SwarmReport{
			ok:      true
			message: swarm_task_help_text()
			data:    {
				'subcommand': 'task'
			}
		}
	}
	if sub == 'next' {
		return swarm_task_next(ws, opts)
	}
	if sub == 'complete' {
		return swarm_task_complete(ws, opts)
	}
	return SwarmReport{
		ok:      false
		message: "Unknown task command: ${sub}\nUsage: agent-toolkit swarm task <next|complete>"
		data:    {
			'subcommand': 'task'
		}
	}
}

fn swarm_task_help_text() string {
	return 'swarm task — durably claim and complete handoff work.

Usage:
    agent-toolkit swarm task next --role ROLE [--run-id ID] [--json]
    agent-toolkit swarm task complete --handoff HID [--run-id ID]

next       moves the highest-priority queued handoff for ROLE to active (priority sort).
complete   moves an active handoff to completed.
'
}

fn swarm_task_next(ws string, opts SwarmOptions) SwarmReport {
	if opts.role.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm task next --role <role> [--run-id <id>]'
			data:    {
				'subcommand': 'task'
			}
		}
	}
	run_id := swarm_resolve_run_id(ws, opts.run_id) or {
		return SwarmReport{
			ok:      false
			message: err.msg()
			data:    {
				'subcommand': 'task'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'task'
				'run_id':     run_id
			}
		}
	}
	mut candidates := []HandoffRecord{}
	for it in list_handoffs(rd, 'queued') {
		if it.to_role == opts.role {
			candidates << it
		}
	}
	// Sort by priority ascending (00 is highest priority).
	candidates.sort(a.priority < b.priority)
	// Enforce at most one active per task-mode role (receive_mode != batch).
	mut has_active := false
	for it in list_handoffs(rd, 'active') {
		if it.to_role == opts.role {
			has_active = true
			break
		}
	}
	if has_active {
		if swarm_role_receive_mode(st.recipe, opts.role) != 'batch' {
			return SwarmReport{
				ok:      false
				message: 'Role ${opts.role} already has active task (at most one active task per task-mode role)'
				data:    {
					'subcommand': 'task'
					'role':       opts.role
				}
			}
		}
	}
	if candidates.len == 0 {
		return SwarmReport{
			ok:      true
			message: 'No queued tasks'
			data:    {
				'subcommand': 'task'
				'task':      ''
			}
		}
	}
	task := candidates[0]
	hid := task.handoff_id
	if hid.len > 0 {
		move_handoff(rd, hid, 'queued', 'active') or {}
		append_swarm_trace(rd, 'handoff_accepted', '${hid}:${opts.role}')
	}
	return SwarmReport{
		ok:      true
		message: json.encode(task)
		data:    {
			'subcommand': 'task'
			'handoff_id': hid
			'type':       task.htype
			'from':       task.from_role
			'to':         task.to_role
			'artifact':   task.artifact
		}
	}
}

fn swarm_task_complete(ws string, opts SwarmOptions) SwarmReport {
	if opts.handoff_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm task complete --handoff <handoff-id> [--run-id <id>]'
			data:    {
				'subcommand': 'task'
			}
		}
	}
	run_id := swarm_resolve_run_id(ws, opts.run_id) or {
		return SwarmReport{
			ok:      false
			message: err.msg()
			data:    {
				'subcommand': 'task'
			}
		}
	}
	rd := swarm_run_dir(ws, run_id)
	read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${run_id}'
			data:    {
				'subcommand': 'task'
				'run_id':     run_id
			}
		}
	}
	hid := opts.handoff_id
	move_handoff(rd, hid, 'active', 'completed') or {
		return SwarmReport{
			ok:      false
			message: 'Handoff not found or not active: ${hid}'
			data:    {
				'subcommand': 'task'
				'handoff_id': hid
			}
		}
	}
	append_swarm_trace(rd, 'handoff_completed', hid)
	return SwarmReport{
		ok:      true
		message: 'Completed handoff ${hid}'
		data:    {
			'subcommand': 'task'
			'handoff_id': hid
		}
	}
}

// swarm_resolve_run_id resolves --run-id or AGENT_TOOLKIT_SWARM_RUN_ID or the latest run.
fn swarm_resolve_run_id(ws string, given string) !string {
	if given.len > 0 {
		return given
	}
	env := os.getenv('AGENT_TOOLKIT_SWARM_RUN_ID')
	if env.len > 0 {
		return env
	}
	dir := swarm_runs_dir(ws)
	if !os.is_dir(dir) {
		return error('No run found')
	}
	mut names := os.ls(dir) or { return error('No run found') }
	if names.len == 0 {
		return error('No run found')
	}
	names.sort()
	return names.last()
}

// swarm_role_receive_mode reports the role receive_mode from the recipe (default: single).
// Python recipes default to a non-batch receive mode, so at most one active task per role.
fn swarm_role_receive_mode(recipe string, role string) string {
	return ''
}

fn ensure_swarm_run_dirs(run_dir string) ! {
	for sub in ['artifacts', 'handoffs/outbox', 'handoffs/queued', 'handoffs/active',
		'handoffs/completed', 'handoffs/failed', 'prompts', 'worktrees'] {
		os.mkdir_all(os.join_path(run_dir, sub))!
	}
}

fn write_swarm_state(run_dir string, st SwarmStateFile) ! {
	os.write_file(os.join_path(run_dir, 'state.json'), json.encode(st) + '\n')!
}

fn read_swarm_state(run_dir string) ?SwarmStateFile {
	path := os.join_path(run_dir, 'state.json')
	if !os.is_file(path) {
		return none
	}
	text := os.read_file(path) or { return none }
	return json.decode(SwarmStateFile, text) or { none }
}

fn write_swarm_approvals(run_dir string, gates []SwarmGate) ! {
	payload := SwarmApprovalsFile{
		gates: gates
	}
	os.write_file(os.join_path(run_dir, 'approvals.json'), json.encode(payload) + '\n')!
}

fn read_swarm_approvals(run_dir string) []SwarmGate {
	path := os.join_path(run_dir, 'approvals.json')
	if !os.is_file(path) {
		return []
	}
	text := os.read_file(path) or { return [] }
	file := json.decode(SwarmApprovalsFile, text) or { return [] }
	return file.gates
}

fn append_swarm_trace(run_dir string, kind string, detail string) {
	line := '{"ts":${json.encode(time.utc().format_rfc3339())},"kind":${json.encode(kind)},"detail":${json.encode(detail)}}\n'
	path := os.join_path(run_dir, 'trace.jsonl')
	existing := os.read_file(path) or { '' }
	os.write_file(path, existing + line) or {}
}

fn swarm_new_run_id() string {
	rfc := time.utc().format_rfc3339()
	date := rfc[..10].clone().replace('-', '')
	clock := if rfc.len >= 19 { rfc[11..19].clone().replace(':', '') } else { '000000' }
	return 's${date}T${clock}Z'
}
