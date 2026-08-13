module agent_toolkit_core

import json
import os

// skills_sync_tools are destinations supported by `skills sync`.
pub const skills_sync_tools = ['claude-code', 'cursor', 'opencode']

// SkillsOptions configures the skills command family (#517).
pub struct SkillsOptions {
pub:
	subcommand   string // list | sync | validate | help
	domain       string
	tools        []string
	home_dir     string // empty → os.home_dir()
	toolkit_root string // empty → lookup_checkout_root()
}

// SkillsReport is the domain result for skills list/sync/validate.
pub struct SkillsReport {
pub mut:
	ok      bool
	message string
	count   int
	errors  int
	warnings int
}

struct LayoutSkill {
	id     string
	name   string
	domain string
}

struct SkillsLayoutFile {
	skills []LayoutSkill
}

// run_skills implements list / sync / validate (Python cli/skills.py parity).
pub fn run_skills(opts SkillsOptions) SkillsReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return SkillsReport{
			ok:      true
			message: skills_help_text()
		}
	}
	root := if opts.toolkit_root.len > 0 { opts.toolkit_root } else { lookup_checkout_root() }
	if root.len == 0 {
		return SkillsReport{
			ok:      false
			message: 'Cannot locate toolkit directory (set AGENT_TOOLKIT_ROOT)'
		}
	}
	home := if opts.home_dir.len > 0 { opts.home_dir } else { os.home_dir() }
	return match sub {
		'list' { skills_list(root, opts.domain) }
		'sync' { skills_sync(root, home, opts.tools) }
		'validate' { skills_validate(root) }
		else {
			SkillsReport{
				ok:      false
				message: 'Unknown subcommand: ${sub}\n  Valid subcommands: list, sync, validate'
			}
		}
	}
}

// skills_result maps SkillsReport to CommandResult.
pub fn skills_result(report SkillsReport) CommandResult {
	return CommandResult{
		command: 'skills'
		ok:      report.ok
		message: report.message
		data:    {
			'count':    '${report.count}'
			'errors':   '${report.errors}'
			'warnings': '${report.warnings}'
		}
	}
}

pub fn skills_help_text() string {
	return 'Usage: agent-toolkit skills <subcommand> [options]

Subcommands:
    list [--domain DOMAIN]     List skills grouped by domain
    sync [--tools TOOLS]       Sync skills to tool-specific directories
    validate                   Validate SKILL.md frontmatter

Options:
    --domain DOMAIN   Filter by domain (used with list)
    --tools TOOLS     Comma-separated tools to sync (used with sync)
                      Valid: claude-code, cursor, opencode
    --json            Structured CommandResult JSON
'
}

fn skills_list(root string, domain_filter string) SkillsReport {
	layout := load_skills_layout(root) or {
		return SkillsReport{
			ok:      false
			message: err.msg()
		}
	}
	mut groups := map[string][]string{}
	for s in layout.skills {
		dom := if s.domain.len > 0 { s.domain } else { first_path_component(s.id) }
		if dom.len == 0 {
			continue
		}
		mut names := groups[dom]
		if s.name !in names {
			names << s.name
		}
		groups[dom] = names
	}
	if domain_filter.len > 0 && domain_filter !in groups {
		mut available := groups.keys()
		available.sort()
		return SkillsReport{
			ok:      false
			message: 'Unknown domain: ${domain_filter}  (available: ${available.join(', ')})'
		}
	}
	mut domains := groups.keys()
	domains.sort()
	if domain_filter.len > 0 {
		domains = [domain_filter]
	}
	mut lines := []string{}
	lines << ''
	lines << 'Available skills'
	lines << ''
	mut total := 0
	for _, names in groups {
		total += names.len
	}
	for domain in domains {
		mut names := groups[domain].clone()
		names.sort()
		lines << '── ${domain} ──'
		for name in names {
			path := os.join_path(root, 'skills', domain, name, 'SKILL.md')
			exists_marker := if os.is_file(path) { '✓' } else { '✗' }
			desc := skill_description(path)
			desc_str := if desc.len > 0 { '  — ${desc}' } else { '' }
			lines << '  ${exists_marker}  ${name:-40}${desc_str}'
		}
		lines << ''
	}
	lines << 'Total: ${total} skill(s) across ${groups.len} domain(s)'
	lines << ''
	return SkillsReport{
		ok:      true
		message: lines.join('\n')
		count:   total
	}
}

fn skills_sync(root string, home string, requested []string) SkillsReport {
	mut tools := requested.clone()
	if tools.len == 0 {
		tools = skills_sync_tools.clone()
	}
	mut lines := []string{}
	lines << ''
	lines << 'Syncing skills...'
	lines << ''
	mut ok := true
	mut count := 0
	for tool in tools {
		if tool !in skills_sync_tools {
			lines << '  ⚠  Unknown tool: ${tool}  (valid: ${skills_sync_tools.join(', ')})'
			ok = false
			continue
		}
		lines << '── ${tool} ──'
		tool_ok, tool_lines, n := match tool {
			'claude-code' { sync_skills_copy(root, os.join_path(home, '.claude', 'skills')) }
			'opencode' { sync_skills_copy(root, os.join_path(home, '.config', 'opencode', 'skills')) }
			'cursor' { sync_skills_cursor_index(root, os.join_path(home, '.cursor', 'skills-index.json')) }
			else { false, ['  ⚠  Unknown tool: ${tool}'], 0 }
		}
		lines << tool_lines
		count += n
		if !tool_ok {
			ok = false
		}
		lines << ''
	}
	return SkillsReport{
		ok:      ok
		message: lines.join('\n')
		count:   count
	}
}

fn skills_validate(root string) SkillsReport {
	skills_dir := os.join_path(root, 'skills')
	if !os.is_dir(skills_dir) {
		return SkillsReport{
			ok:      false
			message: 'Skills directory not found: ${skills_dir}'
		}
	}
	mut lines := []string{}
	lines << ''
	lines << 'Validating SKILL.md frontmatter...'
	lines << ''
	lines << '── skills/ ──'
	mut total_errors := 0
	mut total_warnings := 0
	mut skill_count := 0
	domains := os.ls(skills_dir) or { []string{} }
	mut domain_names := domains.clone()
	domain_names.sort()
	for domain in domain_names {
		dpath := os.join_path(skills_dir, domain)
		if !os.is_dir(dpath) {
			continue
		}
		entries := os.ls(dpath) or { continue }
		mut names := entries.clone()
		names.sort()
		for name in names {
			spath := os.join_path(dpath, name)
			if !os.is_dir(spath) {
				continue
			}
			errs, warns, msg := validate_skill_dir(spath, root)
			total_errors += errs
			total_warnings += warns
			skill_count++
			lines << msg
		}
	}
	plugins_dir := os.join_path(root, 'plugins')
	if os.is_dir(plugins_dir) {
		lines << ''
		lines << '── plugins/ (bundled copies) ──'
		plugins := os.ls(plugins_dir) or { []string{} }
		mut plugin_names := plugins.clone()
		plugin_names.sort()
		for plugin in plugin_names {
			ps := os.join_path(plugins_dir, plugin, 'skills')
			if !os.is_dir(ps) {
				continue
			}
			sk := os.ls(ps) or { continue }
			mut sk_names := sk.clone()
			sk_names.sort()
			for name in sk_names {
				spath := os.join_path(ps, name)
				if !os.is_dir(spath) {
					continue
				}
				errs, warns, msg := validate_skill_dir(spath, root)
				total_errors += errs
				total_warnings += warns
				lines << msg
			}
		}
	}
	lines << ''
	lines << '── Summary ──'
	lines << '  Skills validated: ${skill_count}'
	if total_errors > 0 {
		lines << ''
		lines << '  ✗  ${total_errors} error(s) found'
	} else if total_warnings > 0 {
		lines << ''
		lines << '  ⚠  All valid with ${total_warnings} warning(s)'
	} else {
		lines << ''
		lines << '  ✓  All SKILL.md files are valid!'
	}
	return SkillsReport{
		ok:       total_errors == 0
		message:  lines.join('\n')
		count:    skill_count
		errors:   total_errors
		warnings: total_warnings
	}
}

fn load_skills_layout(root string) !SkillsLayoutFile {
	path := os.join_path(root, 'catalogs', 'skills-layout.json')
	if !os.is_file(path) {
		return error('skills-layout.json not found: ${path}')
	}
	text := os.read_file(path) or { return error('Cannot parse skills-layout.json: ${err}') }
	return json.decode(SkillsLayoutFile, text) or {
		return error('Cannot parse skills-layout.json: ${err}')
	}
}

fn skill_description(skill_md string) string {
	if !os.is_file(skill_md) {
		return ''
	}
	text := os.read_file(skill_md) or { return '' }
	fm := parse_skill_frontmatter(text) or { return '' }
	desc := fm['description'] or { '' }
	if desc.len > 120 {
		return desc[..120]
	}
	return desc
}

fn parse_skill_frontmatter(content string) ?map[string]string {
	if !content.starts_with('---') {
		return none
	}
	rest := content[3..]
	end := rest.index('\n---') or { return none }
	block := rest[..end]
	mut result := map[string]string{}
	lines := block.split_into_lines()
	mut i := 0
	for i < lines.len {
		line := lines[i]
		stripped := line.trim_space()
		if stripped.len == 0 || stripped.starts_with('#') {
			i++
			continue
		}
		if !stripped.contains(':') {
			i++
			continue
		}
		key := stripped.all_before(':').trim_space()
		mut val := stripped.all_after(':').trim_space().trim('"').trim("'")
		if val in ['>', '>-', '|-', '|', '>+', '|+'] {
			mut block_lines := []string{}
			i++
			for i < lines.len && (lines[i].starts_with(' ') || lines[i].starts_with('\t')) {
				block_lines << lines[i].trim_space()
				i++
			}
			result[key] = block_lines.join(' ')
			continue
		}
		if key.len > 0 {
			result[key] = val
		}
		i++
	}
	return result
}

fn sync_skills_copy(root string, dst_root string) (bool, []string, int) {
	skills_dir := os.join_path(root, 'skills')
	if !os.is_dir(skills_dir) {
		return false, ['  ✗  Skills directory not found: ${skills_dir}'], 0
	}
	mut lines := []string{}
	mut ok := true
	mut n := 0
	files := collect_named(skills_dir, 'SKILL.md')
	mut sorted := files.clone()
	sorted.sort()
	fs := new_fs()
	for skill_md in sorted {
		name := os.file_name(os.dir(skill_md))
		dst := os.join_path(dst_root, name, 'SKILL.md')
		src_bytes := os.read_file(skill_md) or {
			lines << '  ✗  ${name}: ${err}'
			ok = false
			continue
		}
		if os.is_file(dst) {
			dst_bytes := os.read_file(dst) or { '' }
			if dst_bytes == src_bytes {
				lines << '  -  ${name}: already up to date'
				continue
			}
		}
		fs.write_atomic(dst, src_bytes) or {
			lines << '  ✗  ${name}: ${err}'
			ok = false
			continue
		}
		lines << '  ✓  ${name}: synced → ${dst}'
		n++
	}
	return ok, lines, n
}

fn sync_skills_cursor_index(root string, dst string) (bool, []string, int) {
	layout := load_skills_layout(root) or {
		return false, ['  ✗  ${err.msg()}'], 0
	}
	mut items := []string{}
	for s in layout.skills {
		dom := if s.domain.len > 0 { s.domain } else { first_path_component(s.id) }
		path := os.join_path(root, 'skills', dom, s.name)
		desc := skill_description(os.join_path(path, 'SKILL.md'))
		escaped_desc := json.encode(desc)
		escaped_path := json.encode(path)
		items << '{"name":${json.encode(s.name)},"group":${json.encode(dom)},"description":${escaped_desc},"path":${escaped_path}}'
	}
	payload := '{"skills":[${items.join(',')}]}\n'
	fs := new_fs()
	fs.write_atomic(dst, payload) or {
		return false, ['  ✗  cursor: ${err}'], 0
	}
	return true, ['  ✓  cursor: skills-index written → ${dst} (${layout.skills.len} skills)'], layout.skills.len
}

fn validate_skill_dir(skill_dir string, toolkit_dir string) (int, int, string) {
	rel := relative_to(skill_dir, toolkit_dir) or { skill_dir }
	skill_md := os.join_path(skill_dir, 'SKILL.md')
	if !os.is_file(skill_md) {
		return 1, 0, '  ✗  ${rel}: missing SKILL.md'
	}
	content := os.read_file(skill_md) or {
		return 1, 0, '  ✗  ${rel}/SKILL.md: cannot read: ${err}'
	}
	fm := parse_skill_frontmatter(content) or {
		return 1, 0, '  ✗  ${rel}/SKILL.md: no YAML frontmatter found (must start with ---)'
	}
	mut errors := 0
	mut warnings := 0
	mut lines := []string{}
	for field in ['name', 'description'] {
		val := fm[field] or { '' }
		if val.len == 0 {
			lines << "  ✗  ${rel}/SKILL.md: missing required frontmatter field '${field}'"
			errors++
		}
	}
	name := fm['name'] or { '' }
	dir_name := os.file_name(skill_dir)
	if name.len > 0 && name != dir_name {
		lines << "  ⚠  ${rel}/SKILL.md: name '${name}' does not match directory '${dir_name}'"
		warnings++
	}
	if os.is_file(os.join_path(skill_dir, 'skill.json')) {
		lines << '  ⚠  ${rel}: skill.json found — not needed, can be removed'
		warnings++
	}
	if errors == 0 {
		lines << '  ✓  ${rel}/SKILL.md'
	}
	return errors, warnings, lines.join('\n')
}
