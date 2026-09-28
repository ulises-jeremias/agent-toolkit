module main

import gg
import pty as pty_mod

// WS3 Terminal+ops headless tests: pool accounting, owner rule, queue,
// strip, kanban read/overlay, no-blank switch, Enter regression. Pure
// logic — no PTYs spawned, no display needed.

fn pooled_sessions() []TermSession {
	return [
		TermSession{
			agent: 'claude-code'
		},
		TermSession{
			agent:  'opencode'
			exited: true
		},
		TermSession{
			agent:     'claude-code'
			dismissed: true
		},
	]
}

fn test_terminal_pool_counts_only_live_slots() {
	assert terminal_live_count(pooled_sessions()) == 1
	assert terminal_live_count([]TermSession{}) == 0
	assert terminal_pool_max == 4
}

fn test_terminal_pool_admit_below_max_only() {
	mut live := []TermSession{}
	for _ in 0 .. terminal_pool_max {
		live << TermSession{
			agent: 'claude-code'
		}
	}
	assert !terminal_pool_admit(live)
	live[0].exited = true
	assert terminal_pool_admit(live)
	assert terminal_pool_admit([]TermSession{})
}

fn test_terminal_reusable_slot_prefers_same_agent() {
	s := pooled_sessions()
	assert terminal_reusable_slot(s, 'claude-code') == 2
	assert terminal_reusable_slot(s, 'gemini') == 1
	assert terminal_reusable_slot([TermSession{ agent: 'x' }], 'x') == -1
}

fn test_terminal_queue_dedupes_caps_and_orders() {
	mut queue := []string{}
	terminal_clear_queue(mut queue)
	assert terminal_queue_len(queue) == 0
	assert terminal_enqueue(mut queue, 'claude-code')
	assert terminal_enqueue(mut queue, 'claude-code')
	assert terminal_queue_len(queue) == 1
	assert !terminal_enqueue(mut queue, '')
	for i in 0 .. terminal_queue_max {
		terminal_enqueue(mut queue, 'agent-${i}')
	}
	assert terminal_queue_len(queue) == terminal_queue_max
	assert !terminal_enqueue(mut queue, 'one-too-many')
	assert terminal_dequeue(mut queue) == 'claude-code'
	assert terminal_queue_len(queue) == terminal_queue_max - 1
	terminal_clear_queue(mut queue)
	assert terminal_dequeue(mut queue) == ''
	assert terminal_queue_len(queue) == 0
}

fn test_terminal_owner_rule_routes_only_live_owned_sessions() {
	s := pooled_sessions()
	// fleet + desk feeds are shared surfaces
	assert terminal_session_accepts(s, -1)
	assert terminal_session_accepts(s, 3)
	// live session accepts its own view
	assert terminal_session_accepts(s, 15)
	// exited / dismissed sessions never accept — no hijack, no blank
	assert !terminal_session_accepts(s, 16)
	assert !terminal_session_accepts(s, 17)
	// unbacked views never reroute elsewhere
	assert !terminal_session_accepts(s, 99)
	assert !terminal_session_accepts([]TermSession{}, 15)
}

fn test_terminal_resolve_view_never_blanks() {
	mut app := &GuiApp{}
	// fleet always backed
	assert terminal_resolve_view(app, -1) == -1
	assert terminal_view_is_backed(app, -1)
	// no desks/VTs and no sessions headless: everything falls to fleet
	assert terminal_resolve_view(app, 0) == -1
	assert terminal_resolve_view(app, 99) == -1
	assert terminal_resolve_view(app, 15) == -1
	// one live session backs view 15 exactly; stale 16 still fleets
	app.sessions << TermSession{
		agent: 'claude-code'
	}
	assert terminal_view_is_backed(app, 15)
	assert terminal_resolve_view(app, 15) == 15
	assert terminal_resolve_view(app, 16) == -1
	assert vt_label(app, terminal_resolve_view(app, 16)) == 'Fleet'
}

fn test_terminal_tabs_never_empty_smoke() {
	mut app := &GuiApp{}
	tabs := terminal_tabs(app)
	assert tabs.len >= 1
	assert tabs[0].label == 'Terminal'
}

fn test_terminal_strip_consumes_escapes_and_controls() {
	assert terminal_strip('\x1b[33mhi\x1b[0m') == 'hi'
	assert terminal_strip('\x1b[33;1mbold\x1b[m') == 'bold'
	assert terminal_strip('\x1b[2J\x1b[Hclean') == 'clean'
	assert terminal_strip('\x1b]0;title\x07ok') == 'ok'
	assert terminal_strip('a\x00b\x07c\nd\te\x7ff') == 'abc\nd\tef'
	assert terminal_strip('plain — ünïcodé ✓') == 'plain — ünïcodé ✓'
	assert terminal_strip('') == ''
}

fn test_terminal_strip_preview_flattens_and_caps() {
	assert terminal_strip_preview('\x1b[32mok\x1b[0m', 20) == 'ok'
	assert terminal_strip_preview('ab\ncd', 20) == 'ab cd'
	long := 'abcdefghijklmnopqrstuvwxyz'
	assert terminal_strip_preview(long, 20) == 'abcdefghijklmnopqrst…'
}

fn test_terminal_kanban_reads_owner_work_doing_first() {
	tasks := [
		KanbanTask{
			id:    '1'
			title: 'Write spec'
			col:   'todo'
			owner: 'Muse'
			pri:   'high'
		},
		KanbanTask{
			id:    '2'
			title: 'Fix bug'
			col:   'doing'
			owner: 'Muse'
			pri:   'high'
		},
		KanbanTask{
			id:    '3'
			title: 'Done thing'
			col:   'done'
			owner: 'Muse'
			pri:   'low'
		},
		KanbanTask{
			id:    '4'
			title: 'Other owner'
			col:   'doing'
			owner: 'Roy'
			pri:   'medium'
		},
	]
	mine := terminal_kanban_for(tasks, 'Muse')
	assert mine.len == 2
	assert mine[0].col == 'doing'
	assert mine[0].title == 'Fix bug'
	// no fabricated ownership: empty owner reads nothing
	assert terminal_kanban_for(tasks, '') == []KanbanTask{}
	assert terminal_kanban_for([]KanbanTask{}, 'Muse') == []KanbanTask{}
}

fn test_terminal_kanban_overlay_counts_and_caps() {
	tasks := [
		KanbanTask{
			id:    '1'
			title: 'Write spec'
			col:   'todo'
			owner: 'Muse'
			pri:   'high'
		},
		KanbanTask{
			id:    '2'
			title: 'Fix bug'
			col:   'doing'
			owner: 'Muse'
			pri:   'high'
		},
		KanbanTask{
			id:    '3'
			title: 'Shipped'
			col:   'done'
			owner: 'Roy'
			pri:   'low'
		},
	]
	lines := terminal_kanban_overlay(tasks, 'Muse', 5)
	assert lines.len == 3
	assert lines[0] == 'Kanban 1 todo · 1 doing · 1 done'
	assert lines[1] == '[doing] Fix bug (Muse·high)'
	capped := terminal_kanban_overlay(tasks, 'Muse', 1)
	assert capped.len == 2
	// empty state stays explicit, never fabricated
	empty := terminal_kanban_overlay([]KanbanTask{}, '', 5)
	assert empty == ['Kanban 0 todo · 0 doing · 0 done']
}

fn test_terminal_spawn_pooled_reuses_slot_then_queues() {
	// Hermetic: absolute /bin/true path, no PATH dependence, every session
	// reaped via defer — mirrors modules/pty/pty_test.v.
	mut queue := []string{}
	terminal_clear_queue(mut queue)
	mut app := &GuiApp{}
	defer {
		for mut s in app.sessions {
			s.sess.kill()
		}
		terminal_clear_queue(mut queue)
	}
	bin := pty_mod.AgentBin{'test-true', '/bin/true', ''}
	msg := terminal_spawn_pooled(mut app, bin, mut queue)
	assert msg.contains('spawned')
	assert app.sessions.len == 1
	assert app.term_view == 15
	app.sessions[0].exited = true
	msg2 := terminal_spawn_pooled(mut app, bin, mut queue)
	assert msg2.contains('respawned in slot 0')
	assert app.sessions.len == 1
	assert !app.sessions[0].exited
	// fill the pool with live slots: further requests queue, none blank
	for app.sessions.len < terminal_pool_max {
		app.sessions << TermSession{
			agent: 'filler'
		}
	}
	msg3 := terminal_spawn_pooled(mut app, bin, mut queue)
	assert msg3.contains('queued at #1')
	assert terminal_queue_len(queue) == 1
}

fn test_terminal_enter_key_routes_carriage_return() {
	e := &gg.Event{
		typ:      .key_down
		key_code: .enter
	}
	assert session_key_bytes(e) == '\r'
	up := &gg.Event{
		typ:      .key_down
		key_code: .up
	}
	assert session_key_bytes(up) == '\x1b[A'
}
