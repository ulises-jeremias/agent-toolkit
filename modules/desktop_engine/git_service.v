module desktop_engine

import os

pub struct GitCommit {
pub:
	hash      string
	message   string
	author    string
	timestamp i64
	parents   []string
	branch    string
	refs      []string
}

pub struct GitChange {
pub:
	path   string
	status string
	staged bool
	hunks  int
}

pub enum DiffLineKind {
	context
	addition
	deletion
	header
}

pub struct DiffLine {
pub:
	kind   DiffLineKind
	text   string
	old_no int
	new_no int
}

pub struct DiffHunk {
pub mut:
	file      string
	old_start int
	old_count int
	new_start int
	new_count int
	lines     []DiffLine
}

pub struct CommitGraph {
pub:
	commits  []GitCommit
	lanes    []int
	max_lane int
}

// GitWorkspaceStatus is the honest availability marker for the Git surface.
// Git data comes only from a real read backend over the active workspace
// repository; until that backend exists, is_repo may be true while
// backend_available is false and all Git data APIs return empty results.
pub struct GitWorkspaceStatus {
pub:
	root              string // active workspace root ('' when none configured)
	is_repo            bool // a real .git directory exists under root
	backend_available  bool // a real Git read backend is wired
}

// git_workspace_root returns the active workspace root from configuration
// truth (recent_workspace). The bundled toolkit root is never used as a
// workspace: an embedded toolkit has no filesystem workspace.
pub fn (mut e Engine) git_workspace_root() string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	return snap.data['recent_workspace'] or { '' }
}

// git_workspace_status reports the real availability of Git data for the
// active workspace: whether a repository exists and whether a read backend
// is wired. It never fabricates repository state.
pub fn (mut e Engine) git_workspace_status() GitWorkspaceStatus {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	root := e.repo.snapshot().data['recent_workspace'] or { '' }
	if root == '' {
		return GitWorkspaceStatus{ root: '', is_repo: false, backend_available: false }
	}
	is_repo := os.is_dir(os.join_path(root, '.git'))
	return GitWorkspaceStatus{ root: root, is_repo: is_repo, backend_available: false }
}

// git_changes returns the working-tree changes of the active workspace
// repository. With no workspace repository or until a real Git read backend
// is wired, the result is empty — real absence, never seeded fixtures.
// Use git_workspace_status() to distinguish "no changes" from "unavailable".
pub fn (mut e Engine) git_changes() []GitChange {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	return []GitChange{}
}

// git_history returns the commit history of the active workspace repository.
// Empty until a real backend exists — no synthetic hashes, authors or dates.
pub fn (mut e Engine) git_history(limit int) []GitCommit {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	_ = limit
	return []GitCommit{}
}

// git_commit_graph returns the commit graph of the active workspace
// repository. Empty until a real backend exists — no synthetic lanes.
pub fn (mut e Engine) git_commit_graph(limit int) CommitGraph {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	_ = limit
	return CommitGraph{
		commits: []GitCommit{}
		lanes: []int{}
		max_lane: 0
	}
}

// git_diff returns the diff hunks for a target in the active workspace
// repository. Empty until a real backend exists — no hand-authored hunks.
pub fn (mut e Engine) git_diff(target string) []DiffHunk {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	_ = target
	return []DiffHunk{}
}

// git_compare returns the diff between two refs. Empty until a real
// backend exists — no relabeled fixture diffs.
pub fn (mut e Engine) git_compare(base string, target string) []DiffHunk {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	_ = base
	_ = target
	return []DiffHunk{}
}
