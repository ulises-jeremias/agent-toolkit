module desktop

// facade_workspace.v — Slice D workspace authoring facade (issue #1231).
//
// Composition root for the workspace/memory/git authoring slice: it owns
// one memory browser, one file-tree workspace viewmodel and one git review
// viewmodel over a single Engine, plus the dirty-tree + running-agent
// guards every destructive op consults. Native V only; the Engine stays
// the authority (no CLI shell-out, no invented memories, read-only stays
// read-only until a write path is proven).

import agent_toolkit_core
import desktop.git
import desktop.memory
import desktop.theme
import desktop.workspace
import desktop_engine

// RunBindingSummary is the run/workspace binding: live agents beside the
// bound project. Counts come from the Engine job catalog — real absence,
// never guesses.
pub struct RunBindingSummary {
pub:
	running         int
	current_project string
	recent_projects []string
}

// WorkspaceAuthoringFacade composes the three slice-D viewmodels.
pub struct WorkspaceAuthoringFacade {
mut:
	engine &desktop_engine.Engine
	mem    &memory.MemoryPalaceViewModel
	ws     &workspace.WorkspaceViewModel
	gv     &git.GitViewModel
}

// new_workspace_authoring_facade builds the facade over one Engine. The
// harness root binds the file tree; '' leaves it unbound until set.
//
// The Engine travels as a plain non-mut reference end to end: forwarding
// a `mut &Engine` param through another `mut` argument re-takes its
// address (V codegen takes `&e` for param aliases but passes call-result
// locals through — the former corrupts every downstream Engine call).
pub fn new_workspace_authoring_facade(engine &desktop_engine.Engine, harness_root string, th theme.Theme) &WorkspaceAuthoringFacade {
	return &WorkspaceAuthoringFacade{
		engine: engine
		mem: memory.new_memory_viewmodel(engine, th)
		ws: workspace.new_workspace_viewmodel(engine, harness_root, th)
		gv: git.new_git_viewmodel(engine, th)
	}
}

// refresh re-reads all three viewmodels from the Engine.
pub fn (mut f WorkspaceAuthoringFacade) refresh() {
	f.mem.refresh()
	f.ws.refresh()
}

// authoring_guard_reason is the shared destructive-op guard: a running
// agent blocks first (live work must never race a delete), then a dirty
// tree. Pure over counts so the ordering is unit-testable; the Engine
// backed guard_reason below supplies the real counts.
pub fn authoring_guard_reason(running int, dirty_total int) string {
	if running > 0 {
		return 'an agent is running — wait for it to finish before changing the workspace'
	}
	if dirty_total > 0 {
		return 'working tree is dirty — save or discard changes first'
	}
	return ''
}

// guard_reason evaluates the shared guard against live Engine state.
pub fn (mut f WorkspaceAuthoringFacade) guard_reason() string {
	running := f.engine.jobs_by_status(.running).len
	dirty := f.engine.workspace_git_status(f.workspace_root()).total
	return authoring_guard_reason(running, dirty)
}

// workspace_root resolves the bound file-tree root.
pub fn (vm WorkspaceAuthoringFacade) workspace_root() string {
	return vm.ws.harness_root_path()
}

// set_workspace_root rebinds the file tree to another harness root.
pub fn (mut f WorkspaceAuthoringFacade) set_workspace_root(path string) {
	f.ws.set_harness_root(path)
}

// run_binding reports live agents beside the bound project.
pub fn (mut f WorkspaceAuthoringFacade) run_binding() RunBindingSummary {
	return RunBindingSummary{
		running: f.engine.jobs_by_status(.running).len
		current_project: f.engine.current_project()
		recent_projects: f.engine.recent_projects()
	}
}

// add_memory records a learning, process or todo (non-destructive).
pub fn (mut f WorkspaceAuthoringFacade) add_memory(entry_type string, title string, content string) agent_toolkit_core.MemoryReport {
	return f.mem.add_entry(entry_type, title, content)
}

// delete_memory removes one knowledge file behind both guards.
pub fn (mut f WorkspaceAuthoringFacade) delete_memory(rel_path string) !u64 {
	guard := f.guard_reason()
	if guard != '' {
		return error(guard)
	}
	return f.mem.delete_entry(rel_path)
}

// review_memory runs the duplicate/stale/contradiction review.
pub fn (mut f WorkspaceAuthoringFacade) review_memory(stale_after int, fix bool) agent_toolkit_core.MemoryReport {
	return f.mem.review_report(stale_after, fix)
}

// list_todos lists pending (and optionally completed) todos.
pub fn (mut f WorkspaceAuthoringFacade) list_todos(show_done bool) agent_toolkit_core.MemoryReport {
	return f.mem.todo_report(show_done)
}

// close_tab_guarded closes a file tab but keeps unsaved changes unless
// forced — the dirty-tab guard.
pub fn (mut f WorkspaceAuthoringFacade) close_tab_guarded(idx int, force bool) !bool {
	return f.ws.close_tab_guarded(idx, force)
}

// switch_project rebinds the workspace to another project id.
pub fn (mut f WorkspaceAuthoringFacade) switch_project(project_id string) !desktop_engine.ProjectSwitchResult {
	return f.ws.switch_project(project_id)
}

// checkout_blocked explains why git checkout stays omitted: read-only
// stays read-only until a backend proves a write path.
pub fn (mut f WorkspaceAuthoringFacade) checkout_blocked() string {
	return f.gv.checkout_blocked()
}
