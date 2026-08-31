module agent_toolkit_server

// Shared HTTP mapping helpers for serve routes (ADR-027 thin adapter).
import agent_toolkit_core
import json2

pub fn result_to_http(res agent_toolkit_core.CommandResult) (int, string) {
	code := if res.ok { 200 } else { 422 }
	mut parts := []string{}
	for k, v in res.data {
		parts << '"${k}":' + json2.encode(v, escape_unicode: true)
	}
	data := if parts.len > 0 { ',' + parts.join(',') } else { '' }
	okstr := if res.ok { 'true' } else { 'false' }
	msg := json2.encode(res.message, escape_unicode: true)
	body := '{"ok":${okstr},"message":${msg}${data}}'
	return code, body
}
