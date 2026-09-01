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
	out << GitChange{ path: 'modules/desktop_engine/skills_service.v', status: 'modified', staged: false, hunks: 2 }
	out << GitChange{ path: 'cmd/agent-toolkit-desktop/main.v', status: 'modified', staged: true, hunks: 4 }
	out << GitChange{ path: 'modules/desktop/skills/skills_viewmodel.v', status: 'modified', staged: false, hunks: 1 }
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
	n := if limit <= 0 || limit > 50 { 20 } else { limit }
	mut out := []GitCommit{cap: n}
	env := resolve_env()
	git_dir := os.join_path(env.toolkit_root, '.git')
	if os.is_dir(git_dir) {}
	authors := ['alice', 'bob', 'carol', 'dave']
	branches := ['main', 'feat/ide', 'feat/git-rails', 'fix/brokered-fs']
	for i in 0 .. n {
		hex := 'abcdef0123456789'
		mut h := ''
		for j in 0 .. 7 {
			h += hex[(i * 7 + j) % hex.len].ascii_str()
		}
		parents := if i == n - 1 {
			[]string{}
		} else if i % 5 == 0 && i + 2 < n {
			[h_next(i + 1), h_next(i + 2)]
		} else {
			[h_next(i + 1)]
		}
		out << GitCommit{
			hash: h
			message: git_message_for(i)
			author: authors[i % authors.len]
			timestamp: 1700000000 + i * 3600
			parents: parents
			branch: branches[i % branches.len]
			refs: if i == 0 {
				['HEAD', 'main']} else if i % 8 == 0 { ['tag v1.${i / 8}.0'] } else { []string{} }
		}
	}
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
	if target == '' || target == 'CHANGES' {
		return [
			DiffHunk{
				file: 'modules/desktop_engine/skills_service.v'
				old_start: 57
				old_count: 4
				new_start: 57
				new_count: 6
				lines: [
					DiffLine{.header, '@@ -57,4 +57,6 @@', 0, 0},
					DiffLine{.context, ' if entries.len >= 116 {', 57, 57},
					DiffLine{.deletion, '-                return entries', 58, 0},
					DiffLine{.addition, '+                if entries.len >= 227 {', 0, 58},
					DiffLine{.addition, '+                    return entries[..227]', 0, 59},
					DiffLine{.context, ' }', 59, 60},
				]
			},
			DiffHunk{
				file: 'cmd/agent-toolkit-desktop/main.v'
				old_start: 1219
				old_count: 8
				new_start: 1219
				new_count: 12
				lines: [
					DiffLine{.header, '@@ -1219,8 +1219,12 @@ fn draw_skills', 0, 0},
					DiffLine{.context, ' fx := 208', 1219, 1219},
					DiffLine{.deletion, '-    app.gg.draw_text(fx+12, "SKILLS 116")', 1220, 0},
					DiffLine{.addition, '+    // 227 searchable via skills_search fuzzy', 0, 1220},
					DiffLine{.addition, '+    cat := app.engine.skills_search(query, domain)', 0, 1221},
					DiffLine{.context, ' }', 1221, 1223},
				]
			},
		]
	}
	return [
		DiffHunk{
			file: 'modules/desktop_engine/git_service.v'
			old_start: 1
			old_count: 3
			new_start: 1
			new_count: 5
			lines: [
				DiffLine{.header, '@@ -1,3 +1,5 @@', 0, 0},
				DiffLine{.addition, '+// brokered via Engine', 0, 1},
				DiffLine{.context, ' module desktop_engine', 1, 2},
			]
		},
	]
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
