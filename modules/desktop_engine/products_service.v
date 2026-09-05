module desktop_engine

import time
import x.json2
import crypto.sha256 as crypto_sha256

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
			mut cur_skills := []string{}
			mut in_skill_list := false
			mut in_products := false
			for line in lines {
				t := line.trim_space()
				if t == 'products:' {
					in_products = true
					continue
				}
				if in_products && t.starts_with('- id:') {
					if cur.id != '' {
						cur.skill_ids = cur_skills.clone()
						out << cur
					}
					cur = ProductEntry{ id: t.all_after(':').trim_space(), provenance: 'distributions/products.yaml' }
					cur_skills = []string{}
					in_skill_list = false
				} else if in_products && t.starts_with('name:') && cur.id != '' && cur.name == '' {
					cur.name = t.all_after(':').trim_space().trim('"')
				} else if in_products && t.starts_with('description:') && cur.id != '' && cur.description == '' {
					cur.description = t.all_after(':').trim_space().trim('"')
				} else if in_products && t == 'skills:' && cur.id != '' {
					in_skill_list = true
				} else if in_products && (t == 'agents:' || t == 'hooks:' || t == 'mcp:') {
					in_skill_list = false
				} else if in_products && in_skill_list && t.starts_with('- ') && cur.id != '' {
					cur_skills << t.all_after('-').trim_space()
				}
			}
			if cur.id != '' {
				cur.skill_ids = cur_skills.clone()
				out << cur
			}
			if out.len > 0 {
				version := data_file_read(env, 'VERSION') or { '' }
				for i in 0 .. out.len {
					out[i].version = version.trim_space()
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

pub fn (mut e Engine) packs_catalog() []PackEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	return [
		PackEntry{ id: 'docs-only', name: 'Docs Only', skill_count: 5, docs_only: true, provenance: 'packs/docs-only/config.yaml', receipt_path: 'receipts/pack-docs-only.json' },
		PackEntry{ id: 'core', name: 'Core', skill_count: 6, docs_only: true, provenance: 'packs/core/config.yaml', receipt_path: 'receipts/pack-core.json' },
		PackEntry{ id: 'design', name: 'Design', skill_count: 12, docs_only: true, provenance: 'packs/design/config.yaml', receipt_path: 'receipts/pack-design.json' },
		PackEntry{ id: 'delivery', name: 'Delivery', skill_count: 10, docs_only: true, provenance: 'packs/delivery/config.yaml', receipt_path: 'receipts/pack-delivery.json' },
		PackEntry{ id: 'forge', name: 'Forge', skill_count: 8, docs_only: true, provenance: 'packs/forge/config.yaml', receipt_path: 'receipts/pack-forge.json' },
		PackEntry{ id: 'security', name: 'Security', skill_count: 7, docs_only: true, provenance: 'packs/security/config.yaml', receipt_path: 'receipts/pack-security.json' },
		PackEntry{ id: 'full', name: 'Full', skill_count: 116, docs_only: true, provenance: 'packs/full/config.yaml', receipt_path: 'receipts/pack-full.json' },
	]
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
	tx.set('receipt:product:${product_id}:digest', crypto_sha256.hexhash(skill_ids.join(',')))
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
	env := resolve_env()
	source_exists := data_file_exists(env, 'distributions/products.yaml')
	return json2.encode({
		'product':    product_id
		'source':     'distributions/products.yaml'
		'provenance': 'plugins/${product_id}/.provenance.json'
		'receipt':    'receipts/product-${product_id}.json'
		'verified':   if source_exists { 'true' } else { 'false' }
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
	installed_at := snap.data['receipt:product:${product_id}:updated_at'] or { '' }
	return json2.encode({
		'schemaVersion': '1'
		'product':       product_id
		'target':        'desktop'
		'installed':     if installed_at != '' { 'true' } else { 'false' }
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
