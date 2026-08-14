module agent_toolkit_core

import os

// DoctorOptions configures doctor (default read-only; --fix is opt-in).
pub struct DoctorOptions {
pub:
	fix               bool
	provenance        bool // --provenance: extra lock reporting (Python flag parity)
	home_dir          string // empty → os.home_dir()
	data_root         string // empty → resolve via update/find_toolkit_root
	skip_data_refresh bool
}

// DoctorCheck is one health check row.
pub struct DoctorCheck {
pub:
	category string
	name     string
	status   string // ok | warn | err
	detail   string
}

// DoctorSnapshot is a health summary for migration observability.
pub struct DoctorSnapshot {
pub:
	engine      string
	version     string
	commit      string
	platform    string
	root        string
	root_ok     bool
	offline     bool
	ok          bool
	message     string
	fix_applied bool
	fix_action  string
pub mut:
	checks []DoctorCheck
}

// run_doctor_readonly performs read-only checks (no --fix).
pub fn run_doctor_readonly() DoctorSnapshot {
	return run_doctor(DoctorOptions{})
}

// run_doctor performs health checks; with fix=true, allowlisted repairs only (#550).
// Allowlisted fix: refresh missing/outdated profiles via run_update (no privilege escalation).
pub fn run_doctor(opts DoctorOptions) DoctorSnapshot {
	ver := doctor_version()
	offline := doctor_is_offline()
	root := doctor_lookup_root()
	root_ok := root.len > 0
	platform := '${os.user_os()}/${os.uname().machine}'
	home := if opts.home_dir.len > 0 { opts.home_dir } else { os.home_dir() }

	mut checks := []DoctorCheck{}
	checks << DoctorCheck{'engine', 'engine', 'ok', 'v'}
	checks << DoctorCheck{'engine', 'version', 'ok', ver}
	checks << DoctorCheck{'engine', 'platform', 'ok', platform}
	if root_ok {
		checks << DoctorCheck{'root', 'root', 'ok', root}
	} else {
		checks << DoctorCheck{'root', 'root', 'err', 'not found (set AGENT_TOOLKIT_ROOT)'}
	}
	if offline {
		checks << DoctorCheck{'root', 'offline', 'warn', 'AGENT_TOOLKIT_OFFLINE set'}
	}
	checks << collect_profile_checks(home)
	if opts.provenance {
		checks << collect_provenance_checks(root)
	}

	mut ok := true
	for c in checks {
		if c.status == 'err' {
			ok = false
		}
	}

	mut lines := []string{}
	lines << ''
	lines << 'agent-toolkit doctor'
	lines << ''
	lines << '── Engine ──'
	for c in checks {
		if c.category == 'engine' {
			lines << doctor_format_check(c)
		}
	}
	lines << ''
	lines << '── Toolkit root ──'
	for c in checks {
		if c.category == 'root' {
			lines << doctor_format_check(c)
		}
	}
	profile_checks := checks.filter(it.category == 'profiles')
	if profile_checks.len > 0 {
		lines << ''
		lines << '── Profiles ──'
		for c in profile_checks {
			lines << doctor_format_check(c)
		}
	}
	prov_checks := checks.filter(it.category == 'provenance')
	if prov_checks.len > 0 {
		lines << ''
		lines << '── Provenance ──'
		for c in prov_checks {
			lines << doctor_format_check(c)
		}
	}

	mut fix_applied := false
	mut fix_action := ''
	if opts.fix {
		has_profile_issues := profile_checks.any(it.status != 'ok')
		if has_profile_issues {
			lines << ''
			lines << '── Auto-fix: refreshing profiles (allowlisted) ──'
			tools := tools_needing_profile_fix(home, profile_checks)
			upd := run_update(UpdateOptions{
				tools:             tools
				home_dir:          home
				data_root:         opts.data_root
				skip_data_refresh: opts.skip_data_refresh || offline
			})
			fix_applied = true
			fix_action = 'update_profiles'
			lines << upd.message
			if !upd.ok && upd.files_updated == 0 {
				ok = false
			}
			// Re-check profiles after fix for summary honesty
			checks = checks.filter(it.category != 'profiles')
			checks << collect_profile_checks(home)
		} else {
			lines << ''
			lines << '── Auto-fix ──'
			lines << '  -  No profile issues to repair'
		}
	}

	lines << ''
	lines << '── Summary ──'
	if ok {
		if opts.fix {
			lines << '  ✓  checks passed'
		} else {
			lines << '  ✓  read-only checks passed'
		}
	} else {
		lines << '  ✗  one or more errors detected'
	}
	lines << ''

	return DoctorSnapshot{
		engine:      'v'
		version:     ver
		commit:      resolve_commit()
		platform:    platform
		root:        root
		root_ok:     root_ok
		offline:     offline
		ok:          ok
		message:     lines.join('\n')
		fix_applied: fix_applied
		fix_action:  fix_action
		checks:      checks
	}
}

// doctor_result maps a snapshot to CommandResult (includes engine/version/platform).
pub fn doctor_result(snap DoctorSnapshot) CommandResult {
	mut warn_n := 0
	mut err_n := 0
	for c in snap.checks {
		if c.status == 'warn' {
			warn_n++
		}
		if c.status == 'err' {
			err_n++
		}
	}
	return CommandResult{
		command: 'doctor'
		ok:      snap.ok
		message: snap.message
		data:    {
			'engine':      snap.engine
			'version':     snap.version
			'commit':      snap.commit
			'platform':    snap.platform
			'root':        snap.root
			'root_ok':     if snap.root_ok { 'true' } else { 'false' }
			'offline':     if snap.offline { 'true' } else { 'false' }
			'fix_applied': if snap.fix_applied { 'true' } else { 'false' }
			'fix_action':  snap.fix_action
			'warnings':    '${warn_n}'
			'errors':      '${err_n}'
		}
	}
}

fn collect_provenance_checks(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	if root.len == 0 {
		out << DoctorCheck{'provenance', 'upstream.lock exists', 'warn', 'no toolkit root'}
		return out
	}
	lock_path := os.join_path(root, 'capabilities', 'upstream.lock')
	if os.is_file(lock_path) {
		out << DoctorCheck{'provenance', 'upstream.lock exists', 'ok', lock_path}
		out << DoctorCheck{'provenance', 'provenance: doctor --provenance', 'ok', 'lock present; full SHA/expiry detail deferred'}
	} else {
		// Warn (not err): wheel/data installs often omit capabilities/upstream.lock
		out << DoctorCheck{'provenance', 'upstream.lock exists', 'warn', 'not found under toolkit root (checkout only)'}
	}
	return out
}

fn doctor_format_check(c DoctorCheck) string {
	icon := match c.status {
		'ok' { '✓' }
		'warn' { '⚠' }
		else { '✗' }
	}
	return '  ${icon}  ${c.name:-30} ${c.detail}'
}

fn collect_profile_checks(home string) []DoctorCheck {
	mut out := []DoctorCheck{}
	if os.is_dir(os.join_path(home, '.claude')) {
		out << profile_check('claude-code CLAUDE.md', os.join_path(home, '.claude', 'CLAUDE.md'))
		out << profile_check('claude-code agents/', os.join_path(home, '.claude', 'agents'))
	}
	if os.is_dir(os.join_path(home, '.cursor')) {
		out << profile_check('cursor rules/', os.join_path(home, '.cursor', 'rules'))
	}
	if os.is_dir(os.join_path(home, '.config', 'opencode')) {
		out << profile_check('opencode agents/',
			os.join_path(home, '.config', 'opencode', 'agents'))
		out << profile_check('opencode opencode.json', os.join_path(home, '.config', 'opencode',
			'opencode.json'))
	}
	windsurf := windsurf_config_dir(home)
	if os.is_dir(windsurf) || os.is_dir(os.join_path(home, '.windsurf')) {
		out << profile_check('windsurf rules/', os.join_path(windsurf, 'rules'))
		out << profile_check('windsurf memories/', os.join_path(windsurf, 'memories'))
	}
	if os.is_dir(os.join_path(home, '.pi')) {
		out << profile_check('pi skills/', os.join_path(home, '.pi', 'agent', 'skills'))
	}
	return out
}

fn profile_check(name string, path string) DoctorCheck {
	if os.exists(path) {
		return DoctorCheck{'profiles', name, 'ok', path}
	}
	return DoctorCheck{'profiles', name, 'warn', 'Not installed: ${path}'}
}

fn tools_needing_profile_fix(home string, checks []DoctorCheck) []string {
	mut tools := []string{}
	for c in checks {
		if c.status == 'ok' {
			continue
		}
		if c.name.starts_with('claude-code') && 'claude-code' !in tools {
			tools << 'claude-code'
		}
		if c.name.starts_with('cursor') && 'cursor' !in tools {
			tools << 'cursor'
		}
		if c.name.starts_with('opencode') && 'opencode' !in tools {
			tools << 'opencode'
		}
		if c.name.starts_with('windsurf') && 'windsurf' !in tools {
			tools << 'windsurf'
		}
		if c.name.starts_with('pi') && 'pi' !in tools {
			tools << 'pi'
		}
	}
	if tools.len == 0 {
		return detect_update_tools(home)
	}
	return tools
}

fn doctor_version() string {
	return resolve_toolkit_version()
}

fn doctor_is_offline() bool {
	v := os.getenv('AGENT_TOOLKIT_OFFLINE').trim_space().to_lower()
	return v in ['1', 'true', 'yes']
}

fn doctor_lookup_root() string {
	root := find_toolkit_root() or { return '' }
	return root.path
}
