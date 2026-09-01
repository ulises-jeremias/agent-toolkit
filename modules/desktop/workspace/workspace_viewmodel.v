module workspace

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct WorkspaceViewModel {
mut:
	engine          &desktop_engine.Engine
	harness_root    string
	tree            []desktop_engine.FileNode
	flat            []desktop_engine.FileNode
	tabs            []desktop_engine.EditorTab
	active_tab      int
	git_rail        string
	selected_commit string
	compare_base    string
	compare_target  string
	memory_query    string
	revision        u64
	theme           theme.Theme
}

pub fn new_workspace_viewmodel(mut engine &desktop_engine.Engine, harness_root string, th theme.Theme) &WorkspaceViewModel {
	mut vm := &WorkspaceViewModel{
		engine: engine
		harness_root: harness_root
		theme: th
		git_rail: 'CHANGES'
		revision: engine.revision()
	}
	vm.refresh()
	return vm
}

pub fn (mut vm WorkspaceViewModel) refresh() {
	nodes := vm.engine.build_file_tree(vm.harness_root, 3) or { []desktop_engine.FileNode{} }
	vm.tree = nodes
	vm.flat = desktop_engine.file_tree_flatten(nodes)
	vm.revision = vm.engine.revision()
}

pub fn (vm WorkspaceViewModel) file_tree() []desktop_engine.FileNode {
	return vm.flat.clone()
}

pub fn (vm WorkspaceViewModel) file_tree_raw() []desktop_engine.FileNode {
	return vm.tree.clone()
}

pub fn (mut vm WorkspaceViewModel) toggle_expand(path string) bool {
	for i, n in vm.tree {
		if n.path == path && n.kind == .dir {
			vm.tree[i].expanded = !n.expanded
			vm.flat = desktop_engine.file_tree_flatten(vm.tree)
			return true
		}
		if vm.toggle_in_children(mut vm.tree[i].children, path) {
			vm.flat = desktop_engine.file_tree_flatten(vm.tree)
			return true
		}
	}
	return false
}

fn (mut vm WorkspaceViewModel) toggle_in_children(mut children []desktop_engine.FileNode, path string) bool {
	for i, c in children {
		if c.path == path && c.kind == .dir {
			children[i].expanded = !c.expanded
			return true
		}
		if c.kind == .dir && vm.toggle_in_children(mut children[i].children, path) {
			return true
		}
	}
	return false
}

pub fn (mut vm WorkspaceViewModel) open_file(path string) !int {
	tab := vm.engine.open_file_brokered(vm.harness_root, path)!
	for idx, t in vm.tabs {
		if t.path == tab.path {
			vm.active_tab = idx
			return idx
		}
	}
	vm.tabs << tab
	vm.active_tab = vm.tabs.len - 1
	return vm.active_tab
}

pub fn (mut vm WorkspaceViewModel) close_tab(idx int) bool {
	if idx < 0 || idx >= vm.tabs.len {
		return false
	}
	vm.tabs.delete(idx)
	if vm.active_tab >= vm.tabs.len {
		vm.active_tab = if vm.tabs.len > 0 { vm.tabs.len - 1 } else { 0 }
	}
	return true
}

pub fn (mut vm WorkspaceViewModel) set_active_tab(idx int) bool {
	if idx < 0 || idx >= vm.tabs.len {
		return false
	}
	vm.active_tab = idx
	return true
}

pub fn (vm WorkspaceViewModel) tabs_count() int {
	return vm.tabs.len
}

pub fn (vm WorkspaceViewModel) active_tab_index() int {
	return vm.active_tab
}

pub fn (vm WorkspaceViewModel) active_tab_content() string {
	if vm.tabs.len == 0 {
		return ''
	}
	if vm.active_tab < 0 || vm.active_tab >= vm.tabs.len {
		return ''
	}
	return vm.tabs[vm.active_tab].content
}

pub fn (vm WorkspaceViewModel) active_tab_syntax() string {
	if vm.tabs.len == 0 {
		return 'txt'
	}
	if vm.active_tab < 0 || vm.active_tab >= vm.tabs.len {
		return 'txt'
	}
	return vm.tabs[vm.active_tab].syntax
}

pub fn (vm WorkspaceViewModel) syntax_tokens() [][]desktop_engine.SyntaxToken {
	if vm.tabs.len == 0 {
		return [][]desktop_engine.SyntaxToken{}
	}
	return desktop_engine.highlight_syntax(vm.active_tab_content(), vm.active_tab_syntax())
}

pub fn (mut vm WorkspaceViewModel) set_git_rail(rail string) {
	if rail in ['CHANGES', 'HISTORY', 'COMPARE'] {
		vm.git_rail = rail
	}
}

pub fn (vm WorkspaceViewModel) git_rail_active() string {
	return vm.git_rail
}

pub fn (mut vm WorkspaceViewModel) git_changes() []desktop_engine.GitChange {
	return vm.engine.git_changes()
}

pub fn (mut vm WorkspaceViewModel) git_history() []desktop_engine.GitCommit {
	return vm.engine.git_history(20)
}

pub fn (mut vm WorkspaceViewModel) git_graph() desktop_engine.CommitGraph {
	return vm.engine.git_commit_graph(20)
}

pub fn (mut vm WorkspaceViewModel) git_diff_for_active() []desktop_engine.DiffHunk {
	if vm.git_rail == 'CHANGES' {
		return vm.engine.git_diff('')
	}
	if vm.selected_commit != '' {
		return vm.engine.git_diff(vm.selected_commit)
	}
	return vm.engine.git_diff('')
}

pub fn (mut vm WorkspaceViewModel) git_compare() []desktop_engine.DiffHunk {
	base := if vm.compare_base == '' { 'HEAD~1' } else { vm.compare_base }
	tgt := if vm.compare_target == '' { 'HEAD' } else { vm.compare_target }
	return vm.engine.git_compare(base, tgt)
}

pub fn (mut vm WorkspaceViewModel) select_commit(hash string) {
	vm.selected_commit = hash
}

pub fn (mut vm WorkspaceViewModel) set_memory_query(q string) {
	vm.memory_query = q
}

pub fn (vm WorkspaceViewModel) memory_query_str() string {
	return vm.memory_query
}

pub fn (mut vm WorkspaceViewModel) memory_recall() []desktop_engine.MemoryRecallResult {
	if vm.memory_query.trim_space() == '' {
		return []desktop_engine.MemoryRecallResult{}
	}
	return vm.engine.memory_semantic_recall(vm.memory_query, 10)
}

pub fn (vm WorkspaceViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm WorkspaceViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

pub fn (mut vm WorkspaceViewModel) on_bus_event(revision u64) bool {
	if revision == vm.revision {
		return false
	}
	vm.refresh()
	return true
}

// ── Super-potent workspace init + persona bootstrap — Engine wiring ──
pub fn (mut vm WorkspaceViewModel) init_workspace(target string) !u64 {
	rev := vm.engine.onboarding_ensure_workspace(target)!
	vm.harness_root = target
	vm.refresh()
	return rev
}

pub fn (mut vm WorkspaceViewModel) init_with_templates(target string, with_personas bool) !u64 {
	rev := vm.engine.workspace_init_with_templates(target, with_personas)!
	vm.harness_root = target
	vm.refresh()
	return rev
}

pub fn (mut vm WorkspaceViewModel) bootstrap_personas() !u64 {
	rev := vm.engine.onboarding_ensure_personas(vm.harness_root)!
	vm.refresh()
	return rev
}

pub fn (vm WorkspaceViewModel) personas() []string {
	st := vm.engine.onboarding_status(vm.harness_root)
	if st.persona_count > 0 {
		mut all := ['architect', 'implementer', 'researcher', 'reviewer']
		if st.persona_count < all.len {
			return all[..st.persona_count].clone()
		}
		return all.clone()
	}
	return []string{}
}

pub fn (vm WorkspaceViewModel) onboarding_status_view() desktop_engine.OnboardingStatus {
	return vm.engine.onboarding_status(vm.harness_root)
}

pub fn (mut vm WorkspaceViewModel) set_harness_root(path string) {
	vm.harness_root = path
	vm.refresh()
}

// ── Super-potent easy management — search, recent, stats, git status ──
pub fn (mut vm WorkspaceViewModel) search(query string) []desktop_engine.FileNode {
	return vm.engine.workspace_search(vm.harness_root, query)
}

pub fn (mut vm WorkspaceViewModel) recent(limit int) []desktop_engine.FileNode {
	return vm.engine.workspace_recent(vm.harness_root, limit)
}

pub fn (vm WorkspaceViewModel) stats() desktop_engine.WorkspaceStats {
	return vm.engine.workspace_stats()
}

pub fn (vm WorkspaceViewModel) git_status() desktop_engine.GitStatusSummary {
	return vm.engine.workspace_git_status(vm.harness_root)
}

pub fn (mut vm WorkspaceViewModel) save_active_tab() !u64 {
	if vm.tabs.len == 0 {
		return error('no active tab')
	}
	tab := vm.tabs[vm.active_tab]
	return vm.engine.save_editor_tab(tab)
}
