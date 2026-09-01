module memory

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct MemoryPalaceViewModel {
mut:
	engine   &desktop_engine.Engine
	query    string
	results  []desktop_engine.MemoryRecallResult
	entries  []desktop_engine.MemoryPalaceEntry
	selected int
	revision u64
	theme    theme.Theme
}

pub fn new_memory_viewmodel(mut engine &desktop_engine.Engine, th theme.Theme) &MemoryPalaceViewModel {
	mut vm := &MemoryPalaceViewModel{ engine: engine, theme: th, revision: engine.revision() }
	vm.refresh()
	return vm
}

pub fn (mut vm MemoryPalaceViewModel) refresh() {
	vm.entries = vm.engine.memory_palace_entries()
	if vm.query.trim_space() != '' {
		vm.results = vm.engine.memory_semantic_recall(vm.query, 10)
	} else {
		vm.results = []desktop_engine.MemoryRecallResult{}
	}
	vm.revision = vm.engine.revision()
}

pub fn (mut vm MemoryPalaceViewModel) set_query(q string) {
	vm.query = q
	if q.trim_space() == '' {
		vm.results = []desktop_engine.MemoryRecallResult{}
		vm.selected = 0
		return
	}
	vm.results = vm.engine.memory_semantic_recall(q, 10)
	vm.selected = 0
}

pub fn (vm MemoryPalaceViewModel) query_str() string {
	return vm.query
}

pub fn (vm MemoryPalaceViewModel) results_ranked() []desktop_engine.MemoryRecallResult {
	return vm.results.clone()
}

pub fn (vm MemoryPalaceViewModel) entries_all() []desktop_engine.MemoryPalaceEntry {
	return vm.entries.clone()
}

pub fn (vm MemoryPalaceViewModel) count() int {
	return vm.results.len
}

pub fn (vm MemoryPalaceViewModel) total_entries() int {
	return vm.entries.len
}

pub fn (mut vm MemoryPalaceViewModel) move(delta int) {
	vm.selected += delta
	if vm.selected < 0 {
		vm.selected = 0
	}
	if vm.selected >= vm.results.len {
		vm.selected = if vm.results.len > 0 { vm.results.len - 1 } else { 0 }
	}
}

pub fn (vm MemoryPalaceViewModel) selected_result() ?desktop_engine.MemoryRecallResult {
	if vm.results.len == 0 {
		return none
	}
	if vm.selected < 0 || vm.selected >= vm.results.len {
		return none
	}
	return vm.results[vm.selected]
}

pub fn (vm MemoryPalaceViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm MemoryPalaceViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

pub fn (mut vm MemoryPalaceViewModel) on_bus_event(revision u64) bool {
	if revision == vm.revision {
		return false
	}
	vm.refresh()
	return true
}
