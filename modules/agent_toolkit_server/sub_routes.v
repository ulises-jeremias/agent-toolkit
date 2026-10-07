module agent_toolkit_server

// Typed request bodies for the generic `/api/v1/<family>/:sub` routes.
//
// Each family decodes its own DTO (which never carries a subcommand: the
// route path is authoritative), validates path-like and name-like fields,
// and maps the result onto the core Options struct. Builders are pure
// functions of (sub, body) so they are unit-testable without a server.
//
// The allowlists and DTO fields are mirrored by `api_subcommands` /
// `api_body` in docs/compatibility/cli-contract.yaml (OpenAPI source);
// tests/test_surface_parity.py fails on drift between the two.
import agent_toolkit_core
import net.http
import os
import veb
import x.json2

// SubRouteError is a rejected :sub request with the HTTP status to return.
pub struct SubRouteError {
	Error
pub:
	status http.Status
	reason string
}

pub fn (e SubRouteError) msg() string {
	return e.reason
}

fn sub_err(status http.Status, reason string) IError {
	return SubRouteError{
		status: status
		reason: reason
	}
}

// sub_route_allowlist is the per-family set of subcommands reachable over
// HTTP. Deliberately excluded (still available from the CLI):
// - loops gate-exec / gate-issue-receipt / gate-check: read the server
//   process argv/env (gate secret); not request-scoped;
// - loops run: use POST /api/v1/loops/{name}/run (job-backed, streamable)
//   instead of blocking a server worker for the whole loop;
// - swarms attach: execvp()s tmux/herdr, replacing the server process.
const sub_route_allowlist = {
	'skills':    ['list', 'sync', 'validate', 'help']
	'mcp':       ['list', 'setup', 'health', 'doctor', 'uninstall', 'help']
	'plugin':    ['sync', 'check', 'help']
	'workspace': ['init', 'context', 'sync', 'use-persona', 'handoff', 'history', 'personas', 'load',
		'profiles', 'validate', 'budget', 'help']
	'memory':    ['add', 'search', 'inject', 'review', 'todo', 'help']
	'project':   ['init', 'clone', 'list', 'add', 'remove', 'scan', 'help']
	'loops':     ['init', 'status', 'audit', 'cost', 'schedule', 'sync', 'list', 'ls', 'templates',
		'help']
	'dc':        ['queue', 'run-once', 'status', 'done', 'sync-todos', 'llm-status', 'help']
	'swarms':    ['recipes', 'recipe', 'backends', 'doctor', 'runners', 'models', 'start', 'init',
		'plan', 'activate', 'deactivate', 'promote', 'list', 'status', 'approve', 'reject', 'cancel',
		'pause', 'resume', 'stop', 'cleanup', 'graph', 'handoff', 'task', 'watch', 'report',
		'artifacts', 'handoffs', 'logs', 'approvals', 'prune', 'help']
}

const max_text_field = 4096
const max_long_text_field = 65536

fn check_sub(family string, sub string) ! {
	allowed := sub_route_allowlist[family] or { []string{} }
	if sub !in allowed {
		return sub_err(.not_found, 'unknown ${family} subcommand: ${sub}')
	}
}

// decode_sub_body decodes a JSON object body into T. An empty body keeps the
// pre-typed behavior (all defaults); anything else must be a JSON object.
fn decode_sub_body[T](body string) !T {
	trimmed := body.trim_space()
	if trimmed.len == 0 {
		return T{}
	}
	if !trimmed.starts_with('{') {
		return sub_err(.bad_request, 'request body must be a JSON object')
	}
	// The decoder message embeds terminal color codes and echoes the body;
	// keep the response stable and non-reflective.
	return json2.decode[T](trimmed) or { return sub_err(.bad_request, 'invalid JSON body') }
}

fn is_ident_char(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
		|| ch == `_` || ch == `-` || ch == `.`
}

fn has_only(value string, extra string) bool {
	for ch in value {
		if !is_ident_char(ch) && !extra.contains_u8(ch) {
			return false
		}
	}
	return true
}

fn bad_field(field string) IError {
	return sub_err(.bad_request, 'invalid ${field}')
}

// check_ident accepts names/ids: [A-Za-z0-9._-], no leading '-' or '.',
// no '..'. Empty means unset.
fn check_ident(field string, value string) ! {
	if value.len == 0 {
		return
	}
	if value.len > 128 || value.starts_with('-') || value.starts_with('.') || value.contains('..')
		|| !has_only(value, '') {
		return bad_field(field)
	}
}

// check_slug accepts an ident or an OWNER/REPO pair of idents.
fn check_slug(field string, value string) ! {
	parts := value.split('/')
	if parts.len > 2 {
		return bad_field(field)
	}
	for part in parts {
		if value.len > 0 && part.len == 0 {
			return bad_field(field)
		}
		check_ident(field, part)!
	}
}

// check_model accepts provider/model ids such as `anthropic/claude:latest`.
fn check_model(field string, value string) ! {
	if value.len == 0 {
		return
	}
	if value.len > 200 || value.starts_with('-') || value.contains('..') || !has_only(value, '/:@+') {
		return bad_field(field)
	}
}

// check_git_ref accepts branch/ref names; rejects option-like and traversal.
fn check_git_ref(field string, value string) ! {
	if value.len == 0 {
		return
	}
	if value.len > 200 || value.starts_with('-') || value.starts_with('/') || value.contains('..')
		|| !has_only(value, '/') {
		return bad_field(field)
	}
}

fn check_commit(field string, value string) ! {
	if value.len == 0 {
		return
	}
	if value.len < 4 || value.len > 64 {
		return bad_field(field)
	}
	for ch in value {
		if !((ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `f`) || (ch >= `A` && ch <= `F`)) {
			return bad_field(field)
		}
	}
}

// check_issue_ref accepts `OWNER/REPO#N` or an issue URL.
fn check_issue_ref(field string, value string) ! {
	if value.len == 0 {
		return
	}
	if value.len > 300 || value.starts_with('-') || value.contains('..') || !has_only(value, '/#:') {
		return bad_field(field)
	}
}

// check_cron keeps schedule expressions single-line (they land in timer
// units/workflows).
fn check_cron(field string, value string) ! {
	if value.len == 0 {
		return
	}
	if value.len > 128 || !has_only(value, '*/,?#@ ') {
		return bad_field(field)
	}
}

// check_text bounds free-form text and rejects NUL bytes.
fn check_text(field string, value string, max int) ! {
	if value.len > max || value.contains('\x00') {
		return bad_field(field)
	}
}

// check_single_line is check_text without line breaks (names, titles).
fn check_single_line(field string, value string, max int) ! {
	check_text(field, value, max)!
	if value.contains('\n') || value.contains('\r') {
		return bad_field(field)
	}
}

fn check_non_negative(field string, value int) ! {
	if value < 0 {
		return bad_field(field)
	}
}

fn check_enum(field string, value string, allowed []string) ! {
	if value.len > 0 && value !in allowed {
		return bad_field(field)
	}
}

// check_path_ref accepts a pack/artifact/project reference: a relative path
// without traversal (resolved by core against the workspace), or an
// absolute path that exists inside the allowed roots.
fn check_path_ref(field string, value string) ! {
	if value.len == 0 {
		return
	}
	if value.len > 1024 || value.contains('..') || value.contains('%') || value.contains('\x00')
		|| value.contains('\\') || value.starts_with('-') || value.starts_with('~') {
		return bad_field(field)
	}
	if os.is_abs_path(value) {
		if !os.exists(value) {
			return sub_err(.not_found, '${field} not found: ${value}')
		}
		if !is_under_allowed_roots(value) {
			return sub_err(.forbidden, '${field} outside allowed roots')
		}
	}
}

// resolve_body_workspace validates a workspace-like directory field with the
// same semantics as POST /api/v1/jobs: traversal 400, missing 404, outside
// the allowed roots (symlinks resolved) 403. Empty returns `fallback`.
fn resolve_body_workspace(field string, path string, fallback string) !string {
	if path.len == 0 {
		return fallback
	}
	if path.contains('..') || path.contains('%') || path.contains('\x00') {
		return sub_err(.bad_request, 'invalid ${field} path')
	}
	if !os.is_dir(path) {
		return sub_err(.not_found, '${field} not found: ${path}')
	}
	if !is_allowed_workspace(path) {
		return sub_err(.forbidden, '${field} outside allowed roots')
	}
	return path
}

fn default_workspace() string {
	return agent_toolkit_core.find_workspace_root('') or { os.getwd() }
}

// ---------------------------------------------------------------------------
// Per-family DTOs and builders
// ---------------------------------------------------------------------------

struct SkillsSubReq {
	domain string
	tools  []string
}

pub fn build_skills_options(sub string, body string) !agent_toolkit_core.SkillsOptions {
	check_sub('skills', sub)!
	req := decode_sub_body[SkillsSubReq](body)!
	check_ident('domain', req.domain)!
	if req.tools.len > 32 {
		return bad_field('tools')
	}
	for tool in req.tools {
		if tool.len == 0 {
			return bad_field('tools')
		}
		check_ident('tools', tool)!
	}
	return agent_toolkit_core.SkillsOptions{
		subcommand: sub
		domain: req.domain
		tools: req.tools
	}
}

struct McpSubReq {
	provider string
	offline  bool
}

pub fn build_mcp_options(sub string, body string) !agent_toolkit_core.McpOptions {
	check_sub('mcp', sub)!
	req := decode_sub_body[McpSubReq](body)!
	check_ident('provider', req.provider)!
	return agent_toolkit_core.McpOptions{
		subcommand: sub
		provider: req.provider
		offline: req.offline
	}
}

// PluginSubReq has no fields: plugin sync/check take no request options, but
// the body is still decoded so malformed JSON is rejected consistently.
struct PluginSubReq {}

pub fn build_plugin_options(sub string, body string) !agent_toolkit_core.PluginOptions {
	check_sub('plugin', sub)!
	decode_sub_body[PluginSubReq](body)!
	return agent_toolkit_core.PluginOptions{
		subcommand: sub
	}
}

struct WorkspaceSubReq {
	workspace string
	dir       string
	name      string
	explain   bool
	arg       string
	profile   string
	pack      string
}

pub fn build_workspace_options(sub string, body string) !agent_toolkit_core.WorkspaceOptions {
	check_sub('workspace', sub)!
	req := decode_sub_body[WorkspaceSubReq](body)!
	ws := resolve_body_workspace('workspace', req.workspace, '')!
	dir := resolve_body_workspace('dir', req.dir, '')!
	check_single_line('name', req.name, 128)!
	check_ident('profile', req.profile)!
	check_path_ref('pack', req.pack)!
	// arg is overloaded by core: pack path (load), history count, persona or
	// validate surface name.
	match sub {
		'load' {
			check_path_ref('arg', req.arg)!
		}
		'history' {
			if req.arg.len > 0 && (req.arg.len > 6 || !req.arg.is_int() || req.arg.int() < 0) {
				return bad_field('arg')
			}
		}
		else {
			check_ident('arg', req.arg)!
		}
	}
	return agent_toolkit_core.WorkspaceOptions{
		subcommand: sub
		workspace_path: ws
		dir: dir
		name: req.name
		explain: req.explain
		arg: req.arg
		profile: req.profile
		pack: req.pack
	}
}

struct MemorySubReq {
	workspace   string
	entry_type  string
	title       string
	content     string
	query       string
	stale_after int
	fix         bool
	show_done   bool
}

pub fn build_memory_options(sub string, body string) !agent_toolkit_core.MemoryOptions {
	check_sub('memory', sub)!
	req := decode_sub_body[MemorySubReq](body)!
	ws := resolve_body_workspace('workspace', req.workspace, '')!
	check_enum('entry_type', req.entry_type, ['learning', 'process', 'todo'])!
	check_single_line('title', req.title, 512)!
	check_text('content', req.content, max_long_text_field)!
	check_single_line('query', req.query, 1024)!
	check_non_negative('stale_after', req.stale_after)!
	return agent_toolkit_core.MemoryOptions{
		subcommand: sub
		workspace_path: ws
		entry_type: req.entry_type
		title: req.title
		content: req.content
		query: req.query
		stale_after: req.stale_after
		fix: req.fix
		show_done: req.show_done
	}
}

struct ProjectSubReq {
	workspace string
	arg       string
	ssh       bool
}

pub fn build_project_options(sub string, body string) !agent_toolkit_core.ProjectOptions {
	check_sub('project', sub)!
	req := decode_sub_body[ProjectSubReq](body)!
	ws := resolve_body_workspace('workspace', req.workspace, '')!
	// arg: a repository path for `add`, OWNER/REPO for `clone`, a name otherwise.
	if sub == 'add' {
		check_path_ref('arg', req.arg)!
	} else {
		check_slug('arg', req.arg)!
	}
	return agent_toolkit_core.ProjectOptions{
		subcommand: sub
		workspace_path: ws
		arg: req.arg
		ssh: req.ssh
	}
}

struct LoopsSubReq {
	workspace   string
	name        string
	custom_name string
	force       bool
	runner      string
	model       string
	pack        string
	no_llm      bool
	dry_run     bool
	cron        string
	platform    string
	list_mode   bool
	remove_mode bool
	status_mode bool
}

pub fn build_loops_options(sub string, body string) !agent_toolkit_core.LoopOptions {
	check_sub('loops', sub)!
	req := decode_sub_body[LoopsSubReq](body)!
	ws := resolve_body_workspace('workspace', req.workspace, default_workspace())!
	if req.name.len > 0 && !is_valid_loop_name(req.name) {
		return bad_field('name')
	}
	if req.custom_name.len > 0 && !is_valid_loop_name(req.custom_name) {
		return bad_field('custom_name')
	}
	check_ident('runner', req.runner)!
	check_model('model', req.model)!
	check_path_ref('pack', req.pack)!
	check_cron('cron', req.cron)!
	check_enum('platform', req.platform, ['local', 'github-actions'])!
	return agent_toolkit_core.LoopOptions{
		subcommand: sub
		workspace_path: ws
		name: req.name
		custom_name: req.custom_name
		force: req.force
		runner: req.runner
		model: req.model
		pack: req.pack
		no_llm: req.no_llm
		dry_run: req.dry_run
		cron: req.cron
		platform: req.platform
		list_mode: req.list_mode
		remove_mode: req.remove_mode
		status_mode: req.status_mode
	}
}

struct DcSubReq {
	workspace string
	arg       string
	template  string
	request   string
	job_id    string
	no_llm    bool
}

pub fn build_dc_options(sub string, body string) !agent_toolkit_core.DevcompanionOptions {
	check_sub('dc', sub)!
	req := decode_sub_body[DcSubReq](body)!
	ws := resolve_body_workspace('workspace', req.workspace, default_workspace())!
	check_slug('arg', req.arg)!
	check_ident('template', req.template)!
	check_text('request', req.request, max_long_text_field)!
	check_ident('job_id', req.job_id)!
	return agent_toolkit_core.DevcompanionOptions{
		subcommand: sub
		workspace_path: ws
		arg: req.arg
		template: req.template
		request: req.request
		job_id: req.job_id
		no_llm: req.no_llm
	}
}

struct SwarmsSubReq {
	workspace     string
	run_id        string
	gate_id       string
	recipe        string
	backend       string
	runner        string
	model_profile string
	person_bindings map[string]string
	role_runners    map[string]string
	role_models     map[string]string
	launch_sessions bool
	task          string
	reason        string
	dry_run       bool
	force         bool
	current       bool
	issue_ref     string
	base_ref      string
	handoff_sub   string
	htype         string
	from_role     string
	to_role       string
	priority      int
	artifact      string
	commit        string
	branch        string
	blocking      bool
	role          string
	handoff_id    string
	to_recipe     string
	older_than    string
}

// build_swarms_options keeps role-to-Person, runner, and model choices typed
// at the HTTP boundary; canonical recipe and catalog validation stays in core.
pub fn build_swarms_options(sub string, body string) !agent_toolkit_core.SwarmOptions {
	check_sub('swarms', sub)!
	req := decode_sub_body[SwarmsSubReq](body)!
	ws := resolve_body_workspace('workspace', req.workspace, default_workspace())!
	if req.run_id.len > 0 && !agent_toolkit_core.swarm_valid_run_id(req.run_id) {
		return bad_field('run_id')
	}
	for field, value in {
		'gate_id':       req.gate_id
		'backend':       req.backend
		'runner':        req.runner
		'model_profile': req.model_profile
		'handoff_sub':   req.handoff_sub
		'htype':         req.htype
		'from_role':     req.from_role
		'to_role':       req.to_role
		'role':          req.role
		'handoff_id':    req.handoff_id
		'older_than':    req.older_than
	} {
		check_ident(field, value)!
	}
	check_path_ref('recipe', req.recipe)!
	check_path_ref('to_recipe', req.to_recipe)!
	check_path_ref('artifact', req.artifact)!
	check_text('task', req.task, max_long_text_field)!
	check_text('reason', req.reason, max_text_field)!
	check_issue_ref('issue_ref', req.issue_ref)!
	check_git_ref('base_ref', req.base_ref)!
	check_git_ref('branch', req.branch)!
	check_commit('commit', req.commit)!
	check_non_negative('priority', req.priority)!
	return agent_toolkit_core.SwarmOptions{
		subcommand: sub
		workspace_path: ws
		run_id: req.run_id
		gate_id: req.gate_id
		recipe: req.recipe
		backend: req.backend
		runner: req.runner
		model_profile: req.model_profile
		person_bindings: req.person_bindings
		role_runners: req.role_runners
		role_models: req.role_models
		launch_sessions: req.launch_sessions
		task: req.task
		reason: req.reason
		dry_run: req.dry_run
		force: req.force
		current: req.current
		issue_ref: req.issue_ref
		base_ref: req.base_ref
		handoff_sub: req.handoff_sub
		htype: req.htype
		from_role: req.from_role
		to_role: req.to_role
		priority: req.priority
		artifact: req.artifact
		commit: req.commit
		branch: req.branch
		blocking: req.blocking
		role: req.role
		handoff_id: req.handoff_id
		to_recipe: req.to_recipe
		older_than: req.older_than
		// A server request must never attach an interactive terminal.
		attach: false
		no_attach: true
	}
}

fn respond_sub_error(mut ctx Ctx, err IError) veb.Result {
	if err is SubRouteError {
		ctx.res.set_status(err.status)
		return ctx.json(DenyErr{ ok: false, error: err.reason })
	}
	ctx.res.set_status(.bad_request)
	return ctx.json(DenyErr{ ok: false, error: err.msg() })
}
