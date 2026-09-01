module git

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct GitViewModel {
mut:
	engine         &desktop_engine.Engine
	rail           string
	selected_hash  string
	compare_base   string
	compare_target string
	revision       u64
	theme          theme.Theme
}

pub fn new_git_viewmodel(mut engine &desktop_engine.Engine, th theme.Theme) &GitViewModel {
	return &GitViewModel{ engine: engine, rail: 'CHANGES', revision: engine.revision(), theme: th }
}

pub fn (mut vm GitViewModel) set_rail(rail string) {
	if rail in ['CHANGES', 'HISTORY', 'COMPARE'] {
		vm.rail = rail
	}
}

pub fn (vm GitViewModel) rail_active() string {
	return vm.rail
}

pub fn (mut vm GitViewModel) select_commit(hash string) {
	vm.selected_hash = hash
}

pub fn (vm GitViewModel) selected() string {
	return vm.selected_hash
}

pub fn (mut vm GitViewModel) changes() []desktop_engine.GitChange {
	return vm.engine.git_changes()
}

pub fn (mut vm GitViewModel) history() []desktop_engine.GitCommit {
	return vm.engine.git_history(20)
}

pub fn (mut vm GitViewModel) graph() desktop_engine.CommitGraph {
	return vm.engine.git_commit_graph(20)
}

pub fn (mut vm GitViewModel) diff() []desktop_engine.DiffHunk {
	if vm.rail == 'CHANGES' {
		return vm.engine.git_diff('')
	}
	if vm.selected_hash != '' {
		return vm.engine.git_diff(vm.selected_hash)
	}
	return vm.engine.git_diff('')
}

pub fn (mut vm GitViewModel) compare() []desktop_engine.DiffHunk {
	base := if vm.compare_base == '' { 'HEAD~1' } else { vm.compare_base }
	tgt := if vm.compare_target == '' { 'HEAD' } else { vm.compare_target }
	return vm.engine.git_compare(base, tgt)
}

pub fn (mut vm GitViewModel) set_compare(base string, target string) {
	vm.compare_base = base
	vm.compare_target = target
}

pub fn (vm GitViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm GitViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

pub fn (mut vm GitViewModel) on_bus_event(revision u64) bool {
	if revision == vm.revision {
		return false
	}
	vm.revision = vm.engine.revision()
	return true
}
