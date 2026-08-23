module agent_toolkit_server

// Phase 3 (#834): read-only API routes over core (ADR-027 thin adapter).

import agent_toolkit_core
import json
import os
import time

pub struct HttpReply {
pub:
	handled bool
	code    int
	body    string
}

// handle_read routes GET reads; handled=false when path is not a read route.
fn handle_read(method string, path string, opts ServeOptions, started time.Time) HttpReply {
	if method != 'GET' {
		return HttpReply{ handled: false }
	}
	match path {
		'/api/v1/inventory' {
			snap := agent_toolkit_core.load_inventory() or {
				body := json_body({
					'ok':    'false'
					'error': err.msg()
				})
				return HttpReply{ handled: true, code: 422, body: body }
			}
			return HttpReply{ handled: true, code: 200, body: '{"ok":true,"root":' + json.encode(snap.root) + ',"skill_count":' + snap.skill_count.str() + ',"agent_count":' + snap.agent_count.str() + ',"product_count":' + snap.product_count.str() + ',"domain_count":' + snap.domain_count.str() + ',"message":' + json.encode(snap.message) + '}' }
		}
		'/api/v1/doctor' {
			snap := agent_toolkit_core.run_doctor_readonly()
			okstr := if snap.ok { 'true' } else { 'false' }
			return HttpReply{ handled: true, code: 200, body: '{"ok":' + okstr + ',"engine":' + json.encode(snap.engine) + ',"version":' + json.encode(snap.version) + ',"platform":' + json.encode(snap.platform) + ',"root":' + json.encode(snap.root) + ',"message":' + json.encode(snap.message) + '}' }
		}
		'/api/v1/matrix' {
			r := agent_toolkit_core.matrix_result()
			code_m, body_m := result_to_http(r)
			return HttpReply{ handled: true, code: code_m, body: body_m }
		}
		'/api/v1/diff' {
			dres := agent_toolkit_core.run_diff(agent_toolkit_core.DiffOptions{})
			dcmd := agent_toolkit_core.diff_result(dres)
			code_d, body_d := result_to_http(dcmd)
			return HttpReply{ handled: true, code: code_d, body: body_d }
		}
		else {}
	}
	if path.starts_with('/api/v1/loops/') && path.ends_with('/status') {
		name := path.all_after('/loops/').all_before('/status')
		opts2 := agent_toolkit_core.LoopOptions{
			subcommand:     'status'
			workspace_path: os.getwd()
			name:           name
		}
		report := agent_toolkit_core.run_loop(opts2)
		if !report.ok && report.message.contains('not found') {
			ebody := json_body({
				'ok':    'false'
				'error': 'loop not found: ${name}'
			})
			return HttpReply{ handled: true, code: 404, body: ebody }
		}
		lres := agent_toolkit_core.loop_result(report)
		code_s, body_s := result_to_http(lres)
		return HttpReply{ handled: true, code: code_s, body: body_s }
	}
	if path == '/api/v1/loops' || path.starts_with('/api/v1/loops?') {
		opts2 := agent_toolkit_core.LoopOptions{
			subcommand:     'list'
			workspace_path: os.getwd()
		}
		report := agent_toolkit_core.run_loop(opts2)
		lres := agent_toolkit_core.loop_result(report)
		code_l, body_l := result_to_http(lres)
		return HttpReply{ handled: true, code: code_l, body: body_l }
	}
	return HttpReply{ handled: false }
}

// result_to_http maps CommandResult → (http_code, json_body).
pub fn result_to_http(res agent_toolkit_core.CommandResult) (int, string) {
	code := if res.ok { 200 } else { 422 }
	mut parts := []string{}
	for k, v in res.data {
		parts << '"${k}":${json.encode(v)}'
	}
	data := if parts.len > 0 { ',${parts.join(',')}' } else { '' }
	okstr := if res.ok { 'true' } else { 'false' }
	msg := json.encode(res.message)
	body := '{"ok":${okstr},"message":${msg}${data}}'
	return code, body
}
