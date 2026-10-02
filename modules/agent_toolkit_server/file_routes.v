module agent_toolkit_server

import agent_toolkit_core
import veb

struct FileWriteReq {
	workspace string
	path      string
	content   string
}

@['/api/v1/files'; get]
pub fn (app &App) files_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	rel := ctx.query['path'] or { '' }
	depth := ctx.query['depth'] or { '0' }.int()
	project := ctx.query['project'] or { '' }
	if project.len > 0 {
		got := agent_toolkit_core.list_project_files(ws, project, rel, depth) or {
			return file_catalog_error(mut ctx, err)
		}
		return ctx.json(got)
	}
	got := agent_toolkit_core.list_workspace_files(ws, rel, depth) or {
		return file_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/files/content'; get]
pub fn (app &App) files_content_get(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	path := ctx.query['path'] or { '' }
	project := ctx.query['project'] or { '' }
	if project.len > 0 {
		got := agent_toolkit_core.read_project_file(ws, project, path) or {
			return file_catalog_error(mut ctx, err)
		}
		return ctx.json(got)
	}
	got := agent_toolkit_core.read_workspace_file(ws, path) or {
		return file_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/files/hits'; get]
pub fn (app &App) files_hits(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	q := ctx.query['q'] or { '' }
	project := ctx.query['project'] or { '' }
	if project.len > 0 {
		got := agent_toolkit_core.search_project_files(ws, project, q) or {
			return file_catalog_error(mut ctx, err)
		}
		return ctx.json(got)
	}
	got := agent_toolkit_core.search_workspace_files(ws, q) or {
		return file_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/files/content'; put]
pub fn (app &App) files_content_put(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[FileWriteReq](ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	if req.path.len == 0 {
		return respond_sub_error(mut ctx, bad_field('path'))
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.write_workspace_file(ws, req.path, req.content) or {
		return file_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

fn file_catalog_error(mut ctx Ctx, err IError) veb.Result {
	msg := err.msg()
	if msg.contains('not found') {
		ctx.res.set_status(.not_found)
	} else if msg.contains('outside') {
		ctx.res.set_status(.forbidden)
	} else {
		ctx.res.set_status(.bad_request)
	}
	return ctx.json(DenyErr{ ok: false, error: msg })
}
