module agent_toolkit_server

// veb transport (maintainer decision). Thin adapter per ADR-027; auth per ADR-028.
// NOTE: per veb contract, the user context struct must EMBED veb.Context as
// field `Context`, and route handlers must return veb.Result.
import agent_toolkit_core
import os
import time
import veb

pub struct App {
pub mut:
	opts    ServeOptions
	started time.Time
}

pub fn validate_bind(host string, allow_remote bool, token string) ! {
	remote := host != '127.0.0.1' && host != 'localhost'
	if remote && (!allow_remote || token.len == 0) {
		return error('remote bind requires --allow-remote AND --auth-token (ADR-028)')
	}
}

pub fn new_app(opts ServeOptions) &App {
	host := if opts.host.len == 0 { '127.0.0.1' } else { opts.host }
	return &App{
		opts: ServeOptions{
			host:         host
			port:         if opts.port == 0 { 3847 } else { opts.port }
			allow_remote: opts.allow_remote
			auth_token:   opts.auth_token
			open_browser: opts.open_browser
			json_logs:    opts.json_logs
		}
		started: time.utc()
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
	ok      bool
	version string
	commit  string
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
	is_local := app.opts.host == '127.0.0.1' || app.opts.host == 'localhost'
	if is_local {
		return none
	}
	auth := ctx.req.header.get_custom('Authorization') or { '' }
	if auth != 'Bearer ${app.opts.auth_token}' {
		return DenyErr{ ok: false, error: 'unauthorized' }
	}
	return none
}

@['/api/v1/health'; get]
pub fn (app &App) health(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	up := int(time.utc().unix() - app.started.unix())
	return ctx.json(VersionResp{
		ok:       true
		version:  agent_toolkit_core.resolve_toolkit_version()
		commit:   agent_toolkit_core.resolve_commit()
		uptime_s: up
	})
}

@['/api/v1/version'; get]
pub fn (app &App) api_version(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(VersionResp{
		ok:      true
		version: agent_toolkit_core.resolve_toolkit_version()
	})
}

@['/api/v1/openapi.json'; get]
pub fn (app &App) openapi(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	p := find_repo_root() + '/docs/surface/openapi.json'
	if !is_file(p) {
		return ctx.json(MsgResp{ ok: false, message: 'openapi.json not generated — run scripts/generate_surface.py' })
	}
	body := os.read_file(p) or { '{"ok":false,"error":"read failed"}' }
	return ctx.text(body)
}

@['/api/v1/inventory'; get]
pub fn (app &App) inventory(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	snap := agent_toolkit_core.load_inventory() or {
		return ctx.json(MsgResp{ ok: false, message: err.msg() })
	}
	return ctx.json(InvResp{
		ok:            true
		root:          snap.root
		skill_count:   snap.skill_count
		agent_count:   snap.agent_count
		product_count: snap.product_count
		domain_count:  snap.domain_count
		message:       snap.message
	})
}

@['/api/v1/doctor'; get]
pub fn (app &App) doctor(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	snap := agent_toolkit_core.run_doctor_readonly()
	return ctx.json(MsgResp{ ok: snap.ok, message: snap.message })
}

@['/api/v1/matrix'; get]
pub fn (app &App) matrix(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.matrix_result()))
}

@['/api/v1/diff'; get]
pub fn (app &App) diff(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.diff_result(agent_toolkit_core.run_diff(agent_toolkit_core.DiffOptions{}))))
}

@['/api/v1/loops'; get]
pub fn (app &App) loops_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(agent_toolkit_core.run_loop(agent_toolkit_core.LoopOptions{
		subcommand:     'list'
		workspace_path: os.getwd()
	}))))
}

@['/api/v1/loops/:name/status'; get]
pub fn (app &App) loops_status(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	report := agent_toolkit_core.run_loop(agent_toolkit_core.LoopOptions{
		subcommand:     'status'
		workspace_path: os.getwd()
		name:           name
	})
	if !report.ok && report.message.contains('not found') {
		return ctx.json(DenyErr{ ok: false, error: 'loop not found: ${name}' })
	}
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(report)))
}

@['/api/v1/help'; get]
pub fn (app &App) help_route(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	p := find_repo_root() + '/docs/surface/cli-help.md'
	if !is_file(p) {
		return ctx.json(MsgResp{ ok: false, message: 'cli-help.md not generated — run scripts/generate_surface.py' })
	}
	body := os.read_file(p) or { '{"ok":false,"error":"read failed"}' }
	return ctx.text(body)
}

fn cmd_resp(res agent_toolkit_core.CommandResult) CmdResp {
	return CmdResp{ ok: res.ok, message: res.message, data: res.data }
}

fn find_repo_root() string {
	mut cur := os.getwd()
	for {
		if os.is_dir(os.join_path(cur, '.git')) && os.is_file(os.join_path(cur, 'VERSION')) {
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

fn is_file(p string) bool {
	return os.exists(p) && !os.is_dir(p)
}
