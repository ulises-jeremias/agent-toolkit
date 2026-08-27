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
	to_recipe      string
}

// SwarmReport is the domain result for swarm subcommands.
pub struct SwarmReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

pub struct RunnerInfo {
pub:
	cap       string
	available bool
	herdr     string
	bin       string
}

struct SwarmStateFile {
pub mut:
	version         int
	run_id          string
	recipe          string
	backend         string
	runner          string
	model_profile   string
	run_state       string
	created_at      string
	task            string
	budget          Budget           @[json: 'budget']
	budget_consumed BudgetConsumed   @[json: 'budget_consumed']
	personas        map[string]string @[json: 'personas']
	policy          map[string]string @[json: 'policy']
	active_roles    []string
	worktrees       []SwarmWorktree
}

struct SwarmApprovalsFile {
	gates []SwarmGate
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

struct SwarmBudgetJson {
pub:
	max_total_tokens int     @[json: 'max_total_tokens']
	total_tokens     int     @[json: 'total_tokens']
	max_cost_usd     f64     @[json: 'max_cost_usd']
	total_cost       f64     @[json: 'total_cost']
	max_wall_seconds int     @[json: 'max_wall_seconds']
	wall_seconds     int     @[json: 'wall_seconds']
}

struct SwarmHandoffsJson {
pub mut:
	outbox    int
	queued    int
	active    int
	completed int
	failed    int
}

struct SwarmApprovalsJson {
pub:
	gates []SwarmGate
}

struct SwarmStatusJson {
pub:
	run_id        string              @[json: 'run_id']
	recipe        string
	backend       string
	runner        string
	model_profile string              @[json: 'model_profile']
	run_state     string              @[json: 'run_state']
	created_at    string              @[json: 'created_at']
	task          string
	worktrees     []string
	approvals     SwarmApprovalsJson
	budget        SwarmBudgetJson
	handoffs      SwarmHandoffsJson
	trace_tail    []string            @[json: 'trace_tail']
	artifacts     []string
}

struct SwarmListEntry {
pub:
	run_id     string @[json: 'run_id']
	recipe     string
	backend    string
	run_state  string @[json: 'run_state']
	created_at string @[json: 'created_at']
	task       string
}

// run_swarm implements recipes/backends/doctor/start/list/status/approve/reject/cancel/init/plan/activate/deactivate/promote/pause/resume/stop/cleanup/handoff/task/runners/models + observability watch/report/artifacts/handoffs/logs/approvals.
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
		'recipes', 'recipe' {
			mut r_opts := opts
			if sub == 'recipe' && r_opts.run_id == 'show' {
				if r_opts.task.len > 0 {
					r_opts = SwarmOptions{
						...r_opts
						run_id: r_opts.task
						task: ''
					}
				} else if r_opts.gate_id.len > 0 {
					r_opts = SwarmOptions{
						...r_opts
						run_id: r_opts.gate_id
						gate_id: ''
					}
				} else {
					r_opts = SwarmOptions{
						...r_opts
						run_id: ''
					}
				}
			}
			swarm_recipes(r_opts)
		}
		'backends' {
			swarm_backends()
		}
		'doctor' {
			swarm_doctor(ws)
		}
		'runners' {
			swarm_runners(opts)
		}
		'models' {
			swarm_models(opts)
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
			swarm_list(ws, opts)
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
		'attach' {
			swarm_attach(ws, opts)
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
	ordered := ['opencode', 'claude', 'codex', 'cursor', 'copilot', 'muse', 'skeleton']
	mut runners_parts := []string{}
	for i, r in ordered {
		if i == 0 {
			runners_parts << '${r} (default via \$SHELL)'
		} else {
			runners_parts << r
		}
	}
	runners_line := runners_parts.join(', ')
	return 'swarm — Multi-agent orchestration (REDESIGN: filesystem SoT, ADR-008/ADR-020).

Usage:
    agent-toolkit swarm recipes [name]
    agent-toolkit swarm backends
    agent-toolkit swarm doctor [--json]
    agent-toolkit swarm runners [--json] [--workspace PATH]
    agent-toolkit swarm models [--json] [--runner NAME] [--profile NAME] [--workspace PATH]
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
    agent-toolkit swarm list [--json] [--workspace PATH] [-C PATH] [--repo PATH]
    agent-toolkit swarm status [run-id] [--json] [--workspace PATH] [-C PATH] [--repo PATH]
    agent-toolkit swarm approve <run-id> <gate>
    agent-toolkit swarm reject <run-id> <gate> --reason TEXT
    agent-toolkit swarm cancel <run-id>
    agent-toolkit swarm handoff create --type artifact|commit|feedback|decision_request --from ROLE --to ROLE [--priority N] [--artifact PATH] [--commit SHA] [--branch BR] [--blocking] [--run-id ID]
    agent-toolkit swarm task next --role ROLE [--run-id ID] [--json]
    agent-toolkit swarm task complete --handoff HID [--run-id ID]
    agent-toolkit swarm attach <run-id> [--workspace PATH] [-C PATH] [--repo PATH]
    agent-toolkit swarm watch [run-id] [--current] [--workspace PATH]
    agent-toolkit swarm report <run-id> [--json] [--workspace PATH]
    agent-toolkit swarm artifacts <run-id> [--json] [--workspace PATH]
    agent-toolkit swarm handoffs <run-id> [--json] [--workspace PATH]
    agent-toolkit swarm logs <run-id> [role] [--json] [--workspace PATH]
    agent-toolkit swarm approvals <run-id> [--json]
    agent-toolkit swarm help

Runners: ${runners_line}. Same capability as: agent-toolkit loop run --runner NAME.
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
		recipe := builtin_recipes[name] or {
			return SwarmReport{
				ok:      false
				message: "Unknown recipe '${name}'. Built-ins: pair, team, full"
			}
		}
		roles := swarm_recipe_roles(name).join(', ')
		if opts.json_output {
			txt := json.encode(recipe)
			return SwarmReport{
				ok:      true
				message: txt
				data:    {
					'subcommand': 'recipes'
					'recipe':     name
					'roles':      roles
					'json':       txt
					'__raw_json': txt
				}
			}
		}
		gates_str := if recipe.gates.len > 0 { recipe.gates.join(', ') } else { 'none' }
		execution_str := 'max_concurrency=${recipe.execution.max_concurrency} lazy_start=${recipe.execution.lazy_start}'
		budget_str := '${recipe.budget.max_total_tokens} tokens / \$${recipe.budget.max_cost_usd:.2f} / ${recipe.budget.max_wall_seconds}s'
		b := recipe_budget(name)
		bj := json.encode(b)
		return SwarmReport{
			ok:      true
			message: '${name}\t${recipe.description}\nroles: ${roles}\nexecution: ${execution_str}\ngates: ${gates_str}\nbudget: ${budget_str}\nbudget_json: ${bj}'
			data:    {
				'subcommand':       'recipes'
				'recipe':           name
				'roles':            roles
				'budget':           bj
				'max_total_tokens': b.max_total_tokens.str()
				'max_cost_usd':     b.max_cost_usd.str()
				'max_wall_seconds': b.max_wall_seconds.str()
				'max_concurrency':  b.max_concurrency.str()
			}
		}
	}
	if opts.json_output {
		txt := json.encode(builtin_recipes)
		return SwarmReport{
			ok:      true
			message: txt
			data:    {
				'subcommand': 'recipes'
				'recipes':    names.join(',')
				'json':       txt
				'__raw_json': txt
			}
		}
	}
	if opts.json_output {
		j := builtin_recipes_json()
		return SwarmReport{
			ok:      true
			message: j
			data:    {
				'subcommand':  'recipes'
				'recipes':     names.join(',')
				'json':        j
				'__raw_json':  j
				'pair_budget': json.encode(recipe_budget('pair'))
				'team_budget': json.encode(recipe_budget('team'))
				'full_budget': json.encode(recipe_budget('full'))
				'budget':      json.encode(recipe_budget('pair'))
			}
		}
	}
	mut lines := []string{}
	for n in names {
		b := recipe_budget(n)
		if r := builtin_recipes[n] {
			lines << '${n}\t${r.description}\tbudget: ${json.encode(b)}'
		} else {
			lines << '${n}\t${swarm_recipe_description(n)}\tbudget: ${json.encode(b)}'
		}
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand':  'recipes'
			'recipes':     names.join(',')
			'pair_budget': json.encode(recipe_budget('pair'))
			'team_budget': json.encode(recipe_budget('team'))
			'full_budget': json.encode(recipe_budget('full'))
			'budget':      json.encode(recipe_budget('pair'))
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

fn swarm_runners(opts SwarmOptions) SwarmReport {
	mut matrix := map[string]RunnerInfo{}
	for r in swarm_runner_names() {
		if r == 'auto' {
			continue
		}
		cap := runner_caps[r] or { 'official' }
		herdr := runner_herdr[r] or {
			if r in ['opencode', 'claude', 'muse', 'skeleton'] { 'official' } else { 'custom' }
		}
		bin := runner_bins[r] or { r }
		matrix[r] = RunnerInfo{
			cap:       cap
			available: runner_available(r)
			herdr:     herdr
			bin:       bin
		}
	}
	if opts.json_output {
		return SwarmReport{
			ok:      true
			message: json.encode(matrix)
			data:    {
				'subcommand': 'runners'
				'count':      '${matrix.len}'
			}
		}
	}
	mut lines := []string{}
	for r, info in matrix {
		avail := if info.available { 'available' } else { 'missing' }
		lines << '${r:12} ${info.cap:10} ${avail:10} herdr:${info.herdr}'
	}
	lines.sort()
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'runners'
			'count':      '${matrix.len}'
		}
	}
}

fn swarm_models(opts SwarmOptions) SwarmReport {
	profiles := swarm_model_profiles()
	if opts.runner.len > 0 && opts.model_profile.len > 0 {
		if opts.model_profile !in profiles {
			return SwarmReport{
				ok:      false
				message: "Unknown model-profile '${opts.model_profile}'. Use economy|balanced|quality|private"
				data:    {
					'subcommand': 'models'
				}
			}
		}
		mp := profiles[opts.model_profile].clone()
		val := mp[opts.runner] or {
			return SwarmReport{
				ok:      false
				message: "Unknown runner '${opts.runner}'. Use ${swarm_runner_names().filter(it != 'auto').join('|')}"
				data:    {
					'subcommand': 'models'
				}
			}
		}
		return SwarmReport{
			ok:      true
			message: val
			data:    {
				'subcommand': 'models'
				'runner':     opts.runner
				'profile':    opts.model_profile
			}
		}
	}
	if opts.runner.len > 0 {
		first := profiles['economy'].clone()
		if opts.runner !in first {
			return SwarmReport{
				ok:      false
				message: "Unknown runner '${opts.runner}'. Use ${swarm_runner_names().filter(it != 'auto').join('|')}"
				data:    {
					'subcommand': 'models'
				}
			}
		}
		mut filtered := map[string]string{}
		for profile, mp in profiles {
			filtered[profile] = mp[opts.runner] or { '' }
		}
		return SwarmReport{
			ok:      true
			message: json.encode(filtered)
			data:    {
				'subcommand': 'models'
				'runner':     opts.runner
			}
		}
	}
	if opts.json_output {
		return SwarmReport{
			ok:      true
			message: json.encode(profiles)
			data:    {
				'subcommand': 'models'
			}
		}
	}
	mut lines := []string{}
	mut header := 'profile   '
	for r in swarm_runner_names() {
		if r in ['auto', 'skeleton'] {
			continue
		}
		header += '${r:12}'
	}
	lines << header
	for profile in ['economy', 'balanced', 'quality', 'private'] {
		mp := profiles[profile].clone()
		mut row := '${profile:10}'
		for r in swarm_runner_names() {
			if r in ['auto', 'skeleton'] {
				continue
			}
			val := mp[r] or { '-' }
			row += '${val:12}'
		}
		lines << row
	}
	return SwarmReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'models'
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
	mut recipe := if opts.recipe.len > 0 { opts.recipe } else { 'pair' }
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
	runner_cli := opts.runner
	model_profile_cli := opts.model_profile
	runner := resolve_swarm_runner(runner_cli)
	model_profile := if model_profile_cli.len > 0 { model_profile_cli } else { 'balanced' }
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
	// Resolve full recipe config (BUILTIN + swarm.yaml + CLI overrides)
	// Pass original CLI values (could be empty) so per-role model_profile not overridden when not provided.
	resolved := resolve_swarm_config(ws, opts.recipe, opts.backend, runner_cli, model_profile_cli) or {
		return SwarmReport{
			ok:      false
			message: err.msg()
		}
	}
	recipe = resolved.metadata.name
	rid := swarm_new_run_id()
	if opts.dry_run {
		mut persona_info := []string{}
		for role, rs in resolved.spec.roles {
			policy := if rs.model_profile.len > 0 { rs.model_profile } else { model_profile }
			persona_info << '${role}:${rs.persona}(${policy})'
		}
		return SwarmReport{
			ok:      true
			message: '[swarm] dry-run start recipe=${recipe} backend=${backend} runner=${runner} model_profile=${model_profile} run_id=${rid}\n  roles: ${swarm_recipe_roles(recipe).join(', ')}\n  personas: ${persona_info.join(', ')}\n  budget: ${json.encode(resolved.budget)}\n  no filesystem writes; UI spawn skipped (ADR-020 fail-closed)'
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
	// task-contract + manifests (Python fbb2280 parity) — verbatim task + per-role manifest
	fs_tc := new_fs()
	fs_tc.write_atomic(os.join_path(run_dir, 'artifacts', 'task-contract.md'), opts.task) or {}
	for role in swarm_recipe_roles(recipe) {
		manifest := {
			'role':    role
			'run_id':  rid
			'task':    opts.task
			'version': swarm_state_version.str()
		}
		fs_tc.write_atomic(os.join_path(run_dir, 'prompts', role + '.manifest.json'), json.encode(manifest) + '\n') or {}
	}
	initial := if resolved.spec.gates.require_plan_approval {
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
	mut personas := map[string]string{}
	mut policy_map := map[string]string{}
	for role, rs in resolved.spec.roles {
		personas[role] = rs.persona
		policy_map[role] = rs.model_profile
		if rs.ui_backend.len > 0 {
			policy_map[role + '_ui'] = rs.ui_backend
		}
	}
	mut st := SwarmStateFile{
		version:         swarm_state_version
		run_id:          rid
		recipe:          recipe
		backend:         backend
		runner:          runner
		model_profile:   model_profile
		run_state:       initial
		created_at:      time.utc().format_rfc3339()
		task:            opts.task
		budget:          resolved.budget
		budget_consumed: BudgetConsumed{}
		personas:        personas
		policy:          policy_map
		active_roles:    []string{}
		worktrees:       created_wts
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
	if _ := check_budget(run_dir) {
		if swarm_can_transition(initial, 'budget_exhausted') {
			ns := SwarmStateFile{
				...st
				run_state: 'budget_exhausted'
			}
			write_swarm_state(run_dir, ns) or {}
			append_swarm_trace(run_dir, 'budget_exhausted', rid)
		}
	}
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
	// Blocking attach (execvp) — must be last statement, like Python's os.execvp. Only when not json/dry_run and attach requested.
	if !opts.dry_run && !opts.json_output && opts.attach && !opts.no_attach {
		if backend == 'tmux' {
			sock := 'agent-toolkit-swarm-${rid}'
			session := 'swarm-${rid}'
			println('Attaching to tmux: tmux -L ${sock} attach -t ${session}')
			os.execvp('tmux', ['tmux', '-L', sock, 'attach', '-t', session]) or {
				return SwarmReport{
					ok:      false
					message: 'tmux attach failed: ${err}'
				}
			}
		} else if backend == 'herdr' {
			println('Attaching to herdr: herdr workspace open swarm-${rid}')
			os.execvp('herdr', ['herdr', 'workspace', 'open', 'swarm-${rid}']) or {
				return SwarmReport{
					ok:      false
					message: 'herdr attach failed: ${err}'
				}
			}
		}
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

fn list_all_swarm_runs(ws string) []string {
	mut out := []string{}
	primary := swarm_runs_dir(ws)
	if os.is_dir(primary) {
		for n in os.ls(primary) or { []string{} } {
			full := os.join_path(primary, n)
			if os.is_dir(full) {
				out << full
			}
		}
	}
	projects_dir := os.join_path(ws, 'projects')
	if os.is_dir(projects_dir) {
		for link in os.ls(projects_dir) or { []string{} } {
			p := os.join_path(projects_dir, link)
			if os.is_link(p) {
				target := os.real_path(p)
				if target.len == 0 {
					continue
				}
				alt := os.join_path(target, '.agent-toolkit', 'swarm', 'runs')
				if os.is_dir(alt) {
					for n in os.ls(alt) or { []string{} } {
						full2 := os.join_path(alt, n)
						if os.is_dir(full2) {
							out << full2
						}
					}
				}
			}
		}
	}
	out.sort_with_compare(fn (a &string, b &string) int {
		ma := os.file_last_mod_unix(*a)
		mb := os.file_last_mod_unix(*b)
		if ma > mb {
			return -1
		}
		if ma < mb {
			return 1
		}
		return 0
	})
	return out
}

fn swarm_list(ws string, opts SwarmOptions) SwarmReport {
	all := list_all_swarm_runs(ws)
	if opts.json_output {
		mut entries := []SwarmListEntry{}
		for rd in all {
			st := read_swarm_state(rd) or { continue }
			entries << SwarmListEntry{
				run_id:     st.run_id
				recipe:     st.recipe
				backend:    st.backend
				run_state:  st.run_state
				created_at: st.created_at
				task:       st.task
			}
		}
		if entries.len == 0 {
			return SwarmReport{
				ok:      true
				message: '[]'
				data:    {
					'subcommand': 'list'
					'count':      '0'
				}
			}
		}
		return SwarmReport{
			ok:      true
			message: json.encode(entries)
			data:    {
				'subcommand': 'list'
				'count':      '${entries.len}'
			}
		}
	}
	if all.len == 0 {
		return SwarmReport{
			ok:      true
			message: 'No swarm runs found.'
			data:    {
				'subcommand': 'list'
				'count':      '0'
			}
		}
	}
	mut lines := []string{}
	mut count := 0
	for rd in all {
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
		return swarm_list(ws, opts)
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
	// Worktrees from state (HEAD) + dir fallback
	mut wlines := []string{}
	for wt in st.worktrees {
		wlines << '${wt.role}:${wt.branch}@${wt.path}'
	}
	mut wt_detail := gtxt.join(', ')
	if wlines.len > 0 {
		wt_detail += '\nworktrees: ' + wlines.join(', ')
	}
	if st.worktrees.len == 0 {
		wt_root := os.join_path(swarm_run_dir(ws, st.run_id), 'worktrees')
		if os.is_dir(wt_root) {
			entries := os.ls(wt_root) or { []string{} }
			if entries.len > 0 {
				wt_detail += if wt_detail.len > 0 { '; ' } else { '' } + 'worktrees(dir): ' + entries.join(', ')
			}
		}
	}
	mut wlines_joined := wlines.join(',')
	if wlines_joined.len == 0 && st.worktrees.len == 0 {
		wt_root2 := os.join_path(swarm_run_dir(ws, st.run_id), 'worktrees')
		if os.is_dir(wt_root2) {
			el := os.ls(wt_root2) or { []string{} }
			if el.len > 0 {
				wlines_joined = el.join(',')
			}
		}
	}
	mut b := st.budget
	if b.max_total_tokens == 0 {
		b = recipe_budget(st.recipe)
	}
	created := time.parse_rfc3339(st.created_at) or { time.utc() }
	wall := int(time.utc().unix() - created.unix())
	bj := json.encode(b)
	bc := st.budget_consumed
	bcj := json.encode(bc)
	// Feature: handoffs, worktrees dir, artifacts, trace_tail, budget json
	mut ho := SwarmHandoffsJson{}
	for q in ['outbox', 'queued', 'active', 'completed', 'failed'] {
		dir := os.join_path(rd, 'handoffs', q)
		mut cnt := 0
		if os.is_dir(dir) {
			entries := os.ls(dir) or { []string{} }
			for e in entries {
				if e.ends_with('.json') {
					cnt++
				}
			}
		}
		match q {
			'outbox' { ho.outbox = cnt }
			'queued' { ho.queued = cnt }
			'active' { ho.active = cnt }
			'completed' { ho.completed = cnt }
			'failed' { ho.failed = cnt }
			else {}
		}
	}
	mut worktrees := []string{}
	wt_dir := os.join_path(rd, 'worktrees')
	if os.is_dir(wt_dir) {
		entries := os.ls(wt_dir) or { []string{} }
		for e in entries {
			if e.starts_with('.') {
				continue
			}
			worktrees << e
		}
		worktrees.sort()
	}
	// Also include state worktrees if not in dir listing
	if worktrees.len == 0 && wlines.len > 0 {
		for wl in wlines {
			worktrees << wl
		}
	}
	mut artifacts := []string{}
	art_dir := os.join_path(rd, 'artifacts')
	if os.is_dir(art_dir) {
		entries := os.ls(art_dir) or { []string{} }
		for e in entries {
			if e.starts_with('.') {
				continue
			}
			artifacts << e
		}
		artifacts.sort()
	}
	mut trace_tail := []string{}
	trace_path := os.join_path(rd, 'trace.jsonl')
	if os.is_file(trace_path) {
		content := os.read_file(trace_path) or { '' }
		lines := content.split_into_lines()
		mut filtered := []string{}
		for l in lines {
			if l.trim_space().len > 0 {
				filtered << l
			}
		}
		start := if filtered.len > 5 { filtered.len - 5 } else { 0 }
		trace_tail = filtered[start..]
	}
	// Budget for JSON: combine b and bc
	budget_json := SwarmBudgetJson{
		max_total_tokens: b.max_total_tokens
		total_tokens:     bc.total_tokens
		max_cost_usd:     b.max_cost_usd
		total_cost:       bc.total_cost
		max_wall_seconds: b.max_wall_seconds
		wall_seconds:     wall
	}
	if opts.json_output {
		status := SwarmStatusJson{
			run_id:        st.run_id
			recipe:        st.recipe
			backend:       st.backend
			runner:        st.runner
			model_profile: st.model_profile
			run_state:     st.run_state
			created_at:    st.created_at
			task:          st.task
			worktrees:     worktrees
			approvals:     SwarmApprovalsJson{
				gates: gates
			}
			budget:        budget_json
			handoffs:      ho
			trace_tail:    trace_tail
			artifacts:     artifacts
		}
		return SwarmReport{
			ok:      true
			message: json.encode(status)
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
	// Human output: combine HEAD and feature
	mut msg_lines := []string{}
	msg_lines << 'run ${st.run_id} recipe=${st.recipe} backend=${st.backend} runner=${st.runner} state=${st.run_state}'
	msg_lines << 'gates: ${gtxt.join(', ')}'
	msg_lines << 'budget: ${bj} consumed: ${bcj} wall_seconds: ${wall}'
	msg_lines << 'handoffs: outbox=${ho.outbox} queued=${ho.queued} active=${ho.active} completed=${ho.completed} failed=${ho.failed}'
	if worktrees.len > 0 {
		msg_lines << 'worktrees: ${worktrees.join(', ')}'
	} else if wlines.len > 0 {
		msg_lines << 'worktrees: ${wlines.join(', ')}'
	} else {
		msg_lines << 'worktrees: (none)'
	}
	if artifacts.len > 0 {
		msg_lines << 'artifacts: ${artifacts.join(', ')}'
	} else {
		msg_lines << 'artifacts: (none)'
	}
	if trace_tail.len > 0 {
		msg_lines << 'trace: ${trace_tail.join(' | ')}'
	}
	return SwarmReport{
		ok:      true
		message: msg_lines.join('\n')
		data:    {
			'subcommand':       'status'
			'run_id':           st.run_id
			'recipe':           st.recipe
			'backend':          st.backend
			'run_state':        st.run_state
			'gates':            gtxt.join(',')
			'worktrees':        if wlines_joined.len > 0 { wlines_joined } else { worktrees.join(',') }
			'budget':           bj
			'budget_consumed':  bcj
			'max_total_tokens': b.max_total_tokens.str()
			'total_tokens':     bc.total_tokens.str()
			'max_cost_usd':     b.max_cost_usd.str()
			'total_cost':       bc.total_cost.str()
			'max_wall_seconds': b.max_wall_seconds.str()
			'wall_seconds':     wall.str()
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

fn swarm_attach(ws string, opts SwarmOptions) SwarmReport {
	if opts.run_id.len == 0 {
		return SwarmReport{
			ok:      false
			message: 'Usage: agent-toolkit swarm attach <run-id>'
		}
	}
	if !swarm_valid_run_id(opts.run_id) {
		return SwarmReport{
			ok:      false
			message: "Invalid run_id '${opts.run_id}'"
		}
	}
	mut rd := swarm_run_dir(ws, opts.run_id)
	if !os.is_dir(rd) {
		if found := swarm_find_run_dir_global(opts.run_id) {
			rd = found
		} else {
			return SwarmReport{
				ok:      false
				message: 'Run not found: ${opts.run_id}'
			}
		}
	}
	st := read_swarm_state(rd) or {
		return SwarmReport{
			ok:      false
			message: 'Run not found: ${opts.run_id}'
		}
	}
	mut backend := st.backend
	if backend.len == 0 {
		backend = resolve_swarm_backend('auto')
	}
	if backend == 'auto' {
		backend = resolve_swarm_backend('auto')
	}
	if backend == 'tmux' {
		sock := 'agent-toolkit-swarm-${opts.run_id}'
		session := 'swarm-${opts.run_id}'
		println('Attaching to tmux: tmux -L ${sock} attach -t ${session}')
		os.execvp('tmux', ['tmux', '-L', sock, 'attach', '-t', session]) or {
			return SwarmReport{
				ok:      false
				message: 'tmux attach failed: ${err}'
			}
		}
	} else if backend == 'herdr' {
		println('Attaching to herdr: herdr workspace open swarm-${opts.run_id}')
		os.execvp('herdr', ['herdr', 'workspace', 'open', 'swarm-${opts.run_id}']) or {
			return SwarmReport{
				ok:      false
				message: 'herdr attach failed: ${err}'
			}
		}
	} else {
		return SwarmReport{
			ok:      false
			message: 'Attach not supported for backend ${backend}: use herdr or tmux'
		}
	}
	return SwarmReport{
		ok:      true
		message: 'Attached ${opts.run_id}'
	}
}

fn swarm_find_run_dir_global(run_id string) ?string {
	home := os.home_dir()
	mut candidates := []string{}
	if home.len > 0 {
		direct := os.join_path(home, '.agent-toolkit', 'swarm', 'runs', run_id)
		if os.is_dir(direct) {
			return direct
		}
		candidates << os.join_path(home, '.ai-workspace', 'repos', 'github.com')
		candidates << os.join_path(home, '.ai-workspace', 'repos')
	}
	mut cur := os.getwd()
	mut cur2 := cur
	for _ in 0 .. 10 {
		if os.is_dir(os.join_path(cur2, 'repos')) && os.file_name(cur2) == '.ai-workspace' {
			candidates << os.join_path(cur2, 'repos', 'github.com')
			candidates << os.join_path(cur2, 'repos')
			break
		}
		parent := os.dir(cur2)
		if parent == cur2 || parent.len == 0 {
			break
		}
		cur2 = parent
	}
	for root in candidates {
		if !os.is_dir(root) {
			continue
		}
		owners := os.ls(root) or { continue }
		for owner in owners {
			owner_path := os.join_path(root, owner)
			if !os.is_dir(owner_path) {
				continue
			}
			if os.is_dir(os.join_path(owner_path, '.git')) || os.is_file(os.join_path(owner_path, '.git')) {
				cand := os.join_path(owner_path, '.agent-toolkit', 'swarm', 'runs', run_id)
				if os.is_dir(cand) {
					return cand
				}
				continue
			}
			repos := os.ls(owner_path) or { continue }
			for repo in repos {
				repo_path := os.join_path(owner_path, repo)
				if !os.is_dir(repo_path) {
					continue
				}
				if !os.is_dir(os.join_path(repo_path, '.git')) && !os.is_file(os.join_path(repo_path, '.git')) {
					continue
				}
				cand := os.join_path(repo_path, '.agent-toolkit', 'swarm', 'runs', run_id)
				if os.is_dir(cand) {
					return cand
				}
			}
		}
	}
	return none
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
	if _ := check_budget(rd) {
		if swarm_can_transition(st.run_state, 'budget_exhausted') {
			ns := SwarmStateFile{
				...st
				run_state: 'budget_exhausted'
			}
			write_swarm_state(rd, ns) or {}
			append_swarm_trace(rd, 'budget_exhausted', run_id)
		}
		mut b := st.budget
		if b.max_total_tokens == 0 {
			b = recipe_budget(st.recipe)
		}
		return SwarmReport{
			ok:      false
			message: 'budget_exhausted: run ${run_id} has exceeded budget (max_total_tokens=${b.max_total_tokens} max_cost_usd=${b.max_cost_usd} max_wall_seconds=${b.max_wall_seconds})'
			data:    {
				'subcommand': 'handoff'
				'run_id':     run_id
				'run_state':  'budget_exhausted'
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
	fs := new_fs()
	fs.write_atomic(os.join_path(run_dir, 'state.json'), json.encode(st) + '\n')!
}

fn read_swarm_state(run_dir string) ?SwarmStateFile {
	path := os.join_path(run_dir, 'state.json')
	if !os.is_file(path) {
		return none
	}
	text := os.read_file(path) or { return none }
	mut st := json.decode(SwarmStateFile, text) or { return none }
	if st.version > swarm_state_version {
		return none
	}
	if st.version < swarm_state_version {
		migrate_swarm_state(mut st)
	}
	return st
}

fn check_budget(run_dir string) ?string {
	st := read_swarm_state(run_dir) or { return none }
	mut b := st.budget
	if b.max_total_tokens == 0 {
		b = recipe_budget(st.recipe)
	}
	created := time.parse_rfc3339(st.created_at) or { time.utc() }
	wall := int(time.utc().unix() - created.unix())
	if st.budget_consumed.total_tokens >= b.max_total_tokens || st.budget_consumed.total_cost >= b.max_cost_usd || wall >= b.max_wall_seconds {
		return 'budget_exhausted'
	}
	return none
}

fn write_swarm_approvals(run_dir string, gates []SwarmGate) ! {
	payload := SwarmApprovalsFile{
		gates: gates
	}
	fs := new_fs()
	fs.write_atomic(os.join_path(run_dir, 'approvals.json'), json.encode(payload) + '\n')!
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
	fs := new_fs()
	existing := os.read_file(path) or { '' }
	fs.write_atomic(path, existing + line) or { os.write_file(path, existing + line) or {} }
}

// is_worktree_dirty reports whether wt_path has uncommitted changes (Python worktree.py:85 parity).
fn is_worktree_dirty(wt_path string) bool {
	if wt_path.len == 0 || !os.is_dir(wt_path) {
		return false
	}
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv:    ['git', '-C', wt_path, 'status', '--porcelain']
		timeout: 5 * time.second
	}) or { return false }
	return res.stdout.trim_space().len > 0
}

fn remove_worktree(repo_root string, wt_path string, force bool) !bool {
	if wt_path.len == 0 || !os.is_dir(wt_path) {
		return false
	}
	if is_worktree_dirty(wt_path) && !force {
		return error('Worktree dirty, refusing removal without --force: ${wt_path}')
	}
	ps := new_process_service()
	mut argv := ['git', 'worktree', 'remove', wt_path]
	if force {
		argv << '--force'
	}
	_ := ps.run(RunOptions{
		argv:    argv
		cwd:     repo_root
		timeout: 10 * time.second
	}) or { RunResult{} }
	if os.is_dir(wt_path) {
		os.rmdir_all(wt_path) or {}
	}
	return true
}

fn swarm_new_run_id() string {
	rfc := time.utc().format_rfc3339()
	date := rfc[..10].clone().replace('-', '')
	clock := if rfc.len >= 19 { rfc[11..19].clone().replace(':', '') } else { '000000' }
	return 's${date}T${clock}Z'
}
