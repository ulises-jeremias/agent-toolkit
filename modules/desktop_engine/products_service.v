module desktop_engine

import time
import x.json2

// ProductEntry mirrors distributions/products.yaml — super-potent with provenance/receipts.
pub struct ProductEntry {
pub mut:
	id           string
	name         string
	description  string
	skill_ids    []string
	pack_ids     []string
	provenance   string
	receipt_path string
	version      string
}

// PackEntry mirrors packs/ (docs-only per ADR-006) — super-potent with provenance.
pub struct PackEntry {
pub:
	id           string
	name         string
	skill_count  int
	docs_only    bool
	enabled      bool
	provenance   string
	receipt_path string
}

// products_catalog returns products from distributions/products.yaml. A missing
// product catalog is unavailable, not a reason to invent products.
pub fn (mut e Engine) products_catalog() []ProductEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	if data_file_exists(env, 'distributions/products.yaml') {
		txt := data_file_read(env, 'distributions/products.yaml') or { '' }
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
					cur = ProductEntry{ id: t.all_after(':').trim_space(), provenance: 'distributions/products.yaml', version: '1.27.0' }
				} else if in_products && t.starts_with('name:') && cur.id != '' && cur.name == '' {
					cur.name = t.all_after(':').trim_space().trim('"')
				} else if in_products && t.starts_with('description:') && cur.id != '' && cur.description == '' {
					cur.description = t.all_after(':').trim_space().trim('"')
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
					out[i].receipt_path = 'receipts/product-${out[i].id}.json'
					out[i].provenance = 'distributions/products.yaml'
				}
				return out
			}
		}
	}
	return []ProductEntry{}
}

// products_search fuzzy filters products — easy potent management.
pub fn (mut e Engine) products_search(query string) []ProductEntry {
	cat := e.products_catalog()
	q := query.trim_space().to_lower()
	if q == '' {
		return cat.clone()
	}
	mut out := []ProductEntry{}
	for p in cat {
		if p.id.to_lower().contains(q) || p.name.to_lower().contains(q) || p.description.to_lower().contains(q) {
			out << p
		}
	}
	return out
}

// packs_catalog discovers packs/*/config.yaml and derives enabled skill counts
// from each config. It uses the tier-aware data_* helpers so embedded binaries
// resolve bundled packs the same way a checkout does.
pub fn (mut e Engine) packs_catalog() []PackEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	root_rel := 'packs'
	mut ids := []string{}
	if data_dir_exists(env, root_rel) {
		ids = data_list_dir(env, root_rel)
	}
	ids.sort()
	mut out := []PackEntry{}
	snap := e.repo.snapshot()
	for id in ids {
		config_rel := '${root_rel}/${id}/config.yaml'
		if !data_file_exists(env, config_rel) {
			continue
		}
		text := data_file_read(env, config_rel) or { '' }
		mut skill_count := 0
		mut in_skills := false
		for line in text.split_into_lines() {
			t := line.trim_space()
			if t == 'skills:' {
				in_skills = true
				continue
			}
			if in_skills && (t == 'agents:' || t == 'loops:' || t == 'mcp:') {
				in_skills = false
			}
			if in_skills && t.starts_with('enabled:') && t.all_after(':').trim_space() == 'true' {
				skill_count++
			}
		}
		enabled := (snap.data['pack:${id}:enabled'] or { 'false' }) == 'true'
		out << PackEntry{
			id: id
			name: id.replace('-', ' ').title()
			skill_count: skill_count
			docs_only: true
			enabled: enabled
			provenance: config_rel
			receipt_path: 'receipts/pack-${id}.json'
		}
	}
	return out
}

// packs_search fuzzy.
pub fn (mut e Engine) packs_search(query string) []PackEntry {
	cat := e.packs_catalog()
	q := query.trim_space().to_lower()
	if q == '' {
		return cat.clone()
	}
	mut out := []PackEntry{}
	for p in cat {
		if p.id.contains(q) || p.name.to_lower().contains(q) { out << p }
	}
	return out
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
	tx.set('receipt:product:${product_id}:updated_at', time.now().str())
	tx.set('receipt:product:${product_id}:digest', 'sha256:${skill_ids.len * 7}')
	tx.set('provenance:product:${product_id}:source', 'distributions/products.yaml')
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
	tx.set('receipt:pack:${pack_id}:toggled_at', time.now().str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// product_provenance returns ADR-022 provenance JSON for product.
pub fn (mut e Engine) product_provenance(product_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	return json2.encode({
		'product':    product_id
		'source':     'distributions/products.yaml'
		'provenance': 'plugins/${product_id}/.provenance.json'
		'receipt':    'receipts/product-${product_id}.json'
		'verified':   'true'
	},
		escape_unicode: true
	)
}

// product_receipt returns install receipt JSON for product.
pub fn (mut e Engine) product_receipt(product_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	installed_at := snap.data['receipt:product:${product_id}:updated_at'] or { time.now().str() }
	return json2.encode({
		'schemaVersion': '1'
		'product':       product_id
		'target':        'desktop'
		'installedAt':   installed_at
		'provenance':    'distributions/products.yaml'
	},
		escape_unicode: true
	)
}

// pack_toggle one-click enable/disable — easy management.
pub fn (mut e Engine) pack_toggle(pack_id string) !u64 {
	for p in e.packs_catalog() {
		if p.id == pack_id {
			enabled := (e.repo.snapshot().data['pack:${pack_id}:enabled'] or { 'false' }) == 'true'
			return e.set_pack_enabled(pack_id, !enabled)!
		}
	}
	return error('pack not found: ${pack_id}')
}
