#!/usr/bin/env -S v run
// Validate AGENT.md frontmatter across all agents.
// Usage: ./scripts/validate-agents.vsh

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

fn main() {
	root := repo_root()
	agents_dir := join_path(root, 'agents')
	mut errors := []string{}
	println('\n🔍 Validating AGENT.md frontmatter...\n')
	mut count := 0
	agents := ls(agents_dir) or { []string{} }
	for agent in agents.sorted() {
		agent_path := join_path(agents_dir, agent)
		if !is_dir(agent_path) {
			continue
		}
		agent_md := join_path(agent_path, 'AGENT.md')
		if !is_file(agent_md) {
			errors << '${agent}: missing AGENT.md'
			println('  ✗ ${agent}: missing AGENT.md')
			continue
		}
		content := read_file(agent_md) or {
			errors << '${agent}/AGENT.md: cannot read'
			println('  ✗ ${agent}/AGENT.md: cannot read')
			continue
		}
		fm := extract_frontmatter(content) or {
			errors << '${agent}/AGENT.md: no YAML frontmatter'
			println('  ✗ ${agent}/AGENT.md: no YAML frontmatter')
			continue
		}
		if fm_field(fm, 'name') or { '' } == '' {
			errors << "${agent}/AGENT.md: missing 'name'"
			println("  ✗ ${agent}/AGENT.md: missing 'name'")
		}
		if fm_field(fm, 'description') or { '' } == '' {
			errors << "${agent}/AGENT.md: missing 'description'"
			println("  ✗ ${agent}/AGENT.md: missing 'description'")
		}
		count++
	}
	println('\nAgents validated: ${count}')
	if errors.len > 0 {
		println('\n❌ ${errors.len} error(s)')
		exit(1)
	}
	println('\n✅ All AGENT.md files are valid!')
}
