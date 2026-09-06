module desktop_engine

import os

// S7C Git truth gates: no fabricated Git data, honest availability markers,
// and workspace surfaces that never fall back to the toolkit root or cwd.

fn git_truth_engine(tmp string) &Engine {
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return eng
}

// Git APIs never invent changes, history, graphs or diffs — with no
// workspace, a non-repo workspace, or until a read backend exists, results
// are empty and the availability marker says why.
fn test_git_never_fabricates() {
	tmp := os.join_path(os.temp_dir(), 'git-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := git_truth_engine(tmp)
	defer { eng.stop() or {} }

	// no workspace configured
	st := eng.git_workspace_status()
	assert st.root == ''
	assert st.is_repo == false
	assert st.backend_available == false
	assert eng.git_changes().len == 0
	assert eng.git_history(20).len == 0
	assert eng.git_commit_graph(20).commits.len == 0
	assert eng.git_diff('').len == 0
	assert eng.git_compare('HEAD~1', 'HEAD').len == 0

	// a real workspace that is NOT a git repository
	ws := os.join_path(tmp, 'workspace')
	os.mkdir_all(os.join_path(ws, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(ws, 'knowledge', 'README.md'), '# real\n') or { panic(err.msg()) }
	eng.switch_workspace(ws) or { panic(err.msg()) }
	st2 := eng.git_workspace_status()
	assert st2.is_repo == false, 'plain dir must not be reported as a repo'
	assert eng.git_changes().len == 0

	// a directory that contains .git is honestly detected as a repository,
	// but without a read backend no data is invented
	repo := os.join_path(tmp, 'repo-ws')
	os.mkdir_all(os.join_path(repo, '.git')) or { panic(err.msg()) }
	eng.switch_workspace(repo) or { panic(err.msg()) }
	st3 := eng.git_workspace_status()
	assert st3.is_repo == true
	assert st3.backend_available == false
	assert eng.git_changes().len == 0, 'repo without backend must not show fabricated changes'
	assert eng.git_history(20).len == 0, 'no synthetic history even in a real repo'
	assert eng.git_diff('HEAD').len == 0, 'no hand-authored hunks even in a real repo'
}

// Workspace surfaces never fall back to the toolkit root or cwd: with no
// configured workspace the tree is empty, stats are zero and file-tree git
// badges are unknown rather than filename-pattern guesses.
fn test_workspace_surfaces_honest_without_workspace() {
	tmp := os.join_path(os.temp_dir(), 'ws-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := git_truth_engine(tmp)
	defer { eng.stop() or {} }

	assert eng.active_workspace_root() == '', 'no workspace means unavailable, never toolkit root'
	tree := eng.workspace_tree()
	assert tree.len == 0, 'no placeholder nodes without a workspace: got ${tree.len}'
	stats := eng.workspace_stats()
	assert stats.knowledge_files == 0
	assert stats.repos_count == 0
	assert stats.projects_count == 0
	assert stats.packs_count == 0
}
