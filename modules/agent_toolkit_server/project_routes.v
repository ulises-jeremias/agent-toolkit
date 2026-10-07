module agent_toolkit_server

import agent_toolkit_core
import veb

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
