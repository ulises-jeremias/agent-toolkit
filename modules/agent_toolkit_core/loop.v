module agent_toolkit_core

import x.json2
import os
import time

// LoopOptions configures the loop command family (#523 REDESIGN / ADR-020).
pub struct LoopOptions {
pub:
	subcommand     string
	workspace_path string
	name           string // loop name or init pattern
	custom_name    string
	force          bool
	quiet          bool
	runner         string
	pack           string
	no_llm         bool
	dry_run        bool
	cron           string
	list_mode      bool
	remove_mode    bool
	platform       string // schedule platform: local | github-actions (Phase 1, #729)
}

// LoopReport is the domain result for loop subcommands.
pub struct LoopReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

struct LoopMeta {
pub mut:
	name                 string
	tier                 string
	cadence              string
	goal                 string
	request              string
	max_tokens           int
	max_runs_per_day     int
	max_wall_seconds     int
	allowlist            []string
	deny                 []string
	attribution_enabled  bool
	attribution_template string
}

// run_loop implements init/run/status/audit/cost/schedule/sync/list/templates.
pub fn run_loop(opts LoopOptions) LoopReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return LoopReport{
			ok: true
			message: loop_help_text()
			data: {
				'subcommand': 'help'
			}
		}
	}
	ws := find_loop_workspace(opts.workspace_path)
	return match sub {
		'init' {
			loop_init(ws, opts)
		}
		'run' {
			loop_run(ws, opts)
		}
		'status' {
			loop_status(ws, opts)
		}
		'audit' {
			loop_audit(ws, opts)
		}
		'cost' {
			loop_cost(ws, opts)
		}
		'schedule' {
			loop_schedule(ws, opts)
		}
		'sync' {
			loop_sync(ws, opts)
		}
		'list', 'ls' {
			loop_list(ws)
		}
		'templates' {
			loop_templates(ws)
		}
		else {
			LoopReport{
				ok: false
				message: "Unknown command: ${sub}\nRun 'agent-toolkit loop help' for usage."
				data: {
					'subcommand': sub
					'workspace':  ws
				}
			}
		}
	}
}

pub fn loop_result(report LoopReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = ''
	}
	return CommandResult{
		command: 'loop'
		ok: report.ok
		message: report.message
		data: data
	}
}

pub fn loop_help_text() string {
	return 'loop — Loop engineering CLI (REDESIGN: process-per-run supervisor, ADR-020).

Usage:
    agent-toolkit loop init <pattern> [--name NAME]
    agent-toolkit loop run <loop> [--force] [--runner NAME] [--no-llm] [--quiet] [--pack PATH]
    agent-toolkit loop list
    agent-toolkit loop status [loop]
    agent-toolkit loop audit [loop]
    agent-toolkit loop cost <loop>
    agent-toolkit loop schedule <loop> [--dry-run] [--cron EXPR] [--platform PLATFORM] [--list] [--remove]
    agent-toolkit loop sync [--platform PLATFORM] [--dry-run]
    agent-toolkit loop templates
    agent-toolkit loop help

loop run options:
    --force       Bypass max_runs_per_day only (not wall/token budgets)
    --quiet       Suppress live runner output
    --pack PATH   Apply loop overrides from pack YAML
    --workspace PATH  Workspace root override
    --runner NAME auto|skeleton (LLM PATH runners fail closed to skeleton without stdin)
    --no-llm      Alias for --runner skeleton (no network)
    --platform PLATFORM  Schedule platform: local (default, systemd/launchd) | github-actions
    --json        Structured CommandResult JSON

Concurrency: one OS process per iteration via ProcessService; no Python threads / no `go` workers.
Schedule: systemd/launchd on Unix (local); GitHub Actions via --platform github-actions; not supported on Windows for local.
'
}

fn find_loop_workspace(override string) string {
	if override.len > 0 && os.is_dir(override) {
		return override
	}
	if ws := find_workspace_root(override) {
		return ws
	}
	return os.getwd()
}

fn loops_dir(ws string) string {
	return os.join_path(ws, 'loops')
}

fn loop_init(ws string, opts LoopOptions) LoopReport {
	pattern := opts.name
	if pattern.len == 0 {
		mut lines := []string{}
		lines << 'Usage: agent-toolkit loop init <pattern> [--name <custom-name>]'
		lines << ''
		lines << 'Available patterns:'
		for t in list_loop_templates(ws) {
			lines << '  ${t}'
		}
		return LoopReport{
			ok: false
			message: lines.join('\n')
			data: {
				'subcommand': 'init'
				'workspace':  ws
			}
		}
	}
	loop_name := if opts.custom_name.len > 0 { opts.custom_name } else { pattern }
	dest := os.join_path(loops_dir(ws), loop_name)
	if os.exists(dest) {
		return LoopReport{
			ok: false
			message: "Loop '${loop_name}' already exists at ${dest}"
			data: {
				'subcommand': 'init'
				'workspace':  ws
			}
		}
	}
	text := load_loop_template(ws, pattern) or {
		mut lines := []string{}
		lines << "Template '${pattern}' not found."
		lines << ''
		lines << 'Available patterns:'
		for t in list_loop_templates(ws) {
			lines << '  ${t}'
		}
		return LoopReport{
			ok: false
			message: lines.join('\n')
			data: {
				'subcommand': 'init'
				'workspace':  ws
			}
		}
	}
	os.mkdir_all(os.join_path(dest, 'runs')) or {
		return LoopReport{
			ok: false
			message: 'mkdir failed: ${err}'
		}
	}
	rewritten := rewrite_loop_name(text, loop_name)
	os.write_file(os.join_path(dest, 'loop.yaml'), rewritten) or {
		return LoopReport{
			ok: false
			message: 'write loop.yaml failed: ${err}'
		}
	}
	// pack overlay for init (P2-06 parity): --pack applies loop_overrides at scaffold time
	if opts.pack.len > 0 {
		mut pack_path := ''
		if os.is_file(opts.pack) {
			pack_path = opts.pack
		} else if os.is_file(os.join_path(ws, opts.pack)) {
			pack_path = os.join_path(ws, opts.pack)
		} else if os.is_file(os.join_path(ws, 'packs', opts.pack)) {
			pack_path = os.join_path(ws, 'packs', opts.pack)
		} else if os.is_file(os.join_path(ws, 'packs', opts.pack + '.yaml')) {
			pack_path = os.join_path(ws, 'packs', opts.pack + '.yaml')
		}
		if pack_path.len > 0 {
			pack_text := os.read_file(pack_path) or { '' }
			if pack_text.len > 0 {
				overrides := parse_pack_overrides(pack_text, loop_name)
				if overrides.tier.len > 0 || overrides.max_tokens > 0 || overrides.cadence.len > 0 || overrides.allowlist.len > 0 {
					patch_loop_yaml_with_overrides(os.join_path(dest, 'loop.yaml'), overrides)
				}
			}
		}
	}
	write_state_md(dest, 'never', 'not_run', '', 0, []string{})
	return LoopReport{
		ok: true
		message: "[loop] Initialized loop '${loop_name}' at loops/${loop_name}\n\n  Edit loops/${loop_name}/loop.yaml to customize.\n  Then run: agent-toolkit loop run ${loop_name}"
		data: {
			'subcommand': 'init'
			'workspace':  ws
			'name':       loop_name
		}
	}
}

fn loop_run(ws string, opts LoopOptions) LoopReport {
	loop_name := opts.name
	if loop_name.len == 0 {
		return LoopReport{
			ok: false
			message: 'Usage: agent-toolkit loop run <loop-name> [--force] [--runner skeleton] [--no-llm]'
			data: {
				'subcommand': 'run'
				'workspace':  ws
			}
		}
	}
	loop_dir := resolve_loop_dir(ws, loop_name) or {
		return LoopReport{
			ok: false
			message: "Loop '${loop_name}' not found. Run: agent-toolkit loop init ${loop_name}"
			data: {
				'subcommand': 'run'
				'workspace':  ws
			}
		}
	}
	mut meta := parse_loop_meta(loop_dir)
	// --- pack overlay (P2-06): --pack PATH or pack name under packs/*.yaml ---
	if opts.pack.len > 0 {
		mut pack_path := ''
		if os.is_file(opts.pack) {
			pack_path = opts.pack
		} else if os.is_file(os.join_path(ws, opts.pack)) {
			pack_path = os.join_path(ws, opts.pack)
		} else if os.is_file(os.join_path(ws, 'packs', opts.pack)) {
			pack_path = os.join_path(ws, 'packs', opts.pack)
		} else if os.is_file(os.join_path(ws, 'packs', opts.pack + '.yaml')) {
			pack_path = os.join_path(ws, 'packs', opts.pack + '.yaml')
		} else if os.is_file(opts.pack + '.yaml') {
			pack_path = opts.pack + '.yaml'
		}
		if pack_path.len > 0 {
			pack_text := os.read_file(pack_path) or { '' }
			if pack_text.len > 0 {
				overrides := parse_pack_overrides(pack_text, loop_name)
				if overrides.tier.len > 0 {
					meta.tier = overrides.tier
				}
				if overrides.cadence.len > 0 && overrides.cadence != '?' {
					meta.cadence = overrides.cadence
				}
				if overrides.max_tokens > 0 {
					meta.max_tokens = overrides.max_tokens
				}
				if overrides.max_runs_per_day > 0 {
					meta.max_runs_per_day = overrides.max_runs_per_day
				}
				if overrides.max_wall_seconds > 0 {
					meta.max_wall_seconds = overrides.max_wall_seconds
				}
				if overrides.goal.len > 0 {
					meta.goal = overrides.goal
				}
				if overrides.request.len > 0 {
					meta.request = overrides.request
				}
				if overrides.allowlist.len > 0 {
					meta.allowlist = overrides.allowlist.clone()
				}
				if overrides.deny.len > 0 {
					meta.deny = overrides.deny.clone()
				}
			}
		}
	}
	max_runs := if meta.max_runs_per_day > 0 { meta.max_runs_per_day } else { 10 }
	mut last_run, _, _, runs_today_val, escalations := read_state_md(loop_dir)
	mut runs_today := runs_today_val
	if last_run.len > 0 && last_run != 'never' {
		today := time.utc().format_rfc3339()[..10]
		if last_run.len >= 10 && last_run[..10] != today {
			runs_today = 0
		}
	}
	if runs_today >= max_runs && !opts.force {
		return LoopReport{
			ok: true
			message: '[loop] Budget: max_runs_per_day (${max_runs}) reached for today. Skipping.\n  Re-run with: agent-toolkit loop run <loop> --force'
			data: {
				'subcommand': 'run'
				'workspace':  ws
				'name':       loop_name
				'status':     'budget_skip'
			}
		}
	}
	// --- budget enforcement (P2-06): max_tokens / max_wall_seconds vs trace.jsonl ---
	wall := if meta.max_wall_seconds > 0 { meta.max_wall_seconds } else { 600 }
	if !opts.force {
		if meta.max_tokens > 0 {
			used := total_tokens_for_loop(loop_dir)
			if used >= meta.max_tokens {
				rid_ex := loop_run_id()
				os.mkdir_all(os.join_path(loop_dir, 'runs', rid_ex)) or {}
				trace_ex := os.join_path(loop_dir, 'runs', rid_ex, 'trace.jsonl')
				os.write_file(trace_ex, '{"kind":"run_end","status":"budget_exhausted","reason":"max_tokens","tokens_used":${used},"max_tokens":${meta.max_tokens},"run_id":${json2.encode(rid_ex,
					escape_unicode: true
				)}}\n') or {}
				write_state_md(loop_dir, time.utc().format_rfc3339(), 'budget_exhausted', rid_ex, runs_today, escalations)
				return LoopReport{
					ok: true
					message: '[loop] Budget exhausted: max_tokens ${meta.max_tokens} reached (used ${used}). Re-run after increasing budget.max_tokens.'
					data: {
						'subcommand': 'run'
						'workspace':  ws
						'name':       loop_name
						'status':     'budget_exhausted'
						'run_id':     rid_ex
					}
				}
			}
		}
		if meta.max_wall_seconds > 0 {
			wall_used := total_wall_for_loop(loop_dir)
			if wall_used > 0 && wall_used >= meta.max_wall_seconds {
				rid_ex := loop_run_id()
				os.mkdir_all(os.join_path(loop_dir, 'runs', rid_ex)) or {}
				trace_ex := os.join_path(loop_dir, 'runs', rid_ex, 'trace.jsonl')
				os.write_file(trace_ex, '{"kind":"run_end","status":"budget_exhausted","reason":"max_wall_seconds","wall_used":${wall_used},"max_wall_seconds":${meta.max_wall_seconds},"run_id":${json2.encode(rid_ex,
					escape_unicode: true
				)}}\n') or {}
				write_state_md(loop_dir, time.utc().format_rfc3339(), 'budget_exhausted', rid_ex, runs_today, escalations)
				return LoopReport{
					ok: true
					message: '[loop] Budget exhausted: max_wall_seconds ${meta.max_wall_seconds}s exceeded (wall ${wall_used}s).'
					data: {
						'subcommand': 'run'
						'workspace':  ws
						'name':       loop_name
						'status':     'budget_exhausted'
						'run_id':     rid_ex
					}
				}
			}
		}
	}
	// --- gh_gate wiring (P2-06): classify + gate check logged for skeleton ---
	// Skeleton has no gh writes, but we log the gate decision so pack/tier parity is visible and grep-able.
	// Future LLM runner must call loop_gate_allows before any `gh` argv.
	mut gate_info := ''
	if true {
		// demonstrate classify_gh_argv + loop_gate_allows are wired (read-only -> true, merge -> tier gated)
		ro_action := classify_gh_argv(['pr', 'view', '1'])
		merge_action := classify_gh_argv(['pr', 'merge', '1'])
		ro_allowed := loop_gate_allows(meta.tier, meta.allowlist, meta.deny, ro_action)
		merge_allowed := loop_gate_allows(meta.tier, meta.allowlist, meta.deny, merge_action)
		gate_info = 'gate ro=${ro_allowed} merge=${merge_allowed} tier=${meta.tier} action_merge=${merge_action}'
		_ = gate_info
	}
	rid := loop_run_id()
	run_dir := os.join_path(loop_dir, 'runs', rid)
	os.mkdir_all(run_dir) or {
		return LoopReport{
			ok: false
			message: 'mkdir run dir failed: ${err}'
		}
	}
	use_skeleton := opts.no_llm || opts.runner in ['skeleton', ''] || opts.runner == 'auto'
	mut lines := []string{}
	lines << '[loop] Running ${loop_name} (tier=${meta.tier} cadence=${meta.cadence})'
	lines << '[loop] ADR-020 process-per-run; skeleton fail-closed without ProcessService stdin'
	if gate_info.len > 0 {
		lines << '[loop] ${gate_info}'
	}
	if opts.pack.len > 0 {
		lines << '[loop] pack overlay: ${opts.pack} tier=${meta.tier}'
	}
	// dry-run: plan only, no side effects beyond run_dir creation (parity with Python --dry-run)
	if opts.dry_run {
		plan_path := os.join_path(run_dir, 'plan.md')
		plan := skeleton_loop_plan(loop_name, meta, rid)
		os.write_file(plan_path, plan) or {
			return LoopReport{
				ok: false
				message: 'write plan failed: ${err}'
			}
		}
		trace := '{"kind":"run_end","status":"completed","runner":"skeleton","run_id":${json2.encode(rid,
			escape_unicode: true
		)},"dry_run":true,"gate":"${gate_info}"}\n'
		os.write_file(os.join_path(run_dir, 'trace.jsonl'), trace) or {}
		lines << '[loop] dry-run Skeleton plan written → ${plan_path}'
		lines << '[loop] wall budget ${wall}s (not consumed by skeleton)'
		_ = use_skeleton
		return LoopReport{
			ok: true
			message: lines.join('\n')
			data: {
				'subcommand': 'run'
				'workspace':  ws
				'name':       loop_name
				'run_id':     rid
				'status':     'completed'
				'runner':     'skeleton'
				'mode':       'dry-run'
			}
		}
	}
	plan_path := os.join_path(run_dir, 'plan.md')
	plan := skeleton_loop_plan(loop_name, meta, rid)
	os.write_file(plan_path, plan) or {
		return LoopReport{
			ok: false
			message: 'write plan failed: ${err}'
		}
	}
	trace := '{"kind":"run_end","status":"completed","runner":"skeleton","run_id":${json2.encode(rid,
		escape_unicode: true
	)}}\n'
	os.write_file(os.join_path(run_dir, 'trace.jsonl'), trace) or {}
	// post-run wall/token check: if tokens now exceed limit, mark exhausted (Python tailer parity)
	if meta.max_tokens > 0 {
		used_after := total_tokens_for_loop(loop_dir)
		if used_after >= meta.max_tokens {
			write_state_md(loop_dir, time.utc().format_rfc3339(), 'budget_exhausted', rid, runs_today + 1, escalations)
			lines << '[loop] Skeleton plan written → ${plan_path}'
			lines << '[loop] wall budget ${wall}s (not consumed by skeleton)'
			lines << '[loop] budget_exhausted: max_tokens ${meta.max_tokens} reached after run (used ${used_after})'
			_ = use_skeleton
			return LoopReport{
				ok: true
				message: lines.join('\n')
				data: {
					'subcommand': 'run'
					'workspace':  ws
					'name':       loop_name
					'run_id':     rid
					'status':     'budget_exhausted'
					'runner':     'skeleton'
				}
			}
		}
	}
	write_state_md(loop_dir, time.utc().format_rfc3339(), 'completed', rid, runs_today + 1, escalations)
	lines << '[loop] Skeleton plan written → ${plan_path}'
	lines << '[loop] wall budget ${wall}s (not consumed by skeleton)'
	_ = use_skeleton
	return LoopReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'run'
			'workspace':  ws
			'name':       loop_name
			'run_id':     rid
			'status':     'completed'
			'runner':     'skeleton'
		}
	}
}

fn loop_status(ws string, opts LoopOptions) LoopReport {
	mut dirs := []string{}
	if opts.name.len > 0 {
		if d := resolve_loop_dir(ws, opts.name) {
			dirs << d
		} else {
			return LoopReport{
				ok: false
				message: "Loop '${opts.name}' not found."
				data: {
					'subcommand': 'status'
					'workspace':  ws
				}
			}
		}
	} else {
		dirs = list_loop_dirs(ws)
		if dirs.len == 0 {
			dirs = bundled_loop_dirs()
		}
	}
	if dirs.len == 0 {
		return LoopReport{
			ok: true
			message: 'No loops found. Run: agent-toolkit loop init <pattern>'
			data: {
				'subcommand': 'status'
				'workspace':  ws
				'count':      '0'
			}
		}
	}
	mut lines := []string{}
	lines << ''
	lines << '── Loop Status ──────────────────────────────────────────'
	for d in dirs {
		meta := parse_loop_meta(d)
		_, last_status, _, _, _ := read_state_md(d)
		runs_n := count_runs(d)
		lines << '  ${os.file_name(d)}  tier=${meta.tier}  cadence=${meta.cadence}  runs=${runs_n}  last=${last_status}'
	}
	lines << ''
	return LoopReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'status'
			'workspace':  ws
			'count':      '${dirs.len}'
		}
	}
}

fn loop_audit(ws string, opts LoopOptions) LoopReport {
	mut dirs := []string{}
	if opts.name.len > 0 {
		if d := resolve_loop_dir(ws, opts.name) {
			dirs << d
		}
	} else {
		dirs = list_loop_dirs(ws)
	}
	mut lines := []string{}
	lines << ''
	lines << '── Loop Audit ───────────────────────────────────────────'
	for d in dirs {
		completed, failed, tokens := audit_loop_dir(d)
		total := completed + failed
		rate := if total > 0 { '${completed * 100 / total}%' } else { '—' }
		lines << ''
		lines << '  ${os.file_name(d)}'
		lines << '    runs=${total}  success=${completed}  failed=${failed}  rate=${rate}  tokens≈${tokens}'
	}
	lines << ''
	return LoopReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'audit'
			'workspace':  ws
			'count':      '${dirs.len}'
		}
	}
}

fn loop_cost(ws string, opts LoopOptions) LoopReport {
	if opts.name.len == 0 {
		return LoopReport{
			ok: false
			message: 'Usage: agent-toolkit loop cost <loop-name>'
			data: {
				'subcommand': 'cost'
			}
		}
	}
	loop_dir := resolve_loop_dir(ws, opts.name) or {
		return LoopReport{
			ok: false
			message: "Loop '${opts.name}' not found. Run: agent-toolkit loop init ${opts.name}"
		}
	}
	meta := parse_loop_meta(loop_dir)
	mut lines := []string{}
	lines << ''
	lines << '  Loop: ${opts.name}'
	lines << '  Tier: ${meta.tier}'
	lines << '  Cadence: ${meta.cadence}'
	lines << '  Budget max_tokens: ${meta.max_tokens}'
	lines << '  Cost tier: unknown'
	lines << '  Estimated per run: —'
	lines << ''
	return LoopReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'cost'
			'workspace':  ws
			'name':       opts.name
			'tier':       meta.tier
		}
	}
}

fn loop_schedule(ws string, opts LoopOptions) LoopReport {
	mut platform := opts.platform.trim_space()
	if platform.len == 0 {
		platform = 'local'
	}
	if platform == 'github-actions' {
		if opts.name.len == 0 {
			return LoopReport{
				ok: false
				message: 'Usage: agent-toolkit loop schedule <loop-name> --platform github-actions [--dry-run] [--force]'
				data: {
					'subcommand': 'schedule'
					'platform':   platform
				}
			}
		}
		loop_dir := resolve_loop_dir(ws, opts.name) or {
			return LoopReport{
				ok: false
				message: "Loop '${opts.name}' not found. Run: agent-toolkit loop init ${opts.name}"
				data: {
					'subcommand': 'schedule'
					'platform':   platform
					'workspace':  ws
				}
			}
		}
		meta := parse_loop_meta(loop_dir)
		mut cron := opts.cron.trim_space()
		if cron.len == 0 {
			cron = cadence_to_cron(meta.cadence) or {
				return LoopReport{
					ok: false
					message: 'invalid cadence "${meta.cadence}" for loop "${opts.name}": ${err.msg()}\n  Use --cron to override or fix loops/${opts.name}/loop.yaml'
					data: {
						'subcommand': 'schedule'
						'platform':   platform
					}
				}
			}
		}
		version := embedded_version
		workflow := emit_github_workflow(opts.name, meta.tier, meta.cadence, cron, version)
		if opts.dry_run {
			return LoopReport{
				ok: true
				message: '[loop] schedule dry-run (github-actions workflow):\n${workflow}'
				data: {
					'subcommand': 'schedule'
					'workspace':  ws
					'name':       opts.name
					'platform':   platform
					'mode':       'dry-run'
					'cron':       cron
				}
			}
		}
		// Determine repo root for workflow path — prefer ws if it looks like a git repo, else fallback to git top-level
		mut repo_root := ws
		// If ws is a harness workspace with loops/ subdir, .github should be at ws (or its parent if ws is nested)
		// We use ws directly; user can move file if needed.
		dir := os.join_path(repo_root, '.github', 'workflows')
		path := os.join_path(dir, 'agent-toolkit-${opts.name}.yml')
		if os.is_file(path) && !opts.force {
			return LoopReport{
				ok: false
				message: '[loop] Workflow already exists at ${path}\n  Use --force to overwrite or --dry-run to preview.\n  To check drift: agent-toolkit loop sync --platform github-actions'
				data: {
					'subcommand': 'schedule'
					'platform':   platform
					'path':       path
				}
			}
		}
		os.mkdir_all(dir) or {
			return LoopReport{
				ok: false
				message: 'mkdir failed: ${err}'
			}
		}
		os.write_file(path, workflow) or {
			return LoopReport{
				ok: false
				message: 'write workflow failed: ${err}'
			}
		}
		mut msg := '[loop] Wrote ${path}\n'
		msg += '  Cron: ${cron} (cadence ${meta.cadence})\n'
		msg += '  Version pin: agent-toolkit-cli==${version}\n'
		msg += '  Next: commit and push, then enable Actions. Secrets: GITHUB_TOKEN is auto-provided; add ANTHROPIC_API_KEY/OPENAI_API_KEY as repo secrets if loop uses LLM.\n'
		msg += '  Sync check: agent-toolkit loop sync --platform github-actions'
		return LoopReport{
			ok: true
			message: msg
			data: {
				'subcommand': 'schedule'
				'workspace':  ws
				'name':       opts.name
				'platform':   platform
				'path':       path
				'cron':       cron
			}
		}
	}
	if platform != 'local' {
		return LoopReport{
			ok: false
			message: "unsupported platform '${platform}' — supported: local, github-actions (see #729)\n  Use: agent-toolkit loop schedule <loop> --platform github-actions"
			data: {
				'subcommand': 'schedule'
				'platform':   platform
			}
		}
	}
	$if windows {
		return LoopReport{
			ok: false
			message: 'loop schedule is Unix-only (systemd/launchd). Not supported on Windows.'
			data: {
				'subcommand': 'schedule'
			}
		}
	}
	if opts.name.len == 0 {
		return LoopReport{
			ok: false
			message: 'Usage: agent-toolkit loop schedule <loop-name> [--dry-run]'
		}
	}
	unit := '[Unit]\nDescription=agent-toolkit loop ${opts.name}\n\n[Service]\nType=oneshot\nExecStart=agent-toolkit loop run ${opts.name}\n\n[Install]\nWantedBy=default.target\n'
	if opts.dry_run || opts.list_mode {
		return LoopReport{
			ok: true
			message: '[loop] schedule dry-run (systemd user unit):\n${unit}'
			data: {
				'subcommand': 'schedule'
				'workspace':  ws
				'name':       opts.name
				'mode':       'dry-run'
			}
		}
	}
	dir := os.join_path(os.home_dir(), '.config', 'systemd', 'user')
	os.mkdir_all(dir) or {}
	path := os.join_path(dir, 'agent-toolkit-loop-${opts.name}.service')
	os.write_file(path, unit) or {
		return LoopReport{
			ok: false
			message: 'write unit failed: ${err}'
		}
	}
	return LoopReport{
		ok: true
		message: '[loop] Wrote ${path}\nEnable with: systemctl --user enable --now agent-toolkit-loop-${opts.name}.service'
		data: {
			'subcommand': 'schedule'
			'workspace':  ws
			'name':       opts.name
			'path':       path
		}
	}
}

fn loop_sync(ws string, opts LoopOptions) LoopReport {
	platform := opts.platform.trim_space()
	if platform == 'github-actions' {
		mut drifts := []string{}
		mut missing := []string{}
		for d in list_loop_dirs(ws) {
			meta := parse_loop_meta(d)
			cron := cadence_to_cron(meta.cadence) or { continue }
			version := embedded_version
			expected := emit_github_workflow(os.file_name(d), meta.tier, meta.cadence, cron, version)
			path := os.join_path(ws, '.github', 'workflows', 'agent-toolkit-${os.file_name(d)}.yml')
			if !os.is_file(path) {
				missing << '${os.file_name(d)} (expected ${path})'
				continue
			}
			actual := os.read_file(path) or { '' }
			if actual.trim_space() != expected.trim_space() {
				drifts << '${os.file_name(d)}'
			}
		}
		if drifts.len == 0 && missing.len == 0 {
			return LoopReport{
				ok: true
				message: '[loop] sync --platform github-actions: all workflows in sync.'
				data: {
					'subcommand': 'sync'
					'platform':   platform
					'workspace':  ws
					'count':      '0'
				}
			}
		}
		mut msg := '[loop] sync --platform github-actions: drift detected\n'
		if missing.len > 0 {
			msg += '  Missing workflows: ${missing.join(', ')}\n'
		}
		if drifts.len > 0 {
			msg += '  Out-of-sync: ${drifts.join(', ')}\n'
		}
		msg += '  Fix: agent-toolkit loop schedule <name> --platform github-actions --force'
		return LoopReport{
			ok: opts.dry_run == false
			message: msg
			data: {
				'subcommand': 'sync'
				'platform':   platform
				'workspace':  ws
				'count':      '${drifts.len + missing.len}'
				'drifts':     drifts.join(',')
				'missing':    missing.join(',')
			}
		}
	}
	if platform.len > 0 && platform != 'local' {
		return LoopReport{
			ok: false
			message: "unsupported platform '${platform}' for sync — supported: local, github-actions"
			data: {
				'subcommand': 'sync'
				'platform':   platform
			}
		}
	}
	mut entries := []string{}
	for d in list_loop_dirs(ws) {
		_, _, _, _, escalations := read_state_md(d)
		for esc in escalations {
			entries << '- [ ] [loop-escalation] ${os.file_name(d)}: ${esc}'
		}
	}
	if entries.len == 0 {
		return LoopReport{
			ok: true
			message: '[loop] No loop escalations to sync.'
			data: {
				'subcommand': 'sync'
				'workspace':  ws
				'count':      '0'
			}
		}
	}
	knowledge := os.join_path(ws, 'knowledge', 'todos', 'pending.md')
	os.mkdir_all(os.dir(knowledge)) or {}
	existing := if os.is_file(knowledge) { os.read_file(knowledge) or { '' } } else { '' }
	header := '<!-- loop-escalations -->'
	footer := '<!-- /loop-escalations -->'
	block := header + '\n' + entries.join('\n') + '\n' + footer
	mut text := existing
	if existing.contains(header) {
		start := existing.index(header) or { existing.len }
		tail := existing[start..].clone()
		endrel := tail.index(footer) or { -1 }
		if endrel >= 0 {
			end := start + endrel + footer.len
			text = existing[..start].clone() + block + existing[end..].clone()
		} else {
			text = existing + '\n' + block + '\n'
		}
	} else {
		text = existing.trim_right(' \n\t\r') + '\n' + block + '\n'
	}
	os.write_file(knowledge, text) or {
		return LoopReport{
			ok: false
			message: 'write todos failed: ${err}'
		}
	}
	return LoopReport{
		ok: true
		message: '[loop] Synced ${entries.len} escalation(s) to knowledge/todos/pending.md'
		data: {
			'subcommand': 'sync'
			'workspace':  ws
			'count':      '${entries.len}'
		}
	}
}

fn loop_list(ws string) LoopReport {
	dirs := list_loop_dirs(ws)
	mut lines := []string{}
	if dirs.len == 0 {
		lines << 'No loops found. Run: agent-toolkit loop init <pattern>'
	} else {
		for d in dirs {
			meta := parse_loop_meta(d)
			lines << '${os.file_name(d)}\ttier=${meta.tier}\tcadence=${meta.cadence}'
		}
	}
	return LoopReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'list'
			'workspace':  ws
			'count':      '${dirs.len}'
		}
	}
}

fn loop_templates(ws string) LoopReport {
	names := list_loop_templates(ws)
	mut lines := []string{}
	for n in names {
		lines << '  ${n}'
	}
	return LoopReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'templates'
			'workspace':  ws
			'count':      '${names.len}'
		}
	}
}

fn list_loop_templates(ws string) []string {
	mut seen := map[string]bool{}
	mut names := []string{}
	user := os.join_path(ws, 'templates', 'loops')
	if os.is_dir(user) {
		for f in os.ls(user) or { []string{} } {
			p := os.join_path(user, f)
			if f.ends_with('.yaml') {
				stem := f.all_before_last('.')
				if stem !in seen {
					seen[stem] = true
					names << stem
				}
			} else if os.is_dir(p) && os.is_file(os.join_path(p, 'loop.yaml')) {
				if f !in seen {
					seen[f] = true
					names << f
				}
			}
		}
	}
	if root := find_toolkit_root() {
		bundled := os.join_path(root.path, 'loops')
		if os.is_dir(bundled) {
			for f in os.ls(bundled) or { []string{} } {
				p := os.join_path(bundled, f)
				if os.is_dir(p) && os.is_file(os.join_path(p, 'loop.yaml')) && f !in seen {
					seen[f] = true
					names << f
				}
			}
		}
	}
	names.sort()
	return names
}

fn load_loop_template(ws string, pattern string) !string {
	user_file := os.join_path(ws, 'templates', 'loops', '${pattern}.yaml')
	if os.is_file(user_file) {
		return os.read_file(user_file)!
	}
	user_dir := os.join_path(ws, 'templates', 'loops', pattern, 'loop.yaml')
	if os.is_file(user_dir) {
		return os.read_file(user_dir)!
	}
	if root := find_toolkit_root() {
		bundled := os.join_path(root.path, 'loops', pattern, 'loop.yaml')
		if os.is_file(bundled) {
			return os.read_file(bundled)!
		}
	}
	return error('not found')
}

fn rewrite_loop_name(text string, name string) string {
	mut out := []string{}
	mut saw := false
	for line in text.split_into_lines() {
		if line.trim_space().starts_with('name:') {
			out << 'name: ${name}'
			saw = true
		} else {
			out << line
		}
	}
	if !saw {
		out.insert(0, 'name: ${name}')
	}
	return out.join('\n') + '\n'
}

fn patch_loop_yaml_with_overrides(path string, overrides LoopMeta) {
	mut text := os.read_file(path) or { return }
	mut lines := text.split_into_lines()
	mut out := []string{}
	mut has_tier := false
	mut has_cadence := false
	mut has_max_tokens := false
	for line in lines {
		t := line.trim_space()
		if t.starts_with('tier:') && overrides.tier.len > 0 {
			out << 'tier: ${overrides.tier}'
			has_tier = true
			continue
		}
		if t.starts_with('cadence:') && overrides.cadence.len > 0 && overrides.cadence != '?' {
			out << 'cadence: ${overrides.cadence}'
			has_cadence = true
			continue
		}
		if t.starts_with('max_tokens:') && overrides.max_tokens > 0 {
			out << '  max_tokens: ${overrides.max_tokens}'
			// also handle top-level max_tokens without indent
			if !line.starts_with(' ') {
				out[out.len - 1] = 'max_tokens: ${overrides.max_tokens}'
			}
			has_max_tokens = true
			continue
		}
		if t.starts_with('max_runs_per_day:') && overrides.max_runs_per_day > 0 {
			out << '  max_runs_per_day: ${overrides.max_runs_per_day}'
			if !line.starts_with(' ') {
				out[out.len - 1] = 'max_runs_per_day: ${overrides.max_runs_per_day}'
			}
			continue
		}
		if t.starts_with('max_wall_seconds:') && overrides.max_wall_seconds > 0 {
			out << '  max_wall_seconds: ${overrides.max_wall_seconds}'
			if !line.starts_with(' ') {
				out[out.len - 1] = 'max_wall_seconds: ${overrides.max_wall_seconds}'
			}
			continue
		}
		if t.starts_with('allowlist:') && overrides.allowlist.len > 0 {
			out << 'allowlist: [${overrides.allowlist.join(', ')}]'
			// skip original list items (next lines starting with - )
			continue
		}
		if t.starts_with('deny:') && overrides.deny.len > 0 {
			out << 'deny: [${overrides.deny.join(', ')}]'
			continue
		}
		// skip old allowlist/deny dash items if we already emitted replacement
		if (t.starts_with('- ') && out.len > 0 && out[out.len - 1].contains('allowlist: [')) {
			continue
		}
		if (t.starts_with('- ') && out.len > 0 && out[out.len - 1].contains('deny: [')) {
			continue
		}
		out << line
	}
	if !has_tier && overrides.tier.len > 0 {
		out << 'tier: ${overrides.tier}'
	}
	if !has_cadence && overrides.cadence.len > 0 && overrides.cadence != '?' {
		out << 'cadence: ${overrides.cadence}'
	}
	// ensure budget block exists for missing keys
	if overrides.max_tokens > 0 && !has_max_tokens {
		out << 'budget:'
		out << '  max_tokens: ${overrides.max_tokens}'
		if overrides.max_runs_per_day > 0 {
			out << '  max_runs_per_day: ${overrides.max_runs_per_day}'
		}
		if overrides.max_wall_seconds > 0 {
			out << '  max_wall_seconds: ${overrides.max_wall_seconds}'
		}
	}
	os.write_file(path, out.join('\n') + '\n') or {}
}

fn resolve_loop_dir(ws string, name string) ?string {
	p := os.join_path(loops_dir(ws), name)
	if os.is_dir(p) && (os.is_file(os.join_path(p, 'loop.yaml')) || os.is_file(os.join_path(p, 'LOOP.md'))) {
		return p
	}
	return none
}

fn list_loop_dirs(ws string) []string {
	dir := loops_dir(ws)
	if !os.is_dir(dir) {
		return []
	}
	mut out := []string{}
	mut names := os.ls(dir) or { return out }
	names.sort()
	for n in names {
		p := os.join_path(dir, n)
		if os.is_dir(p) && (os.is_file(os.join_path(p, 'loop.yaml')) || os.is_file(os.join_path(p, 'LOOP.md'))) {
			out << p
		}
	}
	return out
}

pub fn bundled_loop_dirs() []string {
	mut out := []string{}
	root := find_toolkit_root() or { return out }
	bundled := os.join_path(root.path, 'loops')
	if !os.is_dir(bundled) {
		return out
	}
	mut names := os.ls(bundled) or { return out }
	names.sort()
	for n in names {
		p := os.join_path(bundled, n)
		if os.is_dir(p) && os.is_file(os.join_path(p, 'loop.yaml')) {
			out << p
		}
	}
	return out
}

fn parse_loop_meta(loop_dir string) LoopMeta {
	mut text := ''
	yaml_path := os.join_path(loop_dir, 'loop.yaml')
	md_path := os.join_path(loop_dir, 'LOOP.md')
	if os.is_file(yaml_path) {
		text = os.read_file(yaml_path) or { '' }
	} else if os.is_file(md_path) {
		text = os.read_file(md_path) or { '' }
	}
	return parse_loop_meta_text(text, os.file_name(loop_dir))
}

pub fn parse_loop_meta_text(text string, default_name string) LoopMeta {
	mut m := LoopMeta{
		name: default_name
		tier: 'L1'
		cadence: '?'
		max_runs_per_day: 10
		max_wall_seconds: 600
		attribution_enabled: true
		attribution_template: ''
	}
	mut in_allow := false
	mut in_deny := false
	mut in_budget := false
	mut in_attribution := false
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('#') || t.len == 0 {
			if t.len == 0 {
				in_allow = false
				in_deny = false
			}
			continue
		}
		if t.starts_with('- ') && in_allow {
			m.allowlist << t[2..].clone().trim_space()
			continue
		}
		if t.starts_with('- ') && in_deny {
			m.deny << t[2..].clone().trim_space()
			continue
		}
		// handle budget: nested keys indented 2 spaces — we treat max_* at any indent if in_budget
		if in_budget && (t.starts_with('max_tokens:') || t.starts_with('max_runs_per_day:') || t.starts_with('max_wall_seconds:')) {
			if t.starts_with('max_tokens:') {
				m.max_tokens = t.all_after('max_tokens:').trim_space().int()
			} else if t.starts_with('max_runs_per_day:') {
				m.max_runs_per_day = t.all_after('max_runs_per_day:').trim_space().int()
			} else if t.starts_with('max_wall_seconds:') {
				m.max_wall_seconds = t.all_after('max_wall_seconds:').trim_space().int()
			}
			continue
		}
		// handle attribution object: enabled/template nested under `attribution:`
		if in_attribution && (t.starts_with('enabled:') || t.starts_with('template:')) {
			if t.starts_with('enabled:') {
				raw := t.all_after('enabled:').trim_space().trim('"').trim("'").to_lower()
				m.attribution_enabled = raw !in ['0', 'false', 'no', 'off', 'disabled']
			} else if t.starts_with('template:') {
				// keep raw template, strip surrounding quotes but preserve placeholders
				mut raw := t.all_after('template:').trim_space()
				if (raw.starts_with('"') && raw.ends_with('"')) || (raw.starts_with("'") && raw.ends_with("'")) {
					raw = raw[1..raw.len - 1]
				}
				m.attribution_template = raw
				m.attribution_enabled = true
			}
			continue
		}
		in_allow = false
		in_deny = false
		// reset budget/attribution context when we hit a top-level key (no indent) that's not child
		if !line.starts_with(' ') && !line.starts_with('\t') && t.contains(':') {
			in_budget = false
			in_attribution = false
		}
		if t.starts_with('budget:') {
			in_budget = true
			continue
		}
		if t.starts_with('attribution:') {
			rest := t.all_after('attribution:').trim_space()
			if rest.len == 0 {
				// object follows on next indented lines
				in_attribution = true
				continue
			}
			// strip quotes for comparison/value
			trimmed := rest.trim('"').trim("'")
			low := rest.to_lower().trim('"').trim("'").trim_space()
			if low in ['false', '0', 'no', 'off', 'disabled', 'none'] {
				m.attribution_enabled = false
				m.attribution_template = ''
			} else if low in ['true', '1', 'yes', 'on', 'enabled'] {
				m.attribution_enabled = true
				m.attribution_template = ''
			} else if rest.starts_with('"') || rest.starts_with("'") {
				m.attribution_enabled = true
				m.attribution_template = trimmed
			} else if rest.len > 0 {
				// raw template string without quotes (e.g. attribution: "> custom ...")
				m.attribution_enabled = true
				m.attribution_template = rest
			}
			continue
		}
		if t.starts_with('name:') {
			m.name = t.all_after('name:').trim_space()
		} else if t.starts_with('tier:') {
			m.tier = t.all_after('tier:').trim_space()
		} else if t.starts_with('cadence:') {
			m.cadence = t.all_after('cadence:').trim_space().trim('"').trim("'")
		} else if t.starts_with('max_tokens:') {
			m.max_tokens = t.all_after('max_tokens:').trim_space().int()
		} else if t.starts_with('max_runs_per_day:') {
			m.max_runs_per_day = t.all_after('max_runs_per_day:').trim_space().int()
		} else if t.starts_with('max_wall_seconds:') {
			m.max_wall_seconds = t.all_after('max_wall_seconds:').trim_space().int()
		} else if t.starts_with('allowlist:') {
			rest := t.all_after('allowlist:').trim_space()
			if rest.starts_with('[') {
				inner := rest.trim('[]')
				for part in inner.split(',') {
					v := part.trim_space().trim('"').trim("'")
					if v.len > 0 {
						m.allowlist << v
					}
				}
			} else {
				in_allow = true
			}
		} else if t.starts_with('deny:') {
			rest := t.all_after('deny:').trim_space()
			if rest.starts_with('[') {
				inner := rest.trim('[]')
				for part in inner.split(',') {
					v := part.trim_space().trim('"').trim("'")
					if v.len > 0 {
						m.deny << v
					}
				}
			} else {
				in_deny = true
			}
		} else if t.starts_with('goal:') {
			m.goal = t.all_after('goal:').trim_space().trim('|').trim_space()
		} else if t.starts_with('request:') {
			m.request = t.all_after('request:').trim_space().trim('|').trim_space()
		}
	}
	return m
}

fn parse_pack_overrides(pack_text string, loop_name string) LoopMeta {
	// strategy 1: direct meta overrides (pack is loop.yaml-like)
	// strategy 2: loop_overrides: block
	// strategy 3: loops/<name>: block with nested budget
	// we try to extract the relevant snippet and parse via parse_loop_meta_text
	mut snippet := pack_text
	// handle loop_overrides: wrapper (Python fbb2280 pack.py loop_overrides)
	if pack_text.contains('loop_overrides:') {
		idx := pack_text.index('loop_overrides:') or { -1 }
		if idx >= 0 {
			after := pack_text[idx + 'loop_overrides:'.len..].clone()
			mut lines := []string{}
			for line in after.split_into_lines() {
				if line.trim_space().len == 0 {
					lines << line
					continue
				}
				// loop_overrides is top-level; its children are indented 2 spaces — strip 2
				if line.starts_with('  ') {
					lines << line[2..].clone()
				} else if line.starts_with('\t') {
					lines << line[1..].clone()
				} else if line.trim_space().starts_with('#') {
					lines << line
				} else if line.len > 0 && !line.starts_with(' ') && line.contains(':') {
					// next top-level key ends block
					break
				} else {
					lines << line
				}
			}
			snippet = lines.join('\n')
		}
	} else if pack_text.contains('loops:') {
		// Python new pack format: loops: { <loop_name>: { tier, budget, ... } }
		mut found := false
		mut lines := []string{}
		mut in_target := false
		mut base_indent := 0
		for line in pack_text.split_into_lines() {
			trim := line.trim_space()
			if !in_target {
				if trim == '${loop_name}:' || trim.starts_with('${loop_name}:') {
					in_target = true
					base_indent = line.len - line.trim_space().len
					// handle inline budget like `budget: {max_tokens: 500}`
					rest := trim.all_after('${loop_name}:').trim_space()
					if rest.len > 0 && rest != '|' {
						// unlikely inline; ignore
					}
					found = true
					continue
				}
			} else {
				if trim.len == 0 {
					lines << ''
					continue
				}
				mut indent := 0
				for ch in line {
					if ch == ` ` || ch == `\t` {
						indent++
					} else {
						break
					}
				}
				if indent <= base_indent && trim.contains(':') {
					break
				}
				// strip 2 or 4 spaces depending on nesting
				stripped := if line.len > base_indent + 2 {
					line[base_indent + 2..].clone()
				} else {
					line.trim_space()
				}
				lines << stripped
			}
		}
		if found {
			snippet = lines.join('\n')
		}
	}
	return parse_loop_meta_text(snippet, loop_name)
}

fn tokens_from_trace_text(text string) int {
	mut total := 0
	for line in text.split_into_lines() {
		if line.len == 0 {
			continue
		}
		if line.contains('prompt_tokens') || line.contains('completion_tokens') || line.contains('total_tokens') {
			// best-effort integer extraction for keys prompt_tokens / completion_tokens / total_tokens / total
			// we look for `"prompt_tokens": <num>` etc.
			for key in ['prompt_tokens', 'completion_tokens', 'total_tokens', '"total"'] {
				search := '"${key}":'
				mut idx := 0
				for {
					pos := line[idx..].index(search) or { break }
					abs_pos := idx + pos + search.len
					rest := line[abs_pos..].trim_space()
					mut num_str := ''
					for ch in rest {
						if ch >= `0` && ch <= `9` {
							num_str += ch.ascii_str()
						} else if num_str.len > 0 {
							break
						}
					}
					if num_str.len > 0 {
						total += num_str.int()
					}
					idx = abs_pos + 1
					if idx >= line.len {
						break
					}
				}
			}
		}
		if line.contains('"tokens_used"') {
			// budget_exhausted trace
			search := '"tokens_used":'
			if pos := line.index(search) {
				rest := line[pos + search.len..].trim_space()
				mut num_str := ''
				for ch in rest {
					if ch >= `0` && ch <= `9` {
						num_str += ch.ascii_str()
					} else if num_str.len > 0 {
						break
					}
				}
				if num_str.len > 0 {
					total += num_str.int()
				}
			}
		}
	}
	return total
}

fn total_tokens_for_loop(loop_dir string) int {
	rd := os.join_path(loop_dir, 'runs')
	if !os.is_dir(rd) {
		return 0
	}
	mut total := 0
	for name in os.ls(rd) or { []string{} } {
		trace := os.join_path(rd, name, 'trace.jsonl')
		if !os.is_file(trace) {
			continue
		}
		text := os.read_file(trace) or { continue }
		total += tokens_from_trace_text(text)
	}
	return total
}

fn total_wall_for_loop(loop_dir string) int {
	// wall budget parity: sum of run wall times if recorded as `"wall": <secs>` or `"wall_used":`
	// fallback: if we have no wall data, use run count * 60 as rough estimate for budget check
	// Python budget.py wall_timeout_seconds vs trace.jsonl wall — we check explicit wall field
	rd := os.join_path(loop_dir, 'runs')
	if !os.is_dir(rd) {
		return 0
	}
	mut total := 0
	mut has_wall := false
	for name in os.ls(rd) or { []string{} } {
		trace := os.join_path(rd, name, 'trace.jsonl')
		if !os.is_file(trace) {
			continue
		}
		text := os.read_file(trace) or { continue }
		for line in text.split_into_lines() {
			if line.contains('"wall"') || line.contains('wall_used') {
				for key in ['"wall":', '"wall_used":', '"duration":'] {
					if pos := line.index(key) {
						rest := line[pos + key.len..].trim_space()
						mut num_str := ''
						for ch in rest {
							if ch >= `0` && ch <= `9` {
								num_str += ch.ascii_str()
							} else if num_str.len > 0 {
								break
							}
						}
						if num_str.len > 0 {
							total += num_str.int()
							has_wall = true
						}
					}
				}
			}
		}
	}
	if !has_wall {
		// no explicit wall data -> estimate from run count for tiny budgets (e.g., max_wall_seconds=1)
		// return 0 so we don't falsely exhaust; gate only triggers when pack/loop sets wall to tiny value + we have at least 1 run
		// caller checks `wall_used >0 && wall_used >= max` so this returns 0 and won't exhaust unless wall data present
		return 0
	}
	return total
}

fn write_state_md(loop_dir string, last_run string, last_status string, last_id string, runs_today int, escalations []string) {
	mut lines := []string{}
	lines << '---'
	lines << 'last_run: ${last_run}'
	lines << 'last_run_status: ${last_status}'
	lines << 'last_run_id: ${last_id}'
	lines << 'runs_today: ${runs_today}'
	lines << 'pending: []'
	if escalations.len == 0 {
		lines << 'escalations: []'
	} else {
		lines << 'escalations:'
		for e in escalations {
			lines << '  - ${e}'
		}
	}
	lines << '---'
	lines << ''
	os.write_file(os.join_path(loop_dir, 'STATE.md'), lines.join('\n') + '\n') or {}
}

fn read_state_md(loop_dir string) (string, string, string, int, []string) {
	path := os.join_path(loop_dir, 'STATE.md')
	if !os.is_file(path) {
		return 'never', 'not_run', '', 0, []string{}
	}
	text := os.read_file(path) or { return 'never', 'not_run', '', 0, []string{} }
	mut last_run := 'never'
	mut last_status := 'not_run'
	mut last_id := ''
	mut runs_today := 0
	mut escalations := []string{}
	mut in_esc := false
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('last_run:') && !t.starts_with('last_run_') {
			last_run = t.all_after('last_run:').trim_space()
		} else if t.starts_with('last_run_status:') {
			last_status = t.all_after('last_run_status:').trim_space()
		} else if t.starts_with('last_run_id:') {
			last_id = t.all_after('last_run_id:').trim_space()
		} else if t.starts_with('runs_today:') {
			runs_today = t.all_after('runs_today:').trim_space().int()
		} else if t.starts_with('escalations:') {
			in_esc = true
			rest := t.all_after('escalations:').trim_space()
			if rest == '[]' {
				in_esc = false
			}
		} else if in_esc && t.starts_with('- ') {
			escalations << t[2..].clone().trim_space()
		} else if t == '---' {
			in_esc = false
		}
	}
	return last_run, last_status, last_id, runs_today, escalations
}

fn count_runs(loop_dir string) int {
	rd := os.join_path(loop_dir, 'runs')
	if !os.is_dir(rd) {
		return 0
	}
	entries := os.ls(rd) or { return 0 }
	return entries.len
}

fn audit_loop_dir(loop_dir string) (int, int, int) {
	rd := os.join_path(loop_dir, 'runs')
	if !os.is_dir(rd) {
		return 0, 0, 0
	}
	mut completed := 0
	mut failed := 0
	mut tokens := 0
	for name in os.ls(rd) or { []string{} } {
		trace := os.join_path(rd, name, 'trace.jsonl')
		if !os.is_file(trace) {
			continue
		}
		text := os.read_file(trace) or { continue }
		for line in text.split_into_lines() {
			if line.contains('"kind":"run_end"') {
				if line.contains('"status":"completed"') {
					completed++
				} else {
					failed++
				}
			}
			if line.contains('prompt_tokens') {
				// best-effort; skeleton traces have none
			}
		}
	}
	_ = tokens
	return completed, failed, tokens
}

fn loop_run_id() string {
	rfc := time.utc().format_rfc3339()
	date := rfc[..10].clone().replace('-', '')
	clock := if rfc.len >= 19 { rfc[11..19].clone().replace(':', '') } else { '000000' }
	return '${date}T${clock}Z'
}

fn skeleton_loop_plan(name string, meta LoopMeta, rid string) string {
	return '# Plan — ${name} (${rid})\n\n**Generated**: ${time.utc().format_rfc3339()}\n**Mode**: skeleton (no LLM) — ADR-020 fail-closed\n**Tier**: ${meta.tier}\n**Cadence**: ${meta.cadence}\n\n## Goal\n\n${meta.goal}\n\n## Request\n\n${meta.request}\n\n## Steps\n\n- [ ] Read loop.yaml and STATE.md\n- [ ] Honour allowlist/deny and tier gates\n- [ ] Produce report.md\n- [ ] Update STATE.md\n'
}
