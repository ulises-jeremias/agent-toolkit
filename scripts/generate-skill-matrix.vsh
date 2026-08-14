#!/usr/bin/env -S v run
// Generate docs/SKILL_PRODUCT_MATRIX.md from distributions/products.yaml.
// Usage:
//   ./scripts/generate-skill-matrix.vsh
//   ./scripts/generate-skill-matrix.vsh --check

import yaml

fn repo_root() string {
	mut d := dir(@FILE)
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

struct ProductIncludes {
	skills []string
	agents []string
}

struct ProductYaml {
	id        string
	stability string
	includes  ProductIncludes
}

struct ProductsDoc {
	products []ProductYaml
}

fn product_targets(raw string, product_id string) []string {
	// Extract target keys under the product's targets: map by scanning YAML text.
	mut targets := []string{}
	lines := raw.split_into_lines()
	mut in_product := false
	mut in_targets := false
	mut product_indent := -1
	for line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with('- id:') || trimmed.starts_with('- id :') {
			id := trimmed.all_after('id:').trim_space().trim('"').trim("'")
			in_product = id == product_id
			in_targets = false
			product_indent = line.len - line.trim_left(' \t').len
			continue
		}
		if !in_product {
			continue
		}
		indent := line.len - line.trim_left(' \t').len
		if trimmed.len > 0 && indent <= product_indent && !trimmed.starts_with('#')
			&& (trimmed.starts_with('- ') || (indent == 0 && trimmed.len > 0)) {
			// next product or top-level
			if trimmed.starts_with('- id') {
				in_product = false
				in_targets = false
			}
		}
		if in_product && trimmed.starts_with('targets:') {
			in_targets = true
			continue
		}
		if in_targets {
			if trimmed.len == 0 || trimmed.starts_with('#') {
				continue
			}
			if indent <= product_indent + 2 && !trimmed.contains(':') {
				in_targets = false
				continue
			}
			if trimmed.ends_with(':') && !trimmed.starts_with('-') {
				key := trimmed.trim_right(':').trim_space()
				if key.len > 0 && key != 'targets' {
					targets << key
				}
			}
			if indent <= product_indent && trimmed.starts_with('- ') {
				in_targets = false
			}
		}
	}
	targets.sort()
	return targets
}

fn all_skills(root string) []string {
	mut out := []string{}
	skills_dir := join_path(root, 'skills')
	for domain in (ls(skills_dir) or { []string{} }).sorted() {
		domain_path := join_path(skills_dir, domain)
		if !is_dir(domain_path) {
			continue
		}
		for skill in (ls(domain_path) or { []string{} }).sorted() {
			if is_file(join_path(domain_path, skill, 'SKILL.md')) {
				out << '${domain}/${skill}'
			}
		}
	}
	return out
}

fn all_agents(root string) []string {
	mut out := []string{}
	agents_dir := join_path(root, 'agents')
	for name in (ls(agents_dir) or { []string{} }).sorted() {
		if is_dir(join_path(agents_dir, name)) {
			out << name
		}
	}
	return out
}

fn render_md(root string) string {
	products_path := join_path(root, 'distributions', 'products.yaml')
	raw := read_file(products_path) or {
		eprintln('cannot read products.yaml: ${err}')
		exit(1)
	}
	doc := yaml.decode[ProductsDoc](raw) or {
		eprintln('products.yaml decode failed: ${err}')
		exit(1)
	}
	skills := all_skills(root)
	agents := all_agents(root)
	mut sku_to_products := map[string][]string{}
	mut agent_to_products := map[string][]string{}
	mut product_targets_map := map[string][]string{}
	mut product_stability := map[string]string{}
	for p in doc.products {
		product_stability[p.id] = p.stability
		product_targets_map[p.id] = product_targets(raw, p.id)
		for s in p.includes.skills {
			mut list := sku_to_products[s] or { []string{} }
			list << p.id
			sku_to_products[s] = list
		}
		for a in p.includes.agents {
			mut list := agent_to_products[a] or { []string{} }
			list << p.id
			agent_to_products[a] = list
		}
	}
	mut lines := []string{}
	lines << '# Skill → Product → Target Membership Matrix'
	lines << ''
	lines << '> Generated from `distributions/products.yaml` — do not hand-edit. Run `./scripts/generate-skill-matrix.vsh` to regenerate, or `./scripts/generate-skill-matrix.vsh --check` in CI.'
	lines << ''
	lines << '_Generated from ${doc.products.len} products × ${skills.len} skills × ${agents.len} agents._'
	lines << ''
	lines << '## Products and targets'
	lines << ''
	lines << '| Product | Stability | Targets | Skills | Agents |'
	lines << '|---------|-----------|---------|--------|--------|'
	for p in doc.products {
		tgs := product_targets_map[p.id] or { []string{} }
		tgs_str := if tgs.len > 0 { tgs.join(', ') } else { '—' }
		sc := p.includes.skills.len
		ag := p.includes.agents.len
		stab := product_stability[p.id] or { '' }
		lines << '| `${p.id}` | ${stab} | ${tgs_str} | ${sc} | ${ag} |'
	}
	lines << ''
	lines << '## Skills → Products'
	lines << ''
	lines << '| Skill | Products | Targets (via products) |'
	lines << '|-------|----------|------------------------|'
	for skill in skills {
		mut prods := sku_to_products[skill] or { []string{} }
		prods.sort()
		if prods.len > 0 {
			prod_str := prods.map(fn (p string) string {
				return '`${p}`'
			}).join(', ')
			mut tset := map[string]bool{}
			for pr in prods {
				for t in product_targets_map[pr] or { []string{} } {
					tset[t] = true
				}
			}
			mut tlist := tset.keys()
			tlist.sort()
			target_str := if tlist.len > 0 { tlist.join(', ') } else { '—' }
			lines << '| `${skill}` | ${prod_str} | ${target_str} |'
		} else {
			lines << '| `${skill}` | _uncovered_ | — |'
		}
	}
	lines << ''
	lines << '## Agents → Products'
	lines << ''
	lines << '| Agent | Products | Targets (via products) |'
	lines << '|-------|----------|------------------------|'
	for agent in agents {
		mut prods := agent_to_products[agent] or { []string{} }
		prods.sort()
		if prods.len > 0 {
			prod_str := prods.map(fn (p string) string {
				return '`${p}`'
			}).join(', ')
			mut tset := map[string]bool{}
			for pr in prods {
				for t in product_targets_map[pr] or { []string{} } {
					tset[t] = true
				}
			}
			mut tlist := tset.keys()
			tlist.sort()
			target_str := if tlist.len > 0 { tlist.join(', ') } else { '—' }
			lines << '| `${agent}` | ${prod_str} | ${target_str} |'
		} else {
			lines << '| `${agent}` | _uncovered_ | — |'
		}
	}
	lines << ''
	lines << '## How to read'
	lines << ''
	lines << '- A skill appears in a marketplace plugin when its product is built for that target (`agent-toolkit build --product <id> --target <target>`).'
	lines << '- `_uncovered_` means the skill/agent is not in any stable product yet — it exists canonically but is not shipped. See Wave 5 curation for promotion decisions.'
	lines << '- Verify membership locally via `agent-toolkit inventory` (canonical counts) or `./scripts/generate-skill-matrix.vsh --check`.'
	lines << ''
	lines << '## See also'
	lines << ''
	lines << '- `distributions/products.yaml` — source of truth'
	lines << '- `agent-toolkit inventory` — CLI inventory'
	lines << '- `agent-toolkit build --check` — drift check'
	lines << ''
	return lines.join('\n')
}

fn main() {
	root := repo_root()
	mut check := false
	mut output := join_path(root, 'docs', 'SKILL_PRODUCT_MATRIX.md')
	mut i := 1
	for i < args.len {
		a := args[i]
		if a == '--check' {
			check = true
		} else if a == '--output' && i + 1 < args.len {
			i++
			output = args[i]
			if !is_abs_path(output) {
				output = join_path(root, output)
			}
		}
		i++
	}
	content := render_md(root)
	if check {
		if !is_file(output) {
			eprintln('Missing matrix file: ${output}')
			exit(1)
		}
		existing := read_file(output) or { '' }
		if existing != content {
			eprintln('Matrix out of date: ${output} differs from distributions/products.yaml')
			eprintln('Run: ./scripts/generate-skill-matrix.vsh')
			exit(1)
		}
		println('Matrix up to date: ${output}')
		exit(0)
	}
	write_file(output, content) or {
		eprintln('write failed: ${err}')
		exit(1)
	}
	println('Wrote matrix to ${output} (${content.split_into_lines().len} lines)')
}
