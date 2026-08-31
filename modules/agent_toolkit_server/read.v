module agent_toolkit_server

// Shared HTTP mapping helpers for serve routes (ADR-027 thin adapter).
import agent_toolkit_core
import json
import strings

pub fn result_to_http(res agent_toolkit_core.CommandResult) (int, string) {
	code := if res.ok {
		200
	} else {
		lower := res.message.to_lower()
		if lower.contains('not found') {
			404
		} else if lower.contains('unauthorized') || lower.contains('auth') {
			401
		} else if lower.contains('forbidden') || lower.contains('denied') || lower.contains('origin') || lower.contains('host') || lower.contains('cross-site') {
			403
		} else if lower.contains('conflict') {
			409
		} else if lower.contains('too many') || lower.contains('max concurrent') || lower.contains('429') {
			429
		} else if lower.contains('unprocessable') || lower.contains('invalid') {
			422
		} else if lower.contains('not implemented') {
			422
		} else {
			500
		}
	}
	mut parts := []string{}
	for k, v in res.data {
		parts << '"${k}":' + json.encode(v)
	}
	data := if parts.len > 0 { ',' + parts.join(',') } else { '' }
	okstr := if res.ok { 'true' } else { 'false' }
	msg := json.encode(res.message)
	body := '{"ok":${okstr},"message":${msg}${data}}'
	return code, body
}
