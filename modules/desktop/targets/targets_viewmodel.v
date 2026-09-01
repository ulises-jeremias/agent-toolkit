module targets

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct TargetsViewModel {
mut:
	engine &desktop_engine.Engine
	matrix []desktop_engine.TargetEntry
	revision u64
}

pub fn new_targets_viewmodel(mut engine &desktop_engine.Engine) TargetsViewModel {
	return TargetsViewModel{
		engine: engine
		matrix: engine.targets()
		revision: engine.revision()
	}
}

pub fn (mut vm TargetsViewModel) refresh() {
	vm.matrix = vm.engine.targets()
	vm.revision = vm.engine.revision()
}

pub fn (vm TargetsViewModel) all_targets() []desktop_engine.TargetEntry {
	return vm.matrix.clone()
}

pub fn (mut vm TargetsViewModel) set_enabled(target_id string, enabled bool) !u64 {
	rev := vm.engine.set_target_enabled(target_id, enabled)!
	vm.refresh()
	return rev
}

pub fn (mut vm TargetsViewModel) preview_diff(before []string, after []string) desktop_engine.TargetDiff {
	return vm.engine.diff(before, after)
}

pub fn (mut vm TargetsViewModel) install(selected []string) !u64 {
	return vm.engine.install(selected)
}

pub fn (mut vm TargetsViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}


// ── super-potent: preview, dry_run, receipts, provenance, toggle, stats ──
pub fn (vm TargetsViewModel) preview(targets []string) desktop_engine.TargetDiff {
	return vm.engine.install_preview(targets)
}

pub fn (vm TargetsViewModel) dry_run(targets []string) string {
	return vm.engine.install_dry_run(targets)
}

pub fn (vm TargetsViewModel) receipts() []desktop_engine.InstallReceiptInfo {
	return vm.engine.list_install_receipts()
}

pub fn (vm TargetsViewModel) receipt_json(target_id string) string {
	return vm.engine.install_receipt_json(target_id)
}

pub fn (mut vm TargetsViewModel) toggle(target_id string) !u64 {
	rev := vm.engine.toggle_target(target_id)!
	vm.refresh()
	return rev
}

pub fn (mut vm TargetsViewModel) install_with_options(opts desktop_engine.InstallOptionsEngine) !u64 {
	rev := vm.engine.install_with_options(opts)!
	vm.refresh()
	return rev
}

pub fn (vm TargetsViewModel) verify() []desktop_engine.BuildDiagnostic {
	return vm.engine.verify_install_receipts()
}

pub fn (vm TargetsViewModel) detailed_paths() string {
	return vm.engine.resolve_paths_detailed()
}


pub fn (vm TargetsViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

// ── Super-potent bulk target/product management ──
pub fn (mut vm TargetsViewModel) set_targets_bulk(ids []string) !u64 {
	rev := vm.engine.onboarding_set_targets_bulk(ids)!
	vm.refresh()
	return rev
}

pub fn (vm TargetsViewModel) enabled_targets() []string {
	mut out := []string{}
	for t in vm.matrix {
		if t.enabled {
			out << t.id
		}
	}
	return out
}

pub fn (mut vm TargetsViewModel) diff_preview_bulk(before []string, after []string) desktop_engine.TargetDiff {
	return vm.engine.diff(before, after)
}

pub fn (vm TargetsViewModel) products_catalog() []desktop_engine.ProductEntry {
	return vm.engine.products_catalog()
}

pub fn (vm TargetsViewModel) packs_catalog() []desktop_engine.PackEntry {
	return vm.engine.packs_catalog()
}
