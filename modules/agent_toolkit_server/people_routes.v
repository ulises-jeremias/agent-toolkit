module agent_toolkit_server

import agent_toolkit_core
import veb
import x.json2

struct PersonSaveReq {
	workspace string
	person    map[string]json2.Any
}

struct PersonArchiveReq {
	workspace string
}

@['/api/v1/people'; get]
pub fn (app &App) people_list(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	result := agent_toolkit_core.list_people(ws) or { return people_error(mut ctx, err) }
	return ctx.json(result)
}

@['/api/v1/people/:id'; get]
pub fn (app &App) people_get(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	result := agent_toolkit_core.read_person(ws, id) or { return people_error(mut ctx, err) }
	return ctx.json(result)
}

@['/api/v1/people'; post]
pub fn (app &App) people_create(mut ctx Ctx) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	req := decode_sub_body[PersonSaveReq](ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	result := agent_toolkit_core.save_person(ws, json2.encode(req.person, escape_unicode: true), true) or {
		return people_error(mut ctx, err)
	}
	return ctx.json(result)
}

@['/api/v1/people/:id'; put]
pub fn (app &App) people_update(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	req := decode_sub_body[PersonSaveReq](ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	person_id := req.person['id'] or { return people_error(mut ctx, error('person id is required')) }
	if person_id is string {
		if person_id != id { return people_error(mut ctx, error('person id cannot change')) }
	} else { return people_error(mut ctx, error('person id must be text')) }
	result := agent_toolkit_core.save_person(ws, json2.encode(req.person, escape_unicode: true), false) or {
		return people_error(mut ctx, err)
	}
	return ctx.json(result)
}

@['/api/v1/people/:id/archive'; post]
pub fn (app &App) people_archive(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none { return respond_deny(mut ctx, deny) }
	req := decode_sub_body[PersonArchiveReq](ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	current := agent_toolkit_core.read_person(ws, id) or { return people_error(mut ctx, err) }
	mut person := current.person.clone()
	person['archived'] = true
	result := agent_toolkit_core.save_person(ws, json2.encode(person, escape_unicode: true), false) or {
		return people_error(mut ctx, err)
	}
	return ctx.json(result)
}

fn people_error(mut ctx Ctx, err IError) veb.Result {
	message := err.msg()
	if message.contains('not found') { ctx.res.set_status(.not_found) }
	else if message.contains('already exists') { ctx.res.set_status(.conflict) }
	else if message.contains('symlink') { ctx.res.set_status(.forbidden) }
	else { ctx.res.set_status(.bad_request) }
	return ctx.json(DenyErr{ ok: false, error: message })
}
