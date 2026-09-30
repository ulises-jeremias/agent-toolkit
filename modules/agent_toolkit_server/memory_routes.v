module agent_toolkit_server

import agent_toolkit_core
import veb

struct MemoryFileAddReq {
	workspace  string
	entry_type string
	title      string
	content    string
}

struct MemoryFileMutReq {
	workspace string
	path      string
	content   string
}

@['/api/v1/memory'; get]
pub fn (app &App) memory_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	entries := agent_toolkit_core.list_memory_entries(ws) or {
		return memory_catalog_error(mut ctx, err)
	}
	return ctx.json(agent_toolkit_core.MemoryListResponse{
		ok: true
		entries: entries
	})
}

@['/api/v1/memory/hits'; get]
pub fn (app &App) memory_hits(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	q := ctx.query['q'] or { '' }
	hits := agent_toolkit_core.search_memory_entries(ws, q) or {
		return memory_catalog_error(mut ctx, err)
	}
	return ctx.json(agent_toolkit_core.MemorySearchResponse{
		ok: true
		query: q.trim_space()
		hits: hits
	})
}

@['/api/v1/memory/file'; get]
pub fn (app &App) memory_file_get(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	path := ctx.query['path'] or { '' }
	entry := agent_toolkit_core.read_memory_entry(ws, path) or {
		return memory_catalog_error(mut ctx, err)
	}
	return ctx.json(agent_toolkit_core.MemoryReadResponse{
		ok: true
		entry: entry
	})
}

@['/api/v1/memory/file'; post]
pub fn (app &App) memory_file_add(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[MemoryFileAddReq](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	check_enum('entry_type', req.entry_type, ['learning', 'process', 'todo']) or {
		return respond_sub_error(mut ctx, err)
	}
	check_single_line('title', req.title, 512) or { return respond_sub_error(mut ctx, err) }
	check_text('content', req.content, max_long_text_field) or {
		return respond_sub_error(mut ctx, err)
	}
	if req.content.len == 0 {
		return respond_sub_error(mut ctx, bad_field('content'))
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.add_memory_entry(ws, req.entry_type, req.title, req.content)
	if !res.ok {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: res.message })
	}
	app.emit(ApiEvent{
		kind: 'memory.changed'
		subject: req.entry_type
		status: 'ok'
		ref: res.path
		message: 'add'
	})
	return ctx.json(res)
}

@['/api/v1/memory/file'; put]
pub fn (app &App) memory_file_edit(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[MemoryFileMutReq](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	check_text('content', req.content, max_long_text_field) or {
		return respond_sub_error(mut ctx, err)
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.edit_memory_entry(ws, req.path, req.content) or {
		return memory_catalog_error(mut ctx, err)
	}
	app.emit(ApiEvent{
		kind: 'memory.changed'
		subject: req.path
		status: 'ok'
		ref: res.path
		message: 'edit'
	})
	return ctx.json(res)
}

@['/api/v1/memory/file/archive'; post]
pub fn (app &App) memory_file_archive(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[MemoryFileMutReq](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.archive_memory_entry(ws, req.path) or {
		return memory_catalog_error(mut ctx, err)
	}
	app.emit(ApiEvent{
		kind: 'memory.changed'
		subject: req.path
		status: 'ok'
		ref: res.path
		message: 'archive'
	})
	return ctx.json(res)
}

fn serve_memory_workspace(ctx Ctx, body_ws string) !string {
	raw := if body_ws.len > 0 { body_ws } else { ctx.query['workspace'] or { '' } }
	ws := resolve_body_workspace('workspace', raw, default_workspace())!
	if ws.len == 0 {
		return sub_err(.not_found, 'workspace not found')
	}
	return ws
}

fn memory_catalog_error(mut ctx Ctx, err IError) veb.Result {
	msg := err.msg()
	if msg.contains('not found') {
		ctx.res.set_status(.not_found)
	} else if msg.contains('outside') {
		ctx.res.set_status(.forbidden)
	} else if msg.contains('already archived') {
		ctx.res.set_status(.conflict)
	} else {
		ctx.res.set_status(.bad_request)
	}
	return ctx.json(DenyErr{ ok: false, error: msg })
}
