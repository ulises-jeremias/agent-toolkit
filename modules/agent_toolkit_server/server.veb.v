module agent_toolkit_server

// veb transport (maintainer decision). Thin adapter per ADR-027; auth per ADR-028.
// NOTE: per veb contract, the user context struct must EMBED veb.Context as
// field `Context`, and route handlers must return veb.Result.
import agent_toolkit_core
import os
import json
import time
import veb

pub struct App {
pub mut:
	opts    ServeOptions
	started time.Time
	runner  &JobRunner = unsafe { nil }
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
		runner:  new_job_runner(os.join_path(os.getwd(), '.agent-toolkit', 'server'))
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
	return ctx.text(openapi_json.str())
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
	return ctx.text(cli_help_md.str())
}

fn cmd_resp(res agent_toolkit_core.CommandResult) CmdResp {
	return CmdResp{ ok: res.ok, message: res.message, data: res.data }
}


@['/api/v1/install'; post]
pub fn (app &App) install(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.install_result(agent_toolkit_core.run_install(agent_toolkit_core.InstallOptions{}))))
}

@['/api/v1/update'; post]
pub fn (app &App) update(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.update_result(agent_toolkit_core.run_update(agent_toolkit_core.UpdateOptions{}))))
}

@['/api/v1/uninstall'; post]
pub fn (app &App) uninstall_route(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.uninstall_result(agent_toolkit_core.run_uninstall(agent_toolkit_core.UninstallOptions{}))))
}

@['/api/v1/skills/:sub'; get; post]
pub fn (app &App) skills(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.skills_result(agent_toolkit_core.run_skills(agent_toolkit_core.SkillsOptions{ subcommand: sub }))))
}

@['/api/v1/mcp/:sub'; get; post]
pub fn (app &App) mcp_route(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.mcp_result(agent_toolkit_core.run_mcp(agent_toolkit_core.McpOptions{ subcommand: sub }))))
}

@['/api/v1/plugin/:sub'; get; post]
pub fn (app &App) plugin_route(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.plugin_result(agent_toolkit_core.run_plugin(agent_toolkit_core.PluginOptions{ subcommand: sub }))))
}

@['/api/v1/workspace/:sub'; get; post]
pub fn (app &App) workspace(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	opts := agent_toolkit_core.WorkspaceOptions{ subcommand: sub }
	return ctx.json(cmd_resp(agent_toolkit_core.workspace_result(agent_toolkit_core.run_workspace(opts))))
}

@['/api/v1/memory/:sub'; get; post]
pub fn (app &App) memory(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.memory_result(agent_toolkit_core.run_memory(agent_toolkit_core.MemoryOptions{ subcommand: sub }))))
}

@['/api/v1/project/:sub'; get; post]
pub fn (app &App) project(mut ctx Ctx, sub string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.project_result(agent_toolkit_core.run_project(agent_toolkit_core.ProjectOptions{ subcommand: sub }))))
}

@['/api/v1/build'; post]
pub fn (app &App) build_route(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.build_result(agent_toolkit_core.run_build(agent_toolkit_core.BuildOptions{}))))
}

@['/api/v1/swarms'; get]
pub fn (app &App) swarms_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	return ctx.json(cmd_resp(agent_toolkit_core.swarm_result(agent_toolkit_core.run_swarm(agent_toolkit_core.SwarmOptions{ subcommand: 'list' }))))
}


// web_index_html is embedded at compile time so serve always has a UI.
const web_index_html = $embed_file('../../web/index.html')
const openapi_json = $embed_file('../../docs/surface/openapi.json')
const cli_help_md = $embed_file('../../docs/surface/cli-help.md')

@['/'; get]
pub fn (app &App) index(mut ctx Ctx) veb.Result {
	return ctx.html(web_index_html.str())
}



fn is_file(p string) bool {
	return os.exists(p) && !os.is_dir(p)
}


struct JobCreateReq {
	cmd  string
	args []string
}

@['/api/v1/jobs'; post]
pub fn (mut app App) jobs_create(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	req := json.decode(JobCreateReq, ctx.req.data) or {
		return ctx.json(DenyErr{ ok: false, error: 'invalid JSON body' })
	}
	if req.cmd.len == 0 {
		return ctx.json(DenyErr{ ok: false, error: 'cmd is required' })
	}
	mut args := [req.cmd]
	args << req.args
	job := app.runner.create(req.cmd, args, os.getwd()) or {
		return ctx.json(DenyErr{ ok: false, error: err.msg() })
	}
	return ctx.json(job)
}

@['/api/v1/jobs'; get]
pub fn (app &App) jobs_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
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
		return ctx.json(deny)
	}
	lp := app.runner.log_path(id)
	if !is_file(lp) {
		return ctx.json(DenyErr{ ok: false, error: 'log not found: ${id}' })
	}
	body := os.read_file(lp) or { '' }
	return ctx.text(body)
}

@['/api/v1/doctor/fix'; post]
pub fn (app &App) doctor_fix(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	snap := agent_toolkit_core.run_doctor(agent_toolkit_core.DoctorOptions{ fix: true })
	return ctx.json(MsgResp{ ok: snap.ok, message: snap.message })
}

@['/api/v1/loops/:name/run'; post]
pub fn (mut app App) loops_run(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	// Enqueue as job for streaming (reuse jobs runner)
	job := app.runner.create('loop', ['loop', 'run', name], os.getwd()) or {
		return ctx.json(DenyErr{ ok: false, error: err.msg() })
	}
	return ctx.json(job)
}

@['/api/v1/loops/:name/schedule'; post]
pub fn (mut app App) loops_schedule(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return ctx.json(deny)
	}
	opts := agent_toolkit_core.LoopOptions{
		subcommand: 'schedule'
		name:       name
	}
	report := agent_toolkit_core.run_loop(opts)
	return ctx.json(cmd_resp(agent_toolkit_core.loop_result(report)))
}
