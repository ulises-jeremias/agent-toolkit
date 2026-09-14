module memory

import agent_toolkit_core
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

pub fn new_memory_viewmodel(engine &desktop_engine.Engine, th theme.Theme) &MemoryPalaceViewModel {
	mut vm := &MemoryPalaceViewModel{ engine: engine, theme: th, revision: 0 }
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

// ── Slice D: memory browser authoring (issue #1231) ─────────────────────
// Search/read/add/edit/delete/review/todo through the thin Engine wrappers.
// Storage stays inspectable: every op reads or writes real knowledge/ files
// under the active workspace; nothing is invented. Edit flows through the
// editor-tab save path (open via Engine.open_file_brokered, save via
// Engine.save_editor_tab with its secret guard); delete is a guarded
// whole-file removal below.

// running_agents counts jobs currently executing — the running-agent guard.
pub fn (mut vm MemoryPalaceViewModel) running_agents() int {
	return vm.engine.jobs_by_status(.running).len
}

// dirty_files_total counts uncommitted working-tree entries — the dirty-tree
// guard. Zero means clean; the Engine reports real absence, never guesses.
pub fn (mut vm MemoryPalaceViewModel) dirty_files_total() int {
	return vm.engine.workspace_git_status(vm.workspace_path()).total
}

// workspace_path resolves the browser root: the active workspace, '' when
// none is configured (ops then report unavailable, never cwd-derived).
fn (mut vm MemoryPalaceViewModel) workspace_path() string {
	snap := vm.engine.snapshot()
	return snap.data['recent_workspace'] or { snap.data['workspace_path'] or { '' } }
}

// guard_reason returns the blocking reason for destructive memory ops, or
// '' when the op may proceed. Running agents win over a dirty tree.
pub fn (mut vm MemoryPalaceViewModel) guard_reason() string {
	if vm.running_agents() > 0 {
		return 'an agent is running — wait for it to finish before changing memories'
	}
	if vm.dirty_files_total() > 0 {
		return 'working tree is dirty — save or discard changes before deleting memories'
	}
	return ''
}

// add_entry records a learning, process or todo. Non-destructive: no guard.
pub fn (mut vm MemoryPalaceViewModel) add_entry(entry_type string, title string, content string) agent_toolkit_core.MemoryReport {
	rep := vm.engine.memory_add_entry(vm.workspace_path(), entry_type, title, content)
	vm.refresh()
	return rep
}

// search_report runs the CLI-parity keyword search over knowledge files.
pub fn (mut vm MemoryPalaceViewModel) search_report(query string) agent_toolkit_core.MemoryReport {
	return vm.engine.memory_search_report(vm.workspace_path(), query)
}

// read_entry reads one knowledge file for the browser read pane.
pub fn (mut vm MemoryPalaceViewModel) read_entry(rel_path string) !string {
	return vm.engine.memory_read_file(vm.workspace_path(), rel_path)
}

// delete_entry removes one knowledge file. Guarded: refuses while an agent
// runs or the tree is dirty, so a delete can never race live work.
pub fn (mut vm MemoryPalaceViewModel) delete_entry(rel_path string) !u64 {
	guard := vm.guard_reason()
	if guard != '' {
		return error(guard)
	}
	rev := vm.engine.memory_delete_file(vm.workspace_path(), rel_path)!
	vm.refresh()
	return rev
}

// review_report runs the duplicate/stale/contradiction review.
pub fn (mut vm MemoryPalaceViewModel) review_report(stale_after int, fix bool) agent_toolkit_core.MemoryReport {
	return vm.engine.memory_review_report(vm.workspace_path(), stale_after, fix)
}

// todo_report lists pending (and optionally completed) todos.
pub fn (mut vm MemoryPalaceViewModel) todo_report(show_done bool) agent_toolkit_core.MemoryReport {
	return vm.engine.memory_todo_report(vm.workspace_path(), show_done)
}
