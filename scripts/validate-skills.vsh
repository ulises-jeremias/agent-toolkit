#!/usr/bin/env -S v run
// Validate SKILL.md frontmatter across all skills per Agent Skills spec.
// Usage: ./scripts/validate-skills.vsh   (from repo root or any subdir)

fn repo_root() string {
	mut d := dir(@FILE)
	// scripts/ -> repo root
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

fn extract_frontmatter(content string) ?string {
	lines := content.split_into_lines()
	if lines.len < 2 || lines[0].trim_space() != '---' {
		return none
	}
	mut end := -1
	for i := 1; i < lines.len; i++ {
		if lines[i].trim_space() == '---' {
			end = i
			break
		}
	}
	if end < 0 {
		return none
	}
	return lines[1..end].join('\n')
}

fn fm_field(fm string, key string) ?string {
	prefix := '${key}:'
	lines := fm.split_into_lines()
	mut i := 0
	for i < lines.len {
		line := lines[i]
		if line.starts_with(prefix) {
			mut val := line[prefix.len..].trim_space()
			if val.len >= 2 {
				if (val[0] == `'` && val[val.len - 1] == `'`)
					|| (val[0] == `"` && val[val.len - 1] == `"`) {
					val = val[1..val.len - 1]
				}
			}
			mut parts := []string{}
			if val.len > 0 {
				parts << val
			}
			i++
			for i < lines.len {
				cont := lines[i]
				if cont.len > 0 && (cont[0] == ` ` || cont[0] == `\t`) {
					parts << cont.trim_space()
					i++
					continue
				}
				break
			}
			joined := parts.join(' ').trim_space()
			if joined.len == 0 {
				return none
			}
			return joined
		}
		i++
	}
	return none
}

fn main() {
	root := repo_root()
	skills_dir := join_path(root, 'skills')
	plugins_dir := join_path(root, 'plugins')
	mut errors := []string{}
	mut warnings := []string{}

	println('\n🔍 Validating SKILL.md frontmatter (Agent Skills spec)...\n')
	mut skill_count := 0
	println('── skills/ ──')
	domains := ls(skills_dir) or { []string{} }
	for domain in domains.sorted() {
		domain_path := join_path(skills_dir, domain)
		if !is_dir(domain_path) {
			continue
		}
		skills := ls(domain_path) or { []string{} }
		for skill in skills.sorted() {
			skill_path := join_path(domain_path, skill)
			if !is_dir(skill_path) {
				continue
			}
			validate_skill(root, skill_path, mut errors, mut warnings)
			skill_count++
		}
	}

	println('\n── plugins/ (bundled copies) ──')
	plugins := ls(plugins_dir) or { []string{} }
	for plugin in plugins.sorted() {
		plugin_path := join_path(plugins_dir, plugin)
		if !is_dir(plugin_path) {
			continue
		}
		plugin_skills := join_path(plugin_path, 'skills')
		if !is_dir(plugin_skills) {
			continue
		}
		skills := ls(plugin_skills) or { []string{} }
		for skill in skills.sorted() {
			skill_path := join_path(plugin_skills, skill)
			if is_dir(skill_path) {
				validate_skill(root, skill_path, mut errors, mut warnings)
			}
		}
	}

	println('\n── Summary ──')
	println('  Skills validated: ${skill_count}')
	if errors.len > 0 {
		println('\n❌ ${errors.len} error(s) found')
		exit(1)
	}
	if warnings.len > 0 {
		println('\n⚠ All valid with ${warnings.len} warning(s)')
	} else {
		println('\n✅ All SKILL.md files are valid!')
	}
}

fn validate_skill(root string, skill_dir string, mut errors []string, mut warnings []string) {
	skill_md := join_path(skill_dir, 'SKILL.md')
	rel := skill_dir.replace('${root}/', '')
	if !is_file(skill_md) {
		errors << '${rel}: missing SKILL.md'
		println('  ✗ ${rel}: missing SKILL.md')
		return
	}
	content := read_file(skill_md) or {
		errors << '${rel}/SKILL.md: cannot read'
		println('  ✗ ${rel}/SKILL.md: cannot read')
		return
	}
	fm := extract_frontmatter(content) or {
		errors << '${rel}/SKILL.md: no YAML frontmatter found (must start with ---)'
		println('  ✗ ${rel}/SKILL.md: no YAML frontmatter found (must start with ---)')
		return
	}
	name := fm_field(fm, 'name') or { '' }
	if name.len == 0 {
		errors << "${rel}/SKILL.md: missing required frontmatter field 'name'"
		println("  ✗ ${rel}/SKILL.md: missing required frontmatter field 'name'")
	}
	desc := fm_field(fm, 'description') or { '' }
	if desc.len == 0 {
		errors << "${rel}/SKILL.md: missing required frontmatter field 'description'"
		println("  ✗ ${rel}/SKILL.md: missing required frontmatter field 'description'")
	}
	dir_name := file_name(skill_dir)
	if name.len > 0 && name != dir_name {
		msg := "${rel}/SKILL.md: name '${name}' does not match directory '${dir_name}'"
		warnings << msg
		println('  ⚠ ${msg}')
	}
	if is_file(join_path(skill_dir, 'skill.json')) {
		msg := '${rel}: skill.json found — not needed by Agent Skills spec, can be removed'
		warnings << msg
		println('  ⚠ ${msg}')
	}
}
