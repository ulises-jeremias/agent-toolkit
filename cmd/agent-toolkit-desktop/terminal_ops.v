module main

import ghostty
import pty as pty_mod

// terminal_ops — WS3 Terminal+ops: pooled PTY slots, owner rule, spawn
// queue, control-char strip, kanban read/overlay, no-blank view switching.
//
// Paper Co identity: the desktop is a paper-operations floor, not a generic
// emulator. Every helper below reads only real state (app.sessions maintained
// by the per-frame PTY drain, app.kanban populated from workspace operations)
// and never fabricates sessions, cards, or output. The Engine remains the
// authority for jobs/handoffs/logs; this layer only pools, routes, strips,
// and overlays what the Engine and the PTY layer already reported.
//
// Deliberately a new file (no edits to existing views): sibling workstreams
// share main.v, so the ops layer lives here and view/input call sites adopt
// terminal_resolve_view / terminal_session_accepts / terminal_spawn_pooled
// as the follow-up wiring.

// terminal_pool_max bounds live PTY sessions: one pooled slot per agent
// family the floor actually multiplexes. Spawning past this enqueues.
const terminal_pool_max = 4
// terminal_queue_max bounds the pending-spawn queue; beyond it new requests
// are refused loudly (false) instead of growing without bound.
const terminal_queue_max = 8
// terminal_overlay_max caps kanban overlay lines so the strip never floods.
const terminal_overlay_max = 5

// Pending spawn requests (agent ids) thread through as an explicit `mut queue`
// parameter — the repo builds without -enable-globals, so no module-level
// state. The wiring call site owns storage (GuiApp field or run-local);
// drained by terminal_drain_queue as slots free up.

// terminal_live_count — pool occupancy: sessions that are neither exited
// (child gone, observed by the per-frame drain) nor dismissed by the user.
// Liveness probes (waitpid) stay in the drain path; accounting here is pure
// so headless tests can prove pool/queue behavior without real PTYs.
fn terminal_live_count(sessions []TermSession) int {
	mut n := 0
	for s in sessions {
		if !s.exited && !s.dismissed {
			n++
		}
	}
	return n
}

// terminal_reusable_slot — index of a dead slot to respawn into: same-agent
// first (keeps the agent's VT history beside its new child), else any dead
// slot, else -1 (pool must grow or queue).
fn terminal_reusable_slot(sessions []TermSession, agent string) int {
	mut any := -1
	for i, s in sessions {
		if s.exited || s.dismissed {
			if s.agent == agent {
				return i
			}
			if any < 0 {
				any = i
			}
		}
	}
	return any
}

// terminal_pool_admit — true while the pool has a free live slot.
fn terminal_pool_admit(sessions []TermSession) bool {
	return terminal_live_count(sessions) < terminal_pool_max
}

// terminal_queue_len — pending spawn requests (observable for the strip).
fn terminal_queue_len(queue []string) int {
	return queue.len
}

// terminal_enqueue — park an agent spawn request. Dedupe keeps one entry per
// agent; a full queue refuses (false) instead of dropping silently elsewhere.
fn terminal_enqueue(mut queue []string, agent string) bool {
	if agent == '' {
		return false
	}
	for q in queue {
		if q == agent {
			return true
		}
	}
	if queue.len >= terminal_queue_max {
		return false
	}
	queue << agent
	return true
}

// terminal_dequeue — oldest pending agent, or '' when the queue is empty
// (empty is valid state, never an error).
fn terminal_dequeue(mut queue []string) string {
	if queue.len == 0 {
		return ''
	}
	next := queue[0]
	queue = queue[1..].clone()
	return next
}

// terminal_clear_queue — reset the pending queue (tests, shutdown).
fn terminal_clear_queue(mut queue []string) {
	queue = []string{}
}

// terminal_session_accepts — owner rule for input routing: keystrokes reach
// a session VT only when the focused view backs a live, non-dismissed
// session. Fleet and desk feeds (view < 15) are shared read-mostly surfaces
// and always accept. Anything unbacked is denied — never rerouted to a
// different session, so typing can neither hijack nor blank another view.
fn terminal_session_accepts(sessions []TermSession, view int) bool {
	if view < 15 {
		return true
	}
	idx := view - 15
	if idx < 0 || idx >= sessions.len {
		return false
	}
	return !sessions[idx].exited && !sessions[idx].dismissed
}

// terminal_view_is_backed — every switch target must resolve to a real VT:
// fleet (-1) always exists; desks need both a roster entry and a live VT;
// sessions need a slot. Unbacked targets fall back to fleet (never blank).
fn terminal_view_is_backed(app &GuiApp, id int) bool {
	if id < 0 {
		return true
	}
	if id < 15 {
		desks := desks_for_app(app)
		return id < desks.len && id < app.per_desk_ghost.len
	}
	return id - 15 < app.sessions.len
}

// terminal_resolve_view — no-blank switch: backed ids pass through, anything
// else (stale session index, desk beyond the roster, garbage) lands on the
// fleet VT that always exists.
fn terminal_resolve_view(app &GuiApp, id int) int {
	if terminal_view_is_backed(app, id) {
		return id
	}
	return -1
}

// terminal_strip — display strip for VT bytes shown outside the terminal
// (desk micro-strips, toasts, overlay lines): consume CSI ESC[…letter,
// OSC ESC]…(BEL or ESC\), drop lone ESC, C0 controls (except \n\t) and
// DEL, pass everything else (including UTF-8 multibyte) through unchanged.
fn terminal_strip(s string) string {
	mut out := []u8{cap: s.len}
	mut i := 0
	for i < s.len {
		c := s[i]
		if c == 27 {
			if i + 1 < s.len && s[i + 1] == `[` {
				mut j := i + 2
				for j < s.len {
					d := s[j]
					if (d >= `A` && d <= `Z`) || (d >= `a` && d <= `z`) {
						break
					}
					j++
				}
				i = if j < s.len { j + 1 } else { s.len }
				continue
			}
			if i + 1 < s.len && s[i + 1] == `]` {
				mut j := i + 2
				for j < s.len {
					if s[j] == 7 {
						j++
						break
					}
					if s[j] == 27 && j + 1 < s.len && s[j + 1] == `\\` {
						j += 2
						break
					}
					j++
				}
				i = j
				continue
			}
			i++
			continue
		}
		if c < 32 && c != `\n` && c != `\t` {
			i++
			continue
		}
		if c == 127 {
			i++
			continue
		}
		out << c
		i++
	}
	return out.bytestr()
}

// terminal_strip_preview — stripped single-line preview for narrow surfaces:
// strip, flatten newlines, truncate to max runes with an ellipsis.
fn terminal_strip_preview(s string, max int) string {
	clean := terminal_strip(s).replace('\n', ' ').replace('\t', ' ')
	m := if max < 1 { 20 } else { max }
	if clean.len <= m {
		return clean
	}
	return clean[..m] + '…'
}

// terminal_kanban_for — read the cards an owner can still work: their
// non-done cards, doing first. Empty owner reads nothing (no fabricated
// ownership); done cards never overlay the terminal.
fn terminal_kanban_for(tasks []KanbanTask, owner string) []KanbanTask {
	mut out := []KanbanTask{}
	if owner == '' {
		return out
	}
	for t in tasks {
		if t.owner == owner && t.col == 'doing' {
			out << t
		}
	}
	for t in tasks {
		if t.owner == owner && t.col != 'doing' && t.col != 'done' {
			out << t
		}
	}
	return out
}

// terminal_spawn_pooled — pooled spawn entry: respawn into a reusable dead
// slot when one exists (old fd closed first via kill, VT refreshed), else
// grow the pool while admitted, else enqueue the request and say so. Returns
// the inspector status line (never blank, never silent). The one-shot
// pending_term_cwd binding behaves exactly like spawn_session: a run action
// lands the fresh shell in the run worktree, then clears.
fn terminal_spawn_pooled(mut app GuiApp, ab pty_mod.AgentBin, mut queue []string) string {
	slot := terminal_reusable_slot(app.sessions, ab.agent)
	if slot >= 0 {
		app.sessions[slot].sess.kill()
		mut s := pty_mod.spawn(ab.agent, ab.binary, [], 120, 32) or {
			app.pending_term_cwd = ''
			return 'Session ${ab.agent} error: ${err}'
		}
		cwd_msg := if app.pending_term_cwd != '' {
			s.write('cd ${term_shell_quote(app.pending_term_cwd)}\n')
			' · cwd ${app.pending_term_cwd}'
		} else {
			''
		}
		app.pending_term_cwd = ''
		app.sessions[slot].sess = s
		app.sessions[slot].vt = ghostty.new_terminal(120, 32)
		app.sessions[slot].exited = false
		app.sessions[slot].dismissed = false
		app.term_view = 15 + slot
		app.sessions_dialog = false
		return 'Session ${ab.agent} respawned in slot ${slot} (pid ${s.pid})${cwd_msg} — Fleet chip returns'
	}
	if terminal_pool_admit(app.sessions) {
		mut s := pty_mod.spawn(ab.agent, ab.binary, [], 120, 32) or {
			app.pending_term_cwd = ''
			return 'Session ${ab.agent} error: ${err}'
		}
		cwd_msg := if app.pending_term_cwd != '' {
			s.write('cd ${term_shell_quote(app.pending_term_cwd)}\n')
			' · cwd ${app.pending_term_cwd}'
		} else {
			''
		}
		app.pending_term_cwd = ''
		app.sessions << TermSession{
			agent: ab.agent
			sess:  s
			vt:    ghostty.new_terminal(120, 32)
		}
		app.term_view = 15 + app.sessions.len - 1
		app.sessions_dialog = false
		return 'Session ${ab.agent} spawned (pid ${s.pid})${cwd_msg} — Fleet chip returns'
	}
	at := terminal_queue_len(queue) + 1
	if terminal_enqueue(mut queue, ab.agent) {
		return 'Pool full (${terminal_pool_max} live) — ${ab.agent} queued at #${at}'
	}
	return 'Pool and queue full — ${ab.agent} refused, dismiss a session first'
}

// terminal_drain_queue — start queued spawns while the pool admits them.
// Call after the per-frame PTY drain marks sessions exited. Agent ids
// resolve through the shared pty detection table (no shadow table to drift);
// unknown ids stay queued for an operator to resolve, never dropped.
fn terminal_drain_queue(mut app GuiApp, mut queue []string) []string {
	mut started := []string{}
	for terminal_queue_len(queue) > 0 && terminal_pool_admit(app.sessions) {
		next := terminal_dequeue(mut queue)
		if next == '' {
			break
		}
		mut found := false
		for ab in pty_mod.agent_bins {
			if ab.agent == next {
				terminal_spawn_pooled(mut app, ab, mut queue)
				started << next
				found = true
				break
			}
		}
		if !found {
			terminal_enqueue(mut queue, next)
			break
		}
	}
	return started
}

// terminal_kanban_overlay — overlay lines for the terminal strip header:
// live counts plus up to max owner cards. Pure read of app state.
fn terminal_kanban_overlay(tasks []KanbanTask, owner string, max int) []string {
	mut lines := []string{}
	mut todo_n := 0
	mut doing_n := 0
	mut done_n := 0
	for t in tasks {
		if t.col == 'doing' {
			doing_n++
		} else if t.col == 'done' {
			done_n++
		} else {
			todo_n++
		}
	}
	lines << 'Kanban ${todo_n} todo · ${doing_n} doing · ${done_n} done'
	m := if max < 1 { terminal_overlay_max } else { max }
	for t in terminal_kanban_for(tasks, owner) {
		if lines.len - 1 >= m {
			break
		}
		lines << '[${t.col}] ${t.title} (${t.owner}·${t.pri})'
	}
	return lines
}
