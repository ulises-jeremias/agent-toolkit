module agent_toolkit_server

// veb transport (maintainer decision). Thin adapter per ADR-027; auth per ADR-028.
// NOTE: per veb contract, the user context struct must EMBED veb.Context as
// field `Context`, and route handlers must return veb.Result.
import agent_toolkit_core
import net.http
import os
import x.json2
import strings
import time
import veb
import veb.sse

pub struct App {
pub mut:
	opts     ServeOptions
	started  time.Time
	runner   &JobRunner = unsafe { nil }
	bus      &EventBus = unsafe { nil }
	sessions &agent_toolkit_core.PersonSessionStore = unsafe { nil }
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

// desktop_client_header marks first-party non-browser clients (Electron
// Desktop over file://) on mutating requests.
const desktop_client_header = 'X-Atk-Desktop'

// is_first_party_mutation reports whether a mutating request on a loopback
// bind is allowed despite a cross-site Fetch Metadata flag. Non-browser
// first-party clients cannot control Sec-Fetch-Site (Chromium stamps
// file:// origins cross-site) but CAN send a custom header, which browsers
// refuse to send cross-origin without a CORS preflight the server never
// answers (no Access-Control-Allow-Origin is emitted). Any local process can
// already POST without headers, so this restores — not weakens — the
// intended policy: browser pages must be same-origin.
fn is_first_party_mutation(sec_site string, desktop_header string) bool {
	if sec_site != 'cross-site' {
		return true
	}
	return desktop_header == '1'
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
			return sub in ['list', 'search', 'show', 'get', 'inject', 'todo']
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
	return is_under_allowed_roots(path)
}

// is_under_allowed_roots reports whether an existing path resolves (symlinks
// followed) inside one of the allowed roots used by is_allowed_workspace.
fn is_under_allowed_roots(path string) bool {
	if !os.exists(path) {
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
	if name.contains('/') || name.contains('\\') || name.contains('..') || name.contains('%') || name.contains('\x00') {
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
	mut bus := new_event_bus()
	mut runner := new_job_runner(os.join_path(os.getwd(), '.agent-toolkit', 'server'))
	runner.bus = bus
	bus.publish(ApiEvent{
		kind: 'backend.ready'
		subject: 'serve'
		status: 'ok'
		message: agent_toolkit_core.resolve_toolkit_version()
	})
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
		runner: runner
		bus: bus
		sessions: agent_toolkit_core.new_person_session_store()
	}
}

// emit publishes e on the global event bus (no-op without a bus, e.g. in
// handler unit tests that build App by hand).
fn (app &App) emit(e ApiEvent) {
	if app.bus == unsafe { nil } {
		return
	}
	mut bus := app.bus
	bus.publish(e)
}

// run_install_action wraps a synchronous install/update/uninstall run with
// install.started / install.finished events.
fn (app &App) run_install_action(action string, run fn () agent_toolkit_core.CommandResult) CmdResp {
	app.emit(ApiEvent{ kind: 'install.started', subject: action, status: 'running' })
	res := run()
	app.emit(ApiEvent{
		kind: 'install.finished'
		subject: action
		status: if res.ok { 'completed' } else { 'failed' }
		message: res.message
	})
	return cmd_resp(res)
}

// swarm_mutating_subs are the swarm subcommands that change run state.
const swarm_mutating_subs = ['start', 'init', 'plan', 'activate', 'deactivate', 'promote', 'approve',
	'reject', 'cancel', 'pause', 'resume', 'stop', 'cleanup', 'prune']

// swarm_sub_mutates reports whether a swarms/{sub} call changes state:
// dry runs never do; handoff/task only for their writing sub-operations.
fn swarm_sub_mutates(sub string, opts agent_toolkit_core.SwarmOptions) bool {
	if opts.dry_run {
		return false
	}
	return match sub {
		'handoff' { opts.handoff_sub == 'create' }
		'task' { opts.handoff_sub in ['next', 'complete'] }
		else { sub in swarm_mutating_subs }
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

pub struct InstallReceiptsResp {
pub mut:
	ok       bool
	receipts []InstallReceiptSummary
}

pub struct InstallReceiptSummary {
pub:
	product        string
	target         string
	scope          string
	version        string
	installed_at   string
	artifact_count int
	created_count  int
	merged_count   int
	receipt_path   string
	artifacts      []InstallArtifactSummary
}

pub struct InstallArtifactSummary {
pub:
	path      string
	ownership string
	status    string
}

fn install_artifact_status(path string, expected_digest string) string {
	if os.is_link(path) {
		return 'replaced'
	}
	if !os.is_file(path) {
		return 'missing'
	}
	current_digest := agent_toolkit_core.receipt_artifact_digest(path)
	if current_digest == 'missing' {
		return 'unavailable'
	}
	if current_digest == expected_digest {
		return 'unchanged'
	}
	return 'modified'
}

pub struct CopilotProjectInstallResp {
pub:
	ok            bool
	message       string
	project       string
	path          string
	content       string
	status        string
	review_token  string
	files_written int
	files_removed int
}

struct InstallReviewedReq {
	tools []string
}

struct CopilotProjectInstallReq {
	workspace    string
	project      string
	action       string
	review_token string
}

fn copilot_project_install_response(report agent_toolkit_core.CopilotProjectInstallReport) CopilotProjectInstallResp {
	return CopilotProjectInstallResp{
		ok: report.ok
		message: report.message
		project: report.project
		path: report.path
		content: report.content
		status: report.status
		review_token: report.review_token
		files_written: report.files_written
		files_removed: report.files_removed
	}
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
			desktop_header := ctx.req.header.get_custom(desktop_client_header) or { '' }
			if !is_first_party_mutation(sec_site, desktop_header) {
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
// landing '/' excluded). V cannot reflect route attributes at runtime, so this
// const is manual and must stay in sync — tests/test_surface_parity.py
// enforces triple parity (contract ↔ openapi ↔ routes ↔ help) and the
// selfcheck runtime diff, and generate_surface.py --check covers openapi freshness.
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
	'/api/v1/loops/:name/audit',
	'/api/v1/loops/:name/history',
	'/api/v1/loops/:name/cost',
	'/api/v1/loops/:name/run',
	'/api/v1/loops/:name/schedule',
	'/api/v1/loops/:sub',
	'/api/v1/help',
	'/api/v1/install',
	'/api/v1/install/preview',
	'/api/v1/install/reviewed',
	'/api/v1/install/copilot-project/preview',
	'/api/v1/install/copilot-project/reviewed',
	'/api/v1/install/receipts',
	'/api/v1/update',
	'/api/v1/uninstall',
	'/api/v1/uninstall/preview',
	'/api/v1/uninstall/reviewed',
	'/api/v1/skills/:sub',
	'/api/v1/mcp/providers',
	'/api/v1/mcp/:sub',
	'/api/v1/plugin/:sub',
	'/api/v1/workspace/:sub',
	'/api/v1/memory',
	'/api/v1/memory/hits',
	'/api/v1/memory/file',
	'/api/v1/memory/file/archive',
	'/api/v1/people',
	'/api/v1/people/bindings',
	'/api/v1/people/:id',
	'/api/v1/people/:id/archive',
	'/api/v1/sessions',
	'/api/v1/sessions/:id/status',
	'/api/v1/memory/:sub',
	'/api/v1/files',
	'/api/v1/files/hits',
	'/api/v1/files/content',
	'/api/v1/projects',
	'/api/v1/project/:sub',
	'/api/v1/dc/:sub',
	'/api/v1/build',
	'/api/v1/swarms',
	'/api/v1/swarms/recipes',
	'/api/v1/swarms/runs/:id',
	'/api/v1/swarms/runs/:id/handoffs',
	'/api/v1/swarms/runs/:id/tasks',
	'/api/v1/swarms/runs/:id/approvals',
	'/api/v1/swarms/runs/:id/artifacts',
	'/api/v1/swarms/runs/:id/approve',
	'/api/v1/swarms/runs/:id/reject',
	'/api/v1/swarms/runs/:id/stop',
	'/api/v1/swarms/:sub',
	'/api/v1/jobs',
	'/api/v1/jobs/:id/log',
	'/api/v1/jobs/:id/events',
	'/api/v1/jobs/:id/cancel',
	'/api/v1/jobs/:id/retry',
	'/api/v1/jobs/:id',
	'/api/v1/events',
	'/api/v1/agents',
	'/api/v1/tools',
	'/api/v1/mcp/providers',
	'/api/v1/providers',
	'/api/v1/models',
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
			'embedded openapi.json matches runtime version ${version}'
		} else {
			'embedded openapi.json declares ${declared}, runtime is ${version} — regenerate with scripts/generate_surface.py'
		}
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
			'${reg.len} routes match embedded OpenAPI'
		} else {
			'mismatch — missing_in_openapi: ${missing_in_openapi.join(',')} undeclared_in_server: ${undeclared_in_server.join(',')}'
		}
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

@['/api/v1/agents'; get]
pub fn (app &App) agents(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(agent_toolkit_core.AgentsResponse{
		ok: true
		agents: agent_toolkit_core.list_agents()
	})
}

@['/api/v1/tools'; get]
pub fn (app &App) tools(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(agent_toolkit_core.ToolsResponse{
		ok: true
		tools: agent_toolkit_core.list_coding_tools()
	})
}

@['/api/v1/providers'; get]
pub fn (app &App) providers(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(agent_toolkit_core.ProvidersResponse{
		ok: true
		providers: agent_toolkit_core.list_providers()
	})
}

@['/api/v1/mcp/providers'; get]
pub fn (app &App) mcp_providers(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(agent_toolkit_core.list_mcp_providers())
}

@['/api/v1/models'; get]
pub fn (app &App) models(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(agent_toolkit_core.ModelsResponse{
		ok: true
		models: agent_toolkit_core.list_models()
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
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	return ctx.json(agent_toolkit_core.list_loops_typed(ws))
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
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.get_loop_status_typed(ws, name) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
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
	return ctx.json(app.run_install_action('install', fn () agent_toolkit_core.CommandResult {
		return agent_toolkit_core.install_result(agent_toolkit_core.run_install(agent_toolkit_core.InstallOptions{}))
	}))
}

@['/api/v1/install/preview'; get]
pub fn (app &App) install_preview(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	tools_raw := ctx.query['tools'] or { '' }
	tools := if tools_raw.len > 0 { tools_raw.split(',') } else { []string{} }
	return ctx.json(cmd_resp(agent_toolkit_core.install_result(agent_toolkit_core.run_install(agent_toolkit_core.InstallOptions{
		dry_run: true
		tools: tools
	}))))
}

@['/api/v1/install/reviewed'; post]
pub fn (app &App) install_reviewed(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := json2.decode[InstallReviewedReq](ctx.req.data) or {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'tools array is required' })
	}
	if req.tools.len == 0 {
		ctx.res.set_status(.unprocessable_entity)
		return ctx.json(DenyErr{ ok: false, error: 'select at least one installation target' })
	}
	if req.tools.len > 6 {
		ctx.res.set_status(.unprocessable_entity)
		return ctx.json(DenyErr{ ok: false, error: 'too many installation targets' })
	}
	mut seen := []string{}
	for tool in req.tools {
		if tool !in agent_toolkit_core.install_valid_tools || tool in ['copilot', 'muse'] {
			ctx.res.set_status(.unprocessable_entity)
			return ctx.json(DenyErr{ ok: false, error: 'unsupported installation target: ${tool}' })
		}
		if tool in seen {
			ctx.res.set_status(.unprocessable_entity)
			return ctx.json(DenyErr{ ok: false, error: 'duplicate installation target: ${tool}' })
		}
		seen << tool
	}
	return ctx.json(app.run_install_action('install', fn [req] () agent_toolkit_core.CommandResult {
		return agent_toolkit_core.install_result(agent_toolkit_core.run_install(agent_toolkit_core.InstallOptions{
			tools: req.tools
		}))
	}))
}

@['/api/v1/install/copilot-project/preview'; get]
pub fn (app &App) copilot_project_install_preview(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	workspace := ctx.query['workspace'] or { '' }
	project := ctx.query['project'] or { '' }
	action := ctx.query['action'] or { 'install' }
	if workspace.len == 0 || project.len == 0 {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'workspace and project are required' })
	}
	if action !in ['install', 'remove'] {
		ctx.res.set_status(.unprocessable_entity)
		return ctx.json(DenyErr{ ok: false, error: 'action must be install or remove' })
	}
	report := if action == 'remove' {
		agent_toolkit_core.copilot_project_remove(workspace, project, '', false, '')
	} else {
		agent_toolkit_core.copilot_project_install(workspace, project, '', false, '')
	}
	return ctx.json(copilot_project_install_response(report))
}

@['/api/v1/install/copilot-project/reviewed'; post]
pub fn (app &App) copilot_project_install_reviewed(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := json2.decode[CopilotProjectInstallReq](ctx.req.data) or {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'workspace, project and review_token are required' })
	}
	if req.workspace.len == 0 || req.project.len == 0 || req.action !in ['install', 'remove'] || req.review_token.len == 0 {
		ctx.res.set_status(.unprocessable_entity)
		return ctx.json(DenyErr{ ok: false, error: 'workspace, project, action and review_token are required' })
	}
	action_name := 'copilot-project-${req.action}'
	app.emit(ApiEvent{ kind: 'install.started', subject: action_name, status: 'running' })
	report := if req.action == 'remove' {
		agent_toolkit_core.copilot_project_remove(req.workspace, req.project, req.review_token, true, '')
	} else {
		agent_toolkit_core.copilot_project_install(req.workspace, req.project, req.review_token, true, '')
	}
	app.emit(ApiEvent{
		kind: 'install.finished'
		subject: action_name
		status: if report.ok { 'completed' } else { 'failed' }
		message: report.message
	})
	if report.status == 'stale-review' {
		ctx.res.set_status(.conflict)
	}
	return ctx.json(copilot_project_install_response(report))
}

@['/api/v1/install/receipts'; get]
pub fn (app &App) install_receipts(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	mut receipts := []InstallReceiptSummary{}
	receipt_dir := agent_toolkit_core.default_receipt_dir()
	for filename in os.ls(receipt_dir) or { []string{} } {
		if !filename.ends_with('.json') {
			continue
		}
		receipt_path := os.join_path(receipt_dir, filename)
		if !os.is_file(receipt_path) {
			continue
		}
		contents := os.read_file(receipt_path) or { continue }
		receipt := agent_toolkit_core.parse_install_receipt(contents) or { continue }
		mut created := 0
		mut merged := 0
		mut artifacts := []InstallArtifactSummary{}
		for artifact in receipt.artifacts {
			if artifact.ownership == 'created' {
				created++
			} else if artifact.ownership == 'merged' { merged++ }
			artifacts << InstallArtifactSummary{
				path: artifact.path
				ownership: artifact.ownership
				status: install_artifact_status(artifact.path, artifact.digest)
			}
		}
		receipts << InstallReceiptSummary{
			product: receipt.product
			target: receipt.target
			scope: receipt.scope
			version: receipt.version
			installed_at: receipt.installed_at
			artifact_count: receipt.artifacts.len
			created_count: created
			merged_count: merged
			receipt_path: os.real_path(receipt_path)
			artifacts: artifacts
		}
	}
	return ctx.json(InstallReceiptsResp{ ok: true, receipts: receipts })
}

@['/api/v1/update'; post]
pub fn (app &App) update(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(app.run_install_action('update', fn () agent_toolkit_core.CommandResult {
		return agent_toolkit_core.update_result(agent_toolkit_core.run_update(agent_toolkit_core.UpdateOptions{}))
	}))
}

@['/api/v1/uninstall'; post]
pub fn (app &App) uninstall_route(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(app.run_install_action('uninstall', fn () agent_toolkit_core.CommandResult {
		return agent_toolkit_core.uninstall_result(agent_toolkit_core.run_uninstall(agent_toolkit_core.UninstallOptions{}))
	}))
}

@['/api/v1/uninstall/preview'; get]
pub fn (app &App) uninstall_preview(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.uninstall_result(agent_toolkit_core.run_uninstall(agent_toolkit_core.UninstallOptions{
		dry_run: true
	}))))
}

@['/api/v1/uninstall/reviewed'; post]
pub fn (app &App) uninstall_reviewed(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	token := ctx.query['review_token'] or { '' }
	if token.len == 0 {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'review_token is required' })
	}
	result := agent_toolkit_core.uninstall_result(agent_toolkit_core.run_uninstall(agent_toolkit_core.UninstallOptions{
		review_token: token
	}))
	if !result.ok && result.message.contains('Removal plan changed since review') {
		ctx.res.set_status(.conflict)
	}
	return ctx.json(app.run_install_action('uninstall', fn [result] () agent_toolkit_core.CommandResult {
		return result
	}))
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
	opts := build_skills_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	return ctx.json(cmd_resp(agent_toolkit_core.skills_result(agent_toolkit_core.run_skills(opts))))
}

@['/api/v1/loops/:sub'; post]
pub fn (app &App) loops_generic(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	opts := build_loops_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(agent_toolkit_core.run_loop(opts))))
}

@['/api/v1/dc/:sub'; post]
pub fn (app &App) devcompanion_generic(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	opts := build_dc_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	return ctx.json(cmd_resp(agent_toolkit_core.devcompanion_result(agent_toolkit_core.run_devcompanion(opts))))
}

@['/api/v1/swarms/:sub'; post]
pub fn (app &App) swarms_generic(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	opts := build_swarms_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.swarm_result(agent_toolkit_core.run_swarm(opts))
	if res.ok && swarm_sub_mutates(sub, opts) {
		app.emit(ApiEvent{
			kind: 'swarm.changed'
			subject: opts.run_id
			status: 'ok'
			message: sub
		})
	}
	return ctx.json(cmd_resp(res))
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
	opts := build_mcp_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	return ctx.json(cmd_resp(agent_toolkit_core.mcp_result(agent_toolkit_core.run_mcp(opts))))
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
	opts := build_plugin_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	return ctx.json(cmd_resp(agent_toolkit_core.plugin_result(agent_toolkit_core.run_plugin(opts))))
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
	opts := build_workspace_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
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
	opts := build_memory_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.memory_result(agent_toolkit_core.run_memory(opts))
	if res.ok && sub == 'add' {
		app.emit(ApiEvent{
			kind: 'memory.changed'
			subject: opts.entry_type
			status: 'ok'
			message: sub
		})
	}
	return ctx.json(cmd_resp(res))
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
	opts := build_project_options(sub, ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	return ctx.json(cmd_resp(agent_toolkit_core.project_result(agent_toolkit_core.run_project(opts))))
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
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	return ctx.json(agent_toolkit_core.list_swarm_runs_typed(ws))
}

@['/api/v1/swarms/recipes'; get]
pub fn (app &App) swarms_recipes(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	return ctx.json(agent_toolkit_core.list_swarm_recipes_typed())
}

const openapi_json = $embed_file('../../docs/surface/openapi.json')
const cli_help_md = $embed_file('../../docs/surface/cli-help.md')

// The HTTP server is a backend API, not a second Desktop frontend.
const status_html = '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Agent Toolkit API</title><body><main><h1>Agent Toolkit backend</h1><p>The API is running. Open Agent Toolkit Desktop to use the workspace.</p><p><a href="/openapi.json">OpenAPI schema</a> · <a href="/api/v1/health">Health</a></p></main></body></html>'

@['/'; get]
pub fn (app &App) index(mut ctx Ctx) veb.Result {
	return ctx.html(status_html)
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
	req := json2.decode[JobCreateReq](ctx.req.data) or {
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
		if req.workspace.contains('..') || req.workspace.contains('%') || req.workspace.contains('\x00') {
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

// jobs_get returns one job. 400 invalid id, 404 unknown.
@['/api/v1/jobs/:id'; get]
pub fn (app &App) jobs_get(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_job_id(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	job := app.runner.get(id) or {
		ctx.res.set_status(.not_found)
		return ctx.json(DenyErr{ ok: false, error: 'job not found: ${id}' })
	}
	return ctx.json(job)
}

// jobs_retry re-runs a failed or canceled job as a new job (same cmd, args
// and workspace; `retry_of` links back). The original is left untouched.
// 404 unknown id or vanished workspace, 403 workspace no longer allowed,
// 409 job not failed/canceled, 429 at capacity.
@['/api/v1/jobs/:id/retry'; post]
pub fn (mut app App) jobs_retry(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_job_id(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	src := app.runner.retry_source(id) or {
		msg := err.msg()
		ctx.res.set_status(if msg.starts_with('job not found') { .not_found } else { .conflict })
		return ctx.json(DenyErr{ ok: false, error: msg })
	}
	if src.workspace.len > 0 {
		if !os.is_dir(src.workspace) {
			ctx.res.set_status(.not_found)
			return ctx.json(DenyErr{ ok: false, error: 'workspace not found: ${src.workspace}' })
		}
		if !is_allowed_workspace(src.workspace) {
			ctx.res.set_status(.forbidden)
			return ctx.json(DenyErr{ ok: false, error: 'workspace outside allowed roots' })
		}
	}
	job := app.runner.create_job(src.cmd, src.args, src.workspace, src.id) or {
		msg := err.msg()
		ctx.res.set_status(if msg.contains('max concurrent') {
			.too_many_requests
		} else {
			.internal_server_error
		})
		return ctx.json(DenyErr{ ok: false, error: msg })
	}
	return ctx.json(job)
}

// events streams the global event bus over SSE. Each message carries
// `id: <boot>-<seq>`, `event: <type>` and a JSON ApiEvent in `data`. Resume
// with `Last-Event-ID` (or ?since=<seq> for this process); a cursor older
// than the retained ring or from another server process first gets a
// `backend.resync` event (refetch state), then every retained event. ?types=job.,loop.finished
// filters by exact type or `family.` prefix. A `: ping` comment every 15s
// detects dead clients.
@['/api/v1/events'; get]
pub fn (app &App) events(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if app.bus == unsafe { nil } {
		ctx.res.set_status(.service_unavailable)
		return ctx.json(DenyErr{ ok: false, error: 'event bus unavailable' })
	}
	// EventSource reconnects to the same URL plus Last-Event-ID, so the
	// header must win over the ?since the stream was first opened with.
	last_event_id := ctx.req.header.get_custom('Last-Event-ID') or { '' }
	since := ctx.query['since'] or { '' }
	header_cursor := last_event_id.trim_space()
	raw_cursor := if header_cursor.len > 0 { header_cursor } else { since }
	mut bus := app.bus
	start := parse_event_cursor(raw_cursor, bus.boot) or {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid since or Last-Event-ID' })
	}
	types_raw := ctx.query['types'] or { '' }
	filter := types_raw.split(',').map(it.trim_space()).filter(it.len > 0)
	if !bus.acquire() {
		ctx.res.set_status(.service_unavailable)
		return ctx.json(DenyErr{ ok: false, error: 'too many event subscribers' })
	}
	ctx.takeover_conn()
	if ctx.conn == unsafe { nil } {
		bus.release()
		return ctx.text('')
	}
	mut sb := strings.new_builder(256)
	sb.write_string('HTTP/1.1 200 OK\r\n')
	sb.write_string('Content-Type: text/event-stream\r\n')
	sb.write_string('Connection: keep-alive\r\n')
	sb.write_string('Cache-Control: no-cache\r\n')
	sb.write_string('\r\n')
	ctx.conn.write(sb) or {
		bus.release()
		ctx.conn.close() or {}
		return veb.no_result()
	}
	mut stream_conn := &sse.SSEConnection{
		conn: ctx.conn
	}
	spawn stream_events(mut bus, mut stream_conn, start, filter)
	return veb.no_result()
}

fn stream_events(mut bus EventBus, mut conn sse.SSEConnection, start EventCursor, filter []string) {
	defer {
		bus.release()
		conn.conn.close() or {}
	}
	// A cursor from another server process says nothing about this one:
	// resync, then replay everything retained.
	mut cursor := if start.foreign { 0 } else { start.seq }
	mut force_resync := start.foreign
	mut idle_ms := 0
	for {
		batch, ring_missed := bus.since(cursor)
		if ring_missed || force_resync {
			force_resync = false
			resync := ApiEvent{
				seq: bus.last_seq()
				boot: bus.boot
				kind: 'backend.resync'
				at: time.utc().format_rfc3339()
				subject: 'serve'
				status: 'ok'
				message: 'events after the resume cursor are not available; refetch state'
			}
			if !send_api_event(mut conn, resync, false) {
				return
			}
			if batch.len == 0 {
				cursor = resync.seq
			}
		}
		for ev in batch {
			cursor = ev.seq
			if !event_matches(ev.kind, filter) {
				continue
			}
			if !send_api_event(mut conn, ev, true) {
				return
			}
			idle_ms = 0
		}
		time.sleep(250 * time.millisecond)
		idle_ms += 250
		if idle_ms >= 15000 {
			conn.conn.write_string(': ping\n\n') or { return }
			idle_ms = 0
		}
	}
}

// send_api_event writes one SSE message; with_id=false omits `id:` so a
// synthetic resync never moves the client's Last-Event-ID.
fn send_api_event(mut conn sse.SSEConnection, ev ApiEvent, with_id bool) bool {
	conn.send_message(
		id: if with_id { event_sse_id(ev) } else { '' }
		event: ev.kind
		data: json2.encode(ev)
	) or { return false }
	return true
}

// jobs_cancel flips a queued/running job to canceled and terminates its
// child process. 404 unknown id, 409 already terminal. Returns the
// canceled Job (typed, like jobs_create).
@['/api/v1/jobs/:id/cancel'; post]
pub fn (mut app App) jobs_cancel(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_job_id(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	job := app.runner.cancel(id) or {
		msg := err.msg()
		if msg.starts_with('job not found') {
			ctx.res.set_status(.not_found)
		} else {
			ctx.res.set_status(.conflict)
		}
		return ctx.json(DenyErr{ ok: false, error: msg })
	}
	return ctx.json(job)
}

// jobs_delete removes a job's registry entry and log file. Running/queued
// jobs need ?force=true (cancels first); terminal jobs delete directly.
// 404 unknown id, 409 running without force.
@['/api/v1/jobs/:id'; delete]
pub fn (mut app App) jobs_delete(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_job_id(id) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid job id' })
	}
	force := ctx.query['force'] or { '' } == 'true'
	app.runner.delete(id, force) or {
		msg := err.msg()
		if msg.starts_with('job not found') {
			ctx.res.set_status(.not_found)
		} else {
			ctx.res.set_status(.conflict)
		}
		return ctx.json(DenyErr{ ok: false, error: msg })
	}
	return ctx.json(MsgResp{ ok: true, message: 'deleted ${id}' })
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
