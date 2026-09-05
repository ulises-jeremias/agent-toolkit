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

pub fn (mut e Engine) git_changes() []GitChange {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []GitChange{}
	if 'dirty_files' in snap.data {
		extra := snap.data['dirty_files'].split(',').map(it.trim_space()).filter(it != '')
		for p in extra {
			if p == '' {
				continue
			}
			mut found := false
			for c in out {
				if c.path == p {
					found = true
					break
				}
			}
			if !found { out << GitChange{ path: p, status: 'modified', staged: false, hunks: 1 } }
		}
	}
	if 'watcher_last_path' in snap.data {
		wp := snap.data['watcher_last_path']
		if wp != '' && wp.contains('.v') {
			out << GitChange{ path: wp.all_after(snap.data['toolkit_root'] or { '' }), status: 'untracked', staged: false, hunks: 0 }
		}
	}
	return out
}

pub fn (mut e Engine) git_history(limit int) []GitCommit {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut out := []GitCommit{cap: if limit > 0 && limit <= 50 { limit } else { 0 }}
	env := resolve_env()
	git_dir := os.join_path(env.toolkit_root, '.git')
	if !os.is_dir(git_dir) {
		return out
	}
	// Git history is populated by the workspace adapter when a repository is
	// explicitly selected. Do not invent commits for a project without a
	// connected adapter.
	return out
}

fn h_next(i int) string {
	hex := 'abcdef0123456789'
	mut h := ''
	for j in 0 .. 7 {
		h += hex[(i * 7 + j) % hex.len].ascii_str()
	}
	return h
}

fn git_message_for(i int) string {
	msgs := [
		'feat(desktop): file-tree IDE + git rails',
		'feat(skills): 227 catalog searchable',
		'feat(memory): palace semantic recall',
		'fix(fs): brokered harness_root escape guard',
		'feat(editor): syntax tabs V/md/yaml',
		'feat(git): CHANGES/HISTORY/COMPARE + commit graph',
		'feat(diff): hunk view with lanes',
		'docs: update IDE rails',
		'refactor: draw_skills/draw_workspace potent',
		'chore: bump to 227',
	]
	return msgs[i % msgs.len] + ' (#${1000 + i})'
}

pub fn (mut e Engine) git_commit_graph(limit int) CommitGraph {
	commits := e.git_history(limit)
	mut lanes := []int{len: commits.len}
	mut max_lane := 0
	for i, c in commits {
		mut lane := i % 3
		if c.parents.len > 1 {
			lane = 1
		}
		lanes[i] = lane
		if lane > max_lane {
			max_lane = lane
		}
	}
	return CommitGraph{ commits: commits, lanes: lanes, max_lane: max_lane }
}

pub fn (mut e Engine) git_diff(target string) []DiffHunk {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	// Diff data is supplied by the selected workspace adapter. Returning an
	// empty result is safer than presenting a diff for files that were never
	// changed.
	return []DiffHunk{}
}

pub fn (mut e Engine) git_compare(base string, target string) []DiffHunk {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if base == '' || target == '' {
		return e.git_diff('')
	}
	mut hunks := e.git_diff('')
	for mut h in hunks {
		h.file = h.file + ' (${base}..${target})'
	}
	return hunks
}
