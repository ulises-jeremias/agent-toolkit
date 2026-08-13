module agent_toolkit_core

import json
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
}

// LoopReport is the domain result for loop subcommands.
pub struct LoopReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

struct LoopMeta {
mut:
	name             string
	tier             string
	cadence          string
	goal             string
	request          string
	max_tokens       int
	max_runs_per_day int
	max_wall_seconds int
	allowlist        []string
	deny             []string
}

// run_loop implements init/run/status/audit/cost/schedule/sync/list/templates.
pub fn run_loop(opts LoopOptions) LoopReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return LoopReport{
			ok:      true
			message: loop_help_text()
			data:    {
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
			loop_sync(ws)
		}
		'list', 'ls' {
			loop_list(ws)
		}
		'templates' {
			loop_templates(ws)
		}
		else {
			LoopReport{
				ok:      false
				message: "Unknown command: ${sub}\nRun 'agent-toolkit loop help' for usage."
				data:    {
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
		ok:      report.ok
		message: report.message
		data:    data
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
    agent-toolkit loop schedule <loop> [--dry-run] [--cron EXPR] [--list] [--remove]
    agent-toolkit loop sync
    agent-toolkit loop templates
    agent-toolkit loop help

loop run options:
    --force       Bypass max_runs_per_day only (not wall/token budgets)
    --quiet       Suppress live runner output
    --pack PATH   Apply loop overrides from pack YAML
    --workspace PATH  Workspace root override
    --runner NAME auto|skeleton (LLM PATH runners fail closed to skeleton without stdin)
    --no-llm      Alias for --runner skeleton (no network)
    --json        Structured CommandResult JSON

Concurrency: one OS process per iteration via ProcessService; no Python threads / no `go` workers.
Schedule: systemd/launchd on Unix; not supported on Windows.
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
			ok:      false
			message: lines.join('\n')
			data:    {
				'subcommand': 'init'
				'workspace':  ws
			}
		}
	}
	loop_name := if opts.custom_name.len > 0 { opts.custom_name } else { pattern }
	dest := os.join_path(loops_dir(ws), loop_name)
	if os.exists(dest) {
		return LoopReport{
			ok:      false
			message: "Loop '${loop_name}' already exists at ${dest}"
			data:    {
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
			ok:      false
			message: lines.join('\n')
			data:    {
				'subcommand': 'init'
				'workspace':  ws
			}
		}
	}
	os.mkdir_all(os.join_path(dest, 'runs')) or {
		return LoopReport{
			ok:      false
			message: 'mkdir failed: ${err}'
		}
	}
	rewritten := rewrite_loop_name(text, loop_name)
	os.write_file(os.join_path(dest, 'loop.yaml'), rewritten) or {
		return LoopReport{
			ok:      false
			message: 'write loop.yaml failed: ${err}'
		}
	}
	write_state_md(dest, 'never', 'not_run', '', 0, []string{})
	return LoopReport{
		ok:      true
		message: "[loop] Initialized loop '${loop_name}' at loops/${loop_name}\n\n  Edit loops/${loop_name}/loop.yaml to customize.\n  Then run: agent-toolkit loop run ${loop_name}"
		data:    {
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
			ok:      false
			message: 'Usage: agent-toolkit loop run <loop-name> [--force] [--runner skeleton] [--no-llm]'
			data:    {
				'subcommand': 'run'
				'workspace':  ws
			}
		}
	}
	loop_dir := resolve_loop_dir(ws, loop_name) or {
		return LoopReport{
			ok:      false
			message: "Loop '${loop_name}' not found. Run: agent-toolkit loop init ${loop_name}"
			data:    {
				'subcommand': 'run'
				'workspace':  ws
			}
		}
	}
	meta := parse_loop_meta(loop_dir)
	max_runs := if meta.max_runs_per_day > 0 { meta.max_runs_per_day } else { 10 }
	mut last_run, _, _, mut runs_today, escalations := read_state_md(loop_dir)
	if last_run.len > 0 && last_run != 'never' {
		today := time.utc().format_rfc3339()[..10]
		if last_run.len >= 10 && last_run[..10] != today {
			runs_today = 0
		}
	}
	if runs_today >= max_runs && !opts.force {
		return LoopReport{
			ok:      true
			message: '[loop] Budget: max_runs_per_day (${max_runs}) reached for today. Skipping.\n  Re-run with: agent-toolkit loop run <loop> --force'
			data:    {
				'subcommand': 'run'
				'workspace':  ws
				'name':       loop_name
				'status':     'budget_skip'
			}
		}
	}
	rid := loop_run_id()
	run_dir := os.join_path(loop_dir, 'runs', rid)
	os.mkdir_all(run_dir) or {
		return LoopReport{
			ok:      false
			message: 'mkdir run dir failed: ${err}'
		}
	}
	wall := if meta.max_wall_seconds > 0 { meta.max_wall_seconds } else { 600 }
	use_skeleton := opts.no_llm || opts.runner in ['skeleton', ''] || opts.runner == 'auto'
	mut lines := []string{}
	lines << '[loop] Running ${loop_name} (tier=${meta.tier} cadence=${meta.cadence})'
	lines << '[loop] ADR-020 process-per-run; skeleton fail-closed without ProcessService stdin'
	plan_path := os.join_path(run_dir, 'plan.md')
	plan := skeleton_loop_plan(loop_name, meta, rid)
	os.write_file(plan_path, plan) or {
		return LoopReport{
			ok:      false
			message: 'write plan failed: ${err}'
		}
	}
	trace := '{"kind":"run_end","status":"completed","runner":"skeleton","run_id":${json.encode(rid)}}\n'
	os.write_file(os.join_path(run_dir, 'trace.jsonl'), trace) or {}
	write_state_md(loop_dir, time.utc().format_rfc3339(), 'completed', rid, runs_today + 1,
		escalations)
	lines << '[loop] Skeleton plan written → ${plan_path}'
	lines << '[loop] wall budget ${wall}s (not consumed by skeleton)'
	_ = use_skeleton
	return LoopReport{
		ok:      true
		message: lines.join('\n')
		data:    {
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
				ok:      false
				message: "Loop '${opts.name}' not found."
				data:    {
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
			ok:      true
			message: 'No loops found. Run: agent-toolkit loop init <pattern>'
			data:    {
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
		ok:      true
		message: lines.join('\n')
		data:    {
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
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'audit'
			'workspace':  ws
			'count':      '${dirs.len}'
		}
	}
}

fn loop_cost(ws string, opts LoopOptions) LoopReport {
	if opts.name.len == 0 {
		return LoopReport{
			ok:      false
			message: 'Usage: agent-toolkit loop cost <loop-name>'
			data:    {
				'subcommand': 'cost'
			}
		}
	}
	loop_dir := resolve_loop_dir(ws, opts.name) or {
		return LoopReport{
			ok:      false
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
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'cost'
			'workspace':  ws
			'name':       opts.name
			'tier':       meta.tier
		}
	}
}

fn loop_schedule(ws string, opts LoopOptions) LoopReport {
	$if windows {
		return LoopReport{
			ok:      false
			message: 'loop schedule is Unix-only (systemd/launchd). Not supported on Windows.'
			data:    {
				'subcommand': 'schedule'
			}
		}
	}
	if opts.name.len == 0 {
		return LoopReport{
			ok:      false
			message: 'Usage: agent-toolkit loop schedule <loop-name> [--dry-run]'
		}
	}
	unit := '[Unit]\nDescription=agent-toolkit loop ${opts.name}\n\n[Service]\nType=oneshot\nExecStart=agent-toolkit loop run ${opts.name}\n\n[Install]\nWantedBy=default.target\n'
	if opts.dry_run || opts.list_mode {
		return LoopReport{
			ok:      true
			message: '[loop] schedule dry-run (systemd user unit):\n${unit}'
			data:    {
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
			ok:      false
			message: 'write unit failed: ${err}'
		}
	}
	return LoopReport{
		ok:      true
		message: '[loop] Wrote ${path}\nEnable with: systemctl --user enable --now agent-toolkit-loop-${opts.name}.service'
		data:    {
			'subcommand': 'schedule'
			'workspace':  ws
			'name':       opts.name
			'path':       path
		}
	}
}

fn loop_sync(ws string) LoopReport {
	mut entries := []string{}
	for d in list_loop_dirs(ws) {
		_, _, _, _, escalations := read_state_md(d)
		for esc in escalations {
			entries << '- [ ] [loop-escalation] ${os.file_name(d)}: ${esc}'
		}
	}
	if entries.len == 0 {
		return LoopReport{
			ok:      true
			message: '[loop] No loop escalations to sync.'
			data:    {
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
			ok:      false
			message: 'write todos failed: ${err}'
		}
	}
	return LoopReport{
		ok:      true
		message: '[loop] Synced ${entries.len} escalation(s) to knowledge/todos/pending.md'
		data:    {
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
		ok:      true
		message: lines.join('\n')
		data:    {
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
		ok:      true
		message: lines.join('\n')
		data:    {
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

fn resolve_loop_dir(ws string, name string) ?string {
	p := os.join_path(loops_dir(ws), name)
	if os.is_dir(p) && (os.is_file(os.join_path(p, 'loop.yaml'))
		|| os.is_file(os.join_path(p, 'LOOP.md'))) {
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
		if os.is_dir(p) && (os.is_file(os.join_path(p, 'loop.yaml'))
			|| os.is_file(os.join_path(p, 'LOOP.md'))) {
			out << p
		}
	}
	return out
}

fn bundled_loop_dirs() []string {
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
	mut m := LoopMeta{
		name:             os.file_name(loop_dir)
		tier:             'L1'
		cadence:          '?'
		max_runs_per_day: 10
		max_wall_seconds: 600
	}
	mut in_allow := false
	mut in_deny := false
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
		in_allow = false
		in_deny = false
		if t.starts_with('name:') {
			m.name = t.all_after('name:').trim_space()
		} else if t.starts_with('tier:') {
			m.tier = t.all_after('tier:').trim_space()
		} else if t.starts_with('cadence:') {
			m.cadence = t.all_after('cadence:').trim_space().trim('"')
		} else if t.starts_with('max_tokens:') {
			m.max_tokens = t.all_after('max_tokens:').trim_space().int()
		} else if t.starts_with('max_runs_per_day:') {
			m.max_runs_per_day = t.all_after('max_runs_per_day:').trim_space().int()
		} else if t.starts_with('max_wall_seconds:') {
			m.max_wall_seconds = t.all_after('max_wall_seconds:').trim_space().int()
		} else if t.starts_with('allowlist:') {
			in_allow = true
		} else if t.starts_with('deny:') {
			in_deny = true
		} else if t.starts_with('goal:') {
			m.goal = t.all_after('goal:').trim_space().trim('|').trim_space()
		} else if t.starts_with('request:') {
			m.request = t.all_after('request:').trim_space().trim('|').trim_space()
		}
	}
	return m
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
	return '# Plan — ${name} (${rid})

**Generated**: ${time.utc().format_rfc3339()}
**Mode**: skeleton (no LLM) — ADR-020 fail-closed
**Tier**: ${meta.tier}
**Cadence**: ${meta.cadence}

## Goal

${meta.goal}

## Request

${meta.request}

## Steps

- [ ] Read loop.yaml and STATE.md
- [ ] Honour allowlist/deny and tier gates
- [ ] Produce report.md
- [ ] Update STATE.md
'
}
