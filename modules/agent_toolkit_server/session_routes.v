module agent_toolkit_server

import agent_toolkit_core
import veb

@['/api/v1/sessions'; get]
pub fn (mut app App) person_sessions_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	result := app.sessions.list_person_sessions(ws) or { return person_session_error(mut ctx, err) }
	return ctx.json(result)
}

@['/api/v1/sessions'; post]
pub fn (mut app App) person_session_create(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	req := decode_sub_body[agent_toolkit_core.PersonSessionCreateRequest](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	result := app.sessions.create_person_session(agent_toolkit_core.PersonSessionCreateRequest{
		workspace: ws
		person_id: req.person_id
		project_id: req.project_id
		provider: req.provider
		model: req.model
	}) or { return person_session_error(mut ctx, err) }
	return ctx.json(agent_toolkit_core.PersonSessionResponse{ ok: true, session: result })
}

@['/api/v1/sessions/:id/status'; post]
pub fn (mut app App) person_session_status(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	req := decode_sub_body[agent_toolkit_core.PersonSessionStatusRequest](ctx.req.data) or {
		return respond_sub_error(mut ctx, err)
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	result := app.sessions.update_person_session(ws, id, req.status, req.exit_code) or {
		return person_session_error(mut ctx, err)
	}
	return ctx.json(agent_toolkit_core.PersonSessionResponse{ ok: true, session: result })
}

fn person_session_error(mut ctx Ctx, err IError) veb.Result {
	message := err.msg()
	if message.contains('not found') { ctx.res.set_status(.not_found) }
	else if message.contains('already exists') { ctx.res.set_status(.conflict) }
	else if message.contains('symlink') { ctx.res.set_status(.forbidden) }
	else if message.contains('invalid session transition') { ctx.res.set_status(.conflict) }
	else { ctx.res.set_status(.bad_request) }
	return ctx.json(DenyErr{ ok: false, error: message })
}
