module agent_toolkit_core

import os
import yaml

struct ProductEntry {
	id   string
	name string
}

struct ProductsFile {
	products []ProductEntry
}

// InventorySnapshot is the domain model for `agent-toolkit inventory`.
pub struct InventorySnapshot {
pub:
	root          string
	skill_count   int
	agent_count   int
	product_count int
	domain_count  int
	message       string
}

// load_inventory lists skills/, agents/, and distributions/products.yaml.
// Catalog YAML is not decoded (vlib/yaml rejects folded descriptions); tree walk is the source.
pub fn load_inventory() !InventorySnapshot {
	if root := find_toolkit_root() {
		return load_inventory_at(root.path)
	}
	root := lookup_checkout_root()
	if root.len == 0 {
		return error('Cannot locate agent-toolkit root (set AGENT_TOOLKIT_ROOT)')
	}
	return load_inventory_at(root)
}

// load_inventory_at is the injectable variant for tests.
pub fn load_inventory_at(root string) !InventorySnapshot {
	if is_embedded_root(root) {
		return load_inventory_embedded()
	}
	skill_files := collect_named(os.join_path(root, 'skills'), 'SKILL.md')
	mut domains := map[string]int{}
	skills_root := os.join_path(root, 'skills')
	for p in skill_files {
		rel := rel_under(skills_root, p)
		domain := first_path_component(rel)
		if domain.len > 0 {
			domains[domain] = domains[domain] + 1
		}
	}
	agent_dirs := list_agent_dirs(os.join_path(root, 'agents'))
	products := load_products(os.join_path(root, 'distributions', 'products.yaml'))

	mut lines := []string{}
	lines << ''
	lines << '═══ agent-toolkit Inventory ═══'
	lines << ''
	lines << 'Skills: ${skill_files.len} across ${domains.len} domains'
	lines << ''
	mut domain_names := domains.keys()
	domain_names.sort()
	for d in domain_names {
		lines << '  ${d}/ (${domains[d]})'
		for p in skill_files {
			rel := rel_under(skills_root, p)
			if first_path_component(rel) != d {
				continue
			}
			name := os.file_name(os.dir(p))
			lines << '    ✓  ${name}'
		}
	}
	lines << ''
	lines << 'Agents: ${agent_dirs.len}'
	mut agents := agent_dirs.clone()
	agents.sort()
	for a in agents {
		lines << '  ✓  ${a}'
	}
	lines << ''
	lines << 'Products: ${products.len}'
	for p in products {
		lines << '  ✓  ${p.id}'
	}
	lines << ''

	return InventorySnapshot{
		root:          root
		skill_count:   skill_files.len
		agent_count:   agent_dirs.len
		product_count: products.len
		domain_count:  domains.len
		message:       lines.join('\n')
	}
}

fn load_inventory_embedded() InventorySnapshot {
	mut skill_files := []string{}
	for k, _ in embedded_file_map {
		if k.starts_with('skills/') && k.ends_with('SKILL.md') {
			skill_files << k
		}
	}
	mut domains := map[string]int{}
	for p in skill_files {
		parts := p.split('/')
		if parts.len >= 2 {
			domain := parts[1]
			domains[domain] = domains[domain] + 1
		}
	}
	mut agent_dirs := []string{}
	for e in embedded_ls('agents') {
		if embedded_is_dir('agents/' + e) {
			agent_dirs << e
		}
	}
	products := load_products_embedded()
	mut lines := []string{}
	lines << ''
	lines << '═══ agent-toolkit Inventory ═══'
	lines << ''
	lines << 'Skills: ${skill_files.len} across ${domains.len} domains'
	lines << ''
	mut domain_names := domains.keys()
	domain_names.sort()
	skill_files.sort()
	for d in domain_names {
		lines << '  ${d}/ (${domains[d]})'
		for p in skill_files {
			parts := p.split('/')
			if parts.len < 3 {
				continue
			}
			if parts[1] != d {
				continue
			}
			name := parts[2]
			lines << '    ✓  ${name}'
		}
	}
	lines << ''
	lines << 'Agents: ${agent_dirs.len}'
	mut agents := agent_dirs.clone()
	agents.sort()
	for a in agents {
		lines << '  ✓  ${a}'
	}
	lines << ''
	lines << 'Products: ${products.len}'
	for p in products {
		lines << '  ✓  ${p.id}'
	}
	lines << ''
	return InventorySnapshot{
		root:          'embedded'
		skill_count:   skill_files.len
		agent_count:   agent_dirs.len
		product_count: products.len
		domain_count:  domains.len
		message:       lines.join('\n')
	}
}

fn load_products_embedded() []ProductEntry {
	text := embedded_read_file('distributions/products.yaml') or { return [] }
	doc := yaml.decode[ProductsFile](text) or { return [] }
	return doc.products
}

// inventory_result maps a snapshot to CommandResult.
pub fn inventory_result(snap InventorySnapshot) CommandResult {
	return CommandResult{
		command: 'inventory'
		ok:      true
		message: snap.message
		data:    {
			'root':           snap.root
			'skills_count':   '${snap.skill_count}'
			'agents_count':   '${snap.agent_count}'
			'products_count': '${snap.product_count}'
			'domains_count':  '${snap.domain_count}'
		}
	}
}

// lookup_checkout_root finds a toolkit checkout via env then CWD walk-up.
pub fn lookup_checkout_root() string {
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		if os.is_dir(os.join_path(val, 'skills')) || os.is_dir(os.join_path(val, 'profiles')) {
			return val
		}
	}
	mut cur := os.getwd()
	for {
		if os.is_dir(os.join_path(cur, 'skills')) && os.is_dir(os.join_path(cur, 'loops')) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	cwd := os.getwd()
	if os.is_dir(os.join_path(cwd, 'skills')) || os.is_dir(os.join_path(cwd, 'loops')) {
		return cwd
	}
	return ''
}

fn collect_named(dir string, name string) []string {
	mut out := []string{}
	if !os.is_dir(dir) {
		return out
	}
	entries := os.ls(dir) or { return out }
	for e in entries {
		if e.starts_with('.') {
			continue
		}
		p := os.join_path(dir, e)
		if os.is_dir(p) {
			out << collect_named(p, name)
		} else if e == name {
			out << p
		}
	}
	return out
}

fn list_agent_dirs(dir string) []string {
	mut out := []string{}
	if !os.is_dir(dir) {
		return out
	}
	entries := os.ls(dir) or { return out }
	for e in entries {
		if e.starts_with('.') {
			continue
		}
		p := os.join_path(dir, e)
		if os.is_dir(p) {
			out << e
		}
	}
	return out
}

fn rel_under(root string, path string) string {
	if path.len <= root.len {
		return ''
	}
	mut rel := path[root.len..]
	if rel.starts_with('/') || rel.starts_with('\\') {
		rel = rel[1..]
	}
	return rel
}

fn first_path_component(rel string) string {
	mut i := 0
	for i < rel.len {
		c := rel[i]
		if c == `/` || c == `\\` {
			return rel[..i]
		}
		i++
	}
	return rel
}

fn load_products(path string) []ProductEntry {
	if !os.is_file(path) {
		return []
	}
	text := os.read_file(path) or { return [] }
	doc := yaml.decode[ProductsFile](text) or { return [] }
	return doc.products
}
