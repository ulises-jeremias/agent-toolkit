module agent_toolkit_core

import crypto.sha256
import os

// update_valid_tools lists profile tools supported by `agent-toolkit update`.
pub const update_valid_tools = ['claude-code', 'cursor', 'opencode', 'windsurf', 'pi']

// UpdateOptions configures capability profile update (not binary self-update).
pub struct UpdateOptions {
pub:
	tools             []string
	check_only        bool
	pin               string // empty → ensure current toolkit version when refreshing
	home_dir          string // empty → os.home_dir()
	data_root         string // empty → find_toolkit_root()
	skip_data_refresh bool   // tests / offline callers that already resolved data
}

// UpdateReport summarizes profile refresh outcomes.
pub struct UpdateReport {
pub mut:
	ok             bool
	message        string
	data_root      string
	files_updated  int
	tools_planned  int
	warnings       []string
}

// run_update refreshes installed AI-tool profiles from toolkit capability data (#516).
pub fn run_update(opts UpdateOptions) UpdateReport {
	mut report := UpdateReport{
		ok: true
	}
	mut lines := []string{}
	lines << 'agent-toolkit update'

	home := if opts.home_dir.len > 0 { opts.home_dir } else { os.home_dir() }
	mut data_root := opts.data_root
	if data_root.len == 0 {
		if !opts.skip_data_refresh {
			ver := if opts.pin.len > 0 { opts.pin } else { resolve_toolkit_version() }
			sync := new_data_sync()
			offline := is_offline()
			refreshed := sync.ensure_data(ver, offline, opts.pin.len > 0) or {
				report.warnings << 'data refresh skipped: ${err}'
				lines << '  ⚠  Data refresh skipped: ${err}'
				''
			}
			if refreshed.len > 0 {
				data_root = refreshed
			}
		}
		if data_root.len == 0 {
			tr := find_toolkit_root() or {
				report.ok = false
				report.message = 'toolkit root not found: ${err}'
				return report
			}
			data_root = tr.path
		}
	}
	report.data_root = data_root
	lines << '  Data: ${data_root}'
	if opts.check_only {
		lines << '  [check] Dry run — no files will be written'
	}

	mut tools := opts.tools.clone()
	if tools.len == 0 {
		tools = detect_update_tools(home)
		if tools.len == 0 {
			report.ok = false
			report.message = lines.join('\n') + '\n  ⚠  No installed tools detected. Use --tools to specify targets.'
			return report
		}
		lines << '  Tools: ${tools.join(', ')}'
	}

	mut total := 0
	mut any_errors := false
	for tool in tools {
		if tool !in update_valid_tools {
			lines << '  ⚠  Unknown tool: ${tool}'
			report.warnings << 'unknown tool: ${tool}'
			any_errors = true
			continue
		}
		plan := plan_tool_update(tool, data_root, home) or {
			lines << '  ⚠  No profile data for: ${tool}'
			continue
		}
		report.tools_planned++
		pending := plan.changed.len + plan.added.len
		if pending == 0 {
			lines << '  ✓ ${tool}: up to date (${plan.up_to_date.len} files)'
			continue
		}
		lines << '  → ${tool}: ${plan.changed.len} changed, ${plan.added.len} new'
		n, apply_lines := apply_tool_update(plan, data_root, home, opts.check_only)
		total += n
		for l in apply_lines {
			lines << l
		}
	}

	lines << ''
	if opts.check_only {
		lines << '  ${total} file(s) would be updated'
		report.ok = total == 0 && !any_errors
	} else if total > 0 {
		lines << '  Updated ${total} file(s)'
		report.ok = !any_errors
	} else {
		lines << '  All profiles up to date'
		report.ok = !any_errors
	}
	report.files_updated = total
	report.message = lines.join('\n')
	return report
}

// update_result maps UpdateReport to CommandResult.
pub fn update_result(report UpdateReport) CommandResult {
	return CommandResult{
		command: 'update'
		ok:      report.ok
		message: report.message
		data:    {
			'data_root':     report.data_root
			'files_updated': '${report.files_updated}'
			'tools_planned': '${report.tools_planned}'
			'check':         if report.message.contains('[check]') { 'true' } else { 'false' }
		}
	}
}

struct FileMapping {
	src string
	dst string
}

struct ToolUpdatePlan {
mut:
	tool       string
	changed    []string
	added      []string
	up_to_date []string
	mappings   []FileMapping
}

fn detect_update_tools(home string) []string {
	mut out := []string{}
	if os.exists(os.join_path(home, '.claude')) || os.exists('/usr/bin/claude') {
		out << 'claude-code'
	}
	if os.exists(os.join_path(home, '.cursor')) {
		out << 'cursor'
	}
	if os.exists(os.join_path(home, '.config', 'opencode')) {
		out << 'opencode'
	}
	if os.exists(os.join_path(home, '.codeium', 'windsurf')) || os.exists(os.join_path(home, '.windsurf')) {
		out << 'windsurf'
	}
	if os.exists(os.join_path(home, '.pi')) {
		out << 'pi'
	}
	return out
}

fn windsurf_config_dir(home string) string {
	codeium := os.join_path(home, '.codeium', 'windsurf')
	if os.is_dir(codeium) {
		return codeium
	}
	legacy := os.join_path(home, '.windsurf')
	if os.is_dir(legacy) {
		return legacy
	}
	return codeium
}

fn mappings_for_tool(tool string, data_root string, home string) []FileMapping {
	mut mappings := []FileMapping{}
	match tool {
		'claude-code' {
			src := os.join_path(data_root, 'profiles', 'claude-code')
			claude_md := os.join_path(src, 'CLAUDE.md')
			if data_is_file(data_root, claude_md) {
				mappings << FileMapping{claude_md, os.join_path(home, '.claude', 'CLAUDE.md')}
			}
			agents := os.join_path(src, 'agents')
			mappings << data_map_tree_files(data_root, agents, os.join_path(home, '.claude', 'agents'))
		}
		'cursor' {
			src := os.join_path(data_root, 'profiles', 'cursor', 'rules')
			mappings << data_map_tree_files(data_root, src, os.join_path(home, '.cursor', 'rules'))
		}
		'opencode' {
			src := os.join_path(data_root, 'profiles', 'opencode')
			cfg := os.join_path(src, 'opencode.json')
			if data_is_file(data_root, cfg) {
				mappings << FileMapping{cfg, os.join_path(home, '.config', 'opencode', 'opencode.json')}
			}
			agents := os.join_path(src, 'agents')
			mappings << data_map_tree_files(data_root, agents, os.join_path(home, '.config', 'opencode', 'agents'))
		}
		'windsurf' {
			src := os.join_path(data_root, 'profiles', 'windsurf')
			cfg := windsurf_config_dir(home)
			for sub in ['rules', 'memories'] {
				mappings << data_map_tree_files(data_root, os.join_path(src, sub), os.join_path(cfg, sub))
			}
		}
		'pi' {
			src := os.join_path(data_root, 'profiles', 'pi', 'skills')
			mappings << data_map_tree_files(data_root, src, os.join_path(home, '.pi', 'agent', 'skills'))
		}
		else {}
	}
	return mappings
}

fn map_tree_files(src_dir string, dst_dir string) []FileMapping {
	mut out := []FileMapping{}
	if !os.is_dir(src_dir) {
		return out
	}
	for rel in list_rel_files(src_dir) {
		out << FileMapping{
			src: os.join_path(src_dir, rel)
			dst: os.join_path(dst_dir, rel)
		}
	}
	return out
}

fn plan_tool_update(tool string, data_root string, home string) ?ToolUpdatePlan {
	mappings := mappings_for_tool(tool, data_root, home)
	if mappings.len == 0 {
		return none
	}
	mut plan := ToolUpdatePlan{
		tool:     tool
		mappings: mappings
	}
	for m in mappings {
		is_src := if m.src.starts_with('embedded/') { embedded_is_file(m.src[9..]) } else { os.is_file(m.src) }
		if !is_src {
			continue
		}
		src_hash := update_file_hash(m.src)
		if os.is_file(m.dst) {
			if update_file_hash(m.dst) == src_hash {
				plan.up_to_date << m.dst
			} else {
				plan.changed << m.dst
			}
		} else {
			plan.added << m.dst
		}
	}
	return plan
}

fn apply_tool_update(plan ToolUpdatePlan, data_root string, home string, check_only bool) (int, []string) {
	mut lines := []string{}
	mut updated := 0
	mut targets := map[string]bool{}
	for p in plan.changed {
		targets[p] = true
	}
	for p in plan.added {
		targets[p] = true
	}
	fs := new_fs()
	for m in plan.mappings {
		if m.dst !in targets {
			continue
		}
		rel := relative_to(m.dst, home) or { m.dst }
		display := if rel.starts_with('/') || rel.contains(':') { rel } else { '~/${rel.replace('\\', '/')}' }
		if check_only {
			lines << '  ~ would update: ${display}'
			updated++
			continue
		}
		content := if m.src.starts_with('embedded/') {
			embedded_read_file(m.src[9..]) or {
				lines << '  ✗  failed to read ${m.src}: ${err}'
				continue
			}
		} else {
			os.read_file(m.src) or {
				lines << '  ✗  failed to read ${m.src}: ${err}'
				continue
			}
		}
			continue
		}
		fs.write_atomic(m.dst, content) or {
			lines << '  ✗  failed to write ${m.dst}: ${err}'
			continue
		}
		lines << '  ✓ updated: ${display}'
		updated++
	}
	_ = data_root
	return updated, lines
}

fn update_file_hash(path string) string {
	data := if path.starts_with('embedded/') {
		embedded_read_file(path[9..]) or { return '' }
	} else {
		os.read_file(path) or { return '' }
	}
	return sha256.hexhash(data)
}
