module agent_toolkit_core

import json
import os
import time

const mutating_dc_templates = ['create-pr', 'fix-ci', 'refactor', 'implement', 'investigate']

// DevcompanionOptions configures the devcompanion / dc command family (#525).
pub struct DevcompanionOptions {
pub:
	subcommand     string
	workspace_path string
	arg            string // project name or job id
	template       string
	request        string
	job_id         string
	no_llm         bool
}

// DevcompanionReport is the domain result for queue subcommands.
pub struct DevcompanionReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

struct DcJob {
pub mut:
	id           string
	created_at   string
	project      string
	project_path string
	repo_path    string
	request      string
	template     string
	status       string
	completed_at string
	llm          bool
}

struct DcConfig {
	harness_mode     bool
	dc_home          string
	queue_dir        string
	runs_dir         string
	queue_pending    string
	queue_processing string
	queue_done       string
	queue_failed     string
}

// run_devcompanion implements queue/run-once/status/done/sync-todos/llm-status (Python cli/devcompanion.py).
pub fn run_devcompanion(opts DevcompanionOptions) DevcompanionReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		ws := find_devcompanion_workspace(opts.workspace_path)
		cfg := get_dc_config(ws)
		return DevcompanionReport{
			ok:      true
			message: devcompanion_help_text(cfg)
			data:    {
				'subcommand': 'help'
				'workspace':  ws
			}
		}
	}
	ws := find_devcompanion_workspace(opts.workspace_path)
	cfg := get_dc_config(ws)
	return match sub {
		'queue' { dc_queue(ws, cfg, opts) }
		'run-once' { dc_run_once(cfg, opts) }
		'status' { dc_status(cfg, ws) }
		'done' { dc_done(cfg, opts) }
		'sync-todos' { dc_sync_todos(ws, cfg) }
		'llm-status' { dc_llm_status() }
		else {
			DevcompanionReport{
				ok:      false
				message: "Unknown subcommand: ${sub}\nRun 'agent-toolkit devcompanion help' for usage."
				data:    {
					'subcommand': sub
					'workspace':  ws
				}
			}
		}
	}
}

// devcompanion_result maps DevcompanionReport to CommandResult.
pub fn devcompanion_result(report DevcompanionReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = ''
	}
	return CommandResult{
		command: 'devcompanion'
		ok:      report.ok
		message: report.message
		data:    data
	}
}

// devcompanion_help_text matches Python cli/devcompanion.py help.
pub fn devcompanion_help_text(cfg DcConfig) string {
	mode := if cfg.harness_mode { 'harness (.job files)' } else { 'workspace (.json files)' }
	queue_loc := if cfg.harness_mode {
		os.join_path(cfg.dc_home, 'queue')
	} else {
		cfg.queue_dir
	}
	return 'agent-toolkit devcompanion — background job queue for AI Workspace

Usage:
  agent-toolkit devcompanion queue <project> [options]   Queue a job
  agent-toolkit devcompanion run-once [--no-llm]         Run oldest pending job
  agent-toolkit devcompanion status                      Show all jobs
  agent-toolkit devcompanion done <job-id>               Mark a job as done
  agent-toolkit devcompanion sync-todos                  Sync todos from plan.md files
  agent-toolkit devcompanion llm-status                  Report LLM allowlist/provider

Queue options:
  --template NAME    Job template from templates/jobs/ directory
  --request "..."    Custom request string (required if no --template)
  --id ID            Custom job ID (default: <project>-<timestamp>)

Workspace detection:
  AGENT_TOOLKIT_WORKSPACE env var, or walk up from CWD looking for .devcompanion/

Queue mode:
  ${mode}
  HARNESS_RUNNER_DIR or HARNESS_DC_HOME or HARNESS_DIR → harness queue under ~/.local/share/agentic-harness/dev-companion

Queue location:
  ${queue_loc}

Runs location:
  ${cfg.runs_dir}

Examples:
  agent-toolkit devcompanion queue my-api --template code-review
  agent-toolkit devcompanion queue my-api --request "add pagination to GET /users"
  agent-toolkit devcompanion run-once
  agent-toolkit devcompanion run-once --no-llm
  agent-toolkit devcompanion status
  agent-toolkit devcompanion done my-api-20260804-120000
  agent-toolkit devcompanion sync-todos
  agent-toolkit devcompanion llm-status

Alias:
  agent-toolkit dc <subcommand>
'
}

pub fn dc_help_text() string {
	ws := find_devcompanion_workspace('')
	return devcompanion_help_text(get_dc_config(ws))
}

fn find_devcompanion_workspace(override string) string {
	if override.len > 0 && os.is_dir(override) {
		return override
	}
	if ws := find_workspace_root(override) {
		return ws
	}
	mut cur := os.getwd()
	for {
		if os.is_dir(os.join_path(cur, '.devcompanion')) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	return os.getwd()
}

fn default_harness_dc_home() string {
	return os.join_path(os.home_dir(), '.local', 'share', 'agentic-harness', 'dev-companion')
}

fn resolve_harness_dc_home() ?string {
	runner := os.getenv('HARNESS_RUNNER_DIR').trim_space()
	if runner.len > 0 {
		return os.expand_tilde_to_home(runner)
	}
	explicit := os.getenv('HARNESS_DC_HOME').trim_space()
	if explicit.len > 0 {
		return os.expand_tilde_to_home(explicit)
	}
	if os.getenv('HARNESS_DIR').trim_space().len > 0 {
		return default_harness_dc_home()
	}
	// HARNESS_RUNNER_DIR may be set via env presence without value is indistinguishable via getenv,
	// but Python also treats HARNESS_RUNNER_DIR presence as harness_mode.
	// Fallback: if HARNESS_RUNNER_DIR is set (even empty string after trim) we already handled non-empty case;
	// empty implies not set, so no harness.
	return none
}

fn get_dc_config(workspace_root string) DcConfig {
	if home := resolve_harness_dc_home() {
		queue_root := os.join_path(home, 'queue')
		return DcConfig{
			harness_mode:     true
			dc_home:          home
			queue_dir:        queue_root
			runs_dir:         os.join_path(queue_root, 'artifacts')
			queue_pending:    os.join_path(queue_root, 'pending')
			queue_processing: os.join_path(queue_root, 'processing')
			queue_done:       os.join_path(queue_root, 'done')
			queue_failed:     os.join_path(queue_root, 'failed')
		}
	}
	dc_home := os.join_path(workspace_root, '.devcompanion')
	queue_dir := os.join_path(dc_home, 'queue')
	return DcConfig{
		harness_mode:     false
		dc_home:          dc_home
		queue_dir:        queue_dir
		runs_dir:         os.join_path(dc_home, 'runs')
		queue_pending:    queue_dir
		queue_processing: queue_dir
		queue_done:       queue_dir
		queue_failed:     queue_dir
	}
}

fn utc_now() string {
	rfc := time.utc().format_rfc3339()
	if rfc.ends_with('Z') {
		return rfc
	}
	if rfc.len >= 19 {
		return rfc[..19] + 'Z'
	}
	return rfc
}

fn job_id_stamp() string {
	rfc := time.utc().format_rfc3339()
	date := rfc[..10].replace('-', '')
	clock := if rfc.len >= 19 { rfc[11..19].replace(':', '') } else { '000000' }
	return '${date}-${clock}'
}

fn dc_queue(ws string, cfg DcConfig, opts DevcompanionOptions) DevcompanionReport {
	project := opts.arg
	if project.len == 0 {
		return DevcompanionReport{
			ok:      false
			message: 'Usage: agent-toolkit devcompanion queue <project> [--template NAME] [--request "..."]'
			data:    {
				'subcommand': 'queue'
				'workspace':  ws
			}
		}
	}
	project_path := resolve_dc_project(ws, project) or {
		mut lines := []string{}
		lines << "Project not found: '${project}'"
		known := list_dc_projects(ws)
		if known.len > 0 {
			lines << ''
			lines << 'Known projects:'
			for name, target in known {
				if target.len > 0 {
					lines << '  ${name} → ${target}'
				} else {
					lines << '  ${name} → (broken)'
				}
			}
		} else {
			lines << '  (no projects indexed)'
		}
		return DevcompanionReport{
			ok:      false
			message: lines.join('\n')
			data:    {
				'subcommand': 'queue'
				'workspace':  ws
			}
		}
	}
	mut request := ''
	if opts.template.len > 0 {
		tpl := load_dc_template(ws, opts.template) or {
			return DevcompanionReport{
				ok:      false
				message: err.msg()
				data:    {
					'subcommand': 'queue'
					'workspace':  ws
				}
			}
		}
		request = tpl
		if opts.request.len > 0 {
			request = '${request}\n\n---\n\n${opts.request}'
		}
	} else if opts.request.len > 0 {
		request = opts.request
	} else {
		return DevcompanionReport{
			ok:      false
			message: 'Provide --request or --template'
			data:    {
				'subcommand': 'queue'
				'workspace':  ws
			}
		}
	}
	job_id := if opts.job_id.len > 0 { opts.job_id } else { '${project}-${job_id_stamp()}' }
	job_file := queue_job_path(cfg, job_id)
	if cfg.harness_mode {
		os.mkdir_all(cfg.queue_pending) or {}
		body := '{
  "id": ${json.encode(job_id)},
  "created_at": ${json.encode(utc_now())},
  "request": ${json.encode(request)},
  "repo_path": ${json.encode(project_path)},
  "llm": true,
  "limits": {"timeout_sec": 1800, "max_steps": 25},
  "actions_allowed": ["plan_only"]
}
'
		os.write_file(job_file, body) or {
			return DevcompanionReport{
				ok:      false
				message: 'write job failed: ${err}'
			}
		}
	} else {
		os.mkdir_all(cfg.queue_dir) or {}
		job := DcJob{
			id:           job_id
			created_at:   utc_now()
			project:      project
			project_path: project_path
			request:      request
			template:     opts.template
			status:       'pending'
		}
		write_dc_job(job_file, job) or {
			return DevcompanionReport{
				ok:      false
				message: 'write job failed: ${err}'
			}
		}
	}
	mut lines := []string{}
	lines << '[devcompanion] Project : ${project}'
	lines << '[devcompanion] Path    : ${project_path}'
	lines << '[devcompanion] Job ID  : ${job_id}'
	lines << '[devcompanion] Job written → ${job_file}'
	lines << ''
	lines << 'Plan stub:'
	lines << "  Run 'agent-toolkit devcompanion run-once' to execute"
	lines << "  Run 'agent-toolkit devcompanion status' to check progress"
	return DevcompanionReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'queue'
			'workspace':  ws
			'job_id':     job_id
			'project':    project
		}
	}
}

fn dc_run_once(cfg DcConfig, opts DevcompanionOptions) DevcompanionReport {
	pending := pending_dc_jobs(cfg)
	if pending.len == 0 {
		return DevcompanionReport{
			ok:      true
			message: '[devcompanion] No pending jobs.'
			data:    {
				'subcommand': 'run-once'
				'count':      '0'
			}
		}
	}
	mut job_file := pending[0].path
	mut job := pending[0].job
	job_id := if job.id.len > 0 { job.id } else { os.file_name(job_file).all_before_last('.') }
	out_dir := os.join_path(cfg.runs_dir, job_id)
	mut lines := []string{}
	lines << '[devcompanion] Running job: ${job_id}'
	lines << '[devcompanion] Project    : ${dc_job_project_name(job)}'
	lines << '[devcompanion] Artifacts  → ${out_dir}'
	if cfg.harness_mode {
		os.mkdir_all(cfg.queue_processing) or {}
		processing := os.join_path(cfg.queue_processing, os.file_name(job_file))
		os.mv(job_file, processing) or {}
		job_file = processing
	} else {
		job.status = 'running'
		write_dc_job(job_file, job) or {}
	}
	rc, extra := dispatch_dc_run(cfg, job_file, job, out_dir, opts.no_llm)
	lines << extra
	if cfg.harness_mode {
		dest_dir := if rc == 0 { cfg.queue_done } else { cfg.queue_failed }
		os.mkdir_all(dest_dir) or {}
		if os.exists(job_file) {
			os.mv(job_file, os.join_path(dest_dir, os.file_name(job_file))) or {}
		}
	} else {
		job.status = if rc == 0 { 'done' } else { 'failed' }
		job.completed_at = utc_now()
		write_dc_job(job_file, job) or {}
	}
	if rc == 0 {
		lines << '[devcompanion] Job done: ${job_id}'
		plan_path := os.join_path(out_dir, 'plan.md')
		if os.is_file(plan_path) {
			plan := os.read_file(plan_path) or { '' }
			clip := if plan.len > 2000 { plan[..2000] } else { plan }
			lines << ''
			lines << '── plan.md ──────────────────────────────────────────────────'
			lines << clip
		}
		return DevcompanionReport{
			ok:      true
			message: lines.join('\n')
			data:    {
				'subcommand': 'run-once'
				'job_id':     job_id
				'status':     'done'
			}
		}
	}
	lines << '[devcompanion] Job failed: ${job_id}'
	return DevcompanionReport{
		ok:      false
		message: lines.join('\n')
		data:    {
			'subcommand': 'run-once'
			'job_id':     job_id
			'status':     'failed'
		}
	}
}

fn dc_status(cfg DcConfig, ws string) DevcompanionReport {
	jobs := iter_dc_jobs(cfg)
	mut lines := []string{}
	lines << ''
	lines << '=== devcompanion queue status ==='
	lines << ''
	if jobs.len == 0 {
		lines << '  (queue is empty)'
		lines << ''
		return DevcompanionReport{
			ok:      true
			message: lines.join('\n')
			data:    {
				'subcommand': 'status'
				'workspace':  ws
				'count':      '0'
			}
		}
	}
	if cfg.harness_mode {
		for state in ['pending', 'processing', 'done', 'failed'] {
			mut n := 0
			mut shown := 0
			for item in jobs {
				if item.status != state {
					continue
				}
				n++
			}
			lines << '${state} ${n} job(s)'
			for item in jobs {
				if item.status != state {
					continue
				}
				if shown >= 5 {
					continue
				}
				jid := if item.job.id.len > 0 {
					item.job.id
				} else {
					os.file_name(item.path).all_before_last('.')
				}
				req := item.job.request.all_before('\n')
				clip := if req.len > 60 { req[..60] } else { req }
				lines << '  ${jid} [${dc_job_project_name(item.job)}] ${clip}'
				shown++
			}
			if n > 5 {
				lines << '  … and ${n - 5} more'
			}
			lines << ''
		}
	} else {
		lines << 'JOB ID                                      PROJECT               STATUS        CREATED AT'
		for item in jobs {
			jid := if item.job.id.len > 0 {
				item.job.id
			} else {
				os.file_name(item.path).all_before_last('.')
			}
			lines << '${jid}  ${dc_job_project_name(item.job)}  ${item.status}  ${item.job.created_at}'
		}
		lines << ''
	}
	return DevcompanionReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'status'
			'workspace':  ws
			'count':      '${jobs.len}'
		}
	}
}

fn dc_done(cfg DcConfig, opts DevcompanionOptions) DevcompanionReport {
	job_id := opts.arg
	if job_id.len == 0 {
		return DevcompanionReport{
			ok:      false
			message: 'Usage: agent-toolkit devcompanion done <job-id>'
			data:    {
				'subcommand': 'done'
			}
		}
	}
	if cfg.harness_mode {
		if mark_job_done(cfg, job_id, utc_now()) {
			return DevcompanionReport{
				ok:      true
				message: '[devcompanion] Marked as done: ${job_id}'
				data:    {
					'subcommand': 'done'
					'job_id':     job_id
					'status':     'done'
				}
			}
		}
		return DevcompanionReport{
			ok:      false
			message: '[devcompanion] Job file not found: ${job_id}.job'
			data:    {
				'subcommand': 'done'
				'job_id':     job_id
			}
		}
	}
	job_file := find_job_path(cfg, job_id) or {
		return DevcompanionReport{
			ok:      false
			message: '[devcompanion] Job file not found: ${job_id}.json'
			data:    {
				'subcommand': 'done'
				'job_id':     job_id
			}
		}
	}
	mut job := read_dc_job(job_file) or {
		return DevcompanionReport{
			ok:      false
			message: 'unreadable job: ${err}'
		}
	}
	job.status = 'done'
	job.completed_at = utc_now()
	write_dc_job(job_file, job) or {
		return DevcompanionReport{
			ok:      false
			message: 'write job failed: ${err}'
		}
	}
	return DevcompanionReport{
		ok:      true
		message: '[devcompanion] Marked as done: ${job_id}'
		data:    {
			'subcommand': 'done'
			'job_id':     job_id
			'status':     'done'
		}
	}
}

fn dc_sync_todos(ws string, cfg DcConfig) DevcompanionReport {
	mut todos := []string{}
	collect_plan_todos(cfg.runs_dir, mut todos)
	knowledge := os.join_path(ws, 'knowledge', 'todos', 'pending.md')
	if todos.len == 0 {
		return DevcompanionReport{
			ok:      true
			message: "[devcompanion] No '- [ ]' items found in run plans."
			data:    {
				'subcommand': 'sync-todos'
				'workspace':  ws
				'count':      '0'
			}
		}
	}
	os.mkdir_all(os.dir(knowledge)) or {}
	existing := if os.is_file(knowledge) { os.read_file(knowledge) or { '' } } else { '' }
	block := '\n## Synced from devcompanion runs\n\n' + todos.join('\n') + '\n'
	marker := '\n## Synced from devcompanion runs\n'
	mut text := ''
	if existing.contains(marker) {
		idx := existing.index(marker) or { existing.len }
		text = existing[..idx] + block
	} else if existing.len > 0 {
		text = existing.trim_right(' \n\t\r') + '\n' + block
	} else {
		text = block
	}
	os.write_file(knowledge, text) or {
		return DevcompanionReport{
			ok:      false
			message: 'write todos failed: ${err}'
		}
	}
	return DevcompanionReport{
		ok:      true
		message: '[devcompanion] Synced ${todos.len} todo(s) → ${knowledge}'
		data:    {
			'subcommand': 'sync-todos'
			'workspace':  ws
			'count':      '${todos.len}'
		}
	}
}

fn dc_llm_status() DevcompanionReport {
	mut allowlist := os.getenv('DOTS_AI_DEVCOMPANION_LLM_ALLOWLIST').trim_space()
	if allowlist.len == 0 {
		allowlist = 'anthropic,openai'
	}
	strict_raw := os.getenv('DOTS_AI_DEVCOMPANION_LLM_STRICT').trim_space()
	strict := strict_raw == '1'
	have_anthropic := os.getenv('ANTHROPIC_API_KEY').trim_space().len > 0
	have_openai := os.getenv('OPENAI_API_KEY').trim_space().len > 0
	have_key := have_anthropic || have_openai
	provider := if have_key { 'anthropic' } else { 'none' }
	offline := !have_key
	// Build JSON payload matching Python: {"allowlist":..., "strict":..., "have_key":..., "provider":..., "offline":...}
	payload := '{"allowlist":${json.encode(allowlist)},"strict":${strict},"have_key":${have_key},"provider":${json.encode(provider)},"offline":${offline}}'
	return DevcompanionReport{
		ok:      true
		message: payload
		data:    {
			'subcommand': 'llm-status'
			'allowlist':  allowlist
			'strict':     '${strict}'
			'have_key':   '${have_key}'
			'provider':   provider
			'offline':    '${offline}'
		}
	}
}

fn dispatch_dc_run(_cfg DcConfig, _job_file string, job DcJob, out_dir string, no_llm bool) (int, string) {
	if no_llm {
		return skeleton_run(job, out_dir)
	}
	if job_is_mutating(job) && !exe_on_path('gh') {
		tpl := if job.template.len > 0 { job.template } else { 'custom' }
		return 2, '[devcompanion] Mutating devcompanion job requires `gh` on PATH for loop-gh-gate (template=${tpl})'
	}
	// ProcessService has no stdin yet, so PATH LLM binaries are not invoked (would hang
	// without the Python prompt pipe). Fall back to the same skeleton as --no-llm.
	rc, msg := skeleton_run(job, out_dir)
	return rc, '[devcompanion] No LLM runner found, falling back to skeleton plan.\n${msg}'
}

fn skeleton_run(job DcJob, out_dir string) (int, string) {
	os.mkdir_all(out_dir) or {
		return 1, '[devcompanion] Skeleton runner failed: ${err}'
	}
	job_id := if job.id.len > 0 { job.id } else { 'unknown' }
	project := dc_job_project_name(job)
	request := if job.request.len > 0 { job.request } else { '(no request)' }
	path := dc_job_project_path(job)
	plan := '# Plan — ${job_id}

**Generated**: ${utc_now()}
**Mode**: skeleton (no LLM)
**Project**: ${project}

## Request

${request}

## Steps

> This is a skeleton plan. Run without --no-llm for AI-generated steps.

- [ ] Read project README and AGENTS.md
- [ ] Understand existing conventions and patterns
- [ ] Analyse the request in context
- [ ] Implement changes following project conventions
- [ ] Run tests and verify
- [ ] Create PR

## Notes

- Job ID: ${job_id}
- Project path: ${if path.len > 0 { path } else { 'not set' }}
'
	plan_path := os.join_path(out_dir, 'plan.md')
	os.write_file(plan_path, plan) or {
		return 1, '[devcompanion] Skeleton runner failed: ${err}'
	}
	return 0, '[devcompanion] Skeleton plan written → ${plan_path}'
}

fn job_is_mutating(job DcJob) bool {
	if job.template in mutating_dc_templates {
		return true
	}
	return false
}

fn exe_on_path(name string) bool {
	os.find_abs_path_of_executable(name) or { return false }
	return true
}

fn resolve_dc_project(ws string, name string) ?string {
	projects_dir := os.join_path(ws, 'projects')
	if !os.is_dir(projects_dir) {
		return none
	}
	link := os.join_path(projects_dir, name)
	if os.is_link(link) {
		target := os.readlink(link) or { return none }
		abs := if os.is_abs_path(target) { target } else { os.join_path(os.dir(link), target) }
		if os.is_dir(abs) {
			return os.real_path(abs)
		}
		return none
	}
	entries := os.ls(projects_dir) or { return none }
	for entry in entries {
		p := os.join_path(projects_dir, entry)
		if os.is_link(p) && entry.contains(name) {
			target := os.readlink(p) or { continue }
			abs := if os.is_abs_path(target) { target } else { os.join_path(os.dir(p), target) }
			if os.is_dir(abs) {
				return os.real_path(abs)
			}
		}
	}
	return none
}

fn list_dc_projects(ws string) map[string]string {
	mut out := map[string]string{}
	projects_dir := os.join_path(ws, 'projects')
	if !os.is_dir(projects_dir) {
		return out
	}
	mut names := os.ls(projects_dir) or { return out }
	names.sort()
	for name in names {
		p := os.join_path(projects_dir, name)
		if !os.is_link(p) {
			continue
		}
		target := os.readlink(p) or { '' }
		abs := if os.is_abs_path(target) { target } else { os.join_path(os.dir(p), target) }
		if os.is_dir(abs) {
			out[name] = os.real_path(abs)
		} else {
			out[name] = ''
		}
	}
	return out
}

fn load_dc_template(ws string, name string) !string {
	tpl_file := os.join_path(ws, 'templates', 'jobs', '${name}.yaml')
	if !os.is_file(tpl_file) {
		return error('Template not found: ${name}  (looked in templates/jobs/)')
	}
	text := os.read_file(tpl_file) or { return error('read template failed: ${err}') }
	lines := text.split_into_lines()
	for i, line in lines {
		stripped := line.trim_space()
		if stripped.starts_with('#') {
			continue
		}
		if stripped == 'request: |' || stripped.starts_with('request: |') {
			mut block := []string{}
			for j in i + 1 .. lines.len {
				bl := lines[j]
				if bl.len > 0 && !bl.starts_with(' ') && !bl.starts_with('\t') && !bl.starts_with('#') {
					break
				}
				if bl.trim_space().starts_with('#') {
					continue
				}
				block << if bl.starts_with('  ') { bl[2..] } else { bl }
			}
			return block.join('\n').trim_space()
		}
		if stripped.starts_with('request:') {
			return stripped.all_after('request:').trim_space().trim('"\'')
		}
	}
	return ''
}

struct DcJobItem {
	status string
	path   string
	job    DcJob
}

fn pending_dc_jobs(cfg DcConfig) []DcJobItem {
	mut items := []DcJobItem{}
	dir := if cfg.harness_mode { cfg.queue_pending } else { cfg.queue_dir }
	os.mkdir_all(dir) or {}
	entries := os.ls(dir) or { return items }
	mut paths := []string{}
	for name in entries {
		p := os.join_path(dir, name)
		if cfg.harness_mode {
			if name.ends_with('.job') {
				paths << p
			}
		} else if name.ends_with('.json') {
			paths << p
		}
	}
	paths.sort_with_compare(fn (a &string, b &string) int {
		ma := os.file_last_mod_unix(*a)
		mb := os.file_last_mod_unix(*b)
		if ma < mb {
			return -1
		}
		if ma > mb {
			return 1
		}
		return 0
	})
	for p in paths {
		job := read_dc_job(p) or { continue }
		if cfg.harness_mode {
			items << DcJobItem{
				status: 'pending'
				path:   p
				job:    job
			}
		} else if job.status == 'pending' {
			items << DcJobItem{
				status: 'pending'
				path:   p
				job:    job
			}
		}
	}
	return items
}

fn iter_dc_jobs(cfg DcConfig) []DcJobItem {
	mut items := []DcJobItem{}
	if cfg.harness_mode {
		states := {
			'pending':    cfg.queue_pending
			'processing': cfg.queue_processing
			'done':       cfg.queue_done
			'failed':     cfg.queue_failed
		}
		for state, directory in states {
			if !os.is_dir(directory) {
				continue
			}
			entries := os.ls(directory) or { continue }
			for name in entries {
				if !name.ends_with('.job') {
					continue
				}
				p := os.join_path(directory, name)
				job := read_dc_job(p) or { continue }
				items << DcJobItem{
					status: state
					path:   p
					job:    job
				}
			}
		}
	} else if os.is_dir(cfg.queue_dir) {
		entries := os.ls(cfg.queue_dir) or { []string{} }
		for name in entries {
			if !name.ends_with('.json') {
				continue
			}
			p := os.join_path(cfg.queue_dir, name)
			job := read_dc_job(p) or { continue }
			st := if job.status.len > 0 { job.status } else { '?' }
			items << DcJobItem{
				status: st
				path:   p
				job:    job
			}
		}
	}
	items.sort_with_compare(fn (a &DcJobItem, b &DcJobItem) int {
		ma := os.file_last_mod_unix(a.path)
		mb := os.file_last_mod_unix(b.path)
		if ma < mb {
			return -1
		}
		if ma > mb {
			return 1
		}
		return 0
	})
	return items
}

fn queue_job_path(cfg DcConfig, job_id string) string {
	if cfg.harness_mode {
		return os.join_path(cfg.queue_pending, '${job_id}.job')
	}
	return os.join_path(cfg.queue_dir, '${job_id}.json')
}

fn find_job_path(cfg DcConfig, job_id string) ?string {
	if cfg.harness_mode {
		for directory in [cfg.queue_pending, cfg.queue_processing, cfg.queue_done, cfg.queue_failed] {
			p := os.join_path(directory, '${job_id}.job')
			if os.exists(p) {
				return p
			}
		}
		return none
	}
	p := os.join_path(cfg.queue_dir, '${job_id}.json')
	if os.exists(p) {
		return p
	}
	return none
}

fn mark_job_done(cfg DcConfig, job_id string, completed_at string) bool {
	if cfg.harness_mode {
		for src_dir in [cfg.queue_pending, cfg.queue_processing, cfg.queue_failed] {
			src := os.join_path(src_dir, '${job_id}.job')
			if os.exists(src) {
				os.mkdir_all(cfg.queue_done) or {}
				os.mv(src, os.join_path(cfg.queue_done, '${job_id}.job')) or { return false }
				return true
			}
		}
		return os.exists(os.join_path(cfg.queue_done, '${job_id}.job'))
	}
	path := os.join_path(cfg.queue_dir, '${job_id}.json')
	if !os.exists(path) {
		return false
	}
	mut job := read_dc_job(path) or { return false }
	job.status = 'done'
	job.completed_at = completed_at
	write_dc_job(path, job) or { return false }
	return true
}

fn read_dc_job(path string) !DcJob {
	text := os.read_file(path) or { return error('read failed: ${err}') }
	job := json.decode(DcJob, text) or { return error('decode failed: ${err}') }
	return job
}

fn write_dc_job(path string, job DcJob) ! {
	os.mkdir_all(os.dir(path)) or { return err }
	payload := json.encode(job)
	os.write_file(path, payload + '\n') or { return err }
}

fn dc_job_project_path(job DcJob) string {
	if job.project_path.len > 0 {
		return job.project_path
	}
	return job.repo_path
}

fn dc_job_project_name(job DcJob) string {
	if job.project.len > 0 {
		return job.project
	}
	p := dc_job_project_path(job)
	if p.len == 0 {
		return '?'
	}
	return os.file_name(p)
}

fn collect_plan_todos(dir string, mut todos []string) {
	if !os.is_dir(dir) {
		return
	}
	entries := os.ls(dir) or { return }
	for name in entries {
		p := os.join_path(dir, name)
		if os.is_dir(p) {
			collect_plan_todos(p, mut todos)
			continue
		}
		if name != 'plan.md' {
			continue
		}
		text := os.read_file(p) or { continue }
		for line in text.split_into_lines() {
			if line.trim_space().starts_with('- [ ]') {
				todos << line.trim_space()
			}
		}
	}
}
