module agent_toolkit_core

import os

// DoctorSnapshot is a read-only health summary for migration observability.
pub struct DoctorSnapshot {
pub:
	engine   string
	version  string
	platform string
	root     string
	root_ok  bool
	offline  bool
	ok       bool
	message  string
}

// run_doctor_readonly performs read-only checks (no --fix).
pub fn run_doctor_readonly() DoctorSnapshot {
	ver := doctor_version()
	offline := doctor_is_offline()
	root := doctor_lookup_root()
	root_ok := root.len > 0
	platform := '${os.user_os()}/${os.uname().machine}'
	ok := root_ok
	mut lines := []string{}
	lines << ''
	lines << 'agent-toolkit doctor'
	lines << ''
	lines << '── Engine ──'
	lines << '  ✓  engine                          v'
	lines << '  ✓  version                         ${ver}'
	lines << '  ✓  platform                        ${platform}'
	lines << ''
	lines << '── Toolkit root ──'
	if root_ok {
		lines << '  ✓  root                            ${root}'
	} else {
		lines << '  ✗  root                            not found (set AGENT_TOOLKIT_ROOT)'
	}
	if offline {
		lines << '  ⚠  offline                         AGENT_TOOLKIT_OFFLINE set'
	}
	lines << ''
	lines << '── Summary ──'
	if ok {
		lines << '  ✓  read-only checks passed'
	} else {
		lines << '  ✗  one or more errors detected'
	}
	lines << ''
	return DoctorSnapshot{
		engine:   'v'
		version:  ver
		platform: platform
		root:     root
		root_ok:  root_ok
		offline:  offline
		ok:       ok
		message:  lines.join('\n')
	}
}

// run_doctor is an alias used by the CLI adapter.
pub fn run_doctor() DoctorSnapshot {
	return run_doctor_readonly()
}

// doctor_result maps a snapshot to CommandResult (includes engine/version/platform).
pub fn doctor_result(snap DoctorSnapshot) CommandResult {
	return CommandResult{
		command: 'doctor'
		ok:      snap.ok
		message: snap.message
		data:    {
			'engine':   snap.engine
			'version':  snap.version
			'platform': snap.platform
			'root':     snap.root
			'root_ok':  if snap.root_ok { 'true' } else { 'false' }
			'offline':  if snap.offline { 'true' } else { 'false' }
		}
	}
}

fn doctor_version() string {
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		vf := os.join_path(val, 'VERSION')
		if os.is_file(vf) {
			text := os.read_file(vf) or { continue }
			v := text.trim_space()
			if v.len > 0 {
				return v
			}
		}
	}
	mut cur := os.getwd()
	for {
		vf := os.join_path(cur, 'VERSION')
		if os.is_file(vf)
			&& (os.is_dir(os.join_path(cur, 'skills')) || os.is_dir(os.join_path(cur, 'loops'))) {
			text := os.read_file(vf) or { '' }
			v := text.trim_space()
			if v.len > 0 {
				return v
			}
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	return '1.10.0'
}

fn doctor_is_offline() bool {
	v := os.getenv('AGENT_TOOLKIT_OFFLINE').trim_space().to_lower()
	return v in ['1', 'true', 'yes']
}

fn doctor_lookup_root() string {
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		if os.is_dir(os.join_path(val, 'skills')) || os.is_dir(os.join_path(val, 'profiles')) {
			return val
		}
	}
	mut cur := os.getwd()
	for {
		if os.is_dir(os.join_path(cur, 'skills')) && os.is_dir(os.join_path(cur, 'loops')) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	cwd := os.getwd()
	if os.is_dir(os.join_path(cwd, 'skills')) || os.is_dir(os.join_path(cwd, 'loops')) {
		return cwd
	}
	return ''
}
