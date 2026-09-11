#!/usr/bin/env -S v run
// Validate agents taxonomy roster vs structured sources (#971).
//
// Usage: ./scripts/validate-agents-taxonomy.vsh [--check]   (from repo root or any subdir)

import os

fn repo_root() string {
	mut d := os.dir(@FILE)
	// scripts/ -> repo root
	d = os.dir(d)
	if os.is_file(os.join_path(d, 'VERSION')) {
		return d
	}
	return os.getwd()
}

fn physical_agents(agents_dir string) []string {
	names := os.ls(agents_dir) or { return []string{} }
	mut out := []string{}
	for name in names {
		if os.is_dir(os.join_path(agents_dir, name))
			&& os.is_file(os.join_path(agents_dir, name, 'AGENT.md')) {
			out << name
		}
	}
	return out.sorted()
}

fn main() {
	check := '--check' in os.args
	root := repo_root()
	agents_dir := os.join_path(root, 'agents')
	mut errors := []string{}

	physical := physical_agents(agents_dir)

	// holistic owners from the registry. Parsed with a tolerant line scanner
	// instead of yaml.decode: V's yaml module rejects the registry's
	// multi-line plain scalars, while every `holistic_owner:` line in the
	// file is a skill field (116 occurrences == skill count), so scanning
	// those lines is exactly equivalent — and immune to future wrapping.
	// Specialists come from the filesystem (authoritative for #971:
	// kind == specialist in AGENT.md frontmatter).
	reg_text := os.read_file(os.join_path(root, 'capabilities', 'skills', 'registry.yaml')) or {
		eprintln('cannot read registry.yaml: ${err}')
		exit(2)
	}
	mut holistic := []string{}
	for line in reg_text.split_into_lines() {
		trimmed := line.trim_space()
		if trimmed.starts_with('holistic_owner:') {
			owner := trimmed['holistic_owner:'.len..].trim_space()
			if owner.len > 0 && owner !in holistic {
				holistic << owner
			}
		}
	}
	mut specialists := []string{}
	for name in physical {
		fm_text := os.read_file(os.join_path(agents_dir, name, 'AGENT.md')) or { continue }
		parts := fm_text.split('---')
		if parts.len > 1 && parts[1].contains('kind: specialist') {
			specialists << name
		}
	}

	for h in holistic {
		if h !in physical {
			errors << "registry holistic_owner '${h}' has no agents/${h}/AGENT.md"
		}
	}

	// taxonomy counts
	tax_path := os.join_path(root, 'docs', 'AGENT_TAXONOMY.md')
	tax_text := os.read_file(tax_path) or { '' }
	if !tax_text.contains('11 holistic') && !tax_text.contains('11 roles') {
		errors << "docs/AGENT_TAXONOMY.md missing '11 holistic' count — stale"
	}
	if !tax_text.contains('18 agents') && !tax_text.contains('18 personas')
		&& !tax_text.contains('18 AI agent') {
		errors << "docs/AGENT_TAXONOMY.md missing '18 agents/personas' count"
	}
	for h in holistic {
		if !tax_text.contains(h) {
			errors << "docs/AGENT_TAXONOMY.md missing holistic_owner '${h}'"
		}
	}

	// expected set: holistics + specialists + the two orchestrators
	mut expected := map[string]bool{}
	for h in holistic {
		expected[h] = true
	}
	for s in specialists {
		expected[s] = true
	}
	expected['assistant'] = true
	expected['client-workflow-bootstrap'] = true
	mut physical_set := map[string]bool{}
	for p in physical {
		physical_set[p] = true
	}
	mut missing := []string{}
	mut extra := []string{}
	for name in expected.keys() {
		if name !in physical_set {
			missing << name
		}
	}
	for p in physical {
		if p !in expected {
			extra << p
		}
	}
	missing.sort()
	extra.sort()
	if missing.len > 0 {
		errors << 'taxonomy drift: expected agents missing on filesystem: ${missing}'
	}
	if extra.len > 0 {
		errors << 'taxonomy drift: filesystem has extra agents not in holistics+specialists+orchestrators: ${extra} — adding agents/new-agent without registry update fails CI (see #971)'
	}

	// product includes check: agent-toolkit-agents must not reference unknowns.
	// Same tolerant line scan: within the `- id: agent-toolkit-agents`
	// block, collect the `agents:` list items (8-space `- name` entries
	// under the 6-space `agents:` key) until the block dedents.
	prod_path := os.join_path(root, 'distributions', 'products.yaml')
	if os.is_file(prod_path) {
		prod_text := os.read_file(prod_path) or { '' }
		mut in_product := false
		mut in_agents := false
		mut prod_agents := []string{}
		for line in prod_text.split_into_lines() {
			if line.starts_with('  - id:') {
				if line.trim_space() == '- id: agent-toolkit-agents' {
					in_product = true
				} else if in_product {
					break
				}
				continue
			}
			if !in_product {
				continue
			}
			trimmed := line.trim_space()
			if trimmed == 'agents:' {
				in_agents = true
				continue
			}
			if in_agents {
				indent := line.len - line.trim_left(' ').len
				if trimmed.starts_with('- ') && indent > 6 {
					prod_agents << trimmed[2..].trim_space()
				} else if trimmed.len > 0 && indent <= 6 {
					in_agents = false
				}
			}
		}
		mut unknown := []string{}
		for a in prod_agents {
			if a !in physical_set {
				unknown << a
			}
		}
		unknown.sort()
		if unknown.len > 0 {
			errors << 'products.yaml agent-toolkit-agents includes unknown agents: ${unknown}'
		}
	}

	if errors.len > 0 {
		for e in errors {
			eprintln('  ✗ ${e}')
		}
		eprintln('\n❌ ${errors.len} taxonomy error(s)')
		exit(1)
	}
	println('✓ taxonomy roster matches registry+specialists+orchestrators (18 = 11 holistic + 2 orchestrators + 6 specialists - overlap)')
	println('✓ docs/AGENT_TAXONOMY.md counts validated')
	if !check {
		println('All taxonomy checks passed')
	}
}
