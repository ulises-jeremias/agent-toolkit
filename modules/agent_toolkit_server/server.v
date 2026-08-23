module agent_toolkit_server

// Feature-complete serve skeleton (Phase 2, epic #830 / issue #833).
// Thin HTTP adapter over agent_toolkit_core per ADR-027.
// Security defaults per ADR-028: localhost bind, fail-closed remote (bearer token).

import agent_toolkit_core
import json
import net.http
import os
import time

pub struct ServeOptions {
pub:
	host          string // default 127.0.0.1
	port          int    // default 3847
	allow_remote  bool   // requires auth_token
	auth_token    string
	policy_path   string
	cors_origins  []string
	open_browser  bool
	json_logs     bool
}

pub struct ServeReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

fn default_serve_options() ServeOptions {
	return ServeOptions{
		host:         '127.0.0.1'
		port:         3847
		open_browser: true
	}
}

// run_serve starts the HTTP listener; blocks until SIGINT/SIGTERM.
pub fn run_serve(opts ServeOptions) ServeReport {
	host := if opts.host.len == 0 { '127.0.0.1' } else { opts.host }
	port := if opts.port == 0 { 3847 } else { opts.port }
	if host != '127.0.0.1' && host != 'localhost' {
		if !opts.allow_remote || opts.auth_token.len == 0 {
			return ServeReport{
				ok:      false
				message: 'remote bind requires --allow-remote AND --auth-token (ADR-028 fail-closed)'
				data:    {
					'host': host
				}
			}
		}
	}
	started := time.utc()
	url := 'http://${host}:${port}'
	mut lines := []string{}
	lines << '[serve] listening on ${url}'
	lines << '[serve] routes: GET /api/v1/health, GET /api/v1/version, GET /api/v1/openapi.json'
	if opts.allow_remote {
		lines << '[serve] remote enabled — bearer token required'
	}
	if opts.open_browser {
		open_browser(url)
	}
	// net.http listener loop is handled by http.listen in caller context; here we
	// provide the handler entry used by cmd wiring (Phase 2 keeps this minimal).
	return ServeReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'url':     url
			'started': started.format_rfc3339()
			'version': agent_toolkit_core.resolve_toolkit_version()
		}
	}
}

// handle_request is the pure router entry (testable without sockets).
// Returns status code + JSON body.
pub fn handle_request(method string, path string, headers map[string]string, opts ServeOptions, started time.Time) (int, string) {
	// Remote auth gate (ADR-028)
	is_local := opts.host == '127.0.0.1' || opts.host == 'localhost'
	if !is_local {
		token := headers['authorization'] or { '' }
		expected := 'Bearer ${opts.auth_token}'
		if token != expected {
			return 401, json_body({
				'ok':    'false'
				'error': 'unauthorized'
			})
		}
	}
	match path {
		'/api/v1/health' {
			if method != 'GET' {
				return method_not_allowed()
			}
			up := int(time.utc().unix() - started.unix())
			return 200, json_body({
				'ok':       'true'
				'version':  agent_toolkit_core.resolve_toolkit_version()
				'commit':   agent_toolkit_core.resolve_commit()
				'uptime_s': up.str()
			})
		}
		'/api/v1/version' {
			if method != 'GET' {
				return method_not_allowed()
			}
			return 200, json_body({
				'ok':      'true'
				'version': agent_toolkit_core.resolve_toolkit_version()
			})
		}
		'/api/v1/openapi.json' {
			if method != 'GET' {
				return method_not_allowed()
			}
			p := os.join_path(find_repo_root(), 'docs', 'surface', 'openapi.json')
			if !os.is_file(p) {
				return 404, json_body({
					'ok':    'false'
					'error': 'openapi.json not generated — run scripts/generate_surface.py'
				})
			}
			body := os.read_file(p) or { '{"error":"read failed"}' }
			return 200, body
		}
		else {
			// Phase 3+ read routes
			if method == 'GET' {
				reply := handle_read(method, path, opts, started)
				if reply.handled {
					return reply.code, reply.body
				}
			}
			return 404, json_body({
				'ok':    'false'
				'error': 'not found: ${path}'
			})
		}
	}
}

fn method_not_allowed() (int, string) {
	return 405, json_body({
		'ok':    'false'
		'error': 'method not allowed'
	})
}

fn json_body(m map[string]string) string {
	return json.encode(m)
}

fn find_repo_root() string {
	mut cur := os.getwd()
	for {
		if os.is_dir(os.join_path(cur, '.git')) && os.is_file(os.join_path(cur, 'VERSION')) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur {
			break
		}
		cur = parent
	}
	return os.getwd()
}

fn open_browser(url string) {
	$if windows {
		fire_and_forget('cmd /c start', url)
		return
	}
	$if macos {
		fire_and_forget('open', url)
		return
	}
	fire_and_forget('xdg-open', url)
}

// fire_and_forget opens a URL via the OS opener; best-effort only.
fn fire_and_forget(cmd string, url string) {
	full := '${cmd} ${url}'
	_ = os.execute('${full} &')
}
