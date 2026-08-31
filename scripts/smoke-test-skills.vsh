#!/usr/bin/env -S v run
// Mechanical smoke validation for skills/ and agents/.
// Usage: ./scripts/smoke-test-skills.vsh

fn repo_root() string {
	mut d := dir(@FILE)
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

fn rel_to(root string, path string) string {
	prefix := '${root}/'
	if path.starts_with(prefix) {
		return path[prefix.len..]
	}
	return path
}

fn is_placeholder(desc string) bool {
	d := desc.trim_space()
	return d in ['', '-', 'tbd', 'TBD', 'todo', 'TODO', 'wip', 'WIP']
}

fn norm_join(base string, rel string) string {
	mut parts := []string{}
	base_abs := if is_abs_path(base) { base } else { join_path(getwd(), base) }
	for p in base_abs.split('/') {
		if p.len == 0 {
			continue
		}
		parts << p
	}
	for p in rel.split('/') {
		if p.len == 0 || p == '.' {
			continue
		}
		if p == '..' {
			if parts.len > 0 {
				parts.delete_last()
			}
			continue
		}
		parts << p
	}
	return '/' + parts.join('/')
}

fn looks_like_repo_ref(target string) bool {
	if target.starts_with('./') || target.starts_with('../') {
		return true
	}
	top := target.all_before('/')
	return top in ['skills', 'agents', 'docs', 'scripts', 'schemas', 'catalogs', 'loops',
		'profiles', 'packs', 'mcp', 'tools', 'integrations', 'distributions', 'capabilities',
		'plugins', '.github']
}

fn resolve_links(root string, content string, source_path string, mut errors []string, mut seen map[string]bool) {
	source_dir := dir(source_path)
	mut start := 0
	for {
		lb := content.index_after('](', start) or { break }
		open := lb + 2
		close := content.index_after(')', open) or { break }
		target := content[open..close]
		start = close + 1
		if target.starts_with('http://') || target.starts_with('https://') || target.starts_with('#')
			|| target.starts_with('mailto:') {
			continue
		}
		file_part := if target.contains('#') { target.all_before('#') } else { target }
		if file_part.len == 0 || !looks_like_repo_ref(file_part) {
			continue
		}
		// Normalize .. segments without requiring the path to exist (parity with Path.resolve).
		candidate := norm_join(source_dir, file_part)
		root_n := real_path(root)
		if !candidate.starts_with(root_n + '/') && candidate != root_n {
			continue
		}
		if !exists(candidate) {
			msg := "${rel_to(root, source_path)}: link target '${file_part}' does not resolve"
			if msg !in seen {
				seen[msg] = true
				errors << msg
				println('  X ${msg}')
			}
		}
	}
}

fn validate_skill(root string, skill_dir string, mut errors []string, mut seen map[string]bool) bool {
	skill_md := join_path(skill_dir, 'SKILL.md')
	rel := rel_to(root, skill_dir)
	mut ok_flag := true
	if !is_file(skill_md) {
		msg := '${rel}: missing SKILL.md'
		if msg !in seen {
			seen[msg] = true
			errors << msg
			println('  X ${msg}')
		}
		return false
	}
	content := read_file(skill_md) or { return false }
	fm := extract_frontmatter(content) or {
		msg := "${rel}/SKILL.md: no YAML frontmatter (must start with '---')"
		if msg !in seen {
			seen[msg] = true
			errors << msg
			println('  X ${msg}')
		}
		return false
	}
	name := fm_field(fm, 'name') or { '' }
	desc := fm_field(fm, 'description') or { '' }
	if name.len == 0 {
		msg := "${rel}/SKILL.md: missing required field 'name'"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	if desc.len == 0 {
		msg := "${rel}/SKILL.md: missing required field 'description'"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	dir_name := file_name(skill_dir)
	if name.len > 0 && name != dir_name {
		msg := "${rel}/SKILL.md: name '${name}' does not match directory '${dir_name}'"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	if is_placeholder(desc) {
		msg := "${rel}/SKILL.md: description is a placeholder ('${desc.trim_space()}')"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	resolve_links(root, content, skill_md, mut errors, mut seen)
	if ok_flag {
		println('  OK ${rel}')
	}
	return ok_flag
}

fn validate_agent(root string, agent_dir string, mut errors []string, mut seen map[string]bool) bool {
	agent_md := join_path(agent_dir, 'AGENT.md')
	rel := rel_to(root, agent_dir)
	mut ok_flag := true
	if !is_file(agent_md) {
		msg := '${rel}: missing AGENT.md'
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		return false
	}
	content := read_file(agent_md) or { return false }
	fm := extract_frontmatter(content) or {
		msg := "${rel}/AGENT.md: no YAML frontmatter (must start with '---')"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		return false
	}
	name := fm_field(fm, 'name') or { '' }
	desc := fm_field(fm, 'description') or { '' }
	if name.len == 0 {
		msg := "${rel}/AGENT.md: missing required field 'name'"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	if desc.len == 0 {
		msg := "${rel}/AGENT.md: missing required field 'description'"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	dir_name := file_name(agent_dir)
	if name.len > 0 && name != dir_name {
		msg := "${rel}/AGENT.md: name '${name}' does not match directory '${dir_name}'"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	if is_placeholder(desc) {
		msg := "${rel}/AGENT.md: description is a placeholder ('${desc.trim_space()}')"
		seen[msg] = true
		errors << msg
		println('  X ${msg}')
		ok_flag = false
	}
	resolve_links(root, content, agent_md, mut errors, mut seen)
	if ok_flag {
		println('  OK ${rel}')
	}
	return ok_flag
}

fn validate_script_shebangs(root string, mut errors []string, mut seen map[string]bool) bool {
	scripts_dir := join_path(root, 'scripts')
	if !is_dir(scripts_dir) {
		return true
	}
	mut ok_flag := true
	entries := ls(scripts_dir) or { []string{} }
	for name in entries.sorted() {
		script := join_path(scripts_dir, name)
		if !is_file(script) {
			continue
		}
		ext := file_ext(script)
		if ext !in ['.py', '.sh', '.bash', '.vsh'] {
			continue
		}
		content := read_file(script) or { continue }
		first := content.all_before('\n').trim_right('\r')
		if !first.starts_with('#!') {
			msg := "${rel_to(root, script)}: missing shebang line (expected '#!/usr/bin/env ...')"
			seen[msg] = true
			errors << msg
			println('  X ${msg}')
			ok_flag = false
		}
	}
	return ok_flag
}

fn main() {
	root := repo_root()
	mut errors := []string{}
	mut seen := map[string]bool{}
	println('\n--- Mechanical smoke: skills/ ---\n')
	mut skill_ok := true
	mut skill_count := 0
	skills_dir := join_path(root, 'skills')
	for domain in (ls(skills_dir) or { []string{} }).sorted() {
		domain_path := join_path(skills_dir, domain)
		if !is_dir(domain_path) {
			continue
		}
		for skill in (ls(domain_path) or { []string{} }).sorted() {
			skill_path := join_path(domain_path, skill)
			if !is_dir(skill_path) {
				continue
			}
			if !validate_skill(root, skill_path, mut errors, mut seen) {
				skill_ok = false
			}
			skill_count++
		}
	}
	println('\n  Skills checked: ${skill_count}')
	if skill_ok {
		println('  Skills: all passed')
	}
	println('\n--- Mechanical smoke: agents/ ---\n')
	mut agent_ok := true
	mut agent_count := 0
	agents_dir := join_path(root, 'agents')
	for agent in (ls(agents_dir) or { []string{} }).sorted() {
		agent_path := join_path(agents_dir, agent)
		if !is_dir(agent_path) {
			continue
		}
		if !validate_agent(root, agent_path, mut errors, mut seen) {
			agent_ok = false
		}
		agent_count++
	}
	println('\n  Agents checked: ${agent_count}')
	if agent_ok {
		println('  Agents: all passed')
	}
	println('\n--- Mechanical smoke: script shebangs ---\n')
	shebang_ok := validate_script_shebangs(root, mut errors, mut seen)
	if shebang_ok {
		println('  Scripts: all passed')
	}
	println('\n=== Summary: ${errors.len} error(s) ===\n')
	if errors.len > 0 {
		for e in errors {
			println('  FAIL: ${e}')
		}
		println('\n${errors.len} error(s) total.')
		exit(1)
	}
	println('  All mechanical smoke checks passed.')
}
