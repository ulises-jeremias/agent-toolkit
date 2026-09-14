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

// ── Slice D: git review foundations (issue #1231) ───────────────────────
// The read side is surfaced fully: status/changed/diff/history/branches
// visibility comes from the Engine wrappers above, which return real
// absence (empty) until a git read backend exists — never fixtures.
// Guarded checkout, branch listing and ahead/behind stay OMITTED: the
// backend proves no support (GitWorkspaceStatus.backend_available is
// always false; no checkout/branch fns exist), and read-only stays
// read-only until a write path is proven. No stage/commit/push.

// status_detail reports root/repo/backend availability for the active
// workspace — the honest marker behind every rail.
pub fn (mut vm GitViewModel) status_detail() desktop_engine.GitWorkspaceStatus {
	return vm.engine.git_workspace_status()
}

// worktrees surfaces worktree visibility: the known-workspace discovery
// list (active first), so parallel checkouts stay visible in review.
pub fn (mut vm GitViewModel) worktrees() []desktop_engine.KnownWorkspace {
	return vm.engine.known_workspaces()
}

// checkout_available is false until a real git backend proves checkout
// support. There is no guarded checkout to call — see checkout_blocked.
pub fn (vm GitViewModel) checkout_available() bool {
	return false
}

// checkout_blocked explains why checkout is omitted: unguarded branch
// switches over a dirty tree or beside a running agent would lose work.
pub fn (vm GitViewModel) checkout_blocked() string {
	st := vm.engine.git_workspace_status()
	if st.root == '' {
		return 'checkout unavailable: no active workspace'
	}
	if !st.is_repo {
		return 'checkout unavailable: active workspace is not a git repository'
	}
	return 'checkout unavailable: no git backend is wired in this build'
}

// branches_available is false: branch names without a backend would be
// invented, and the desktop never invents repository state.
pub fn (vm GitViewModel) branches_available() bool {
	return false
}

// dirty_tree_blocked reports whether the working tree has uncommitted
// entries — the guard a future checkout must consult first.
pub fn (mut vm GitViewModel) dirty_tree_blocked() bool {
	return vm.engine.git_changes().len > 0
}

// running_agent_blocked reports whether an agent is executing — the guard
// a future checkout must consult alongside the dirty tree.
pub fn (mut vm GitViewModel) running_agent_blocked() bool {
	return vm.engine.jobs_by_status(.running).len > 0
}
