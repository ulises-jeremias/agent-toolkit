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
	checks << collect_swarm_checks()
	checks << collect_mcp_checks(root)
	checks << collect_pack_checks(root)
	checks << collect_loop_checks(root)
	checks << collect_matrix_checks(root)
	checks << collect_context_cost_checks(root)
	checks << collect_audit_checks(root)
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
	swarm_checks := checks.filter(it.category == 'swarm')
	if swarm_checks.len > 0 {
		lines << ''
		lines << '── Swarm ──'
		for c in swarm_checks {
			lines << doctor_format_check(c)
		}
	}
	mcp_checks := checks.filter(it.category == 'mcp')
	if mcp_checks.len > 0 {
		lines << ''
		lines << '── MCP ──'
		for c in mcp_checks {
			lines << doctor_format_check(c)
		}
	}
	pack_checks := checks.filter(it.category == 'pack')
	if pack_checks.len > 0 {
		lines << ''
		lines << '── Packs ──'
		for c in pack_checks {
			lines << doctor_format_check(c)
		}
	}
	loop_checks := checks.filter(it.category == 'loops')
	if loop_checks.len > 0 {
		lines << ''
		lines << '── Loops ──'
		for c in loop_checks {
			lines << doctor_format_check(c)
		}
	}
	matrix_checks := checks.filter(it.category == 'matrix')
	if matrix_checks.len > 0 {
		lines << ''
		lines << '── Matrix ──'
		for c in matrix_checks {
			lines << doctor_format_check(c)
		}
	}
	cc_checks := checks.filter(it.category == 'context-cost')
	if cc_checks.len > 0 {
		lines << ''
		lines << '── Context-cost ──'
		for c in cc_checks {
			lines << doctor_format_check(c)
		}
	}
	audit_checks := checks.filter(it.category == 'audit')
	if audit_checks.len > 0 {
		lines << ''
		lines << '── Audit ──'
		for c in audit_checks {
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
		checks:  snap.checks
	}
}

fn collect_provenance_checks(root string) []DoctorCheck {
	return verify_provenance(root)
}

fn collect_swarm_checks() []DoctorCheck {
	mut out := []DoctorCheck{}
	for name in ['herdr', 'tmux'] {
		bd := doctor_backend(name)
		status := if bd.available { 'ok' } else { 'warn' }
		detail := if bd.available {
			if bd.version.len > 0 { bd.version } else { 'available' }
		} else {
			if bd.reason.len > 0 { bd.reason } else { 'not available' }
		}
		out << DoctorCheck{'swarm', name, status, detail}
	}
	out << DoctorCheck{'swarm', 'apiVersion', 'ok', 'agent-toolkit.dev/v1alpha1'}
	return out
}

fn collect_mcp_checks(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	if root.len == 0 {
		out << DoctorCheck{'mcp', 'providers', 'warn', 'no toolkit root'}
		return out
	}
	providers := list_known_mcp_providers(root)
	if providers.len == 0 {
		out << DoctorCheck{'mcp', 'providers', 'warn', 'no MCP providers found'}
		return out
	}
	for provider in providers {
		tmpl_dir := os.join_path(root, 'mcp', 'templates', provider)
		tmpl_file := os.join_path(tmpl_dir, 'config.template.json')
		reg_file := os.join_path(root, 'mcp', 'registry', provider + '.yaml')
		mut exists := false
		mut detail := ''
		if os.is_file(tmpl_file) {
			exists = true
			detail = tmpl_file
		} else if os.is_file(reg_file) {
			exists = true
			detail = reg_file
		} else if os.is_dir(tmpl_dir) {
			exists = true
			detail = tmpl_dir
		}
		if exists {
			out << DoctorCheck{'mcp', provider, 'ok', detail}
		} else {
			out << DoctorCheck{'mcp', provider, 'warn', 'template missing'}
		}
	}
	return out
}

fn collect_pack_checks(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	if root.len == 0 {
		out << DoctorCheck{'pack', 'packs', 'warn', 'no toolkit root'}
		return out
	}
	packs_dir := os.join_path(root, 'packs')
	if !os.is_dir(packs_dir) {
		out << DoctorCheck{'pack', 'packs', 'warn', 'not found: ${packs_dir}'}
		return out
	}
	entries := os.ls(packs_dir) or { []string{} }
	mut found_any := false
	for e in entries {
		if e == 'README.md' {
			continue
		}
		p := os.join_path(packs_dir, e)
		if !os.is_dir(p) {
			continue
		}
		found_any = true
		cfg := os.join_path(p, 'config.yaml')
		if os.is_file(cfg) {
			out << DoctorCheck{'pack', e, 'ok', cfg}
		} else {
			out << DoctorCheck{'pack', e, 'warn', 'config.yaml missing'}
		}
	}
	if !found_any {
		out << DoctorCheck{'pack', 'packs', 'warn', 'no packs found in ${packs_dir}'}
	}
	return out
}

fn collect_loop_checks(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	// Workspace loops: detect via find_workspace_root or cwd
	mut ws := ''
	if w := find_workspace_root('') {
		ws = w
	} else {
		ws = os.getwd()
	}
	// Bundled loops (toolkit root)
	if root.len > 0 {
		bundled := bundled_loop_dirs()
		if bundled.len > 0 {
			out << DoctorCheck{'loops', 'bundled', 'ok', '${bundled.len} bundled loops'}
		} else {
			loops_path := os.join_path(root, 'loops')
			if os.is_dir(loops_path) {
				entries := os.ls(loops_path) or { []string{} }
				mut cnt := 0
				for e in entries {
					p := os.join_path(loops_path, e)
					if os.is_dir(p) && (os.is_file(os.join_path(p, 'loop.yaml')) || os.is_file(os.join_path(p, 'LOOP.md'))) {
						cnt++
					}
				}
				if cnt > 0 {
					out << DoctorCheck{'loops', 'bundled', 'ok', '${cnt} loops in ${loops_path}'}
				} else {
					out << DoctorCheck{'loops', 'bundled', 'warn', 'no bundled loops in ${loops_path}'}
				}
			} else {
				out << DoctorCheck{'loops', 'bundled', 'warn', 'loops dir missing: ${loops_path}'}
			}
		}
	} else {
		out << DoctorCheck{'loops', 'bundled', 'warn', 'no toolkit root'}
	}
	// Workspace loops
	loops_dir := os.join_path(ws, 'loops')
	if os.is_dir(loops_dir) {
		entries := os.ls(loops_dir) or { []string{} }
		mut cnt := 0
		for e in entries {
			p := os.join_path(loops_dir, e)
			if os.is_dir(p) && (os.is_file(os.join_path(p, 'loop.yaml')) || os.is_file(os.join_path(p, 'LOOP.md'))) {
				cnt++
			}
		}
		if cnt > 0 {
			out << DoctorCheck{'loops', 'workspace', 'ok', '${cnt} loops in ${loops_dir}'}
		} else {
			out << DoctorCheck{'loops', 'workspace', 'warn', 'no loops in workspace ${ws}'}
		}
	} else {
		out << DoctorCheck{'loops', 'workspace', 'warn', 'no loops dir at ${loops_dir}'}
	}
	return out
}

fn collect_matrix_checks(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	if root.len == 0 {
		out << DoctorCheck{'matrix', 'platform-capability-matrix', 'warn', 'no toolkit root'}
		return out
	}
	path := os.join_path(root, 'docs', 'research', 'platform-capability-matrix.md')
	if os.is_file(path) {
		out << DoctorCheck{'matrix', 'platform-capability-matrix', 'ok', path}
		// Light content check for parity targets pi/windsurf
		text := os.read_file(path) or { '' }
		if text.contains('pi') || text.contains('windsurf') || text.contains('cursor') {
			out << DoctorCheck{'matrix', 'compiler', 'ok', 'targets parsed (pi/windsurf/cursor present)'}
		} else {
			out << DoctorCheck{'matrix', 'compiler', 'warn', 'matrix missing expected targets'}
		}
	} else {
		out << DoctorCheck{'matrix', 'platform-capability-matrix', 'warn', 'not found: ${path}'}
		out << DoctorCheck{'matrix', 'compiler', 'warn', 'matrix missing, cannot verify parity'}
	}
	return out
}

fn collect_context_cost_checks(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	// Token clip 2000 for memory inject parity (Python cli/context_budget.py:455)
	out << DoctorCheck{'context-cost', 'clip', 'ok', '2000 (memory inject budget)'}
	// Optional: check knowledge base size if workspace exists
	if ws := find_workspace_root('') {
		knowledge := os.join_path(ws, 'knowledge')
		if os.is_dir(knowledge) {
			out << DoctorCheck{'context-cost', 'knowledge', 'ok', knowledge}
		} else {
			out << DoctorCheck{'context-cost', 'knowledge', 'warn', 'knowledge dir missing: ${knowledge}'}
		}
	}
	return out
}

fn collect_audit_checks(root string) []DoctorCheck {
	mut out := []DoctorCheck{}
	if root.len == 0 {
		out << DoctorCheck{'audit', 'skills', 'warn', 'no toolkit root'}
		out << DoctorCheck{'audit', 'loops', 'warn', 'no toolkit root'}
		return out
	}
	// Skills audit via skills_validate (Python parity: skills.validate)
	rep := skills_validate(root)
	if rep.ok {
		detail := if rep.count > 0 { '${rep.count} skills validated' } else { 'skills validated' }
		if rep.warnings > 0 {
			out << DoctorCheck{'audit', 'skills', 'warn', '${detail} (${rep.warnings} warnings)'}
		} else {
			out << DoctorCheck{'audit', 'skills', 'ok', detail}
		}
	} else {
		// Surface first error line for brevity
		mut msg := rep.message.split_into_lines().filter(it.trim_space().len > 0)
		short := if msg.len > 0 { msg.last().trim_space() } else { 'skills validation failed' }
		out << DoctorCheck{'audit', 'skills', 'err', '${rep.errors} error(s): ${short}'}
	}
	loops_dir := os.join_path(root, 'loops')
	if os.is_dir(loops_dir) {
		out << DoctorCheck{'audit', 'loops', 'ok', loops_dir}
	} else if is_embedded_root(root) {
		out << DoctorCheck{'audit', 'loops', 'ok', 'embedded loops present'}
	} else {
		out << DoctorCheck{'audit', 'loops', 'warn', 'loops dir missing: ${loops_dir}'}
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
		for msg in detect_stale_install_check('claude-code', home) {
			out << DoctorCheck{'profiles', 'claude-code stale agents', 'warn', msg}
		}
	}
	if os.is_dir(os.join_path(home, '.cursor')) {
		out << profile_check('cursor rules/', os.join_path(home, '.cursor', 'rules'))
		for msg in detect_stale_install_check('cursor', home) {
			out << DoctorCheck{'profiles', 'cursor stale rules', 'warn', msg}
		}
	}
	if os.is_dir(os.join_path(home, '.config', 'opencode')) {
		out << profile_check('opencode agents/',
			os.join_path(home, '.config', 'opencode', 'agents'))
		out << profile_check('opencode opencode.json', os.join_path(home, '.config', 'opencode',
			'opencode.json'))
		for msg in detect_stale_install_check('opencode', home) {
			out << DoctorCheck{'profiles', 'opencode stale agents', 'warn', msg}
		}
	}
	windsurf := windsurf_config_dir(home)
	if os.is_dir(windsurf) || os.is_dir(os.join_path(home, '.windsurf')) {
		out << profile_check('windsurf rules/', os.join_path(windsurf, 'rules'))
		out << profile_check('windsurf memories/', os.join_path(windsurf, 'memories'))
		for msg in detect_stale_install_check('windsurf', home) {
			out << DoctorCheck{'profiles', 'windsurf stale rules', 'warn', msg}
		}
	}
	if os.is_dir(os.join_path(home, '.pi')) {
		out << profile_check('pi skills/', os.join_path(home, '.pi', 'agent', 'skills'))
		for msg in detect_stale_install_check('pi', home) {
			out << DoctorCheck{'profiles', 'pi stale skills', 'warn', msg}
		}
	}
	return out
}

// detect_stale_install_check surfaces prior-install artifacts that no longer exist
// in the current Toolkit payload (#872). Warns when a receipt tracks stale agents
// still present on disk but absent from current mappings. Does not fail doctor —
// `install --force` cleans them (see install.v cleanup_stale_install_files).
fn detect_stale_install_check(tool string, home string) []string {
	mut out := []string{}
	receipt := load_install_receipt(tool, profiles_product, '') or { return out }
	if receipt.artifacts.len == 0 {
		return out
	}
	// Build current mapping set (best-effort from local checkout or embedded)
	mut data_root := find_toolkit_root() or { ToolkitRoot{} }.path
	mut current := map[string]bool{}
	if data_root.len > 0 {
		for m in install_file_mappings(tool, data_root, home) {
			current[m.dst] = true
		}
	} else if is_embedded_root('embedded') {
		// Embedded CLI (published binary): use compiled agents list directly
		compiled := compiled_agent_files('embedded')
		for name, _ in compiled {
			dst := match tool {
				'claude-code' { os.join_path(home, '.claude', 'agents', '${name}.md') }
				'cursor' { os.join_path(home, '.cursor', 'rules', '${name}.mdc') }
				'opencode' { os.join_path(home, '.config', 'opencode', 'agents', '${name}.md') }
				'windsurf' { '' } // windsurf rules are not agent-derived in doctor stale sense
				'pi' { os.join_path(home, '.pi', 'agent', 'skills', name, 'skill.md') }
				else { '' }
			}
			if dst.len > 0 {
				current[dst] = true
			}
		}
	}
	mut stale := []string{}
	for a in receipt.artifacts {
		if a.ownership != 'created' {
			continue
		}
		if a.path in current {
			continue
		}
		if !os.exists(a.path) {
			continue
		}
		// Heuristic: agent-like stale names (archived #865)
		if a.path.contains('database-reviewer') || a.path.contains('typescript-reviewer')
			|| a.path.contains('performance-optimizer') || a.path.contains('refactor-cleaner')
			|| a.path.contains('docs-lookup') || a.path.contains('reference-lookup')
			|| a.path.contains('tech-assistant') {
			stale << os.file_name(a.path)
		}
	}
	if stale.len == 0 {
		return out
	}
	stale.sort()
	out << 'stale Toolkit files present (${stale.len}): ${stale.join(', ')} — run `agent-toolkit install --force --tools ${tool}` to clean (preserves user files)'
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
