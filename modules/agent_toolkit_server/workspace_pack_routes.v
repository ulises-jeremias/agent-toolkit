module agent_toolkit_server

import agent_toolkit_core
import veb

struct WorkspacePackActivateReq {
	workspace string
	pack_path string
}

@['/api/v1/workspace/packs'; get]
pub fn (app &App) workspace_packs_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	workspace := ctx.query['workspace'] or { '' }
	ws := serve_memory_workspace(ctx, workspace) or { return respond_sub_error(mut ctx, err) }
	response := agent_toolkit_core.list_workspace_packs(ws) or {
		return workspace_packs_error(mut ctx, err)
	}
	return ctx.json(response)
}

@['/api/v1/workspace/packs/activate'; post]
pub fn (app &App) workspace_packs_activate(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	req := decode_sub_body[WorkspacePackActivateReq](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	response := agent_toolkit_core.activate_workspace_pack(agent_toolkit_core.WorkspacePackActivateRequest{
		workspace: ws
		pack_path: req.pack_path
	}) or {
		return workspace_packs_error(mut ctx, err)
	}
	return ctx.json(response)
}

fn workspace_packs_error(mut ctx Ctx, err IError) veb.Result {
	message := err.msg()
	if message.contains('not found') { ctx.res.set_status(.not_found) }
	else if message.contains('symlink') { ctx.res.set_status(.forbidden) }
	else { ctx.res.set_status(.bad_request) }
	return ctx.json(DenyErr{ ok: false, error: message })
}
