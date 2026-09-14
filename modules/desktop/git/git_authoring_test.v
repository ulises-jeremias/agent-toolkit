module git

// git_authoring_test.v — Slice D git review foundations (issue #1231).
// Behavior-named: read side surfaced honestly, checkout omitted with reasons.

import desktop.theme
import desktop_engine
import os

fn setup_git_vm(tag string) (string, string, &desktop_engine.Engine, &GitViewModel) {
	tmp := os.join_path(os.temp_dir(), 'desk-gitvm-${tag}-${os.getpid()}')
	os.rmdir_all(tmp) or {}
	workspace := os.join_path(tmp, 'workspace')
	os.mkdir_all(os.join_path(workspace, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(workspace, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	eng.switch_workspace(workspace) or { panic(err.msg()) }
	th := theme.default_theme()
	mut vm := new_git_viewmodel(mut eng, th)
	return tmp, workspace, eng, vm
}

fn test_git_review_without_repo_reports_honest_unavailability() {
	tmp, _, mut eng, mut vm := setup_git_vm('no-repo')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	st := vm.status_detail()
	assert st.root != '', 'active workspace root must be reported'
	assert !st.is_repo, 'workspace without .git is not a repo'
	assert !st.backend_available, 'no backend is wired in this build'
	assert vm.changes() == [], 'no backend means no changes — never fixtures'
	assert vm.history().len == 0, 'no backend means no history — never synthetic hashes'
	assert vm.graph().commits.len == 0, 'no backend means no graph lanes'
	assert vm.diff() == [], 'no backend means no diff hunks'
	assert vm.compare() == [], 'no backend means no compare hunks'
}

fn test_git_checkout_stays_omitted_with_reason() {
	tmp, _, mut eng, mut vm := setup_git_vm('checkout-omitted')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	assert !vm.checkout_available(), 'checkout must stay unavailable without a backend'
	assert vm.checkout_blocked().contains('checkout unavailable')
	assert !vm.branches_available(), 'branch names without a backend would be invented'
}

fn test_git_checkout_reason_names_repo_state() {
	tmp, workspace, mut eng, mut vm := setup_git_vm('checkout-repo')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.mkdir_all(os.join_path(workspace, '.git')) or { panic(err.msg()) }
	assert vm.status_detail().is_repo, '.git marker must be detected'
	assert vm.checkout_blocked().contains('no git backend'), 'reason must name the missing backend'
	assert !vm.dirty_tree_blocked(), 'empty change list means a clean tree'
	assert !vm.running_agent_blocked(), 'no jobs means no running agent'
}

fn test_git_guards_observe_real_engine_state() {
	tmp, _, mut eng, mut vm := setup_git_vm('guards')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut repo := eng.state_repo()
	mut tx := repo.begin('authoring-test-git-running')
	tx.set('jobs/agent-9/cmd', 'sleep 30')
	tx.set('jobs/agent-9/status', 'running')
	tx.set('jobs/agent-9/started_at', '1')
	eng.put_transaction(mut tx) or { panic(err.msg()) }
	assert vm.running_agent_blocked(), 'cataloged running job must trip the guard'
}
