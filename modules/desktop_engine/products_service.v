module desktop_engine

import os

// ProductEntry mirrors distributions/products.yaml.
pub struct ProductEntry {
pub mut:
	id          string
	name        string
	description string
	skill_ids   []string
	pack_ids    []string
}

// PackEntry mirrors packs/ (docs-only per ADR-006).
pub struct PackEntry {
pub:
	id         string
	name       string
	skill_count int
	docs_only  bool
}

// products_catalog returns products from distributions/products.yaml or synthetic.
pub fn (mut e Engine) products_catalog() []ProductEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	prod_path := os.join_path(env.toolkit_root, 'distributions', 'products.yaml')
	if os.is_file(prod_path) {
		txt := os.read_file(prod_path) or { '' }
		if txt.contains('agent-toolkit-core') {
			mut out := []ProductEntry{}
			lines := txt.split_into_lines()
			mut cur := ProductEntry{}
			mut in_products := false
			for line in lines {
				t := line.trim_space()
				if t == 'products:' {
					in_products = true
					continue
				}
				if in_products && t.starts_with('- id:') {
					if cur.id != '' {
						out << cur
					}
					cur = ProductEntry{id: t.all_after(':').trim_space()}
				} else if in_products && t.starts_with('name:') && cur.id != '' && cur.name == '' {
					cur.name = t.all_after(':').trim_space().trim('"')
				}
			}
			if cur.id != '' {
				out << cur
			}
			if out.len > 0 {
				for i in 0 .. out.len {
					out[i].skill_ids = e.skills_installed()
					if out[i].skill_ids.len == 0 {
						out[i].skill_ids = ['core/assistant', 'core/dev-companion']
					}
				}
				return out
			}
		}
	}
	return [
		ProductEntry{id: 'agent-toolkit-core', name: 'Agent Toolkit Core', description: 'Core', skill_ids: ['core/assistant', 'core/dev-companion'], pack_ids: ['docs-only']},
		ProductEntry{id: 'agent-toolkit-work', name: 'Work Pack', description: 'Delivery', skill_ids: ['delivery/scrum'], pack_ids: ['work']},
		ProductEntry{id: 'agent-toolkit-full', name: 'Full', description: 'All', skill_ids: e.skills_catalog().map(it.id)[..10], pack_ids: ['full']},
	]
}

pub fn (mut e Engine) packs_catalog() []PackEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	return [
		PackEntry{id: 'docs-only', name: 'Docs Only', skill_count: 5, docs_only: true},
		PackEntry{id: 'core', name: 'Core', skill_count: 6, docs_only: true},
		PackEntry{id: 'design', name: 'Design', skill_count: 12, docs_only: true},
		PackEntry{id: 'delivery', name: 'Delivery', skill_count: 10, docs_only: true},
		PackEntry{id: 'forge', name: 'Forge', skill_count: 8, docs_only: true},
		PackEntry{id: 'security', name: 'Security', skill_count: 7, docs_only: true},
		PackEntry{id: 'full', name: 'Full', skill_count: 116, docs_only: true},
	]
}

pub fn (mut e Engine) update_product_membership(product_id string, skill_ids []string) !u64 {
	if product_id == '' {
		return error('product id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('update-product')
	tx.set('product:${product_id}:skills', skill_ids.join(','))
	tx.set('products_count', e.products_catalog().len.str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

pub fn (mut e Engine) set_pack_enabled(pack_id string, enabled bool) !u64 {
	if pack_id == '' {
		return error('pack id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('set-pack')
	tx.set('pack:${pack_id}:enabled', if enabled { 'true' } else { 'false' })
	rev := e.put_transaction(mut tx)!
	return rev.revision
}
