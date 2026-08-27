#!/usr/bin/env -S v run
// Regenerate catalogs/{skill,agent,loop}-catalog.yaml from the filesystem (#78).
// Usage:
//   ./scripts/generate-catalogs.vsh          # write catalogs
//   ./scripts/generate-catalogs.vsh --check  # fail on drift

import yaml

fn repo_root() string {
	mut d := dir(@FILE)
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

fn extract_frontmatter(content string) string {
	lines := content.split_into_lines()
	if lines.len < 2 || lines[0].trim_space() != '---' {
		return ''
	}
	mut end := -1
	for i := 1; i < lines.len; i++ {
		if lines[i].trim_space() == '---' {
			end = i
			break
		}
	}
	if end < 0 {
		return ''
	}
	return lines[1..end].join('\n')
}

fn fm_field(fm string, key string) string {
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
			return parts.join(' ').trim_space()
		}
		i++
	}
	return ''
}

fn fm_list(fm string, key string) []string {
	prefix := '${key}:'
	lines := fm.split_into_lines()
	mut i := 0
	for i < lines.len {
		line := lines[i]
		trimmed := line.trim_space()
		if trimmed.starts_with(prefix) {
			mut rest := trimmed[prefix.len..].trim_space()
			if rest.len > 0 && rest.starts_with('[') {
				mut inner := rest
				if inner.contains(']') {
					end := inner.index(']') or { inner.len - 1 }
					inner = inner[1..end]
				} else {
					inner = inner[1..]
				}
				inner = inner.trim_space()
				if inner.len == 0 {
					return []string{}
				}
				mut out := []string{}
				parts := inner.split(',')
				for pp in parts {
					mut v := pp.trim_space()
					if v.len >= 2 && ((v[0] == `'` && v[v.len - 1] == `'`) || (v[0] == `"` && v[v.len - 1] == `"`)) {
						v = v[1..v.len - 1]
					}
					if v.len > 0 {
						out << v.trim_space()
					}
				}
				return out
			}
			mut out := []string{}
			i++
			for i < lines.len {
				l := lines[i]
				tt := l.trim_space()
				if tt.len == 0 {
					i++
					continue
				}
				if tt.starts_with('-') {
					mut v := tt[1..].trim_space()
					if v.len >= 2 && ((v[0] == `'` && v[v.len - 1] == `'`) || (v[0] == `"` && v[v.len - 1] == `"`)) {
						v = v[1..v.len - 1]
					}
					if v.len > 0 {
						out << v
					}
					i++
					continue
				}
				break
			}
			return out
		}
		i++
	}
	return []string{}
}

fn truncate(s string, n int) string {
	if s.len <= n {
		return s
	}
	return s[..n]
}

fn yaml_escape_scalar(s string) string {
	// Always single-line; quote when YAML-special chars appear.
	needs := s.len == 0 || s.contains(':') || s.contains('#') || s.contains("'")
		|| s.contains('"') || s.contains('{') || s.contains('}') || s.contains('[')
		|| s.contains(']') || s.contains(',') || s.contains('\n') || s.contains('—')
		|| s.contains('→') || s.contains('×') || s.starts_with('*') || s.starts_with('&')
		|| s.starts_with('!') || s.contains('  ')
	if needs {
		esc := s.replace("'", "''")
		return "'${esc}'"
	}
	return s
}

fn yaml_kv(indent int, key string, value string) string {
	pad := ' '.repeat(indent)
	return '${pad}${key}: ${yaml_escape_scalar(value)}\n'
}

struct SkillEntry {
	id          string
	name        string
	domain      string
	description string
	stability   string
}

struct AgentEntry {
	id                string
	name              string
	description       string
	kind              string
	delegates         []string
	collaborates_with []string
}

struct LoopEntry {
	id          string
	name        string
	tier        string
	cadence     string
	description string
}

struct LoopYaml {
	id          string
	name        string
	tier        string
	cadence     string
	schedule    string
	description string
}

fn dump_skills(entries []SkillEntry) string {
	mut s := 'version: 1\ngenerated: true\ncount: ${entries.len}\nskills:\n'
	for e in entries {
		s += '  - id: ${yaml_escape_scalar(e.id)}\n'
		s += yaml_kv(4, 'name', e.name)
		s += yaml_kv(4, 'domain', e.domain)
		s += yaml_kv(4, 'description', e.description)
		s += yaml_kv(4, 'stability', e.stability)
	}
	return s
}

fn dump_agents(entries []AgentEntry) string {
	mut s := 'version: 1\ngenerated: true\ncount: ${entries.len}\nagents:\n'
	for e in entries {
		s += '  - id: ${yaml_escape_scalar(e.id)}\n'
		s += yaml_kv(4, 'name', e.name)
		s += yaml_kv(4, 'description', e.description)
		s += yaml_kv(4, 'kind', e.kind)
		if e.delegates.len > 0 {
			s += '    delegates:\n'
			for d in e.delegates {
				s += '      - ${yaml_escape_scalar(d)}\n'
			}
		}
		if e.collaborates_with.len > 0 {
			s += '    collaborates_with:\n'
			for c in e.collaborates_with {
				s += '      - ${yaml_escape_scalar(c)}\n'
			}
		}
	}
	return s
}

fn dump_loops(entries []LoopEntry) string {
	mut s := 'version: 1\ngenerated: true\ncount: ${entries.len}\nloops:\n'
	for e in entries {
		s += '  - id: ${yaml_escape_scalar(e.id)}\n'
		s += yaml_kv(4, 'name', e.name)
		if e.tier.len > 0 {
			s += yaml_kv(4, 'tier', e.tier)
		} else {
			s += '    tier: null\n'
		}
		if e.cadence.len > 0 {
			s += yaml_kv(4, 'cadence', e.cadence)
		} else {
			s += '    cadence: null\n'
		}
		s += yaml_kv(4, 'description', e.description)
	}
	return s
}

fn dump_skills_layout(groups map[string][]string, skills []SkillEntry) string {
	mut s := '{\n'
	s += '  "layout": "skills/<group>/<skill>/SKILL.md",\n'
	s += '  "groups": {\n'
	mut group_keys := groups.keys()
	group_keys.sort()
	for i, g in group_keys {
		names := groups[g]
		s += '    "${g}": [\n'
		for j, n in names {
			comma := if j < names.len - 1 { ',' } else { '' }
			s += '      "${n}"${comma}\n'
		}
		comma := if i < group_keys.len - 1 { ',' } else { '' }
		s += '    ]${comma}\n'
	}
	s += '  },\n'
	s += '  "skills": [\n'
	mut sorted_skills := skills.clone()
	sorted_skills.sort(a.id < b.id)
	for i, e in sorted_skills {
		comma := if i < sorted_skills.len - 1 { ',' } else { '' }
		s += '    {\n'
		s += '      "id": "${e.id}",\n'
		s += '      "name": "${e.name}",\n'
		s += '      "domain": "${e.domain}"\n'
		s += '    }${comma}\n'
	}
	s += '  ]\n'
	s += '}\n'
	return s
}

fn gen_skills(root string) []SkillEntry {
	mut skills := []SkillEntry{}
	skills_dir := join_path(root, 'skills')
	domains := ls(skills_dir) or { []string{} }
	for domain in domains.sorted() {
		domain_path := join_path(skills_dir, domain)
		if !is_dir(domain_path) {
			continue
		}
		names := ls(domain_path) or { []string{} }
		for name in names.sorted() {
			skill_md := join_path(domain_path, name, 'SKILL.md')
			if !is_file(skill_md) {
				continue
			}
			fm := extract_frontmatter(read_file(skill_md) or { '' })
			nm := fm_field(fm, 'name')
			desc := fm_field(fm, 'description')
			stab := fm_field(fm, 'stability')
			skills << SkillEntry{
				id:          '${domain}/${name}'
				name:        if nm.len > 0 { nm } else { name }
				domain:      domain
				description: truncate(desc, 200)
				stability:   if stab.len > 0 { stab } else { 'stable' }
			}
		}
	}
	return skills
}

fn gen_agents(root string) []AgentEntry {
	mut agents := []AgentEntry{}
	agents_dir := join_path(root, 'agents')
	names := ls(agents_dir) or { []string{} }
	for name in names.sorted() {
		agent_md := join_path(agents_dir, name, 'AGENT.md')
		if !is_file(agent_md) {
			continue
		}
		fm := extract_frontmatter(read_file(agent_md) or { '' })
		nm := fm_field(fm, 'name')
		desc := fm_field(fm, 'description')
		kind := fm_field(fm, 'kind')
		delegates := fm_list(fm, 'delegates')
		collab := fm_list(fm, 'collaborates_with')
		agents << AgentEntry{
			id:                name
			name:              if nm.len > 0 { nm } else { name }
			description:       truncate(desc, 200)
			kind:              if kind.len > 0 { kind } else { 'holistic' }
			delegates:         delegates
			collaborates_with: collab
		}
	}
	return agents
}

fn gen_loops(root string) []LoopEntry {
	mut loops := []LoopEntry{}
	loops_dir := join_path(root, 'loops')
	names := ls(loops_dir) or { []string{} }
	for name in names.sorted() {
		loop_yaml := join_path(loops_dir, name, 'loop.yaml')
		if !is_file(loop_yaml) {
			continue
		}
		text := read_file(loop_yaml) or { continue }
		data := yaml.decode[LoopYaml](text) or { LoopYaml{} }
		id := if data.id.len > 0 { data.id } else { name }
		nm := if data.name.len > 0 { data.name } else { name }
		cadence := if data.cadence.len > 0 { data.cadence } else { data.schedule }
		loops << LoopEntry{
			id:          id
			name:        nm
			tier:        data.tier
			cadence:     cadence
			description: truncate(data.description, 200)
		}
	}
	return loops
}

fn main() {
	root := repo_root()
	check := '--check' in args
	out := join_path(root, 'catalogs')
	mkdir(out) or {}
	mut drifted := false
	skills := gen_skills(root)
	agents := gen_agents(root)
	loops := gen_loops(root)
	mut groups := map[string][]string{}
	for e in skills {
		mut lst := groups[e.domain]
		if e.name !in lst {
			lst << e.name
		}
		groups[e.domain] = lst
	}
	for _, mut lst in groups {
		lst.sort()
	}
	layout_rendered := dump_skills_layout(groups, skills)
	mapping := {
		'skill-catalog.yaml': dump_skills(skills)
		'agent-catalog.yaml': dump_agents(agents)
		'loop-catalog.yaml':  dump_loops(loops)
	}
	counts := {
		'skill-catalog.yaml': skills.len
		'agent-catalog.yaml': agents.len
		'loop-catalog.yaml':  loops.len
	}
	// skills-layout.json is derived from filesystem, not hand-maintained
	layout_path := join_path(out, 'skills-layout.json')
	if check {
		if !is_file(layout_path) {
			println('MISSING ${layout_path}')
			drifted = true
		} else {
			existing := read_file(layout_path) or { '' }
			if existing != layout_rendered {
				println('DRIFT ${layout_path} (committed != regenerated)')
				drifted = true
			} else {
				println('ok ${layout_path} (${skills.len} skills, ${groups.len} groups)')
			}
		}
	} else {
		write_file(layout_path, layout_rendered) or {
			eprintln('write failed: ${layout_path}: ${err}')
			exit(1)
		}
		println('wrote ${layout_path} (${skills.len} skills, ${groups.len} groups)')
	}
	for name in ['skill-catalog.yaml', 'agent-catalog.yaml', 'loop-catalog.yaml'] {
		path := join_path(out, name)
		rendered := mapping[name]
		if check {
			if !is_file(path) {
				println('MISSING ${path}')
				drifted = true
				continue
			}
			existing := read_file(path) or { '' }
			if existing != rendered {
				println('DRIFT ${path} (committed != regenerated)')
				drifted = true
			} else {
				println('ok ${path} (${counts[name]} entries)')
			}
			continue
		}
		write_file(path, rendered) or {
			eprintln('write failed: ${path}: ${err}')
			exit(1)
		}
		println('wrote ${path} (${counts[name]} entries)')
	}
	if check && drifted {
		println('Catalogs out of sync — run: ./scripts/generate-catalogs.vsh')
		exit(1)
	}
}
