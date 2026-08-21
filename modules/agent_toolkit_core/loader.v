module agent_toolkit_core

import os
import yaml

struct ProductIncludesYaml {
	skills []string
	agents []string
	hooks  []string
	mcp    []string
}

struct ProductYaml {
	id          string
	name        string
	description string
	stability   string
	includes    ProductIncludesYaml
}

struct ProductsDoc {
	products []ProductYaml
}

// HookHandlerYaml mirrors the `handler` block of a canonical hook definition
// (capabilities/hooks/*.yaml). Only the fields needed for adapter emission are decoded.
struct HookHandlerYaml {
	command    []string
	timeout_ms int
}

// HookYaml is one canonical lifecycle hook (ADR-026 hook registry, #754).
struct HookYaml {
	id        string
	event     string
	handler   HookHandlerYaml
	platforms map[string]string
}

// LoadedSkill is a capability node from skills/<domain>/<name>/SKILL.md.
pub struct LoadedSkill {
pub:
	id          string
	name        string
	domain      string
	source_path string
}

// LoadedAgent is a persona node from agents/<name>/AGENT.md.
pub struct LoadedAgent {
pub:
	id          string
	name        string
	source_path string
}

// LoadedHook is a canonical lifecycle hook from capabilities/hooks/*.yaml (#754).
pub struct LoadedHook {
pub:
	id           string
	event        string
	command      []string
	timeout_ms   int
	cursor_event string // Cursor adapter event name, empty = unsupported
}

// LoadedProduct is a product selected from distributions/products.yaml.
pub struct LoadedProduct {
pub:
	id              string
	name            string
	description     string
	stability       string
	included_skills []string
	included_agents []string
	included_hooks  []string
	included_mcp    []string
}

// CanonicalGraph is the compiler IR (ADR-001) after loading canonical sources.
pub struct CanonicalGraph {
pub mut:
	skills   map[string]LoadedSkill
	agents   map[string]LoadedAgent
	hooks    map[string]LoadedHook
	products map[string]LoadedProduct
	errors   []string
	warnings []string
}

// is_valid reports whether load produced no errors.
pub fn (g CanonicalGraph) is_valid() bool {
	return g.errors.len == 0
}

// select_product returns a product by id.
pub fn (g CanonicalGraph) select_product(id string) ?LoadedProduct {
	if id in g.products {
		return g.products[id]
	}
	return none
}

// load_graph loads skills/, agents/, and distributions/products.yaml (ADR-001 / ADR-006).
// SKILL.md folded-scalar descriptions are not decoded (vlib/yaml); ids come from the tree.
pub fn load_graph(repo_root string) CanonicalGraph {
	mut g := CanonicalGraph{}
	if repo_root.len == 0 || !os.is_dir(repo_root) {
		g.errors << 'repo root not found: ${repo_root}'
		return g
	}
	g.skills = load_skill_ids(os.join_path(repo_root, 'skills'))
	g.agents = load_agent_ids(os.join_path(repo_root, 'agents'))
	g.hooks = load_hooks(os.join_path(repo_root, 'capabilities', 'hooks'))
	products, perrs := load_products_file(os.join_path(repo_root, 'distributions', 'products.yaml'))
	g.errors << perrs
	for p in products {
		g.products[p.id] = p
	}
	validate_product_refs(mut g)
	return g
}

// load_products_file decodes distributions/products.yaml into LoadedProduct values.
pub fn load_products_file(path string) ([]LoadedProduct, []string) {
	mut errors := []string{}
	if !os.is_file(path) {
		return []LoadedProduct{}, ['products.yaml not found: ${path}']
	}
	text := os.read_file(path) or {
		return []LoadedProduct{}, ['cannot read products.yaml: ${err}']
	}
	doc := yaml.decode[ProductsDoc](text) or {
		return []LoadedProduct{}, ['products.yaml decode failed: ${err}']
	}
	mut out := []LoadedProduct{}
	for p in doc.products {
		if p.id.len == 0 {
			errors << "Product missing 'id' field"
			continue
		}
		stab := p.stability
		stability := if stab in ['stable', 'experimental', 'deprecated'] { stab } else { 'stable' }
		out << LoadedProduct{
			id:              p.id
			name:            if p.name.len > 0 { p.name } else { p.id }
			description:     p.description
			stability:       stability
			included_skills: p.includes.skills
			included_agents: p.includes.agents
			included_hooks:  p.includes.hooks
			included_mcp:    p.includes.mcp
		}
	}
	return out, errors
}

fn load_skill_ids(skills_root string) map[string]LoadedSkill {
	mut out := map[string]LoadedSkill{}
	files := collect_named_files(skills_root, 'SKILL.md')
	for p in files {
		name := os.file_name(os.dir(p))
		domain := os.file_name(os.dir(os.dir(p)))
		if name.len == 0 || domain.len == 0 {
			continue
		}
		id := '${domain}/${name}'
		out[id] = LoadedSkill{
			id:          id
			name:        name
			domain:      domain
			source_path: p
		}
	}
	return out
}

fn load_agent_ids(agents_root string) map[string]LoadedAgent {
	mut out := map[string]LoadedAgent{}
	files := collect_named_files(agents_root, 'AGENT.md')
	for p in files {
		name := os.file_name(os.dir(p))
		if name.len == 0 {
			continue
		}
		out[name] = LoadedAgent{
			id:          name
			name:        name
			source_path: p
		}
	}
	return out
}

fn validate_product_refs(mut g CanonicalGraph) {
	for pid, product in g.products {
		for sid in product.included_skills {
			if sid !in g.skills {
				g.warnings << "Product '${pid}' references skill '${sid}' not found in skills/"
			}
		}
		for aid in product.included_agents {
			if aid !in g.agents {
				g.warnings << "Product '${pid}' references agent '${aid}' not found in agents/"
			}
		}
		for hid in product.included_hooks {
			if hid !in g.hooks {
				g.warnings << "Product '${pid}' references hook '${hid}' not found in capabilities/hooks/"
			}
		}
	}
}

// cursor_hook_event maps a canonical hook event to a Cursor lifecycle event name.
// Returns an empty string when the event is not supported by the Cursor hook surface.
fn cursor_hook_event(event string) string {
	return match event {
		'session.start' { 'SessionStart' }
		'tool.before' { 'BeforeFileWrite' }
		else { '' }
	}
}

// load_hooks reads capabilities/hooks/*.yaml into canonical hook definitions.
fn load_hooks(hooks_root string) map[string]LoadedHook {
	mut out := map[string]LoadedHook{}
	if !os.is_dir(hooks_root) {
		return out
	}
	entries := os.ls(hooks_root) or { return out }
	for e in entries {
		if !e.ends_with('.yaml') {
			continue
		}
		p := os.join_path(hooks_root, e)
		text := os.read_file(p) or { continue }
		h := yaml.decode[HookYaml](text) or { continue }
		if h.id.len == 0 {
			continue
		}
		out[h.id] = LoadedHook{
			id:           h.id
			event:        h.event
			command:      h.handler.command
			timeout_ms:   h.handler.timeout_ms
			cursor_event: cursor_hook_event(h.event)
		}
	}
	return out
}

fn collect_named_files(dir string, name string) []string {
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
			out << collect_named_files(p, name)
		} else if e == name {
			out << p
		}
	}
	return out
}
