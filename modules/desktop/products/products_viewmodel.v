module products

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct ProductsViewModel {
mut:
	engine   &desktop_engine.Engine
	products []desktop_engine.ProductEntry
	packs    []desktop_engine.PackEntry
	revision u64
}

pub fn new_products_viewmodel(mut engine &desktop_engine.Engine) ProductsViewModel {
	return ProductsViewModel{
		engine: engine
		products: engine.products_catalog()
		packs: engine.packs_catalog()
		revision: engine.revision()
	}
}

pub fn (mut vm ProductsViewModel) refresh() {
	vm.products = vm.engine.products_catalog()
	vm.packs = vm.engine.packs_catalog()
	vm.revision = vm.engine.revision()
}

pub fn (mut vm ProductsViewModel) update_membership(product_id string, skill_ids []string) !u64 {
	rev := vm.engine.update_product_membership(product_id, skill_ids)!
	vm.refresh()
	return rev
}

pub fn (mut vm ProductsViewModel) set_pack_enabled(pack_id string, enabled bool) !u64 {
	rev := vm.engine.set_pack_enabled(pack_id, enabled)!
	vm.refresh()
	return rev
}

pub fn (mut vm ProductsViewModel) build_preview() string {
	return vm.engine.build_preview()
}

pub fn (mut vm ProductsViewModel) build_diagnostics() []desktop_engine.BuildDiagnostic {
	return vm.engine.build_check()
}

pub fn (vm ProductsViewModel) all_products() []desktop_engine.ProductEntry {
	return vm.products.clone()
}

pub fn (vm ProductsViewModel) all_packs() []desktop_engine.PackEntry {
	return vm.packs.clone()
}

pub fn (mut vm ProductsViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm ProductsViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

// ── Super-potent product/pack management — easy bulk ──
pub fn (mut vm ProductsViewModel) set_products_bulk(ids []string) !u64 {
	rev := vm.engine.onboarding_set_products_bulk(ids)!
	vm.refresh()
	return rev
}

pub fn (vm ProductsViewModel) enabled_packs() []string {
	mut out := []string{}
	snap := vm.engine.snapshot()
	for k, v in snap.data {
		if k.starts_with('pack:') && k.ends_with(':enabled') && v == 'true' {
			out << k.all_after('pack:').all_before(':enabled')
		}
	}
	return out
}

pub fn (mut vm ProductsViewModel) update_membership_bulk(product_id string, skill_ids []string) !u64 {
	return vm.update_membership(product_id, skill_ids)
}

pub fn (vm ProductsViewModel) stats() map[string]int {
	return {
		'products': vm.products.len
		'packs':    vm.packs.len
	}
}
