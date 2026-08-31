module agent_toolkit_server

// serve entry (Phase 2+) — transport via veb (server.veb.v). ADR-027/028.
import agent_toolkit_core
import os
import veb

pub struct ServeOptions {
pub:
	host         string // default 127.0.0.1
	port         int // default 3847
	allow_remote bool // requires auth_token
	auth_token   string
	open_browser bool
	json_logs    bool
}

pub struct ServeReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

pub fn default_serve_options() ServeOptions {
	return ServeOptions{
		host: '127.0.0.1'
		port: 3847
		open_browser: true
	}
}

// run_serve validates bind (ADR-028), opens browser optionally, then blocks on veb.run.
pub fn run_serve(opts ServeOptions) ServeReport {
	host := if opts.host.len == 0 { '127.0.0.1' } else { opts.host }
	port := if opts.port == 0 { 3847 } else { opts.port }
	validate_bind(host, opts.allow_remote, opts.auth_token) or {
		return ServeReport{
			ok: false
			message: err.msg()
			data: {
				'host': host
			}
		}
	}
	if opts.open_browser {
		fire_and_forget('http://${host}:${port}')
	}
	mut app := new_app(opts)
	url := 'http://${host}:${port}'
	veb.run_at[App, Ctx](mut app, host: host, port: port) or { panic(err.msg()) }
	return ServeReport{
		ok: true
		message: '[serve] listening on ${url} (veb)'
		data: {
			'url':     url
			'version': agent_toolkit_core.resolve_toolkit_version()
		}
	}
}

fn fire_and_forget(url string) {
	$if macos {
		spawn_opener('open', url)
		return
	}
	$if windows {
		spawn_opener('cmd /c start', url)
		return
	}
	spawn_opener('xdg-open', url)
}

fn spawn_opener(cmd string, url string) {
	_ = os.execute('${cmd} ${url} &')
}
