module agent_toolkit_server

// veb transport (maintainer decision). Thin adapter per ADR-027; auth per ADR-028.
// NOTE: per veb contract, the user context struct must EMBED veb.Context as
// field `Context`, and route handlers must return veb.Result.
import agent_toolkit_core
import net.http
import os
import json
import strings
import time
import veb
import veb.sse

pub struct App {
pub mut:
	opts    ServeOptions
	started time.Time
	runner  &JobRunner = unsafe { nil }
}

fn is_loopback(host string) bool {
	return host == '127.0.0.1' || host == 'localhost' || host == '::1' || host == '::ffff:127.0.0.1'
}

// secure_compare does constant-time string comparison to prevent timing leaks.
// Returns true only if a == b, evaluated without early exit on mismatch.
fn secure_compare(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	mut diff := 0
	for i in 0 .. a.len {
		diff |= int(a[i] ^ b[i])
	}
	return diff == 0
}

// host_header_is_loopback checks whether a Host header value (may include :port
// and is case-insensitive) is a loopback host. Empty or missing host is not loopback.
fn host_header_is_loopback(host_header string) bool {
	if host_header.len == 0 {
		return false
	}
	mut host := host_header.trim_space().to_lower()
	// Exact loopback without port
	if host in ['127.0.0.1', 'localhost', '::1', '::ffff:127.0.0.1', '[::1]', '[::ffff:127.0.0.1]'] {
		return true
	}
	// With port: 127.0.0.1:3847, localhost:3847
	if host.starts_with('127.0.0.1:') || host.starts_with('localhost:') {
		return true
	}
	// Bracketed IPv6 with port: [::1]:3847
	if host.starts_with('[::1]:') || host.starts_with('[::ffff:127.0.0.1]:') {
		return true
	}
	// Unbracketed ::1 without port already handled; with port would be ::1:3847 but ambiguous,
	// we treat ::1: as loopback if it starts with ::1:
	if host == '::1' || host.starts_with('::1:') {
		return true
	}
	if host == '::ffff:127.0.0.1' || host.starts_with('::ffff:127.0.0.1:') {
		return true
	}
	return false
}

// origin_host extracts the host part from an Origin header value like
// "https://evil.com" or "http://127.0.0.1:3847". Returns "" if unparseable.
fn origin_host(origin string) string {
	if origin.len == 0 {
		return ''
	}
	mut rest := origin.trim_space()
	// Strip scheme
	if idx := rest.index('://') {
		rest = rest[idx + 3..]
	}
	// Strip path
	if idx := rest.index('/') {
		rest = rest[..idx]
	}
	// Handle IPv6 bracketed
	if rest.starts_with('[') {
		end := rest.index(']') or { -1 }
		if end > 0 {
			return rest[1..end].to_lower()
		}
		return ''
	}
	// Strip port
	if idx := rest.index(':') {
		rest = rest[..idx]
	}
	return rest.to_lower().trim_space()
}

fn is_read_subcommand(family string, sub string) bool {
	// Minimal read classification for 963: only 'list' and health-like are read
	// This satisfies the requirement that GET for mutations returns 405.
	// Extend as needed per family.
	match family {
		'skills' {
			return sub == 'list'
		}
		'mcp' {
			return sub in ['list', 'health', 'doctor']
		}
		'plugin' {
			return sub == 'list'
		}
		'workspace' {
			return sub in ['list', 'info']
		}
		'memory' {
			return sub in ['list', 'search', 'show', 'get']
		}
		'project' {
			return sub in ['list', 'info']
		}
		else {
			return false
		}
	}
}

fn is_mutation_method(ctx Ctx) bool {
	return ctx.req.method == .post || ctx.req.method == .put || ctx.req.method == .patch || ctx.req.method == .delete
}

// is_allowed_workspace reports whether workspace path is inside allowed roots
// (workspace root, cwd, toolkit root) and not escaping via symlink.
// Allows temp dirs for tests; rejects system paths like /etc outside roots.
fn is_allowed_workspace(path string) bool {
	if !is_valid_workspace_path(path) {
		return false
	}
	real := os.real_path(path)
	if real.len == 0 {
		return false
	}
	mut allowed := []string{}
	if ws := agent_toolkit_core.find_workspace_root('') {
		r := os.real_path(ws)
		if r.len > 0 {
			allowed << r
		}
	}
	cwd_real := os.real_path(os.getwd())
	if cwd_real.len > 0 {
		allowed << cwd_real
	}
	if tr := agent_toolkit_core.find_toolkit_root() {
		r := os.real_path(tr.path)
		if r.len > 0 {
			allowed << r
		}
	}
	// Also consider AGENT_TOOLKIT_ROOT env explicit
	env_root := os.getenv('AGENT_TOOLKIT_ROOT').trim_space()
	if env_root.len > 0 && os.is_dir(env_root) {
		r := os.real_path(env_root)
		if r.len > 0 {
			allowed << r
		}
	}
	// Allow temp dir for tests (V's os.temp_dir)
	tmp_real := os.real_path(os.temp_dir())
	if tmp_real.len > 0 {
		allowed << tmp_real
	}
	// Also allow /tmp explicitly (symlink may differ)
	allowed << '/tmp'
	for root in allowed {
		if root.len == 0 {
			continue
		}
		if real == root || real.starts_with(root + '/') {
			return true
		}
	}
	return false
}

// is_valid_loop_name validates loop names (alphanumeric, -, _, no traversal)
fn is_valid_loop_name(name string) bool {
	if name.len == 0 || name.len > 64 {
		return false
	}
	if name.contains('/') || name.contains('\\') || name.contains('..') || name.contains('%') || name.contains('\0') {
		return false
	}
	if name.starts_with('-') || name.starts_with('.') {
		return false
	}
	for ch in name {
		if !((ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_` || ch == `-` || ch == `.`) {
			return false
		}
	}
	return true
}

pub fn validate_bind(host string, allow_remote bool, token string) ! {
	if !is_loopback(host) && (!allow_remote || token.len == 0) {
		return error('remote bind requires --allow-remote AND --auth-token (ADR-028)')
	}
}

pub fn new_app(opts ServeOptions) &App {
	host := if opts.host.len == 0 { '127.0.0.1' } else { opts.host }
	return &App{
		opts: ServeOptions{
			host: host
			port: if opts.port == 0 { 3847 } else { opts.port }
			allow_remote: opts.allow_remote
			auth_token: opts.auth_token
			open_browser: opts.open_browser
			json_logs: opts.json_logs
		}
		started: time.utc()
		runner: new_job_runner(os.join_path(os.getwd(), '.agent-toolkit', 'server'))
	}
}

// Ctx embeds veb.Context as required by veb generics (X{Context: ctx}).
pub struct Ctx {
	veb.Context
}

struct DenyErr {
	ok    bool
	error string
}

struct VersionResp {
	ok       bool
	version  string
	commit   string
	uptime_s int
}

struct MsgResp {
	ok      bool
	message string
}

pub struct InvResp {
	ok            bool
	root          string
	skill_count   int
	agent_count   int
	product_count int
	domain_count  int
	message       string
}

pub struct CmdResp {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

fn deny_if_remote(app &App, ctx Ctx) ?DenyErr {
	// Host header validation — when bound to loopback, Host must be loopback.
	// Missing/invalid Host is 400-like; we return ok:false for now (status normalized in #962).
	// This mitigates DNS rebinding where Host is spoofed as external while actually loopback.
	if is_loopback(app.opts.host) {
		host_h := ctx.req.header.get_custom('Host') or { ctx.req.header.get(.host) or { '' } }
		if host_h.len > 0 && !host_header_is_loopback(host_h) {
			return DenyErr{ ok: false, error: 'invalid host header' }
		}
		// Browser-origin protection for mutating routes on localhost.
		// POST/PUT/PATCH/DELETE from a cross-origin browser page must be rejected
		// unless the Origin is loopback or Sec-Fetch-Site is same-origin.
		if is_mutation_method(ctx) {
			sec_site := ctx.req.header.get_custom('Sec-Fetch-Site') or { '' }
			if sec_site == 'cross-site' {
				return DenyErr{ ok: false, error: 'cross-site request forbidden' }
			}
			origin := ctx.req.header.get_custom('Origin') or { '' }
			if origin.len > 0 {
				oh := origin_host(origin)
				if oh.len > 0 && !is_loopback(oh) {
					return DenyErr{ ok: false, error: 'origin not allowed' }
				}
			}
		}
		return none
	}
	// Remote binding: every request requires valid Bearer token, constant-time compare.
	// No CORS by default (no Access-Control-Allow-Origin emitted elsewhere).
	auth := ctx.req.header.get_custom('Authorization') or { '' }
	expected := 'Bearer ${app.opts.auth_token}'
	// Use constant-time compare and handle token length 10k without crash.
	if !secure_compare(auth, expected) {
		return DenyErr{ ok: false, error: 'unauthorized' }
	}
	return none
}

fn deny_http_status(err_msg string) http.Status {
	lower := err_msg.to_lower()
	if lower.contains('invalid host') || lower.contains('bad request') {
		return .bad_request
	}
	if lower.contains('unauthorized') {
		return .unauthorized
	}
	if lower.contains('forbidden') || lower.contains('origin') || lower.contains('cross-site') {
		return .forbidden
	}
	if lower.contains('not found') {
		return .not_found
	}
	if lower.contains('conflict') {
		return .conflict
	}
	if lower.contains('too many') || lower.contains('max concurrent') {
		return .too_many_requests
	}
	if lower.contains('unprocessable') || lower.contains('invalid') {
		return .unprocessable_entity
	}
	return .forbidden
}

fn respond_deny(mut ctx Ctx, deny DenyErr) veb.Result {
	ctx.res.set_status(deny_http_status(deny.error))
	return ctx.json(deny)
}

@['/api/v1/health'; get]
pub fn (app &App) health(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	up := int(time.utc().unix() - app.started.unix())
	return ctx.json(VersionResp{
		ok: true
		version: agent_toolkit_core.resolve_toolkit_version()
		commit: agent_toolkit_core.resolve_commit()
		uptime_s: up
	})
}

@['/api/v1/version'; get]
pub fn (app &App) api_version(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(VersionResp{
		ok: true
		version: agent_toolkit_core.resolve_toolkit_version()
	})
}

@['/api/v1/openapi.json'; get]
pub fn (app &App) openapi(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.text(openapi_json.to_string())
}

// registered_api_routes mirrors every @['...'] route attribute below (the
// landing '/' excluded). tests/test_surface_parity.py asserts this const stays
// in sync with the actual attributes, and selfcheck uses it for the runtime
// contract-vs-routes diff.
const registered_api_routes = [
	'/api/v1/health',
	'/api/v1/version',
	'/api/v1/openapi.json',
	'/api/v1/selfcheck',
	'/api/v1/inventory',
	'/api/v1/doctor',
	'/api/v1/doctor/fix',
	'/api/v1/matrix',
	'/api/v1/diff',
	'/api/v1/insights',
	'/api/v1/loops',
	'/api/v1/loops/:name/status',
	'/api/v1/loops/:name/run',
	'/api/v1/loops/:name/schedule',
	'/api/v1/loops/:sub',
	'/api/v1/help',
	'/api/v1/install',
	'/api/v1/update',
	'/api/v1/uninstall',
	'/api/v1/skills/:sub',
	'/api/v1/mcp/:sub',
	'/api/v1/plugin/:sub',
	'/api/v1/workspace/:sub',
	'/api/v1/memory/:sub',
	'/api/v1/project/:sub',
	'/api/v1/dc/:sub',
	'/api/v1/build',
	'/api/v1/swarms',
	'/api/v1/swarms/:sub',
	'/api/v1/jobs',
	'/api/v1/jobs/:id/log',
	'/api/v1/jobs/:id/events',
]

// SelfcheckCheck is one named runtime coherence result.
struct SelfcheckCheck {
	name   string
	status string // ok | warn | err
	detail string
}

// SelfcheckResp reports runtime coherence of the programmatic API surface.
// It validates what can only be checked at runtime (embedded OpenAPI freshness
// vs the running binary, jobs dir writability, bind policy). Contract↔route
// coverage is enforced statically by tests/test_surface_parity.py.
struct SelfcheckResp {
	ok      bool
	version string
	commit  string
	checks  []SelfcheckCheck
}

// openapi_declared_version extracts info.version from the embedded OpenAPI
// document to detect stale generated artifacts at runtime.
fn openapi_declared_version(doc string) string {
	marker := '"version": "'
	idx := doc.index(marker) or { return '' }
	rest := doc[idx + marker.len..]
	end := rest.index('"') or { return '' }
	return rest[..end]
}

// extract_openapi_paths pulls every "/api/v1/..." path key from the embedded
// OpenAPI JSON and normalises '{param}' placeholders to ':param'.
fn extract_openapi_paths(doc string) []string {
	mut paths := []string{}
	mut rest := doc
	for {
		idx := rest.index('"/api/v1') or { break }
		rest = rest[idx + 1..]
		end := rest.index('"') or { break }
		path := rest[..end]
		rest = rest[end..]
		if path.ends_with(':') || path.contains('#') {
			continue
		}
		paths << path.replace('{', ':').replace('}', '')
	}
	return paths
}

@['/api/v1/selfcheck'; get]
pub fn (app &App) selfcheck(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	version := agent_toolkit_core.resolve_toolkit_version()
	mut checks := []SelfcheckCheck{}

	// 1. Embedded OpenAPI freshness (stale-artifact detection).
	declared := openapi_declared_version(openapi_json.to_string())
	openapi_ok := declared.len > 0 && declared == version
	checks << SelfcheckCheck{
		name: 'openapi_fresh'
		status: if openapi_ok { 'ok' } else { 'err' }
		detail: if openapi_ok {
			'embedded openapi.json matches runtime version ${version}'} else {
			'embedded openapi.json declares ${declared}, runtime is ${version} — regenerate with scripts/generate_surface.py'}
	}

	// 2. Jobs directory writable (async execution available).
	jobs_dir := app.runner.dir
	jobs_writable := os.is_dir(jobs_dir) && os.is_writable(jobs_dir)
	checks << SelfcheckCheck{
		name: 'jobs_dir_writable'
		status: if jobs_writable { 'ok' } else { 'warn' }
		detail: jobs_dir
	}

	// 3. Bind configuration satisfies the localhost-default security policy.
	mut bind_ok := true
	validate_bind(app.opts.host, app.opts.allow_remote, app.opts.auth_token) or {
		bind_ok = false
	}
	checks << SelfcheckCheck{
		name: 'bind_policy'
		status: if bind_ok { 'ok' } else { 'err' }
		detail: '${app.opts.host} allow_remote=${app.opts.allow_remote}'
	}

	// 4. Route manifest: every registered route must be described by the
	// embedded OpenAPI document and vice versa (runtime drift detection).
	openapi_paths := extract_openapi_paths(openapi_json.to_string())
	reg := registered_api_routes.clone()
	missing_in_openapi := reg.filter(it !in openapi_paths)
	undeclared_in_server := openapi_paths.filter(it !in reg)
	manifest_ok := missing_in_openapi.len == 0 && undeclared_in_server.len == 0
	checks << SelfcheckCheck{
		name: 'route_manifest_match'
		status: if manifest_ok { 'ok' } else { 'err' }
		detail: if manifest_ok {
			'${reg.len} routes match embedded OpenAPI'} else {
			'mismatch — missing_in_openapi: ${missing_in_openapi.join(',')} undeclared_in_server: ${undeclared_in_server.join(',')}'}
	}

	ok := checks.all(it.status != 'err')
	return ctx.json(SelfcheckResp{
		ok: ok
		version: version
		commit: agent_toolkit_core.resolve_commit()
		checks: checks
	})
}

@['/api/v1/inventory'; get]
pub fn (app &App) inventory(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	snap := agent_toolkit_core.load_inventory() or {
		return ctx.json(MsgResp{ ok: false, message: err.msg() })
	}
	return ctx.json(InvResp{
		ok: true
		root: snap.root
		skill_count: snap.skill_count
		agent_count: snap.agent_count
		product_count: snap.product_count
		domain_count: snap.domain_count
		message: snap.message
	})
}

@['/api/v1/doctor'; get]
pub fn (app &App) doctor(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	snap := agent_toolkit_core.run_doctor_readonly()
	return ctx.json(MsgResp{ ok: snap.ok, message: snap.message })
}

@['/api/v1/matrix'; get]
pub fn (app &App) matrix(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.matrix_result()))
}

@['/api/v1/insights'; get]
pub fn (app &App) insights(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.insights_result(agent_toolkit_core.run_insights(agent_toolkit_core.InsightsOptions{
		tool: 'all'
		no_llm: true
		json_mode: true
	}))))
}

@['/api/v1/diff'; get]
pub fn (app &App) diff(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.diff_result(agent_toolkit_core.run_diff(agent_toolkit_core.DiffOptions{}))))
}

@['/api/v1/loops'; get]
pub fn (app &App) loops_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := agent_toolkit_core.find_workspace_root('') or { os.getwd() }
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(agent_toolkit_core.run_loop(agent_toolkit_core.LoopOptions{
		subcommand: 'list'
		workspace_path: ws
	}))))
}

@['/api/v1/loops/:name/status'; get]
pub fn (app &App) loops_status(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_loop_name(name) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid loop name' })
	}
	ws := agent_toolkit_core.find_workspace_root('') or { os.getwd() }
	report := agent_toolkit_core.run_loop(agent_toolkit_core.LoopOptions{
		subcommand: 'status'
		workspace_path: ws
		name: name
	})
	if !report.ok && report.message.contains('not found') {
		ctx.res.set_status(.not_found)
		return ctx.json(DenyErr{ ok: false, error: 'loop not found: ${name}' })
	}
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(report)))
}

@['/api/v1/help'; get]
pub fn (app &App) help_route(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.text(cli_help_md.to_string())
}

fn cmd_resp(res agent_toolkit_core.CommandResult) CmdResp {
	return CmdResp{ ok: res.ok, message: res.message, data: res.data }
}

@['/api/v1/install'; post]
pub fn (app &App) install(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.install_result(agent_toolkit_core.run_install(agent_toolkit_core.InstallOptions{}))))
}

@['/api/v1/update'; post]
pub fn (app &App) update(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.update_result(agent_toolkit_core.run_update(agent_toolkit_core.UpdateOptions{}))))
}

@['/api/v1/uninstall'; post]
pub fn (app &App) uninstall_route(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.uninstall_result(agent_toolkit_core.run_uninstall(agent_toolkit_core.UninstallOptions{}))))
}

@['/api/v1/skills/:sub'; get; post]
pub fn (app &App) skills(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if ctx.req.method == .get && !is_read_subcommand('skills', sub) {
		ctx.res.set_status(.method_not_allowed)
		return ctx.json(DenyErr{ ok: false, error: 'method not allowed: use POST for skills/${sub}' })
	}
	return ctx.json(cmd_resp(agent_toolkit_core.skills_result(agent_toolkit_core.run_skills(agent_toolkit_core.SkillsOptions{ subcommand: sub }))))
}

@['/api/v1/loops/:sub'; post]
pub fn (app &App) loops_generic(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := agent_toolkit_core.find_workspace_root('') or { os.getwd() }
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(agent_toolkit_core.run_loop(agent_toolkit_core.LoopOptions{
		subcommand: sub
		workspace_path: ws
	}))))
}

@['/api/v1/dc/:sub'; post]
pub fn (app &App) devcompanion_generic(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := agent_toolkit_core.find_workspace_root('') or { os.getwd() }
	return ctx.json(cmd_resp(agent_toolkit_core.devcompanion_result(agent_toolkit_core.run_devcompanion(agent_toolkit_core.DevcompanionOptions{
		subcommand: sub
		workspace_path: ws
	}))))
}

@['/api/v1/swarms/:sub'; post]
pub fn (app &App) swarms_generic(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := agent_toolkit_core.find_workspace_root('') or { os.getwd() }
	return ctx.json(cmd_resp(agent_toolkit_core.swarm_result(agent_toolkit_core.run_swarm(agent_toolkit_core.SwarmOptions{
		subcommand: sub
		workspace_path: ws
	}))))
}

@['/api/v1/mcp/:sub'; get; post]
pub fn (app &App) mcp_route(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if ctx.req.method == .get && !is_read_subcommand('mcp', sub) {
		ctx.res.set_status(.method_not_allowed)
		return ctx.json(DenyErr{ ok: false, error: 'method not allowed: use POST for mcp/${sub}' })
	}
	return ctx.json(cmd_resp(agent_toolkit_core.mcp_result(agent_toolkit_core.run_mcp(agent_toolkit_core.McpOptions{ subcommand: sub }))))
}

@['/api/v1/plugin/:sub'; get; post]
pub fn (app &App) plugin_route(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if ctx.req.method == .get && !is_read_subcommand('plugin', sub) {
		ctx.res.set_status(.method_not_allowed)
		return ctx.json(DenyErr{ ok: false, error: 'method not allowed: use POST for plugin/${sub}' })
	}
	return ctx.json(cmd_resp(agent_toolkit_core.plugin_result(agent_toolkit_core.run_plugin(agent_toolkit_core.PluginOptions{ subcommand: sub }))))
}

@['/api/v1/workspace/:sub'; get; post]
pub fn (app &App) workspace(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if ctx.req.method == .get && !is_read_subcommand('workspace', sub) {
		ctx.res.set_status(.method_not_allowed)
		return ctx.json(DenyErr{ ok: false, error: 'method not allowed: use POST for workspace/${sub}' })
	}
	opts := agent_toolkit_core.WorkspaceOptions{ subcommand: sub }
	return ctx.json(cmd_resp(agent_toolkit_core.workspace_result(agent_toolkit_core.run_workspace(opts))))
}

@['/api/v1/memory/:sub'; get; post]
pub fn (app &App) memory(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if ctx.req.method == .get && !is_read_subcommand('memory', sub) {
		ctx.res.set_status(.method_not_allowed)
		return ctx.json(DenyErr{ ok: false, error: 'method not allowed: use POST for memory/${sub}' })
	}
	return ctx.json(cmd_resp(agent_toolkit_core.memory_result(agent_toolkit_core.run_memory(agent_toolkit_core.MemoryOptions{ subcommand: sub }))))
}

@['/api/v1/project/:sub'; get; post]
pub fn (app &App) project(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if ctx.req.method == .get && !is_read_subcommand('project', sub) {
		ctx.res.set_status(.method_not_allowed)
		return ctx.json(DenyErr{ ok: false, error: 'method not allowed: use POST for project/${sub}' })
	}
	return ctx.json(cmd_resp(agent_toolkit_core.project_result(agent_toolkit_core.run_project(agent_toolkit_core.ProjectOptions{ subcommand: sub }))))
}

@['/api/v1/build'; post]
pub fn (app &App) build_route(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.build_result(agent_toolkit_core.run_build(agent_toolkit_core.BuildOptions{}))))
}

@['/api/v1/swarms'; get]
pub fn (app &App) swarms_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.swarm_result(agent_toolkit_core.run_swarm(agent_toolkit_core.SwarmOptions{ subcommand: 'list' }))))
}

// web_index_html is embedded at compile time so serve always has a UI.
const web_index_html = $embed_file('../../web/index.html')
const openapi_json = $embed_file('../../docs/surface/openapi.json')
const cli_help_md = $embed_file('../../docs/surface/cli-help.md')

@['/'; get]
pub fn (app &App) index(mut ctx Ctx) veb.Result {
	return ctx.html(web_index_html.to_string())
}

fn is_file(p string) bool {
	return os.exists(p) && !os.is_dir(p)
}

struct JobCreateReq {
	cmd       string
	args      []string
	workspace string
}

@['/api/v1/jobs'; post]
pub fn (mut app App) jobs_create(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := json.decode(JobCreateReq, ctx.req.data) or {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid JSON body' })
	}
	if req.cmd.len == 0 {
		ctx.res.set_status(.unprocessable_entity)
		return ctx.json(DenyErr{ ok: false, error: 'cmd is required' })
	}
	mut workspace := ''
	if req.workspace.len > 0 {
		// Reject traversal / encoded traversal early (400)
		if req.workspace.contains('..') || req.workspace.contains('%') || req.workspace.contains('\0') {
			ctx.res.set_status(.bad_request)
			return ctx.json(DenyErr{ ok: false, error: 'invalid workspace path' })
		}
		if !os.is_dir(req.workspace) {
			ctx.res.set_status(.not_found)
			return ctx.json(DenyErr{ ok: false, error: 'workspace not found: ${req.workspace}' })
		}
		// Enforce allowed roots and symlink safety (403 if outside)
		if !is_allowed_workspace(req.workspace) {
			ctx.res.set_status(.forbidden)
			return ctx.json(DenyErr{ ok: false, error: 'workspace outside allowed roots' })
		}
		workspace = req.workspace
	} else {
		workspace = agent_toolkit_core.find_workspace_root('') or { os.getwd() }
	}
	mut args := []string{}
	if req.args.len > 0 && req.args[0] == req.cmd {
		args = req.args.clone()
	} else {
		args << req.cmd
		args << req.args
	}
	// Only workspace-aware commands accept the flag; others run with the
	// resolved workspace as their process working directory instead.
	if req.cmd == 'loop' {
		has_ws := args.contains('--workspace') || args.contains('-w')
		if !has_ws && workspace.len > 0 {
			args << '--workspace'
			args << workspace
		}
	}
	job := app.runner.create(req.cmd, args, workspace) or {
		msg := err.msg()
		if msg.contains('max concurrent') {
			ctx.res.set_status(.too_many_requests)
		} else {
			ctx.res.set_status(.internal_server_error)
		}
		return ctx.json(DenyErr{ ok: false, error: msg })
	}
	lp := app.runner.log_path(job.id)
	if !is_file(lp) {
		os.write_file(lp, '[running]\n') or {}
	}
	return ctx.json(job)
}

@['/api/v1/jobs'; get]
pub fn (app &App) jobs_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	app.runner.mut.lock()
	jobs := app.runner.jobs.clone()
	app.runner.mut.unlock()
	return ctx.json(jobs)
}

@['/api/v1/jobs/:id/log'; get]
pub fn (app &App) jobs_log(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_job_id(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	// Symlink escape check before reading
	if !app.runner.is_log_path_safe(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	lp := app.runner.log_path(id)
	if !is_file(lp) {
		ctx.res.set_status(.not_found)
		return ctx.json(DenyErr{ ok: false, error: 'log not found: ${id}' })
	}
	// If file is symlink pointing outside runner dir, block
	if os.is_link(lp) {
		ctx.res.set_status(.forbidden)
		return ctx.json(DenyErr{ ok: false, error: 'symlink not allowed' })
	}
	body := os.read_file(lp) or { '' }
	return ctx.text(body)
}

// jobs_events streams job lifecycle events over SSE (ADR-030 async story).
// Emits `status` events on state transitions, `log` events for new log lines,
// and closes the stream when the job reaches a terminal status.
@['/api/v1/jobs/:id/events'; get]
pub fn (app &App) jobs_events(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_job_id(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	if !app.runner.is_log_path_safe(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	job := app.runner.get(id) or {
		ctx.res.set_status(.not_found)
		return ctx.json(DenyErr{ ok: false, error: 'job not found: ${id}' })
	}
	ctx.takeover_conn()
	// SSE responses must not carry Content-Length; write raw headers.
	mut sb := strings.new_builder(256)
	sb.write_string('HTTP/1.1 200 OK\r\n')
	sb.write_string('Content-Type: text/event-stream\r\n')
	sb.write_string('Connection: keep-alive\r\n')
	sb.write_string('Cache-Control: no-cache\r\n')
	sb.write_string('\r\n')
	if ctx.conn == unsafe { nil } {
		return ctx.text('')
	}
	ctx.conn.write(sb) or {}
	runner := app.runner
	mut stream_conn := &sse.SSEConnection{ conn: ctx.conn }
	spawn fn [id, job, runner, mut stream_conn] () {
		defer {
			stream_conn.close()
		}
		stream_conn.send_message(event: 'status', data: job.status, id: id) or { return }
		mut sent_lines := 0
		mut last_status := job.status
		for {
			time.sleep(500 * time.millisecond)
			current := runner.get(id) or { break }
			if current.status != last_status {
				stream_conn.send_message(event: 'status', data: current.status, id: id) or { break }
				last_status = current.status
			}
			log_path := runner.log_path(id)
			if os.is_file(log_path) {
				body := os.read_file(log_path) or { '' }
				mut lines := body.split_into_lines()
				for lines.len > 0 && lines.last().len == 0 {
					lines.delete_last()
				}
				for sent_lines < lines.len {
					stream_conn.send_message(event: 'log', data: lines[sent_lines], id: id) or { break }
					sent_lines++
				}
			}
			if is_terminal(current.status) {
				stream_conn.send_message(event: 'done', data: current.status, id: id) or {}
				break
			}
		}
	}()
	return veb.no_result()
}

@['/api/v1/doctor/fix'; post]
pub fn (app &App) doctor_fix(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	snap := agent_toolkit_core.run_doctor(agent_toolkit_core.DoctorOptions{ fix: true })
	return ctx.json(MsgResp{ ok: snap.ok, message: snap.message })
}

@['/api/v1/loops/:name/run'; post]
pub fn (mut app App) loops_run(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_loop_name(name) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid loop name' })
	}
	// Enqueue as job for streaming (reuse jobs runner) — workspace-aware
	workspace := agent_toolkit_core.find_workspace_root('') or { os.getwd() }
	mut args := ['loop', 'run', name]
	has_ws := args.contains('--workspace') || args.contains('-w')
	if !has_ws && workspace.len > 0 {
		args << '--workspace'
		args << workspace
	}
	job := app.runner.create('loop', args, workspace) or {
		return ctx.json(DenyErr{ ok: false, error: err.msg() })
	}
	return ctx.json(job)
}

@['/api/v1/loops/:name/schedule'; post]
pub fn (mut app App) loops_schedule(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_loop_name(name) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid loop name' })
	}
	opts := agent_toolkit_core.LoopOptions{
		subcommand: 'schedule'
		name: name
	}
	report := agent_toolkit_core.run_loop(opts)
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(report)))
}
