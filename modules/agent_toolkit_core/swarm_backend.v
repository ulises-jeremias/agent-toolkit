module agent_toolkit_core

import os
import time

// BackendDoctor is the isolated UI-backend probe (ADR-008). No invented Herdr APIs.
pub struct BackendDoctor {
pub:
	name      string
	available bool
	version   string
	reason    string
}

pub fn swarm_backend_names() []string {
	return ['herdr', 'tmux', 'headless', 'auto']
}

pub fn doctor_backend(name string) BackendDoctor {
	n := if name == 'auto' { 'headless' } else { name }
	return match n {
		'headless' {
			BackendDoctor{
				name:      'headless'
				available: true
				version:   'filesystem'
				reason:    'always available (ADR-008 filesystem SoT)'
			}
		}
		'tmux' {
			probe_unix_bin('tmux', ['tmux', '-V'])
		}
		'herdr' {
			probe_unix_bin('herdr', ['herdr', '--version'])
		}
		else {
			BackendDoctor{
				name:      n
				available: false
				reason:    'unknown backend'
			}
		}
	}
}

pub fn resolve_swarm_backend(requested string) string {
	name := if requested.len == 0 { 'auto' } else { requested }
	if name == 'auto' {
		h := doctor_backend('herdr')
		if h.available {
			return 'herdr'
		}
		t := doctor_backend('tmux')
		if t.available {
			return 'tmux'
		}
		return 'headless'
	}
	return name
}

fn probe_unix_bin(name string, argv []string) BackendDoctor {
	$if windows {
		return BackendDoctor{
			name:      name
			available: false
			reason:    '${name} is Unix-only; not supported on Windows'
		}
	}
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv:    argv
		timeout: 5 * time.second
	}) or { return BackendDoctor{
		name:      name
		available: false
		reason:    err.msg()
	} }
	if res.timed_out {
		return BackendDoctor{
			name:      name
			available: false
			reason:    '${name} probe timed out'
		}
	}
	if res.exit_code != 0 {
		mut msg := res.stderr.trim_space()
		if msg.len == 0 {
			msg = res.stdout.trim_space()
		}
		if msg.len == 0 {
			msg = 'exit ${res.exit_code}'
		}
		return BackendDoctor{
			name:      name
			available: false
			reason:    msg
		}
	}
	mut ver := res.stdout.trim_space()
	if ver.len == 0 {
		ver = res.stderr.trim_space()
	}
	return BackendDoctor{
		name:      name
		available: true
		version:   ver
	}
}

fn find_git_root(start string) ?string {
	mut cur := if start.len > 0 { start } else { os.getwd() }
	for {
		git_dir := os.join_path(cur, '.git')
		if os.is_dir(git_dir) || os.is_file(git_dir) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	return none
}
