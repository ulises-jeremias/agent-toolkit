#!/usr/bin/env -S v run
// Generate docs/TARGET_CAPABILITY_MATRIX.md from capabilities/targets/registry.yaml.
//
// Usage:
//   ./scripts/generate-target-matrix.vsh              # write docs/TARGET_CAPABILITY_MATRIX.md
//   ./scripts/generate-target-matrix.vsh --check      # fail on drift
//   ./scripts/generate-target-matrix.vsh --output PATH
//
// Also validates that registry covers all profiles/ dirs (copilot maps to copilot-cli + copilot-repository).

import os

// ---------------------------------------------------------------------------
// Minimal YAML-subset reader for the targets registry.
// V's `yaml` module rejects this file (block-level `- id:` items and
// multi-line plain scalars), so the registry is read with a tolerant,
// fail-loud line parser covering exactly the grammar the file uses:
// `key: scalar` (bool true/false, plain or single/double-quoted strings,
// inline `[]`), `key:` + deeper `subkey: scalar` maps, `key:` + `- item`
// lists, and deeper-indented plain-scalar continuation lines (folded with
// single spaces, like YAML). Anything else aborts with the line number.
// ---------------------------------------------------------------------------

struct CVal {
	val     string
	is_null bool
}

fn cval_str(s string) CVal {
	return CVal{s, false}
}

fn cval_null() CVal {
	return CVal{'', true}
}

struct Target {
mut:
	id                      string
	display                 string
	adapter                 string
	aliases                 []string
	commands                map[string]CVal
	capabilities            map[string]CVal
	tier                    string
	tier_rationale          string
	maturity                string
	agent_plugins_extension string
	has_extension           bool
	researched_at           string
	sources                 []string
	notes                   string
}

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

// looks_like_key reports whether a (deeper-indented) line opens a new
// `key:` mapping entry rather than continuing a plain scalar.
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

// strip_comment cuts a ` #` comment suffix. Safe for this registry: the
// only ` #` occurrences in the file are full-line comments (skipped
// elsewhere), and no quoted value contains ` #`.
fn strip_comment(s string) string {
	idx := s.index(' #') or { return s }
	return s[..idx].trim_space()
}

// unquote strips one pair of outer matching quotes. (No `''` escapes exist
// in the file, so no unescaping pass is needed.)
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

// collect_scalar folds `key: value` + deeper continuation lines. Quote
// stripping applies to the FOLDED whole (multi-line quoted scalars keep
// their opening quote on the first fragment and the closing one on the
// last), matching PyYAML.
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

fn (mut p Parser) parse_list(item_indent int) []string {
	mut out := []string{}
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		line := p.lines[p.idx]
		t := line.trim_space()
		if indent_of(line) != item_indent || !t.starts_with('- ') {
			break
		}
		out << clean_scalar(t[2..])
		p.idx++
	}
	return out
}

// parse_map collects `subkey: scalar` entries at exactly map_indent.
fn (mut p Parser) parse_map(map_indent int) map[string]CVal {
	mut out := map[string]CVal{}
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		line := p.lines[p.idx]
		t := line.trim_space()
		if indent_of(line) != map_indent || t.starts_with('- ') {
			break
		}
		colon := t.index(':') or { break }
		key := t[..colon].trim_space()
		rest := t[colon + 1..].trim_space()
		p.idx++
		if rest == '' {
			// Empty value: nested block, continuation, or explicit null.
			p.skip_trivia()
			if p.idx < p.lines.len {
				nl := p.lines[p.idx]
				nt := nl.trim_space()
				if indent_of(nl) > map_indent && !nt.starts_with('- ') && !looks_like_key(nt) {
					out[key] = cval_str(p.collect_scalar('', map_indent))
					continue
				}
			}
			out[key] = cval_null()
		} else if rest == '[]' {
			out[key] = cval_str('[]')
		} else {
			out[key] = cval_str(p.collect_scalar(rest, map_indent))
		}
	}
	return out
}

struct Registry {
mut:
	targets      []Target
	researched_at string
}

fn parse_registry(text string) Registry {
	mut p := Parser{text.split_into_lines(), 0}
	mut reg := Registry{}
	// Seek the top-level `targets:` sequence, noting a top-level
	// `researched_at:` (preferred over targets[0]'s, like the retired script).
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		t := p.lines[p.idx].trim_space()
		if t == 'targets:' {
			p.idx++
			break
		}
		if t.starts_with('researched_at:') {
			reg.researched_at = clean_scalar(t['researched_at:'.len..])
		}
		p.idx++
	}
	mut targets := []Target{}
	for {
		p.skip_trivia()
		if p.idx >= p.lines.len {
			break
		}
		line := p.lines[p.idx]
		t := line.trim_space()
		if indent_of(line) != 0 || !t.starts_with('- ') {
			p.idx++
			continue
		}
		// New `- id: <id>` item; remaining fields sit at indent 2.
		rest := t[2..]
		colon := rest.index(':') or {
			eprintln('registry: malformed item line ${p.idx + 1}: ${t}')
			exit(2)
		}
		if rest[..colon].trim_space() != 'id' {
			eprintln('registry: expected `- id:` at line ${p.idx + 1}')
			exit(2)
		}
		id_val := clean_scalar(rest[colon + 1..])
		p.idx++
		mut tgt := Target{}
		tgt.id = id_val
		for {
			p.skip_trivia()
			if p.idx >= p.lines.len {
				break
			}
			fl := p.lines[p.idx]
			ft := fl.trim_space()
			fi := indent_of(fl)
			if fi == 0 && ft.starts_with('- ') {
				break // next target
			}
			if fi != 2 {
				eprintln('registry: unexpected indent ${fi} at line ${p.idx + 1}: ${ft}')
				exit(2)
			}
			if ft.starts_with('- ') {
				eprintln('registry: unexpected list item at line ${p.idx + 1}: ${ft}')
				exit(2)
			}
			fcolon := ft.index(':') or {
				eprintln('registry: malformed field at line ${p.idx + 1}: ${ft}')
				exit(2)
			}
			fkey := ft[..fcolon].trim_space()
			frest := ft[fcolon + 1..].trim_space()
			p.idx++
			// Nested blocks land directly in the struct; scalars fold
			// continuations; anything else is an explicit null.
			if fkey == 'aliases' || fkey == 'sources' {
				// Block items sit at the SAME indent as the key
				// (`sources:` + `  - url`), unlike nested maps.
				mut lst := []string{}
				if frest != '' && frest != '[]' {
					lst << p.collect_scalar(frest, 2)
				} else if frest == '' {
					p.skip_trivia()
					if p.idx < p.lines.len && indent_of(p.lines[p.idx]) >= 2
						&& p.lines[p.idx].trim_space().starts_with('- ') {
						lst = p.parse_list(indent_of(p.lines[p.idx]))
					}
				}
				if fkey == 'aliases' {
					tgt.aliases = lst
				} else {
					tgt.sources = lst
				}
			} else if fkey == 'commands' || fkey == 'capabilities' {
				p.skip_trivia()
				mut sub := map[string]CVal{}
				if p.idx < p.lines.len && indent_of(p.lines[p.idx]) > 2
					&& looks_like_key(p.lines[p.idx].trim_space()) {
					sub = p.parse_map(indent_of(p.lines[p.idx]))
				}
				if fkey == 'commands' {
					tgt.commands = sub
				} else {
					tgt.capabilities = sub
				}
			} else if frest == '' {
				p.skip_trivia()
				if p.idx < p.lines.len {
					nl := p.lines[p.idx]
					nt := nl.trim_space()
					if indent_of(nl) > 2 && !nt.starts_with('- ') && !looks_like_key(nt) {
						set_scalar(mut tgt, fkey, p.collect_scalar('', 2))
						continue
					}
				}
				set_scalar(mut tgt, fkey, '')
				tgt_null(mut tgt, fkey)
			} else if frest == '[]' || frest == '{}' {
				set_scalar(mut tgt, fkey, '')
				tgt_null(mut tgt, fkey)
			} else {
				set_scalar(mut tgt, fkey, p.collect_scalar(frest, 2))
			}
		}
		targets << tgt
	}
	reg.targets = targets
	return reg
}

// set_scalar stores a scalar field; tgt_null marks it explicit-null.
fn set_scalar(mut tgt Target, key string, val string) {
	match key {
		'display_name' { tgt.display = val }
		'adapter' { tgt.adapter = val }
		'tier' { tgt.tier = val }
		'tier_rationale' { tgt.tier_rationale = val }
		'maturity' { tgt.maturity = val }
		'agent_plugins_extension' {
			tgt.agent_plugins_extension = val
			tgt.has_extension = true
		}
		'researched_at' { tgt.researched_at = val }
		'notes' { tgt.notes = val }
		else {}
	}
}

fn tgt_null(mut tgt Target, key string) {
	// Explicit-null scalars: Python renders `t.get(k, dflt)` nulls as the
	// string 'None' in f-strings (tier/maturity/adapter/researched_at) —
	// replicate exactly. (The file carries no explicit nulls today; this
	// only guards future edits.) The extension check treats None as
	// missing → validation fails loudly, same as the retired script.
	match key {
		'agent_plugins_extension' {
			tgt.has_extension = false
			tgt.agent_plugins_extension = ''
		}
		'tier' { tgt.tier = 'None' }
		'maturity' { tgt.maturity = 'None' }
		'adapter' { tgt.adapter = 'None' }
		'researched_at' { tgt.researched_at = 'None' }
		else {}
	}
}

// ---------------------------------------------------------------------------
// Rendering + validation (mirrors the retired generate-target-matrix.py)
// ---------------------------------------------------------------------------

const capabilities_order = ['agent_skills', 'agent_plugins', 'native_custom_agents', 'primary_agents',
	'subagents', 'automatic_delegation', 'nested_delegation', 'parallel_agents', 'agent_permissions',
	'agent_models', 'mcp', 'hooks', 'commands', 'rules', 'plugin_marketplace']

fn cap_label(cap string) string {
	return match cap {
		'agent_skills' { 'Agent Skills' }
		'agent_plugins' { 'Agent Plugins' }
		'native_custom_agents' { 'Native Custom Agents' }
		'primary_agents' { 'Primary / Default Agents' }
		'subagents' { 'Subagents' }
		'automatic_delegation' { 'Automatic Delegation' }
		'nested_delegation' { 'Nested Delegation' }
		'parallel_agents' { 'Parallel Agents' }
		'agent_permissions' { 'Agent Permissions' }
		'agent_models' { 'Agent Models' }
		'mcp' { 'MCP' }
		'hooks' { 'Hooks' }
		'commands' { 'Commands' }
		'rules' { 'Rules / Instructions' }
		'plugin_marketplace' { 'Plugin Marketplace' }
		else { cap }
	}
}

// fmt renders a capability cell. Null → '—', bools → ✅/❌, else the
// retired script's lowered mapping (exact strings preserved).
fn fmt_cell(v CVal) string {
	if v.is_null {
		return '—'
	}
	s := v.val.trim_space()
	match s.to_lower() {
		'true' { return '✅' }
		'false' { return '❌' }
		'partial' { return '◐ partial' }
		'unknown' { return '❓ unknown' }
		'unknown-blocked' { return '❓ unknown-blocked' }
		'native' { return '✅ native' }
		'native-experimental' { return '🧪 native-experimental' }
		'generated' { return '🔧 generated' }
		'bridged' { return '🔗 bridged' }
		'manual' { return '✋ manual' }
		'unsupported' { return '❌ unsupported' }
		'v1' { return '`v1`' }
		'none' { return '—' }
		'custom' { return '`custom`' }
		else { return s }
	}
}

fn fmt_opt(v CVal) string {
	// fmt(None) is '—'; a MISSING key defaults to '—' before fmt.
	if v.is_null {
		return '—'
	}
	return fmt_cell(v)
}

fn display_of(t Target) string {
	return if t.display.len > 0 { t.display } else { t.id }
}

fn validate_profiles_coverage(root string, targets []Target) {
	profiles_dir := os.join_path(root, 'profiles')
	if !os.is_dir(profiles_dir) {
		return
	}
	mut profile_ids := []string{}
	for name in (os.ls(profiles_dir) or { []string{} }) {
		if os.is_dir(os.join_path(profiles_dir, name)) {
			profile_ids << name
		}
	}
	profile_ids.sort()
	mut expected := map[string]bool{}
	for pid in profile_ids {
		if pid == 'copilot' {
			expected['copilot-cli'] = true
			expected['copilot-repository'] = true
		} else {
			expected[pid] = true
		}
	}
	mut registry_ids := map[string]bool{}
	for t in targets {
		registry_ids[t.id] = true
	}
	mut missing := []string{}
	for id in expected.keys() {
		if id !in registry_ids {
			missing << id
		}
	}
	mut extra := []string{}
	for id in registry_ids.keys() {
		if id !in expected && id != 'agent-plugins' {
			extra << id
		}
	}
	missing.sort()
	extra.sort()
	mut msgs := []string{}
	if missing.len > 0 {
		msgs << 'registry missing profiles coverage: ${missing} (profiles=${profile_ids})'
	}
	if extra.len > 0 {
		msgs << 'registry has extra ids not in profiles/: ${extra}'
	}
	if msgs.len > 0 {
		for m in msgs {
			eprintln('FAIL: ${m}')
		}
		exit(1)
	}
}

fn validate_agent_plugins_extension(targets []Target) {
	for t in targets {
		tid := if t.id.len > 0 { t.id } else { '<unknown>' }
		ap := if 'agent_plugins' in t.capabilities && !t.capabilities['agent_plugins'].is_null {
			t.capabilities['agent_plugins'].val
		} else {
			''
		}
		if !t.has_extension || t.agent_plugins_extension.trim_space() == '' {
			eprintln('FAIL: ${tid}: missing agent_plugins_extension (required #973 to distinguish portable vs extension)')
			exit(1)
		}
		ext := t.agent_plugins_extension.trim_space()
		if ap == 'custom' {
			if ext.to_lower() == 'portable' || ext.to_lower() == 'none' {
				eprintln("FAIL: ${tid}: agent_plugins is 'custom' but extension is '${ext}' — must specify client extension like 'opencode.json' or 'gemini-extension.json' (#973)")
				exit(1)
			}
			if ext.len < 3 {
				eprintln("FAIL: ${tid}: agent_plugins custom extension too short: '${ext}'")
				exit(1)
			}
		} else if ap == 'v1' {
			if ext != 'portable' {
				eprintln("FAIL: ${tid}: agent_plugins 'v1' must have extension 'portable' (got '${ext}')")
				exit(1)
			}
		} else if ap == 'none' {
			if ext != 'none' {
				eprintln("FAIL: ${tid}: agent_plugins 'none' must have extension 'none' (got '${ext}')")
				exit(1)
			}
		}
	}
}

fn plugins_cell(t Target) string {
	ap := if 'agent_plugins' in t.capabilities && !t.capabilities['agent_plugins'].is_null {
		t.capabilities['agent_plugins'].val
	} else {
		'—'
	}
	ext := if t.has_extension { t.agent_plugins_extension } else { '' }
	if ap == 'v1' && ext == 'portable' {
		return '`v1` (portable)'
	}
	if ap == 'custom' && ext != '' && ext != 'portable' && ext != 'none' {
		short := ext.split(' (')[0]
		return '`custom` (requires ${short})'
	}
	return fmt_cell(if 'agent_plugins' in t.capabilities {
		t.capabilities['agent_plugins']
	} else {
		CVal{'—', false}
	})
}

fn render_md(reg Registry) string {
	targets := reg.targets
	validate_profiles_coverage(repo_root(), targets)
	validate_agent_plugins_extension(targets)

	mut lines := []string{}
	lines << '# Target Capability Matrix'
	lines << ''
	lines << '> Generated from `capabilities/targets/registry.yaml` — do not hand-edit.'
	lines << '> Run `./scripts/generate-target-matrix.vsh` to regenerate, or `./scripts/generate-target-matrix.vsh --check` in CI.'
	lines << ''
	researched := if reg.researched_at.len > 0 {
		reg.researched_at
	} else if targets.len > 0 {
		targets[0].researched_at
	} else {
		''
	}
	if researched.len > 0 {
		lines << '_Researched at: ${researched} — sources per target below._'
		lines << ''
	}
	lines << '## Adapter Tiers (#868)'
	lines << ''
	// One long line (the retired script joins f-string fragments).
	lines << 'Tiers describe the **harness adapter richness** — what the harness natively supports and what the compiler may emit. Least-common-denominator is rejected: each target receives the richest correct subset it supports. `tier` is stored in `capabilities/targets/registry.yaml` (`tier: A/B/C/D`) per #868.'
	lines << ''
	lines << '| Tier | Label | What the adapter supports | Targets |'
	lines << '|------|-------|---------------------------|---------|'
	mut tier_members := {
		'A': []string{}
		'B': []string{}
		'C': []string{}
		'D': []string{}
	}
	for t in targets {
		tier := t.tier.trim_space().to_upper()
		if tier in tier_members {
			tier_members[tier] << display_of(t)
		}
	}
	members_a := if tier_members['A'].len > 0 { tier_members['A'].join(', ') } else { '—' }
	members_b := if tier_members['B'].len > 0 { tier_members['B'].join(', ') } else { '—' }
	members_c := if tier_members['C'].len > 0 { tier_members['C'].join(', ') } else { '—' }
	members_d := if tier_members['D'].len > 0 { tier_members['D'].join(', ') } else { '—' }
	lines << '| **A** | Rich multi-agent | Holistic + specialist agents, delegation (auto/nested/parallel), permissions, models, hooks, MCP, marketplace | ${members_a} |'
	lines << '| **B** | Custom agents, limited delegation | Agents + routing guidance, explicit handoffs; some delegation/MCP/hooks partial or bridged | ${members_b} |'
	lines << '| **C** | Skills + instructions | Agent Skills, global routing guidance, rules/instructions, MCP where native; no subagents/delegation | ${members_c} |'
	lines << '| **D** | Minimal | Richest correct subset only (rules + manual MCP); no marketplace/extensions, no custom agent delegation | ${members_d} |'
	lines << ''
	lines << '> **Gating:** if a capability is `false`/`unknown` the compiler **must not** emit its config (e.g., no subagent config where `subagents: false`). Partial/unknown degrade gracefully via instruction fallback, not invalid config.'
	lines << ''
	lines << '## Legend'
	lines << ''
	lines << '| Symbol | Meaning |'
	lines << '|--------|---------|'
	lines << '| ✅ | Supported (native/stable) |'
	lines << '| ❌ | Not supported |'
	lines << '| ◐ partial | Partial / bridged / requires runtime |'
	lines << '| ❓ unknown | Could not confirm from official docs |'
	lines << '| `v1` | Agent Plugins 1.0 portable |'
	lines << '| `v1` (portable) | Portable via agent-plugins.org (skills + mcp.json) |'
	lines << '| `custom` | Tool-specific custom format |'
	lines << '| `custom` (requires extension X) | Custom agents via client extension — not portable without that extension |'
	lines << '| — | None / not applicable |'
	lines << ''
	lines << '> **Portable vs extension (#973):** `agent_plugins: v1` with `agent_plugins_extension: portable` means portable Agent Plugins 1.0 (skills + mcp.json) per https://agent-plugins.org — guaranteed across Cursor, VS Code, Copilot, Codex, Claude Code. `custom` with `agent_plugins_extension: <extension>` (e.g. `opencode.json`, `gemini-extension.json`, `pi-package.json`) means custom-agent support requires that vendor-specific extension inside an otherwise portable `plugin.json` — not portable without it. `none` = no plugin manifest.'
	lines << ''

	lines << '## Capability × Target'
	lines << ''
	mut header_names := []string{}
	for t in targets {
		header_names << display_of(t)
	}
	lines << '| Capability | ' + header_names.join(' | ') + ' |'
	mut seps := ['---']
	for _ in targets {
		seps << '---'
	}
	lines << '|' + seps.join('|') + '|'
	// Canonical order first, then any extra keys (sorted) from target 0.
	mut ordered := capabilities_order.clone()
	if targets.len > 0 {
		mut extra_caps := []string{}
		for k in targets[0].capabilities.keys() {
			if k !in ordered {
				extra_caps << k
			}
		}
		extra_caps.sort()
		ordered << extra_caps
	}
	for cap in ordered {
		mut row := [cap_label(cap)]
		for t in targets {
			if cap == 'agent_plugins' {
				row << plugins_cell(t)
			} else {
				v := if cap in t.capabilities { t.capabilities[cap] } else { CVal{'—', false} }
				row << fmt_cell(v)
			}
		}
		lines << '| ' + row.join(' | ') + ' |'
	}
	lines << ''

	lines << '## Build Commands & Tiers'
	lines << ''
	lines << '| Target | `build` | `diff` | `release` | Tier | Maturity | Aliases |'
	lines << '|--------|---------|--------|-----------|------|----------|---------|'
	for t in targets {
		mut aq := []string{}
		for a in t.aliases {
			aq << '`${a}`'
		}
		aliases := if aq.len > 0 { aq.join(', ') } else { '—' }
		mat := if t.maturity.len > 0 { t.maturity } else { '—' }
		tier := if t.tier.len > 0 { t.tier } else { '—' }
		b := fmt_opt(if 'build' in t.commands { t.commands['build'] } else { CVal{'—', false} })
		d := fmt_opt(if 'diff' in t.commands { t.commands['diff'] } else { CVal{'—', false} })
		r := fmt_opt(if 'release' in t.commands { t.commands['release'] } else { CVal{'—', false} })
		lines << '| ${display_of(t)} (`${t.id}`) | ${b} | ${d} | ${r} | ${tier} | ${mat} | ${aliases} |'
	}
	lines << ''

	lines << '## Tier Assignment'
	lines << ''
	lines << '| Target | Tier | Rationale |'
	lines << '|--------|------|-----------|'
	for t in targets {
		tier := if t.tier.len > 0 { t.tier } else { '—' }
		rationale := t.tier_rationale.replace('|', '\\|').replace('\n', ' ')
		lines << '| ${display_of(t)} (`${t.id}`) | ${tier} | ${rationale} |'
	}
	lines << ''

	lines << '## Per-Target Details'
	lines << ''
	for t in targets {
		lines << '### ${display_of(t)} (`${t.id}`)'
		lines << ''
		lines << '- **Adapter:** `${t.adapter}`'
		mut aq := []string{}
		for a in t.aliases {
			aq << '`${a}`'
		}
		lines << '- **Aliases:** ${if aq.len > 0 { aq.join(', ') } else { '—' }}'
		b := fmt_opt(if 'build' in t.commands { t.commands['build'] } else { CVal{'—', false} })
		d := fmt_opt(if 'diff' in t.commands { t.commands['diff'] } else { CVal{'—', false} })
		r := fmt_opt(if 'release' in t.commands { t.commands['release'] } else { CVal{'—', false} })
		lines << '- **Commands:** build=${b} diff=${d} release=${r}'
		lines << '- **Tier:** ${if t.tier.len > 0 { t.tier } else { '—' }}'
		if t.tier_rationale.len > 0 {
			lines << '- **Tier rationale:** ${t.tier_rationale}'
		}
		ap := if 'agent_plugins' in t.capabilities && !t.capabilities['agent_plugins'].is_null {
			t.capabilities['agent_plugins'].val
		} else {
			'—'
		}
		ext := if t.has_extension { t.agent_plugins_extension } else { '—' }
		if ap == 'v1' && ext == 'portable' {
			lines << '- **Agent Plugins:** `${ap}` (portable via https://agent-plugins.org)'
		} else if ap == 'custom' && ext != 'portable' && ext != 'none' && ext != '—' && ext != '' {
			lines << '- **Agent Plugins:** `${ap}` (requires extension `${ext}` — not portable without it)'
		} else {
			lines << '- **Agent Plugins:** `${ap}` / extension `${ext}`'
		}
		mat := if t.maturity.len > 0 { t.maturity } else { '—' }
		lines << '- **Maturity:** ${mat}'
		lines << '- **Researched at:** ${if t.researched_at.len > 0 { t.researched_at } else { '—' }}'
		if t.sources.len > 0 {
			lines << '- **Sources:**'
			for s in t.sources {
				lines << '  - ${s}'
			}
		} else {
			lines << '- **Sources:** —'
		}
		if t.notes.len > 0 {
			lines << '- **Notes:** ${t.notes}'
		}
		lines << ''
	}

	lines << '## See also'
	lines << ''
	lines << '- `capabilities/targets/registry.yaml` — source of truth (validated by `schemas/target-capability-registry.schema.json`)'
	lines << '- `schemas/target-capability-registry.schema.json` — JSON schema'
	lines << '- `docs/TARGETS.md` — supported targets overview and install commands'
	lines << '- `docs/research/platform-capability-matrix.md` — prior research (2026-08-04) and capability value definitions'
	lines << '- `docs/research/source-ledger.md` — source URLs and dates'
	lines << '- `agent-toolkit build --check` — compiler drift check'
	lines << ''
	return lines.join('\n') + '\n'
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

fn print_diff_hint(existing string, content string) {
	old_lines := existing.split_into_lines()
	new_lines := content.split_into_lines()
	mut shown := 0
	mut i := 0
	mut j := 0
	// Walk both files; report the first differing regions with line numbers
	// (a readability hint only — exit status carries the verdict).
	for i < old_lines.len || j < new_lines.len {
		ol := if i < old_lines.len { old_lines[i] } else { '' }
		nl := if j < new_lines.len { new_lines[j] } else { '' }
		if ol == nl {
			i++
			j++
			continue
		}
		if shown >= 10 {
			println('... (more differences omitted)')
			break
		}
		println('line ${i + 1} differs:')
		println('< ${ol}')
		println('> ${nl}')
		shown++
		i++
		j++
	}
}

fn main() {
	mut check := false
	mut output := ''
	mut args := os.args.clone()
	// os.args[0] is the compiled binary path; some V versions additionally
	// pass the script path next — drop both, parse only real flags.
	if args.len > 0 {
		args = args[1..].clone()
	}
	if args.len > 0 && args[0].ends_with('.vsh') {
		args = args[1..].clone()
	}
	mut i := 0
	for i < args.len {
		match args[i] {
			'--check' {
				check = true
				i++
			}
			'--output' {
				if i + 1 < args.len {
					output = args[i + 1]
					i += 2
				} else {
					i++
				}
			}
			else {
				if args[i].starts_with('--output=') {
					output = args[i]['--output='.len..]
				}
				i++
			}
		}
	}
	root := repo_root()
	reg_path := os.join_path(root, 'capabilities', 'targets', 'registry.yaml')
	reg_text := os.read_file(reg_path) or {
		eprintln('cannot read ${reg_path}: ${err}')
		exit(2)
	}
	reg := parse_registry(reg_text)
	if reg.targets.len == 0 {
		eprintln("FAIL: registry.yaml missing 'targets' key")
		exit(1)
	}
	content := render_md(reg)
	out := if output == '' {
		os.join_path(root, 'docs', 'TARGET_CAPABILITY_MATRIX.md')
	} else if os.is_abs_path(output) {
		output
	} else {
		os.join_path(root, output)
	}
	if check {
		if !os.is_file(out) {
			eprintln('Missing matrix file: ${out}')
			exit(1)
		}
		existing := os.read_file(out) or { '' }
		if existing != content {
			eprintln('Matrix out of date: ${out} differs from ${reg_path}')
			eprintln('Run: ./scripts/generate-target-matrix.vsh')
			print_diff_hint(existing, content)
			exit(1)
		}
		println('Matrix up to date: ${out}')
		return
	}
	os.mkdir_all(os.dir(out)) or {}
	os.write_file(out, content) or {
		eprintln('cannot write ${out}: ${err}')
		exit(1)
	}
	println('Wrote matrix to ${out} (${content.split_into_lines().len} lines)')
}
