module agent_toolkit_server

import agent_toolkit_core
import veb

struct SwarmGateReq {
	workspace string
	gate_id   string
	reason    string
}

@['/api/v1/swarms/runs/:id'; get]
pub fn (app &App) swarm_run_get(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.get_swarm_run_typed(ws, id) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/swarms/runs/:id/handoffs'; get]
pub fn (app &App) swarm_run_handoffs(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.list_swarm_handoffs_typed(ws, id) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/swarms/runs/:id/tasks'; get]
pub fn (app &App) swarm_run_tasks(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.list_swarm_tasks_typed(ws, id) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/swarms/runs/:id/approvals'; get]
pub fn (app &App) swarm_run_approvals(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.list_swarm_approvals_typed(ws, id) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/swarms/runs/:id/artifacts'; get]
pub fn (app &App) swarm_run_artifacts(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.list_swarm_artifacts_typed(ws, id) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/swarms/runs/:id/approve'; post]
pub fn (app &App) swarm_run_approve(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[SwarmGateReq](ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	check_ident('gate_id', req.gate_id) or { return respond_sub_error(mut ctx, err) }
	if req.gate_id.len == 0 {
		return respond_sub_error(mut ctx, bad_field('gate_id'))
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.approve_swarm_gate_typed(ws, id, req.gate_id)
	if !res.ok {
		return work_action_error(mut ctx, res.message)
	}
	app.emit(ApiEvent{
		kind: 'swarm.changed'
		subject: id
		status: res.status
		message: 'approve'
	})
	return ctx.json(res)
}

@['/api/v1/swarms/runs/:id/reject'; post]
pub fn (app &App) swarm_run_reject(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[SwarmGateReq](ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	check_ident('gate_id', req.gate_id) or { return respond_sub_error(mut ctx, err) }
	check_text('reason', req.reason, 1024) or { return respond_sub_error(mut ctx, err) }
	if req.gate_id.len == 0 || req.reason.len == 0 {
		return respond_sub_error(mut ctx, bad_field('reason'))
	}
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.reject_swarm_gate_typed(ws, id, req.gate_id, req.reason)
	if !res.ok {
		return work_action_error(mut ctx, res.message)
	}
	app.emit(ApiEvent{
		kind: 'swarm.changed'
		subject: id
		status: res.status
		message: 'reject'
	})
	return ctx.json(res)
}

@['/api/v1/swarms/runs/:id/stop'; post]
pub fn (app &App) swarm_run_stop(mut ctx Ctx, id string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	req := decode_sub_body[SwarmGateReq](ctx.req.data) or { return respond_sub_error(mut ctx, err) }
	ws := serve_memory_workspace(ctx, req.workspace) or { return respond_sub_error(mut ctx, err) }
	res := agent_toolkit_core.stop_swarm_run_typed(ws, id)
	if !res.ok {
		return work_action_error(mut ctx, res.message)
	}
	app.emit(ApiEvent{
		kind: 'swarm.changed'
		subject: id
		status: res.status
		message: 'stop'
	})
	return ctx.json(res)
}

@['/api/v1/loops/:name/audit'; get]
pub fn (app &App) loops_audit(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_loop_name(name) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid loop name' })
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.get_loop_audit_typed(ws, name) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/loops/:name/history'; get]
pub fn (app &App) loops_history(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_loop_name(name) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid loop name' })
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.get_loop_history_typed(ws, name) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

@['/api/v1/loops/:name/cost'; get]
pub fn (app &App) loops_cost(mut ctx Ctx, name string) veb.Result {
	deny := deny_if_remote(app, ctx)
	if deny != none {
		return respond_deny(mut ctx, deny)
	}
	if !is_valid_loop_name(name) {
		ctx.res.set_status(.bad_request)
		return ctx.json(DenyErr{ ok: false, error: 'invalid loop name' })
	}
	ws := serve_memory_workspace(ctx, '') or { return respond_sub_error(mut ctx, err) }
	got := agent_toolkit_core.get_loop_cost_typed(ws, name) or {
		return work_catalog_error(mut ctx, err)
	}
	return ctx.json(got)
}

fn work_catalog_error(mut ctx Ctx, err IError) veb.Result {
	msg := err.msg()
	if msg.contains('not found') {
		ctx.res.set_status(.not_found)
	} else if msg.contains('invalid') {
		ctx.res.set_status(.bad_request)
	} else {
		ctx.res.set_status(.bad_request)
	}
	return ctx.json(DenyErr{ ok: false, error: msg })
}

fn work_action_error(mut ctx Ctx, msg string) veb.Result {
	if msg.contains('not found') || msg.contains('Run not found') || msg.contains('Gate not found') {
		ctx.res.set_status(.not_found)
	} else {
		ctx.res.set_status(.bad_request)
	}
	return ctx.json(DenyErr{ ok: false, error: msg })
}
