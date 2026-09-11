#!/usr/bin/env -S v run
// Validate skill capability registry against schema and filesystem.
//
// Checks:
// - capabilities/skills/registry.yaml has a skills list (full JSON-Schema
//   validation lives in validate.yml via python jsonschema — V has no
//   jsonschema equivalent; see header note below)
// - count matches catalogs/skill-catalog.yaml, skills/*/*/SKILL.md, and products coverage
// - no orphan skills (every skill has holistic_owner)
// - every trigger/overlap/complementary/prereq/follow_up references a real skill id
// - design routing skills are present and owned by designer
// - docs/SKILL_ROUTING.md exists and mentions required routing phrases
// - agents/designer/AGENT.md exists and validates via AGENT.md rules
//
// Usage:
//   ./scripts/validate-skill-capability.vsh              # validate
//   ./scripts/validate-skill-capability.vsh --check      # same, for CI (fails on drift)
//   ./scripts/validate-skill-capability.vsh --json       # JSON output
//
// YAML reading: V's `yaml` module rejects this registry (block-level
// `- id:` items, multi-line plain scalars), so skills are read with the
// same tolerant, fail-loud line parser as generate-target-matrix.vsh
// (identical grammar: items at indent 0, fields at 2, submaps at 4,
// list items at the key indent).

import os

const holistic_owners = ['assistant', 'planner', 'architect', 'designer', 'implementer', 'reviewer',
	'qa-engineer', 'security-engineer', 'platform-engineer', 'data-engineer', 'researcher']

const design_skills = ['design/frontend-design', 'design/frontend-design-review', 'design/web-design-guidelines',
	'design/design-assessment', 'design/design-improvement', 'design/figma', 'design/figma-code-connect-components',
	'design/figma-create-design-system-rules', 'design/figma-create-new-file', 'design/figma-implement-design',
	'accessibility/review']

const required_routing_phrases = ['New visual direction / creative frontend', 'Existing frontend quality/design review',
	'Concrete web-interface best-practice audit', 'Evidence-based holistic UX/UI diagnosis',
	'Iterative browser-grounded remediation', 'Figma-driven work', 'Accessibility-sensitive UI']

// ---------------------------------------------------------------------------
// Line parser (same core as generate-target-matrix.vsh)
// ---------------------------------------------------------------------------

fn indent_of(line string) int {
	mut n := 0
	for c in line {
		if c != ` ` {
			break
		}
		n++
	}
	return n
}

fn looks_like_key(trimmed string) bool {
	if trimmed.starts_with('- ') {
		return false
	}
	colon := trimmed.index(':') or { return false }
	if colon <= 0 {
		return false
	}
	after := trimmed[colon + 1..]
	if after.len == 0 || after[0] == ` ` || after[0] == `\t` {
		name := trimmed[..colon]
		for c in name {
			if !(c.is_alnum() || c == `_` || c == `-` || c == `.`) {
				return false
			}
		}
		return true
	}
	return false
}

fn strip_comment(s string) string {
	idx := s.index(' #') or { return s }
	return s[..idx].trim_space()
}

fn unquote(s string) string {
	sq := s.starts_with("'") && s.ends_with("'")
	dq := s.starts_with('"') && s.ends_with('"')
	if s.len >= 2 && (sq || dq) {
		return s[1..s.len - 1]
	}
	return s
}

fn clean_scalar(raw string) string {
	return unquote(strip_comment(raw.trim_space()))
}

struct Parser {
mut:
	lines []string
	idx   int
}

fn (mut p Parser) skip_trivia() {
	for p.idx < p.lines.len {
		t := p.lines[p.idx].trim_space()
		if t == '' || t.starts_with('#') {
			p.idx++
			continue
		}
		break
	}
}

fn (mut p Parser) collect_scalar(first string, key_indent int) string {
	mut parts := [strip_comment(first.trim_space())]
	for p.idx < p.lines.len {
		line := p.lines[p.idx]
		t := line.trim_space()
		if t == '' || t.starts_with('#') {
			break
		}
		if indent_of(line) <= key_indent {
			break
		}
		if t.starts_with('- ') || looks_like_key(t) {
			break
		}
		parts << strip_comment(t)
		p.idx++
	}
	return unquote(parts.join(' '))
}

fn (mut p Parser) parse_str_list(list_indent int) []string {
	mut out := []string{}
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		line := p.lines[p.idx]
		t := line.trim_space()
		if indent_of(line) != list_indent || !t.starts_with('- ') {
			break
		}
		out << clean_scalar(t[2..])
		p.idx++
	}
	return out
}

fn (mut p Parser) parse_str_map(map_indent int) map[string]string {
	mut out := map[string]string{}
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		line := p.lines[p.idx]
		t := line.trim_space()
		if t.starts_with('- ') && indent_of(line) >= map_indent {
			// Nested item list (e.g. upstream.sources, whose items sit at
			// the key indent with subfields below): consume items and
			// their deeper subfields. No check reads these. The indent
			// guard is load-bearing: a `- id:` skill line at indent 0
			// must break the map, never be eaten as a nested item.
			item_indent := indent_of(line)
			for p.idx < p.lines.len {
				nl := p.lines[p.idx]
				nt := nl.trim_space()
				if nt == '' || nt.starts_with('#') {
					p.idx++
					continue
				}
				ni := indent_of(nl)
				if ni > item_indent || (ni == item_indent && nt.starts_with('- ')) {
					p.idx++
					continue
				}
				break
			}
			continue
		}
		if indent_of(line) > map_indent {
			// Other nested block: consume through it instead of choking.
			for p.idx < p.lines.len {
				nl := p.lines[p.idx]
				nt := nl.trim_space()
				if nt != '' && !nt.starts_with('#') && indent_of(nl) <= map_indent {
					break
				}
				p.idx++
			}
			continue
		}
		if indent_of(line) != map_indent {
			break
		}
		colon := t.index(':') or { break }
		key := t[..colon].trim_space()
		rest := t[colon + 1..].trim_space()
		p.idx++
		if rest == '' {
			p.skip_trivia()
			if p.idx < p.lines.len {
				nl := p.lines[p.idx]
				nt := nl.trim_space()
				if indent_of(nl) > map_indent && !nt.starts_with('- ') && !looks_like_key(nt) {
					out[key] = p.collect_scalar('', map_indent)
					continue
				}
			}
			out[key] = ''
		} else if rest == '[]' || rest == '{}' {
			out[key] = ''
		} else {
			out[key] = p.collect_scalar(rest, map_indent)
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// Skill model
// ---------------------------------------------------------------------------

struct Skill {
mut:
	id                   string
	holistic_owner       string
	triggers             []string
	contraindications    string
	domain               string
	origin               string
	has_upstream         bool
	upstream             map[string]string
	specialist_agents    []string
	specialist_justified bool
	secondary_owners     []string
	overlap              []string
	complementary        []string
	prerequisites        []string
	follow_ups           []string
	requires             []string
	role                 string
}

fn set_skill_str(mut s Skill, key string, val string) {
	match key {
		'holistic_owner' { s.holistic_owner = val }
		'contraindications' { s.contraindications = val }
		'domain' { s.domain = val }
		'origin' { s.origin = val }
		'role' { s.role = val }
		else {}
	}
}

fn set_skill_list(mut s Skill, key string, lst []string) {
	match key {
		'triggers' { s.triggers = lst }
		'specialist_agents' { s.specialist_agents = lst }
		'secondary_owners' { s.secondary_owners = lst }
		'overlap' { s.overlap = lst }
		'complementary' { s.complementary = lst }
		'prerequisites' { s.prerequisites = lst }
		'follow_ups' { s.follow_ups = lst }
		'requires' { s.requires = lst }
		else {}
	}
}

struct SkillsFile {
mut:
	skills []Skill
	count  int
	has_count bool
}

fn parse_skills_file(text string) SkillsFile {
	mut p := Parser{text.split_into_lines(), 0}
	mut out := SkillsFile{}
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		line := p.lines[p.idx]
		t := line.trim_space()
		if indent_of(line) == 0 {
			if t == 'skills:' {
				p.idx++
				continue
			}
			if t.starts_with('count:') {
				out.count = t['count:'.len..].trim_space().int()
				out.has_count = true
				p.idx++
				continue
			}
			if t.starts_with('- ') {
				rest := t[2..]
				colon := rest.index(':') or {
					eprintln('skills registry: malformed item line ${p.idx + 1}: ${t}')
					exit(2)
				}
				if rest[..colon].trim_space() != 'id' {
					eprintln('skills registry: expected `- id:` at line ${p.idx + 1}')
					exit(2)
				}
				mut s := Skill{}
				s.id = clean_scalar(rest[colon + 1..])
				p.idx++
				parse_skill_fields(mut p, mut s)
				out.skills << s
				continue
			}
		}
		p.idx++
	}
	return out
}

fn parse_skill_fields(mut p Parser, mut s Skill) {
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		line := p.lines[p.idx]
		t := line.trim_space()
		fi := indent_of(line)
		if fi == 0 && t.starts_with('- ') {
			break // next skill
		}
		if fi != 2 {
			eprintln('skills registry: unexpected indent ${fi} at line ${p.idx + 1}: ${t}')
			exit(2)
		}
		if t.starts_with('- ') {
			eprintln('skills registry: unexpected list item at line ${p.idx + 1}: ${t}')
			exit(2)
		}
		colon := t.index(':') or {
			eprintln('skills registry: malformed field at line ${p.idx + 1}: ${t}')
			exit(2)
		}
		key := t[..colon].trim_space()
		frest := t[colon + 1..].trim_space()
		p.idx++
		if key == 'upstream' {
			s.has_upstream = true
			p.skip_trivia()
			if p.idx < p.lines.len && indent_of(p.lines[p.idx]) > 2
				&& looks_like_key(p.lines[p.idx].trim_space()) {
				s.upstream = p.parse_str_map(indent_of(p.lines[p.idx]))
			}
		} else if key == 'triggers' || key == 'specialist_agents' || key == 'secondary_owners'
			|| key == 'overlap' || key == 'complementary' || key == 'prerequisites' || key == 'follow_ups'
			|| key == 'requires' || key == 'mcp_required' {
			// mcp_required is consumed and discarded: no check reads it,
			// but the parser must not choke on its block list.
			mut lst := []string{}
			if frest != '' && frest != '[]' {
				lst << p.collect_scalar(frest, 2)
			} else if frest == '' {
				p.skip_trivia()
				if p.idx < p.lines.len && indent_of(p.lines[p.idx]) >= 2
					&& p.lines[p.idx].trim_space().starts_with('- ') {
					lst = p.parse_str_list(indent_of(p.lines[p.idx]))
				}
			}
			set_skill_list(mut s, key, lst)
		} else if key == 'specialist_justified' {
			s.specialist_justified = frest.to_lower() == 'true'
		} else if frest == '' {
			p.skip_trivia()
			if p.idx < p.lines.len {
				nl := p.lines[p.idx]
				nt := nl.trim_space()
				if indent_of(nl) > 2 && !nt.starts_with('- ') && !looks_like_key(nt) {
					set_skill_str(mut s, key, p.collect_scalar('', 2))
					continue
				}
			}
			set_skill_str(mut s, key, '')
		} else if frest == '[]' || frest == '{}' {
			set_skill_str(mut s, key, '')
		} else {
			set_skill_str(mut s, key, p.collect_scalar(frest, 2))
		}
	}
}

// Catalog scan: top-level `count:` + `  - id:` items (fields ignored).
fn parse_catalog_ids(text string) ([]string, int, bool) {
	mut ids := []string{}
	mut count := 0
	mut has_count := false
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t == '' || t.starts_with('#') {
			continue
		}
		if indent_of(line) == 0 && t.starts_with('count:') {
			count = t['count:'.len..].trim_space().int()
			has_count = true
		} else if indent_of(line) == 2 && t.starts_with('- id:') {
			ids << clean_scalar(t['- id:'.len..])
		}
	}
	return ids, count, has_count
}

fn repo_root() string {
	mut d := os.dir(@FILE)
	// scripts/ -> repo root
	d = os.dir(d)
	if os.is_file(os.join_path(d, 'VERSION')) {
		return d
	}
	return os.getwd()
}

fn collect_skill_files(dir string) []string {
	// Recursive SKILL.md discovery (no symlink following, like rglob).
	mut out := []string{}
	entries := os.ls(dir) or { return out }
	for name in entries {
		p := os.join_path(dir, name)
		if os.is_link(p) {
			continue
		}
		if os.is_dir(p) {
			out << collect_skill_files(p)
		} else if name == 'SKILL.md' {
			out << p
		}
	}
	return out
}

fn first_sorted(items []string, n int) []string {
	mut c := items.clone()
	c.sort()
	if c.len > n {
		return c[..n]
	}
	return c
}

fn validate_registry(root string) []string {
	mut errors := []string{}
	reg_path := os.join_path(root, 'capabilities', 'skills', 'registry.yaml')
	schema_path := os.join_path(root, 'schemas', 'skill-capability-registry.schema.json')
	if !os.is_file(reg_path) {
		return ['missing registry: ${reg_path}']
	}
	if !os.is_file(schema_path) {
		return ['missing schema: ${schema_path}']
	}
	// Full JSON-Schema validation is intentionally NOT re-implemented here
	// (V has no jsonschema equivalent): validate.yml enforces it with
	// python jsonschema in the step right before this script. Absence of a
	// skills list still fails loudly below (the retired script's fallback).
	reg_text := os.read_file(reg_path) or { return ['missing registry: ${reg_path}'] }
	reg := parse_skills_file(reg_text)
	if reg.skills.len == 0 {
		return ["registry missing 'skills' key"]
	}
	skills := reg.skills
	count := if reg.has_count { reg.count } else { skills.len }
	if count != skills.len {
		errors << 'registry count ${count} != len(skills) ${skills.len}'
	}

	cat_path := os.join_path(root, 'catalogs', 'skill-catalog.yaml')
	if os.is_file(cat_path) {
		cat_text := os.read_file(cat_path) or { '' }
		cat_ids_list, cat_count_raw, cat_has_count := parse_catalog_ids(cat_text)
		cat_count := if cat_has_count { cat_count_raw } else { cat_ids_list.len }
		mut cat_ids := map[string]bool{}
		for id in cat_ids_list {
			cat_ids[id] = true
		}
		mut reg_ids := map[string]bool{}
		for s in skills {
			reg_ids[s.id] = true
		}
		if count != cat_count {
			errors << 'registry count ${count} != catalog count ${cat_count} (${cat_path})'
		}
		mut missing := []string{}
		for id in cat_ids.keys() {
			if id !in reg_ids {
				missing << id
			}
		}
		mut extra := []string{}
		for id in reg_ids.keys() {
			if id !in cat_ids {
				extra << id
			}
		}
		if missing.len > 0 {
			errors << 'registry missing ids present in catalog: ${first_sorted(missing, 10)}'
		}
		if extra.len > 0 {
			errors << 'registry has extra ids not in catalog: ${first_sorted(extra, 10)}'
		}
		// filesystem
		skills_dir := os.join_path(root, 'skills')
		mut fs_ids := map[string]bool{}
		for f in collect_skill_files(skills_dir) {
			parent := os.dir(f)
			rel := parent[skills_dir.len + 1..]
			fs_ids[rel] = true
		}
		mut fs_missing := []string{}
		for id in fs_ids.keys() {
			if id !in reg_ids {
				fs_missing << id
			}
		}
		mut fs_extra := []string{}
		for id in reg_ids.keys() {
			if id !in fs_ids {
				fs_extra << id
			}
		}
		if fs_missing.len > 0 {
			errors << 'registry missing ids present on filesystem: ${first_sorted(fs_missing, 10)}'
		}
		if fs_extra.len > 0 {
			errors << 'registry has extra ids not on filesystem: ${first_sorted(fs_extra, 10)}'
		}
		if fs_ids.len != cat_count {
			errors << 'filesystem skills ${fs_ids.len} != catalog ${cat_count}'
		}
	} else {
		errors << 'missing catalog: ${cat_path}'
	}

	agents_dir := os.join_path(root, 'agents')
	mut physical_agents := map[string]bool{}
	if os.is_dir(agents_dir) {
		for name in (os.ls(agents_dir) or { []string{} }) {
			if os.is_dir(os.join_path(agents_dir, name)) {
				physical_agents[name] = true
			}
		}
	}
	mut valid_secondary := map[string]bool{}
	for h in holistic_owners {
		valid_secondary[h] = true
	}
	for a in physical_agents.keys() {
		valid_secondary[a] = true
	}
	for s in skills {
		if s.holistic_owner == '' {
			errors << '${s.id}: missing holistic_owner (orphan)'
		} else if s.holistic_owner !in holistic_owners {
			errors << "${s.id}: invalid holistic_owner '${s.holistic_owner}' (must be one of 11)"
		}
		if s.triggers.len == 0 {
			errors << '${s.id}: missing triggers (at least one required)'
		}
		if s.contraindications == '' || s.contraindications.runes().len < 10 {
			errors << '${s.id}: missing or too short contraindications'
		}
		if s.domain != '' && s.id != '' && s.id.contains('/') {
			expected_domain := s.id.split('/')[0]
			if s.domain != expected_domain {
				errors << "${s.id}: domain '${s.domain}' != id prefix '${expected_domain}'"
			}
		}
		if s.origin == 'upstream' {
			if !s.has_upstream {
				errors << '${s.id}: origin upstream must have upstream metadata'
			} else {
				for k in ['repository', 'path', 'ref', 'license'] {
					if k !in s.upstream || s.upstream[k] == '' {
						errors << "${s.id}: upstream missing required field '${k}'"
					}
				}
			}
		} else if s.origin == 'first-party' {
			if s.has_upstream {
				errors << '${s.id}: first-party must not have upstream field'
			}
		}
		for ag in s.specialist_agents {
			if ag !in physical_agents {
				errors << "${s.id}: specialist_agents references unknown agent '${ag}'"
			}
		}
		if s.specialist_justified && s.specialist_agents.len == 0 {
			errors << '${s.id}: specialist_justified true but specialist_agents empty'
		}
		for sec in s.secondary_owners {
			if sec !in valid_secondary {
				errors << "${s.id}: secondary_owners references unknown owner/agent '${sec}'"
			}
		}
	}

	mut all_ids := map[string]bool{}
	for s in skills {
		all_ids[s.id] = true
	}
	for s in skills {
		for field in ['overlap', 'complementary', 'prerequisites', 'follow_ups'] {
			refs := match field {
				'overlap' { s.overlap }
				'complementary' { s.complementary }
				'prerequisites' { s.prerequisites }
				else { s.follow_ups }
			}
			for ref in refs {
				if ref == s.id {
					errors << '${s.id}: ${field} self-reference not allowed'
				} else if ref !in all_ids {
					errors << "${s.id}: ${field} references unknown skill '${ref}'"
				}
			}
		}
		for ref in s.requires {
			if ref.contains('/') {
				if ref == s.id {
					errors << '${s.id}: requires self-reference not allowed'
				} else if ref !in all_ids {
					errors << "${s.id}: requires references unknown skill '${ref}'"
				}
			}
		}
	}

	mut reg_id_set := map[string]bool{}
	for s in skills {
		reg_id_set[s.id] = true
	}
	for did in design_skills {
		if did !in reg_id_set {
			errors << 'design skill missing from registry: ${did}'
		} else {
			for s in skills {
				if s.id == did {
					if s.holistic_owner != 'designer' {
						errors << "${did}: holistic_owner should be 'designer', got '${s.holistic_owner}'"
					}
					break
				}
			}
		}
	}

	routing_path := os.join_path(root, 'docs', 'SKILL_ROUTING.md')
	if !os.is_file(routing_path) {
		errors << 'missing routing doc: ${routing_path}'
	} else {
		text := os.read_file(routing_path) or { '' }
		for phrase in required_routing_phrases {
			if !text.contains(phrase) {
				errors << "routing doc missing required phrase: '${phrase}'"
			}
		}
		if !text.contains('capabilities/skills/registry.yaml') {
			errors << 'routing doc should reference capabilities/skills/registry.yaml as SoT'
		}
	}

	designer_path := os.join_path(root, 'agents', 'designer', 'AGENT.md')
	if !os.is_file(designer_path) {
		errors << 'missing designer agent: ${designer_path}'
	} else {
		text := os.read_file(designer_path) or { '' }
		if !text.contains('holistic_owner') && !text.contains('capabilities/skills/registry.yaml') {
			errors << 'designer agent should reference registry.yaml or holistic_owner'
		}
		for phrase in ['frontend-design', 'design-assessment'] {
			if !text.contains(phrase) {
				errors << 'designer agent missing expected skill reference: ${phrase}'
			}
		}
	}

	orch_path := os.join_path(root, 'skills', 'core', 'assistant', 'references', 'ORCHESTRATION.md')
	if !os.is_file(orch_path) {
		errors << 'missing orchestration: ${orch_path}'
	} else {
		text := os.read_file(orch_path) or { '' }
		for did in ['frontend-design', 'design-assessment', 'web-design-guidelines'] {
			if !text.contains(did) {
				errors << 'orchestration Design section missing: ${did}'
			}
		}
	}

	return errors
}

fn dict_repr(order []string, counts map[string]int) string {
	mut parts := []string{}
	for k in order {
		parts << "'${k}': ${counts[k]}"
	}
	return '{' + parts.join(', ') + '}'
}

// escape_json_str covers the --json string surface (quotes, backslash,
// newline); error texts carry none of the exotic escapes in practice.
fn escape_json_str(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r',
		'\\r').replace('\t', '\\t')
}

fn main() {
	check := '--check' in os.args
	json_mode := '--json' in os.args
	root := repo_root()
	errors := validate_registry(root)
	if json_mode {
		mut err_parts := []string{}
		for e in errors {
			err_parts << '"${escape_json_str(e)}"'
		}
		ok := if errors.len == 0 { 'true' } else { 'false' }
		println('{\n  "errors": [${err_parts.join(', ')}],\n  "ok": ${ok}\n}')
		exit(if errors.len == 0 { 0 } else { 1 })
	}
	if errors.len > 0 {
		for e in errors {
			eprintln('ERROR: ${e}')
		}
		eprintln('\n${errors.len} validation error(s).')
		exit(1)
	}
	// Summary (clean path only — mirrors the retired script).
	reg_text := os.read_file(os.join_path(root, 'capabilities', 'skills', 'registry.yaml')) or { '' }
	reg := parse_skills_file(reg_text)
	mut owners := map[string]int{}
	mut owners_order := []string{}
	mut roles := map[string]int{}
	mut roles_order := []string{}
	for s in reg.skills {
		if s.holistic_owner !in owners {
			owners[s.holistic_owner] = 0
			owners_order << s.holistic_owner
		}
		owners[s.holistic_owner]++
		if s.role !in roles {
			roles[s.role] = 0
			roles_order << s.role
		}
		roles[s.role]++
	}
	println('skill capability OK — ${reg.skills.len} skills, no orphans')
	println('  owners: ${dict_repr(owners_order, owners)}')
	println('  roles: ${dict_repr(roles_order, roles)}')
	println('  design routing: ${design_skills.len} design skills owned by designer')
	_ = check
}
