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
	task           string
	reason         string
	dry_run        bool
	force          bool
}

// SwarmReport is the domain result for swarm subcommands.
pub struct SwarmReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

struct SwarmStateFile {
	version    int
	run_id     string
	recipe     string
	backend    string
	run_state  string
	created_at string
	task       string
}

struct SwarmApprovalsFile {
	gates []SwarmGate
}

// run_swarm implements recipes/backends/doctor/start/list/status/approve/reject/cancel.
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
    agent-toolkit swarm start [--recipe pair|team|full] [--backend auto|herdr|tmux|headless] [--dry-run] [task]
    agent-toolkit swarm list
    agent-toolkit swarm status [run-id]
    agent-toolkit swarm approve <run-id> <gate>
    agent-toolkit swarm reject <run-id> <gate> --reason TEXT
    agent-toolkit swarm cancel <run-id>
    agent-toolkit swarm help

Backends: herdr (recommended), tmux (Unix fallback), headless (filesystem only).
Windows: tmux/herdr unsupported; use --backend headless.
Concurrency: process-per-run supervisor; UI spawn is fail-closed without ProcessService stdin.
State: .agent-toolkit/swarm/runs/<run-id>/ (state.json, approvals.json, trace.jsonl).
'
}

fn find_swarm_workspace(override string) string {
	if override.len > 0 && os.is_dir(override) {
		return override
	}
	if ws := find_workspace_root(override) {
		return ws
	}
	if git := find_git_root('') {
		return git
	}
	return os.getwd()
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
	rid := swarm_new_run_id()
	if opts.dry_run {
		return SwarmReport{
			ok:      true
			message: '[swarm] dry-run start recipe=${recipe} backend=${backend} run_id=${rid}\n  roles: ${swarm_recipe_roles(recipe).join(', ')}\n  no filesystem writes; UI spawn skipped (ADR-020 fail-closed)'
			data:    {
				'subcommand': 'start'
				'mode':       'dry-run'
				'recipe':     recipe
				'backend':    backend
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
	initial := if swarm_require_plan_approval(recipe) {
		'awaiting_plan_approval'
	} else {
		'running'
	}
	st := SwarmStateFile{
		version:    1
		run_id:     rid
		recipe:     recipe
		backend:    backend
		run_state:  initial
		created_at: time.utc().format_rfc3339()
		task:       opts.task
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
	return SwarmReport{
		ok:      true
		message: '[swarm] started ${rid} recipe=${recipe} backend=${backend} state=${initial}\n  ${run_dir}\n  UI spawn fail-closed (ADR-020); filesystem state is authoritative (ADR-008).'
		data:    {
			'subcommand': 'start'
			'run_id':     rid
			'recipe':     recipe
			'backend':    backend
			'run_state':  initial
			'workspace':  ws
		}
	}
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
