module desktop_engine

import os

pub enum WorkspaceNodeKind {
	dir
	file
	pack
	memory_ledger
}

pub struct WorkspaceNode {
pub:
	path     string
	label    string
	kind     WorkspaceNodeKind
	revision u64
	dirty    bool
}

pub struct MemoryEntry {
pub:
	ts         i64
	actor      string
	entry      string
	project_id string
}

pub fn (mut e Engine) workspace_tree() []WorkspaceNode {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	base := env.toolkit_root
	harness_candidates := [
		os.join_path(base, 'knowledge'),
		os.join_path(base, 'repos'),
		os.join_path(base, 'projects'),
		os.join_path(base, 'packs'),
	]
	mut out := []WorkspaceNode{}
	rev := e.repo.revision_nr()
	for p in harness_candidates {
		if os.is_dir(p) {
			files := os.ls(p) or { []string{} }
			for f in files {
				out << WorkspaceNode{
					path: os.join_path(p, f)
					label: f
					kind: .dir
					revision: rev
				}
			}
			if files.len == 0 {
				out << WorkspaceNode{
					path: p
					label: p.all_after_last('/')
					kind: .dir
					revision: rev
				}
			}
		} else {
			out << WorkspaceNode{
				path: p
				label: p.all_after_last('/')
				kind: .dir
				revision: rev
			}
		}
	}
	snap := e.repo.snapshot()
	for k, _ in snap.data {
		if k.starts_with('memory/') {
			out << WorkspaceNode{
				path: k
				label: k.all_after_last('/')
				kind: .memory_ledger
				revision: snap.revision
			}
		}
	}
	if out.len == 0 {
		out << WorkspaceNode{path: 'knowledge/README.md', label: 'README.md', kind: .file, revision: rev}
	}
	return out
}

pub fn (mut e Engine) memory_ledger(project_id string) []MemoryEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []MemoryEntry{}
	for k, v in snap.data {
		if k.starts_with('memory/') {
			parts := v.split('|')
			if project_id != '' && !v.contains(project_id) {
				continue
			}
			out << MemoryEntry{
				ts: snap.timestamp
				actor: parts[0] or { 'system' }
				entry: v
				project_id: project_id
			}
		}
	}
	if out.len == 0 {
		out << MemoryEntry{ts: snap.timestamp, actor: 'system', entry: 'init memory', project_id: project_id}
	}
	return out
}

pub fn (mut e Engine) open_path_validated(harness_root string, path string) !string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if harness_root == '' || path == '' {
		return error('harness_root or path empty')
	}
	clean := os.real_path(path)
	root_clean := os.real_path(harness_root)
	if !clean.starts_with(root_clean) {
		return error('harness_root_escape')
	}
	return clean
}
