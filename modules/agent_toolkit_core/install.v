module agent_toolkit_core

import os

// install_valid_tools lists profile tools supported by `agent-toolkit install`.
pub const install_valid_tools = ['claude-code', 'cursor', 'opencode', 'copilot', 'windsurf', 'pi',
	'muse-code', 'muse']

const install_agent_products = ['agent-toolkit-core', 'agent-toolkit-agents', 'agent-toolkit-forge']
const install_muse_products = ['agent-toolkit-complete', 'agent-toolkit-core']

// InstallOptions configures profile install (Python cli/install.py).
pub struct InstallOptions {
pub:
	tools             []string
	dry_run           bool
	force             bool
	offline           bool
	home_dir          string // empty → os.home_dir()
	data_root         string // empty → find_toolkit_root()
	receipt_dir       string // empty → default_receipt_dir()
	skip_data_refresh bool
}

// InstallReport summarizes install outcomes.
pub struct InstallReport {
pub mut:
	ok            bool
	message       string
	data_root     string
	files_written int
	tools_ok      int
	skipped       int
	dry_run       bool
	failures      []string
}

// run_install copies toolkit profiles into AI-tool config dirs via InstallTransaction (#607).
pub fn run_install(opts InstallOptions) InstallReport {
	mut report := InstallReport{
		ok:      true
		dry_run: opts.dry_run
	}
	if opts.offline {
		os.setenv('AGENT_TOOLKIT_OFFLINE', '1', true)
	}
	home := if opts.home_dir.len > 0 { opts.home_dir } else { os.home_dir() }
	mut data_root := opts.data_root
	if data_root.len == 0 {
		tr := find_toolkit_root() or {
			report.ok = false
			report.message = 'toolkit root not found: ${err}'
			return report
		}
		data_root = tr.path
	}
	report.data_root = data_root
	receipt_dir := if opts.receipt_dir.len > 0 { opts.receipt_dir } else { default_receipt_dir() }

	mut lines := []string{}
	lines << ''
	lines << 'agent-toolkit installer'
	lines << 'Toolkit: ${data_root}'
	if opts.offline {
		lines << '  [info]  Offline mode — using bundled data only'
	}
	if opts.dry_run {
		lines << ''
		lines << '  ⚠  DRY RUN — no files will be written'
	}

	mut tools := opts.tools.clone()
	if tools.len == 0 {
		lines << ''
		lines << '  [info]  Auto-detecting installed AI tools...'
		tools = detect_install_tools(home, opts.home_dir.len == 0)
		for t in tools {
			lines << '  [info]    Detected: ${t}'
		}
		lines << '  [info]  Copilot: use --tools copilot to install per-project'
		if tools.len == 0 {
			report.ok = false
			lines << '  ⚠  No AI tools detected. Install at least one supported tool and re-run,'
			lines << '  ⚠  or specify with: --tools claude-code,cursor,opencode,copilot,windsurf,pi,muse-code'
			report.message = lines.join('\n')
			return report
		}
	}

	lines << ''
	lines << '  [info]  Tools to install: ${tools.join(', ')}'

	mut installed := []string{}
	mut skipped_tools := []string{}
	mut failed := []string{}
	mut files := 0

	for tool in tools {
		canonical := canonical_install_tool(tool)
		if canonical.len == 0 {
			lines << '  ⚠  Unknown tool: ${tool} (valid: ${install_valid_tools.join(', ')})'
			skipped_tools << tool
			report.skipped++
			continue
		}
		if canonical == 'copilot' {
			lines << ''
			lines << '  [info]  Installing: GitHub Copilot'
			lines << '  -  Non-interactive — skip per-project Copilot (run interactively in Python CLI)'
			skipped_tools << canonical
			report.skipped++
			continue
		}
		ok, tool_files, tool_lines := install_one_tool(canonical, data_root, home, receipt_dir,
			opts.dry_run, opts.force)
		lines << tool_lines
		files += tool_files
		if ok {
			installed << canonical
			report.tools_ok++
		} else {
			failed << canonical
			report.ok = false
		}
	}

	lines << ''
	lines << '----------------------------------------------------------------------'
	lines << 'Installation summary'
	if installed.len > 0 {
		lines << '  ✓  Installed: ${installed.join(', ')}'
	}
	if skipped_tools.len > 0 {
		lines << '  -  Skipped:   ${skipped_tools.join(', ')}'
	}
	if failed.len > 0 {
		lines << '  ✗  Failed:    ${failed.join(', ')}'
		report.failures = failed
	}
	lines << ''
	lines << '  [info]  Next steps:'
	lines << '  [info]    1. Restart your AI tool(s) to load the new profiles'
	lines << "  [info]    2. Run 'agent-toolkit doctor' to verify the installation"
	report.files_written = files
	report.message = lines.join('\n')
	if failed.len > 0 {
		report.ok = false
	}
	return report
}

// install_result maps InstallReport to CommandResult.
pub fn install_result(report InstallReport) CommandResult {
	return CommandResult{
		command: 'install'
		ok:      report.ok
		message: report.message
		data:    {
			'data_root':     report.data_root
			'files_written': '${report.files_written}'
			'tools_ok':      '${report.tools_ok}'
			'skipped':       '${report.skipped}'
			'dry_run':       if report.dry_run { 'true' } else { 'false' }
			'failures':      report.failures.join(',')
		}
	}
}

fn canonical_install_tool(tool string) string {
	if tool == 'muse' {
		return 'muse-code'
	}
	if tool in install_valid_tools {
		return tool
	}
	return ''
}

fn detect_install_tools(home string, check_path bool) []string {
	mut out := []string{}
	if (check_path && install_tool_on_path('claude')) || os.exists(os.join_path(home, '.claude')) {
		out << 'claude-code'
	}
	if (check_path && install_tool_on_path('cursor')) || os.exists(os.join_path(home, '.cursor')) {
		out << 'cursor'
	}
	if (check_path && install_tool_on_path('opencode'))
		|| os.exists(os.join_path(home, '.config', 'opencode')) {
		out << 'opencode'
	}
	if (check_path && install_tool_on_path('windsurf'))
		|| os.exists(os.join_path(home, '.codeium', 'windsurf'))
		|| os.exists(os.join_path(home, '.windsurf')) {
		out << 'windsurf'
	}
	if (check_path && install_tool_on_path('pi')) || os.exists(os.join_path(home, '.pi')) {
		out << 'pi'
	}
	if (check_path && install_tool_on_path('muse'))
		|| os.exists(os.join_path(home, '.config', 'muse'))
		|| os.exists(os.join_path(home, '.agents')) {
		out << 'muse-code'
	}
	return out
}

fn install_tool_on_path(name string) bool {
	os.find_abs_path_of_executable(name) or { return false }
	return true
}

fn install_one_tool(tool string, data_root string, home string, receipt_dir string, dry_run bool, force bool) (bool, int, string) {
	mut lines := []string{}
	lines << ''
	lines << '  [info]  Installing: ${tool}'
	if !install_source_present(tool, data_root) {
		lines << '  ⚠  Profile source not found for ${tool}'
		return false, 0, lines.join('\n')
	}
	mappings := install_file_mappings(tool, data_root, home)
	if mappings.len == 0 {
		lines << '  ⚠  No installable files for ${tool}'
		return false, 0, lines.join('\n')
	}
	if dry_run {
		for m in mappings {
			lines << '  [dry]   Would copy: ${os.file_name(m.src)} → ${m.dst}'
		}
		return true, mappings.len, lines.join('\n')
	}
	mut tx := new_install_transaction(tool, InstallTxOptions{
		dry_run:      false
		force:        force
		receipt_dir:  receipt_dir
		toolkit_root: data_root
	})
	mut planned := 0
	for m in mappings {
		if !os.is_file(m.src) {
			lines << '  ⚠  Source not found, skipping: ${m.src}'
			continue
		}
		kind := stage_install_mapping(mut tx, m, force) or {
			lines << '  ✗  Failed to stage ${m.dst}: ${err}'
			return false, 0, lines.join('\n')
		}
		match kind {
			'skip_identical' {
				lines << '  -  Already up to date: ${m.dst}'
			}
			'skip_preserve' {
				lines << '  -  Preserving user-owned file (use --force to overwrite): ${m.dst}'
			}
			'merged' {
				lines << '  ✓  Merged config: ${m.dst}'
				planned++
			}
			else {
				lines << '  ✓  Installed: ${m.dst}'
				planned++
			}
		}
	}
	path := tx.commit() or {
		lines << '  ✗  Install commit failed: ${err}'
		return false, 0, lines.join('\n')
	}
	if path.len > 0 {
		lines << '  ✓  Saved install receipt for ${tool}'
	}
	return true, planned, lines.join('\n')
}

fn stage_install_mapping(mut tx InstallTransaction, m FileMapping, force bool) !string {
	if m.dst.ends_with('.json') && os.is_file(m.dst) && !force {
		content, ownership := merge_json_install(m.src, m.dst)
		if ownership == 'skipped' {
			return 'skip_preserve'
		}
		if ownership == 'unchanged' {
			return 'skip_identical'
		}
		tx.stage_write_owned(m.dst, content, 'merged')!
		return 'merged'
	}
	src := os.read_file(m.src) or { return error('read source failed: ${m.src}: ${err}') }
	if os.is_file(m.dst) {
		existing := os.read_file(m.dst) or { return error('read dest failed: ${m.dst}: ${err}') }
		if existing == src {
			return 'skip_identical'
		}
		if !force {
			return 'skip_preserve'
		}
	}
	tx.stage_write(m.dst, src)!
	return 'created'
}

fn merge_json_install(src_path string, dst_path string) (string, string) {
	src_text := os.read_file(src_path) or { return '', 'skipped' }
	dst_text := os.read_file(dst_path) or { return '', 'skipped' }
	overlay := parse_flat_json_strings(src_text) or { return '', 'skipped' }
	mut base := parse_flat_json_strings(dst_text) or { return '', 'skipped' }
	mut changed := false
	for k, v in overlay {
		if k !in base {
			base[k] = v
			changed = true
		}
	}
	if !changed {
		return dst_text, 'unchanged'
	}
	return encode_flat_json_strings(base) + '\n', 'merged'
}

fn parse_flat_json_strings(text string) ?map[string]string {
	s := text.trim_space()
	if s.len < 2 || s[0] != `{` {
		return none
	}
	mut out := map[string]string{}
	mut i := 1
	for i < s.len {
		for i < s.len && (s[i].is_space() || s[i] == `,`) {
			i++
		}
		if i >= s.len || s[i] == `}` {
			break
		}
		if s[i] != `"` {
			return none
		}
		i++
		key_start := i
		for i < s.len && s[i] != `"` {
			i++
		}
		if i >= s.len {
			return none
		}
		key := s[key_start..i]
		i++
		for i < s.len && s[i].is_space() {
			i++
		}
		if i >= s.len || s[i] != `:` {
			return none
		}
		i++
		for i < s.len && s[i].is_space() {
			i++
		}
		if i >= s.len || s[i] != `"` {
			return none
		}
		i++
		val_start := i
		for i < s.len {
			if s[i] == `\\` && i + 1 < s.len {
				i += 2
				continue
			}
			if s[i] == `"` {
				break
			}
			i++
		}
		if i >= s.len {
			return none
		}
		out[key] = s[val_start..i]
		i++
	}
	return out
}

fn encode_flat_json_strings(m map[string]string) string {
	mut keys := m.keys()
	keys.sort()
	mut parts := []string{}
	for k in keys {
		parts << '"${k}":"${m[k]}"'
	}
	return '{' + parts.join(',') + '}'
}

fn install_source_present(tool string, data_root string) bool {
	match tool {
		'claude-code' {
			profile := os.join_path(data_root, 'profiles', 'claude-code')
			return os.is_dir(profile) || compiled_agent_files(data_root).len > 0
		}
		'cursor' {
			return os.is_dir(os.join_path(data_root, 'profiles', 'cursor', 'rules'))
		}
		'opencode' {
			profile := os.join_path(data_root, 'profiles', 'opencode')
			return os.is_dir(profile) || compiled_agent_files(data_root).len > 0
		}
		'windsurf' {
			return os.is_dir(os.join_path(data_root, 'profiles', 'windsurf'))
		}
		'pi' {
			return os.is_dir(os.join_path(data_root, 'profiles', 'pi', 'skills'))
		}
		'muse-code' {
			if os.is_dir(os.join_path(data_root, 'skills')) {
				return true
			}
			if os.is_dir(os.join_path(data_root, 'profiles', 'muse-code')) {
				return true
			}
			for prod in install_muse_products {
				if os.is_dir(os.join_path(data_root, 'plugins', prod, 'skills')) {
					return true
				}
			}
			return os.is_dir(os.join_path(data_root, 'plugins', 'muse-code', 'skills'))
		}
		else {
			return false
		}
	}
}

fn install_file_mappings(tool string, data_root string, home string) []FileMapping {
	mut mappings := []FileMapping{}
	compiled := compiled_agent_files(data_root)
	match tool {
		'claude-code' {
			claude_md := os.join_path(data_root, 'profiles', 'claude-code', 'CLAUDE.md')
			if os.is_file(claude_md) {
				mappings << FileMapping{claude_md, os.join_path(home, '.claude', 'CLAUDE.md')}
			}
			mappings << agent_dest_mappings(tool, data_root, compiled, os.join_path(home,
				'.claude', 'agents'))
		}
		'cursor' {
			src := os.join_path(data_root, 'profiles', 'cursor', 'rules')
			mappings << map_tree_files(src, os.join_path(home, '.cursor', 'rules'))
		}
		'opencode' {
			cfg := os.join_path(data_root, 'profiles', 'opencode', 'opencode.json')
			if os.is_file(cfg) {
				mappings << FileMapping{cfg, os.join_path(home, '.config', 'opencode',
					'opencode.json')}
			}
			mappings << agent_dest_mappings(tool, data_root, compiled, os.join_path(home,
				'.config', 'opencode', 'agents'))
		}
		'windsurf' {
			src := os.join_path(data_root, 'profiles', 'windsurf')
			cfg := windsurf_config_dir(home)
			for sub in ['rules', 'memories'] {
				mappings << map_tree_files(os.join_path(src, sub), os.join_path(cfg, sub))
			}
		}
		'pi' {
			src := os.join_path(data_root, 'profiles', 'pi', 'skills')
			mappings << map_tree_files(src, os.join_path(home, '.pi', 'agent', 'skills'))
		}
		'muse-code' {
			mappings << muse_skill_mappings(data_root, home)
		}
		else {}
	}
	return mappings
}

fn agent_dest_mappings(tool string, data_root string, compiled map[string]string, dst_dir string) []FileMapping {
	if compiled.len > 0 {
		mut out := []FileMapping{}
		mut names := compiled.keys()
		names.sort()
		for name in names {
			out << FileMapping{
				src: compiled[name]
				dst: os.join_path(dst_dir, '${name}.md')
			}
		}
		return out
	}
	return map_tree_files(os.join_path(data_root, 'profiles', tool, 'agents'), dst_dir)
}

fn compiled_agent_files(data_root string) map[string]string {
	mut plugins := os.join_path(data_root, 'plugins')
	override := os.getenv('AGENT_TOOLKIT_INSTALL_SOURCE').trim_space()
	if override.len > 0 && os.is_dir(override) {
		plugins = override
	}
	if !os.is_dir(plugins) {
		parent := os.join_path(os.dir(data_root), 'plugins')
		if os.is_dir(parent) {
			plugins = parent
		}
	}
	mut agents := map[string]string{}
	if !os.is_dir(plugins) {
		return agents
	}
	for product_id in install_agent_products {
		agents_dir := os.join_path(plugins, product_id, 'agents')
		if !os.is_dir(agents_dir) {
			continue
		}
		entries := os.ls(agents_dir) or { continue }
		for e in entries {
			agent_md := os.join_path(agents_dir, e, 'AGENT.md')
			if os.is_file(agent_md) {
				agents[e] = agent_md
			}
		}
	}
	return agents
}

fn muse_skill_mappings(data_root string, home string) []FileMapping {
	mut src := ''
	for prod in install_muse_products {
		p := os.join_path(data_root, 'plugins', prod, 'skills')
		if os.is_dir(p) {
			src = p
			break
		}
	}
	if src.len == 0 {
		p := os.join_path(data_root, 'plugins', 'muse-code', 'skills')
		if os.is_dir(p) {
			src = p
		}
	}
	if src.len == 0 {
		p := os.join_path(data_root, 'skills')
		if os.is_dir(p) {
			src = p
		}
	}
	if src.len == 0 {
		return map_tree_files(os.join_path(data_root, 'profiles', 'muse-code'), os.join_path(home,
			'.config', 'muse'))
	}
	mut out := []FileMapping{}
	out << map_tree_files(src, os.join_path(home, '.config', 'muse', 'skills'))
	out << map_tree_files(src, os.join_path(home, '.agents', 'skills'))
	return out
}
