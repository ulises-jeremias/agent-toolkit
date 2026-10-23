module agent_toolkit_server

import agent_toolkit_core
import veb

@['/api/v1/projects/:id/issues'; get]
pub fn (app &App) project_issues(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	root := agent_toolkit_core.resolve_project_root(ws, id) or {
		return respond_sub_error(mut ctx, err)
	}
	limit := (ctx.query['limit'] or { '30' }).int()
	return ctx.json(agent_toolkit_core.list_project_issues_typed(root, limit))
}

struct ProjectGitPathsReq {
	workspace string
	paths     []string
}

struct ProjectGitCommitReq {
	workspace string
	message   string
}

fn project_git_root(mut ctx Ctx, id string, body_ws string) !string {
	ws := serve_memory_workspace(ctx, body_ws)!
	return agent_toolkit_core.resolve_project_root(ws, id)
}

@['/api/v1/projects/:id/git/status'; get]
pub fn (app &App) project_git_status(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	root := project_git_root(mut ctx, id, '') or { return respond_sub_error(mut ctx, err) }
	return ctx.json(agent_toolkit_core.project_git_status_typed(root, id))
}

@['/api/v1/projects/:id/git/diff'; get]
pub fn (app &App) project_git_diff(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	root := project_git_root(mut ctx, id, '') or { return respond_sub_error(mut ctx, err) }
	path := ctx.query['path'] or { '' }
	staged := (ctx.query['staged'] or { '' }) in ['1', 'true']
	return ctx.json(agent_toolkit_core.project_git_diff_typed(root, id, path, staged))
}

@['/api/v1/projects/:id/git/stage'; post]
pub fn (app &App) project_git_stage(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[ProjectGitPathsReq](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	root := project_git_root(mut ctx, id, req.workspace) or {
		return respond_sub_error(mut ctx, err)
	}
	return ctx.json(agent_toolkit_core.project_git_stage_typed(root, id, req.paths))
}

@['/api/v1/projects/:id/git/unstage'; post]
pub fn (app &App) project_git_unstage(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[ProjectGitPathsReq](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	root := project_git_root(mut ctx, id, req.workspace) or {
		return respond_sub_error(mut ctx, err)
	}
	return ctx.json(agent_toolkit_core.project_git_unstage_typed(root, id, req.paths))
}

@['/api/v1/projects/:id/git/commit'; post]
pub fn (app &App) project_git_commit(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[ProjectGitCommitReq](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	root := project_git_root(mut ctx, id, req.workspace) or {
		return respond_sub_error(mut ctx, err)
	}
	return ctx.json(agent_toolkit_core.project_git_commit_typed(root, id, req.message))
}

@['/api/v1/projects'; get]
pub fn (app &App) projects_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	response := agent_toolkit_core.list_project_entries(ws) or {
		return respond_sub_error(mut ctx, err)
	}
	return ctx.json(response)
}
