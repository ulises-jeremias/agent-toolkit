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

pub fn (vm TargetsViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
