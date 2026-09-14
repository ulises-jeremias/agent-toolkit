module main

import os

// Worktree visibility rail (slice G, #1238): one row per run-owned worktree,
// bound to real run records. Existence is a live filesystem check; a path
// claimed by two owners is flagged shared. No checkout affordance exists:
// there is no proven git write backend, so the rail stays read-only and the
// copy says so.

struct WorktreeRow {
	owner  string // 'swarm <id>' or 'loop <name>/<run>'
	path   string
	exists bool
	shared bool
}

// git_worktree_rows binds [owner, path] entries to filesystem truth. Empty
// paths resolve to '(withheld)' and never to an invented directory.
fn git_worktree_rows(entries [][]string, exists fn (string) bool) []WorktreeRow {
	mut counts := map[string]int{}
	for e in entries {
		if e.len < 2 || e[1] == '' {
			continue
		}
		counts[e[1]]++
	}
	mut out := []WorktreeRow{}
	for e in entries {
		if e.len < 2 {
			continue
		}
		path := if e[1] == '' { '(withheld)' } else { e[1] }
		ok := if e[1] == '' { false } else { exists(e[1]) }
		out << WorktreeRow{
			owner: e[0]
			path: path
			exists: ok
			shared: counts[e[1]] > 1
		}
	}
	return out
}

// workspace_worktree_rows collects one entry per run-owned worktree from
// live Engine records: swarm runs carry their path; loop runs resolve it
// through the validated worktree seam (unresolvable entries are withheld,
// never invented).
fn workspace_worktree_rows(mut app GuiApp) []WorktreeRow {
	mut entries := [][]string{}
	if app.desktop != unsafe { nil } {
		for r in app.desktop.swarm_list() {
			if r.worktree == '' {
				continue
			}
			entries << ['swarm ${r.id}', r.worktree]
		}
		for h in app.desktop.engine_loop_history('') {
			path := app.desktop.engine_loop_worktree_path(h.loop_name, h.run_id) or { '' }
			entries << ['loop ${h.loop_name}/${h.run_id}', path]
		}
	}
	return git_worktree_rows(entries, os.exists)
}

// git_worktree_state is the single status word for a row — never color alone.
fn git_worktree_state(r WorktreeRow) string {
	if r.path == '(withheld)' {
		return 'withheld'
	}
	if r.shared {
		return 'shared'
	}
	if r.exists {
		return 'present'
	}
	return 'missing'
}
