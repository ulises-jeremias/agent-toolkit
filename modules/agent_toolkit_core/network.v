module agent_toolkit_core

import net.http
import os
import time
import crypto.sha256

// NetworkClient is the shared HTTP/download abstraction for V core.
pub struct NetworkClient {
pub:
	user_agent     string        = 'agent-toolkit'
	timeout        time.Duration = 30 * time.second
	allow_redirect bool          = true
	offline        bool
}

// new_network_client builds a client; offline is read from AGENT_TOOLKIT_OFFLINE when auto_offline is true.
pub fn new_network_client(auto_offline bool) NetworkClient {
	mut offline := false
	if auto_offline {
		v := os.getenv('AGENT_TOOLKIT_OFFLINE').to_lower()
		offline = v in ['1', 'true', 'yes']
	}
	return NetworkClient{
		offline: offline
	}
}

// HttpResponse is a narrowed response for core callers.
pub struct HttpResponse {
pub:
	status_code int
	body        string
}

// get performs an HTTP GET with toolkit defaults (TLS validate on).
pub fn (c NetworkClient) get(url string) !HttpResponse {
	if c.offline {
		return error('network offline: AGENT_TOOLKIT_OFFLINE prevents HTTP')
	}
	resp := http.fetch(
		method:         .get
		url:            url
		user_agent:     c.user_agent
		read_timeout:   i64(c.timeout)
		write_timeout:  i64(c.timeout)
		allow_redirect: c.allow_redirect
		validate:       true
	) or { return error('http get failed: ${err}') }
	return HttpResponse{
		status_code: resp.status_code
		body:        resp.body
	}
}

// download writes url contents to dest_path via atomic write.
pub fn (c NetworkClient) download(url string, dest_path string) ! {
	if c.offline {
		return error('network offline: AGENT_TOOLKIT_OFFLINE prevents download')
	}
	resp := c.get(url)!
	if resp.status_code < 200 || resp.status_code >= 300 {
		return error('download failed: HTTP ${resp.status_code} for ${url}')
	}
	fs := new_fs()
	fs.write_atomic(dest_path, resp.body)!
}

// verify_sha256 checks file contents against an expected hex digest (checksum hook).
pub fn (c NetworkClient) verify_sha256(path string, expected_hex string) ! {
	data := os.read_file(path) or { return error('checksum read failed: ${err}') }
	sum := sha256.hexhash(data)
	if sum.to_lower() != expected_hex.to_lower() {
		return error('checksum mismatch for ${path}: got ${sum}, want ${expected_hex}')
	}
}
