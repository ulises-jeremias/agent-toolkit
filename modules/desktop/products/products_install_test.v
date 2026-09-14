module products

import os
import desktop_engine

// Library products/packs lifecycle (slice C): provenance + receipt evidence
// and pack preview, with failure paths that never invent catalog facts.

fn new_products_lifecycle_test_engine(suffix string) (string, &desktop_engine.Engine) {
	tmp := os.join_path(os.temp_dir(), 'products-install-${suffix}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut e := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { panic(err.msg()) }
	e.start() or { panic(err.msg()) }
	return tmp, e
}

fn test_product_receipt_absent_is_honest_not_empty() {
	tmp, mut e := new_products_lifecycle_test_engine('receipt')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_products_viewmodel(mut e)
	// the Engine answers absence with an installed:false payload; the
	// viewmodel must translate that to an honest absence, never a bare claim
	msg := vm.receipt_text('definitely-not-a-product-xyz')
	assert msg == 'none — no install receipt covers this product yet', 'absence must be explicit: ${msg}'
}

fn test_product_provenance_names_the_product() {
	tmp, mut e := new_products_lifecycle_test_engine('provenance')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_products_viewmodel(mut e)
	prods := e.products_catalog()
	if prods.len == 0 {
		return
	}
	p := vm.provenance_text(prods[0].id)
	assert p.contains(prods[0].id), 'provenance must name the product it describes: ${p}'
	assert p.contains('distributions/products.yaml'), 'provenance must cite its real source: ${p}'
}

fn test_pack_preview_unknown_pack_explains() {
	tmp, mut e := new_products_lifecycle_test_engine('pack-preview')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_products_viewmodel(mut e)
	msg := vm.pack_preview('definitely-not-a-pack-xyz')
	assert msg.starts_with('cannot preview:'), 'unknown pack must explain, not invent a preview: ${msg}'
}

fn test_pack_preview_names_the_change_without_mutating() {
	tmp, mut e := new_products_lifecycle_test_engine('pack-change')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_products_viewmodel(mut e)
	packs := e.packs_catalog()
	if packs.len == 0 {
		return
	}
	rev_before := e.revision()
	msg := vm.pack_preview(packs[0].id)
	assert msg.contains(packs[0].id), 'preview must name the pack: ${msg}'
	assert msg.contains('will enable') || msg.contains('will disable'), 'preview must name the direction: ${msg}'
	assert e.revision() == rev_before, 'preview must never mutate'
}

fn test_pack_enable_empty_id_fails_without_mutating() {
	tmp, mut e := new_products_lifecycle_test_engine('pack-empty')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_products_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.set_pack_enabled('', true) {
		assert false, 'enabling an empty pack id must fail'
	} else {
		assert err.msg().contains('empty'), 'failure must explain the cause: ${err.msg()}'
	}
	assert e.revision() == rev_before, 'failed enable must not advance the revision'
}

fn test_pack_toggle_unknown_pack_fails_with_recovery() {
	tmp, mut e := new_products_lifecycle_test_engine('pack-toggle')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_products_viewmodel(mut e)
	rev_before := e.revision()
	if _ := vm.engine.pack_toggle('definitely-not-a-pack-xyz') {
		assert false, 'toggling an unknown pack must fail'
	} else {
		assert err.msg().contains('not found'), 'failure must name the cause for recovery: ${err.msg()}'
	}
	assert e.revision() == rev_before
}
