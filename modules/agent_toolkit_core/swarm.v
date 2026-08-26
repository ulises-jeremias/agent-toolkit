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
	to_recipe      string
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
	active_roles []string
	worktrees  []SwarmWorktree
}

struct SwarmApprovalsFile {
	gates []SwarmGate
}

// run_swarm implements recipes/backends/doctor/start/list/status/approve/reject/cancel/init/plan/activate/deactivate/promote/pause/resume/stop/cleanup/handoff/task.
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
		'init' {
			swarm_init(ws, opts)
		}
		'plan' {
			swarm_plan(ws, opts)
		}
		'activate' {
			swarm_activate(ws, opts)
		}
		'deactivate' {
			swarm_deactivate(ws, opts)
		}
		'promote' {
			swarm_promote(ws, opts)
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
		'pause' {
			swarm_pause(ws, opts)
		}
		'resume' {
			swarm_resume(ws, opts)
		}
		'stop' {
			swarm_stop(ws, opts)
		}
		'cleanup' {
			swarm_cleanup(ws, opts)
		}
		'handoff' {
			swarm_handoff(ws, opts)
		}
		'task' {
			swarm_task(ws, opts)
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
    agent-toolkit swarm init [--recipe pair|team|full] [--workspace PATH] [--json] [--runner NAME] [--model-profile NAME] [task]
    agent-toolkit swarm plan <run-id> [--workspace PATH]
    agent-toolkit swarm activate <run-id> <role> [--workspace PATH]
    agent-toolkit swarm deactivate <run-id> <role> [--workspace PATH]
    agent-toolkit swarm promote <run-id> [--force] [--base-ref REF] [--workspace PATH]
    agent-toolkit swarm promote <run-id> --to <team|full>
    agent-toolkit swarm pause <run-id>
    agent-toolkit swarm resume <run-id>
    agent-toolkit swarm stop <run-id>
    agent-toolkit swarm cleanup <run-id> [--force] [--dry-run]
    agent-toolkit swarm list
    agent-toolkit swarm status [run-id]
    agent-toolkit swarm approve <run-id> <gate>
    agent-toolkit swarm reject <run-id> <gate> --reason TEXT
    agent-toolkit swarm cancel <run-id>
    agent-toolkit swarm handoff create --type artifact|commit|feedback|decision_request --from ROLE --to ROLE [--priority N] [--artifact PATH] [--commit SHA] [--branch BR] [--blocking] [--run-id ID]
    agent-toolkit swarm task next --role ROLE [--run-id ID] [--json]
    agent-toolkit swarm task complete --handoff HID [--run-id ID]
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
	if override != '' {
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
	if home != '' {
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
	if home != '' {
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
	// OWNER/REPO shorthand hint parity with Python _resolve_owner_repo_from_prompt + find_repo_root
	// When --workspace/-C/--repo is an OWNER/REPO shorthand and not found locally, emit clone hint (fixes #902)
	if opts.workspace_path.len > 0 && is_owner_repo_shorthand(opts.workspace_path) {
		if ws == opts.workspace_path {
			owner_repo := opts.workspace_path
			detected := resolve_owner_repo_from_prompt(opts.task) or { owner_repo }
			hint := if detected == owner_repo {
				'Hint: Run: agent-toolkit project clone ${owner_repo} or specify --workspace <path|OWNER/REPO>'
			} else {
				'Hint: Autodetected ${detected} from prompt. Run: agent-toolkit project clone ${detected} or specify --workspace <path>'
			}
			return SwarmReport{
				ok:      false
				message: 'Not a git repository: ${ws}\n${hint}'
				data:    {
					'subcommand': 'start'
					'workspace':  ws
				}
			}
		}
	}
	if is_owner_repo_shorthand(ws) && !os.is_dir(ws) {
		owner_repo := ws
		mut hint := 'Hint: Run: agent-toolkit project clone ${owner_repo} or specify --workspace <path|OWNER/REPO>'
		if detected := resolve_owner_repo_from_prompt(opts.task) {
			hint = 'Hint: Autodetected ${detected} from prompt. Run: agent-toolkit project clone ${detected} or specify --workspace <path>'
		}
		return SwarmReport{
			ok:      false
			message: 'Not a git repository: ${ws}\n${hint}'
			data:    {
				'subcommand': 'start'
				'workspace':  ws
			}
		}
	}
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
	// Lazy worktree per writer — port fbb2280 cli.py:688-750 initial_roles + create_worktree.
	// Determine initial roles: planner > implementer > first role.
	roles_all := swarm_recipe_roles(recipe)
	mut initial_roles := []string{}
	if 'planner' in roles_all {
		initial_roles = ['planner']
	} else if 'implementer' in roles_all {
		initial_roles = ['implementer']
	} else if roles_all.len > 0 {
		initial_roles = [roles_all[0]]
	}
	lazy := swarm_recipe_lazy_start(recipe)
	repo_root := find_git_root(ws) or { ws }
	base_ref := if opts.base_ref != '' { opts.base_ref } else { 'HEAD' }
	mut created_wts := []SwarmWorktree{}
	for role in roles_all {
		if !swarm_role_has_worktree(recipe, role) {
			continue
		}
		if lazy && role !in initial_roles {
			continue
		}
		wt := swarm_create_worktree(repo_root, run_dir, role, rid, base_ref) or {
			append_swarm_trace(run_dir, 'worktree_failed', role + ':' + err.msg())
			continue
		}
		created_wts << wt
		// Copy opencode agent into worktree if a runner agent exists for that role
		// Mirrors cli.py:709 ff: runner/opencode/agents/<role>.md -> wt/.opencode/agents/<role>.md
		agent_src := os.join_path(run_dir, 'runner', 'opencode', 'agents', role + '.md')
		if os.is_file(agent_src) {
			wt_agents := os.join_path(wt.path, '.opencode', 'agents')
			os.mkdir_all(wt_agents) or {}
			agent_content := os.read_file(agent_src) or { '' }
			os.write_file(os.join_path(wt_agents, role + '.md'), agent_content) or {}
			prompt_src := os.join_path(run_dir, 'prompts', role + '.md')
			if os.is_file(prompt_src) {
				prompt_content := os.read_file(prompt_src) or { '' }
				os.write_file(os.join_path(wt.path, '.agent-toolkit-prompt-' + role + '.md'),
					prompt_content) or {}
			}
		}
		append_swarm_trace(run_dir, 'worktree_created', role + ':' + wt.branch + ':' + wt.path)
	}
	mut st := SwarmStateFile{
		version:       1
		run_id:        rid
		recipe:        recipe
		backend:       backend
		runner:        runner
		model_profile: model_profile
		run_state:     initial
		created_at:    time.utc().format_rfc3339()
		task:          opts.task
		active_roles:  []string{}
		worktrees:     created_wts
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
	for role in swarm_recipe_roles(recipe) {
		prompt, manifest := swarm_compose_role_prompt(recipe, role, opts.task, '', swarm_role_skills(recipe,
			role), rid)
		os.write_file(os.join_path(run_dir, 'prompts', role + '.md'), prompt) or {}
		os.write_file(os.join_path(run_dir, 'prompts', role + '.manifest.json'), json.encode(manifest) +
			'\n') or {}
		append_swarm_trace(run_dir, 'prompt_composed', role)
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
	mut wlines := []string{}
	for wt in st.worktrees {
		wlines << '${wt.role}:${wt.branch}@${wt.path}'
	}
	mut wt_detail := gtxt.join(', ')
	if wlines.len > 0 {
		wt_detail += '\nworktrees: ' + wlines.join(', ')
	}
	// Also reflect owned worktrees not in state but on disk
	if st.worktrees.len == 0 {
		wt_root := os.join_path(swarm_run_dir(ws, st.run_id), 'worktrees')
		if os.is_dir(wt_root) {
			entries := os.ls(wt_root) or { []string{} }
			if entries.len > 0 {
				wt_detail += if wt_detail.len > 0 { '; ' } else { '' } + 'worktrees(dir): ' + entries.join(', ')
			}
		}
	}
	mut msg := 'run ${st.run_id} recipe=${st.recipe} backend=${st.backend} state=${st.run_state}\ngates: ${gtxt.join(', ')}'
	if wlines.len > 0 {
		msg += '\nworktrees: ' + wlines.join(', ')
	}
	mut wt_data := wlines.join(',')
	if wt_data.len == 0 && st.worktrees.len == 0 {
		wt_root2 := os.join_path(swarm_run_dir(ws, st.run_id), 'worktrees')
		if os.is_dir(wt_root2) {
			el := os.ls(wt_root2) or { []string{} }
			if el.len > 0 {
				wt_data = el.join(',')
			}
		}
	}
	return SwarmReport{
		ok:      true
		message: msg
		data:    {
			'subcommand': 'status'
			'run_id':     st.run_id
			'recipe':     st.recipe
			'backend':    st.backend
			'run_state':  st.run_state
			'gates':      gtxt.join(',')
			'worktrees':  wt_data
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


fn swarm_pause(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm pause <run-id>'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	if !swarm_can_transition(st.run_state, 'paused') {
		return SwarmReport{
			ok:      false
			message: "Invalid transition '${st.run_state}' -> 'paused'"
		}
	}
	next := SwarmStateFile{
		...st
		run_state: 'paused'
	}
	write_swarm_state(rd, next) or {
		return SwarmReport{
			ok:      false
			message: 'write state failed: ${err}'
		}
	}
	append_swarm_trace(rd, 'run_state_changed', 'paused')
	return SwarmReport{
		ok:      true
		message: 'Paused ${opts.run_id}: ${st.run_state} -> paused'
		data:    {
			'subcommand': 'pause'
			'run_id':     opts.run_id
			'run_state':  'paused'
		}
	}
}

fn swarm_resume(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm resume <run-id>'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	if st.run_state !in ['paused', 'budget_exhausted', 'failed'] {
		if !swarm_can_transition(st.run_state, 'running') {
			return SwarmReport{
				ok:      false
				message: "Cannot resume from state '${st.run_state}' (expected paused|budget_exhausted|failed)"
			}
		}
	}
	if !swarm_can_transition(st.run_state, 'running') {
		if st.run_state !in ['paused', 'budget_exhausted', 'failed'] {
			return SwarmReport{
				ok:      false
				message: "Invalid transition '${st.run_state}' -> 'running'"
			}
		}
	}
	next := SwarmStateFile{
		...st
		run_state: 'running'
	}
	write_swarm_state(rd, next) or {
		return SwarmReport{
			ok:      false
			message: 'write state failed: ${err}'
		}
	}
	append_swarm_trace(rd, 'run_state_changed', 'running')
	append_swarm_trace(rd, 'role_state_changed', 'resume')
	return SwarmReport{
		ok:      true
		message: 'Resumed ${opts.run_id}: ${st.run_state} -> running'
		data:    {
			'subcommand': 'resume'
			'run_id':     opts.run_id
			'run_state':  'running'
		}
	}
}

fn swarm_stop(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm stop <run-id>'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	if st.run_state != 'paused' {
		if !swarm_can_transition(st.run_state, 'paused') {
			if st.run_state !in ['running', 'awaiting_human', 'awaiting_plan_approval'] {
				return SwarmReport{
					ok:      false
					message: "Cannot stop from state '${st.run_state}'"
				}
			}
		}
		next := SwarmStateFile{
			...st
			run_state: 'paused'
		}
		write_swarm_state(rd, next) or {
			return SwarmReport{
				ok:      false
				message: 'write state failed: ${err}'
			}
		}
	}
	swarm_stop_backend_agents(st.backend, opts.run_id, st.recipe)
	append_swarm_trace(rd, 'role_stopped', opts.run_id)
	return SwarmReport{
		ok:      true
		message: 'Run ${opts.run_id} stopped (state preserved). Resume with: agent-toolkit swarm resume ${opts.run_id}'
		data:    {
			'subcommand': 'stop'
			'run_id':     opts.run_id
			'run_state':  'paused'
		}
	}
}

fn swarm_cleanup(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm cleanup <run-id> [--force] [--dry-run]'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	if !os.is_dir(rd) {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	st_opt := read_swarm_state(rd)
	backend := if st_opt != none { st_opt.backend } else { 'auto' }
	wt_root := os.join_path(rd, 'worktrees')
	mut disk_wts := []string{}
	if os.is_dir(wt_root) {
		entries := os.ls(wt_root) or { []string{} }
		for e in entries {
			p := os.join_path(wt_root, e)
			if os.is_dir(p) {
				disk_wts << p
			}
		}
	}
	if opts.dry_run {
		return SwarmReport{
			ok:      true
			message: 'Would remove ${disk_wts.len} worktrees, keep branches (branches never deleted automatically)'
			data:    {
				'subcommand': 'cleanup'
				'run_id':     opts.run_id
				'mode':       'dry-run'
				'worktrees':  '${disk_wts.len}'
			}
		}
	}
	if !opts.force {
		for wt in disk_wts {
			if swarm_is_worktree_dirty(wt) {
				return SwarmReport{
					ok:      false
					message: 'Worktree contains uncommitted changes. Toolkit will not remove it.\n\nPath:\n  ${wt}\n\nResolve or preserve the changes, then rerun cleanup with --force.'
				}
			}
		}
	}
	for wt in disk_wts {
		if !wt.starts_with(wt_root + os.path_separator) && wt != wt_root {
			continue
		}
		if os.is_dir(wt) {
			if swarm_is_worktree_dirty(wt) && !opts.force {
				return SwarmReport{
					ok:      false
					message: 'Worktree contains uncommitted changes.\nPath: ${wt}'
				}
			}
			// Use existing helper with force flag; HEAD's version returns !bool, handle accordingly
			swarm_remove_worktree(ws, wt, opts.force) or {}
		}
	}
	swarm_teardown_backend(backend, opts.run_id)
	append_swarm_trace(rd, 'cleanup_completed', opts.run_id)
	return SwarmReport{
		ok:      true
		message: 'Cleanup completed for ${opts.run_id} (branches preserved).'
		data:    {
			'subcommand': 'cleanup'
			'run_id':     opts.run_id
		}
	}
}

fn swarm_init(ws string, opts SwarmOptions) SwarmReport {
	recipe := if opts.recipe.len > 0 { opts.recipe } else { 'pair' }
	if swarm_recipe_description(recipe).len == 0 {
		return SwarmReport{
			ok:      false
			message: "Unknown recipe '${recipe}'. Built-ins: pair, team, full"
		}
	}
	runner := resolve_swarm_runner(opts.runner)
	model_profile := if opts.model_profile.len > 0 { opts.model_profile } else { 'balanced' }
	if runner !in swarm_runner_names() {
		return SwarmReport{
			ok:      false
			message: "Unknown runner '${runner}'. Use auto|skeleton|opencode|claude|codex|cursor|copilot|muse"
			data:    {
				'subcommand': 'init'
				'runner':     runner
			}
		}
	}
	if model_profile !in ['economy', 'balanced', 'quality', 'private'] {
		return SwarmReport{
			ok:      false
			message: "Unknown model-profile '${model_profile}'. Use economy|balanced|quality|private"
			data:    {
				'subcommand': 'init'
				'model_profile': model_profile
			}
		}
	}
	rid := swarm_new_run_id()
	if opts.dry_run {
		return SwarmReport{
			ok:      true
			message: '[swarm] dry-run init recipe=${recipe} run_id=${rid}\n  roles: ${swarm_recipe_roles(recipe).join(', ')}\n  no filesystem writes'
			data:    {
				'subcommand': 'init'
				'mode':       'dry-run'
				'recipe':     recipe
				'runner':     runner
				'model_profile': model_profile
				'run_id':     rid
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
	// task-contract.md mirrors Python task-contract scaffold
	task_text := opts.task
	artifacts_dir := os.join_path(run_dir, 'artifacts')
	os.mkdir_all(artifacts_dir) or {}
	tc_path := os.join_path(artifacts_dir, 'task-contract.md')
	os.write_file(tc_path, task_text) or {
		return SwarmReport{
			ok:      false
			message: 'write task-contract failed: ${err}'
		}
	}
	st := SwarmStateFile{
		version:       1
		run_id:        rid
		recipe:        recipe
		backend:       'headless'
		runner:        runner
		model_profile: model_profile
		run_state:     'planning'
		created_at:    time.utc().format_rfc3339()
		task:          task_text
		active_roles:  []string{}
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
	append_swarm_trace(run_dir, 'run_initialized', rid)
	return SwarmReport{
		ok:      true
		message: 'Swarm run initialized: ${rid}\n  ${run_dir}'
		data:    {
			'subcommand': 'init'
			'run_id':     rid
			'recipe':     recipe
			'run_state':  'planning'
			'workspace':  ws
		}
	}
}

fn swarm_plan(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm plan <run-id>'
		}
	}
	if !swarm_valid_run_id(opts.run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${opts.run_id}'"
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	mut st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	// Render artifacts/plan.md from compose_role_prompt equivalent (placeholder).
	recipe := st.recipe
	roles := swarm_recipe_roles(recipe)
	mut lines := []string{}
	lines << '# Plan for ${opts.run_id}'
	lines << ''
	lines << 'Recipe: ${recipe}'
	lines << 'Roles: ${roles.join(', ')}'
	lines << 'Task: ${st.task}'
	lines << ''
	lines << 'Generated: ${time.utc().format_rfc3339()}'
	lines << ''
	for role in roles {
		lines << '## ${role}'
		lines << 'Prompt for ${role} (recipe ${recipe}) — task: ${st.task}'
		lines << ''
	}
	content := lines.join('\n')
	artifacts_dir := os.join_path(rd, 'artifacts')
	os.mkdir_all(artifacts_dir) or {}
	plan_path := os.join_path(artifacts_dir, 'plan.md')
	os.write_file(plan_path, content) or {
		return SwarmReport{
			ok:      false
			message: 'write plan failed: ${err}'
		}
	}
	if st.run_state == 'planning' {
		if swarm_can_transition(st.run_state, 'awaiting_plan_approval') {
			st = SwarmStateFile{
				...st
				run_state: 'awaiting_plan_approval'
			}
			write_swarm_state(rd, st) or {
				return SwarmReport{
					ok:      false
					message: 'write state failed: ${err}'
				}
			}
		}
	}
	append_swarm_trace(rd, 'plan_created', opts.run_id)
	return SwarmReport{
		ok:      true
		message: 'plan created at ${plan_path} state=${st.run_state}'
		data:    {
			'subcommand': 'plan'
			'run_id':     opts.run_id
			'run_state':  st.run_state
			'plan_path':  plan_path
		}
	}
}

fn swarm_activate(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 || opts.role.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm activate <run-id> <role>'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	mut st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	roles := swarm_recipe_roles(st.recipe)
	if opts.role !in roles && opts.role != 'human' {
		// allow any valid role name but warn if not in recipe
		if !handoff_role_valid(opts.role) {
			return SwarmReport{
				ok:      false
				message: 'Invalid role: ${opts.role}'
			}
		}
	}
	if opts.role !in st.active_roles {
		mut new_roles := st.active_roles.clone()
		new_roles << opts.role
		st = SwarmStateFile{
			...st
			active_roles: new_roles
		}
		write_swarm_state(rd, st) or {
			return SwarmReport{
				ok:      false
				message: 'write state failed: ${err}'
			}
		}
	}
	append_swarm_trace(rd, 'agent_activated', opts.role)
	return SwarmReport{
		ok:      true
		message: 'Activated ${opts.role} for ${opts.run_id}'
		data:    {
			'subcommand':   'activate'
			'run_id':       opts.run_id
			'role':         opts.role
			'active_roles': st.active_roles.join(',')
		}
	}
}

fn swarm_deactivate(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 || opts.role.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm deactivate <run-id> <role>'
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	mut st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	mut idx := -1
	for i, r in st.active_roles {
		if r == opts.role {
			idx = i
			break
		}
	}
	if idx >= 0 {
		mut new_roles := []string{}
		for i, r in st.active_roles {
			if i != idx {
				new_roles << r
			}
		}
		st = SwarmStateFile{
			...st
			active_roles: new_roles
		}
		write_swarm_state(rd, st) or {
			return SwarmReport{
				ok:      false
				message: 'write state failed: ${err}'
			}
		}
	}
	append_swarm_trace(rd, 'agent_deactivated', opts.role)
	return SwarmReport{
		ok:      true
		message: 'Deactivated ${opts.role} for ${opts.run_id}'
		data:    {
			'subcommand':   'deactivate'
			'run_id':       opts.run_id
			'role':         opts.role
			'active_roles': st.active_roles.join(',')
		}
	}
}

fn swarm_branch_for_role(run_id string, role string) string {
	return 'agent-toolkit-swarm/${run_id}/${role}'
}

fn swarm_worktree_path(run_dir string, role string) string {
	return os.join_path(run_dir, 'worktrees', role)
}

fn swarm_promote(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm promote <run-id> [--to <team|full>] [--force] [--base-ref REF]'
		}
	}
	// If --to is provided, do recipe promotion (feat/887 lifecycle)
	if opts.to_recipe.len > 0 || opts.recipe.len > 0 {
		mut to := opts.to_recipe
		if to.len == 0 {
			to = opts.recipe
		}
		if to in ['pair', 'team', 'full'] {
			rd := swarm_run_dir(ws, opts.run_id)
			mut st := read_swarm_state(rd) or {
				return SwarmReport{
					ok:      false
					message: 'Run not found: ${opts.run_id}'
				}
			}
			order := {
				'pair': 1
				'team': 2
				'full': 3
			}
			old_recipe := st.recipe
			if order[to] or { 0 } <= order[old_recipe] or { 0 } {
				return SwarmReport{
					ok:      false
					message: 'Cannot promote ${old_recipe} -> ${to} (must increase: pair->team->full)'
				}
			}
			st = SwarmStateFile{
				...st
				recipe: to
			}
			write_swarm_state(rd, st) or {
				return SwarmReport{
					ok:      false
					message: 'write state failed: ${err}'
				}
			}
			mut gates := read_swarm_approvals(rd)
			mut seen := map[string]bool{}
			for g in gates {
				seen[g.id] = true
			}
			for g in swarm_default_gates(to) {
				if g.id !in seen {
					gates << g
					seen[g.id] = true
				}
			}
			write_swarm_approvals(rd, gates) or {
				return SwarmReport{
					ok:      false
					message: 'write approvals failed: ${err}'
				}
			}
			append_swarm_trace(rd, 'recipe_promoted', '${old_recipe}->${to}')
			return SwarmReport{
				ok:      true
				message: 'Promoted ${opts.run_id}: ${old_recipe} -> ${to} (run ID preserved, artifacts intact)'
				data:    {
					'subcommand': 'promote'
					'run_id':     opts.run_id
					'from':       old_recipe
					'to':         to
					'recipe':     to
				}
			}
		}
		// if to_recipe is not a valid recipe name, fall through to integrator promote if --to was not intended
		if opts.to_recipe.len > 0 {
			return SwarmReport{
				ok:      false
				message: "Unknown recipe '${to}'. Built-ins: pair, team, full"
			}
		}
	}
	rd := swarm_run_dir(ws, opts.run_id)
	mut st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	// Python asserts state in running/awaiting_human; allow running, awaiting_human, completed, awaiting_plan_approval for flexibility.
	allowed_src := ['running', 'awaiting_human', 'completed', 'awaiting_plan_approval', 'paused']
	if st.run_state !in allowed_src {
		return SwarmReport{
			ok:      false
			message: 'Cannot promote from state ${st.run_state} (expected running or awaiting_human)'
		}
	}
	integrator_branch := swarm_branch_for_role(opts.run_id, 'integrator')
	worktree_path := swarm_worktree_path(rd, 'integrator')
	if !opts.force && swarm_is_worktree_dirty(worktree_path) {
		return SwarmReport{
			ok:      false
			message: 'Worktree dirty, refusing to promote without --force'
		}
	}
	ps := new_process_service()
	verify := ps.run(RunOptions{
		argv:    ['git', 'rev-parse', '--verify', integrator_branch]
		cwd:     ws
		timeout: 5 * time.second
	}) or {
		return SwarmReport{
			ok:      false
			message: 'Branch not found: ${integrator_branch}'
		}
	}
	if verify.exit_code != 0 {
		return SwarmReport{
			ok:      false
			message: 'Branch not found: ${integrator_branch}'
		}
	}
	base := if opts.base_ref.len > 0 { opts.base_ref } else { 'HEAD' }
	_ = base
	merge_res := ps.run(RunOptions{
		argv:    ['git', 'merge', '--no-ff', integrator_branch]
		cwd:     ws
		timeout: 30 * time.second
	}) or {
		return SwarmReport{
			ok:      false
			message: 'git merge failed: ${err.msg()}'
		}
	}
	if merge_res.exit_code != 0 {
		mut msg := if merge_res.stderr.len > 0 { merge_res.stderr.trim_space() } else { merge_res.stdout.trim_space() }
		if msg.len == 0 {
			msg = 'exit ${merge_res.exit_code}'
		}
		return SwarmReport{
			ok:      false
			message: 'git merge failed: ${msg}'
		}
	}
	next_state := 'cleanup_pending'
	if swarm_can_transition(st.run_state, next_state) || st.run_state in ['running', 'awaiting_human', 'completed'] {
		st = SwarmStateFile{
			...st
			run_state: next_state
		}
		write_swarm_state(rd, st) or {
			return SwarmReport{
				ok:      false
				message: 'write state failed: ${err}'
			}
		}
	} else {
		st = SwarmStateFile{
			...st
			run_state: next_state
		}
		write_swarm_state(rd, st) or {}
	}
	append_swarm_trace(rd, 'promoted', opts.run_id)
	return SwarmReport{
		ok:      true
		message: 'Promoted ${opts.run_id} via ${integrator_branch} -> cleanup_pending'
		data:    {
			'subcommand': 'promote'
			'run_id':     opts.run_id
			'run_state':  next_state
			'branch':     integrator_branch
		}
	}
}


fn swarm_stop_backend_agents(backend string, run_id string, recipe string) {
	ps := new_process_service()
	effective := if backend.len == 0 { 'auto' } else { backend }
	roles := swarm_recipe_roles(recipe)
	if effective in ['tmux', 'auto'] {
		sock := 'agent-toolkit-swarm-${run_id}'
		session := 'swarm-${run_id}'
		for role in roles {
			ps.run(RunOptions{
				argv:    ['tmux', '-L', sock, 'kill-window', '-t', '${session}:${role}']
				timeout: 5 * time.second
			}) or {}
		}
	}
	if effective in ['herdr', 'auto'] {
		for role in roles {
			ps.run(RunOptions{
				argv:    ['herdr', 'agent', 'stop', 'swarm-${run_id}-${role}']
				timeout: 5 * time.second
			}) or {}
		}
	}
}

fn swarm_teardown_backend(backend string, run_id string) {
	ps := new_process_service()
	effective := if backend.len == 0 { 'auto' } else { backend }
	if effective in ['tmux', 'auto', 'herdr'] {
		sock := 'agent-toolkit-swarm-${run_id}'
		session := 'swarm-${run_id}'
		ps.run(RunOptions{
			argv:    ['tmux', '-L', sock, 'kill-session', '-t', session]
			timeout: 5 * time.second
		}) or {}
		ps.run(RunOptions{
			argv:    ['tmux', '-L', sock, 'kill-server']
			timeout: 5 * time.second
		}) or {}
		$if !windows {
			tmpdir := os.getenv('TMPDIR')
			for base in ['/tmp', if tmpdir.len > 0 {
				tmpdir
			} else {
				'/tmp'
			}] {
				uid := os.getuid()
				cand := os.join_path(base, 'tmux-${uid}', sock)
				if os.exists(cand) {
					os.rm(cand) or {}
				}
			}
		}
	}
	if effective in ['herdr', 'auto'] {
		ps.run(RunOptions{
			argv:    ['herdr', 'workspace', 'remove', 'swarm-${run_id}']
			timeout: 5 * time.second
		}) or {}
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
		'handoffs/completed', 'handoffs/failed', 'prompts', 'worktrees', 'runner/opencode/agents'] {
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
