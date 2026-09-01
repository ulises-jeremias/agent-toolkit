module workspace

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct WorkspaceViewModel {
mut:
	engine &desktop_engine.Engine
	nodes  []desktop_engine.WorkspaceNode
	revision u64
}

pub fn new_workspace_viewmodel(mut engine &desktop_engine.Engine) WorkspaceViewModel {
	return WorkspaceViewModel{
		engine: engine
		nodes: engine.workspace_tree()
		revision: engine.revision()
	}
}

pub fn (mut vm WorkspaceViewModel) refresh() {
	vm.nodes = vm.engine.workspace_tree()
	vm.revision = vm.engine.revision()
}

pub fn (vm WorkspaceViewModel) all_nodes() []desktop_engine.WorkspaceNode {
	return vm.nodes.clone()
}

pub fn (mut vm WorkspaceViewModel) memory(project_id string) []desktop_engine.MemoryEntry {
	return vm.engine.memory_ledger(project_id)
}

pub fn (mut vm WorkspaceViewModel) open_path(harness_root string, path string) !string {
	return vm.engine.open_path_validated(harness_root, path)
}

pub fn (mut vm WorkspaceViewModel) on_bus_event(revision u64) bool {
	if revision == vm.revision {
		return false
	}
	vm.refresh()
	return true
}

pub fn (mut vm WorkspaceViewModel) search(project_id string, query string) []desktop_engine.MemoryEntry {
	return vm.engine.memory_search(query, project_id)
}

pub fn (vm WorkspaceViewModel) stats() desktop_engine.WorkspaceStats {
	return vm.engine.workspace_stats()
}

pub fn (mut vm WorkspaceViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm WorkspaceViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
