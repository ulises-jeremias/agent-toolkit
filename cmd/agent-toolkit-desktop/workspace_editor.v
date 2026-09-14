module main

import desktop_engine
import gg

// Integrated editor model (slice F, #1237): keystroke → tab transitions as
// pure functions. cursor is a rune offset into content. Every mutation sets
// dirty; cursor moves never do.

// editor_max_edit_bytes bounds the editable buffer: larger files open
// read-only with an honest message instead of stalling the frame loop.
const editor_max_edit_bytes = 262144

// editor_editable reports whether a tab may take keystrokes.
fn editor_editable(tab EditorTab) bool {
	return tab.content.len <= editor_max_edit_bytes
}

fn editor_clamp(tab EditorTab) EditorTab {
	mut t := tab
	n := t.content.runes().len
	if t.cursor < 0 {
		t.cursor = 0
	}
	if t.cursor > n {
		t.cursor = n
	}
	return t
}

// editor_insert splices text at the cursor and marks the tab dirty.
fn editor_insert(tab EditorTab, s string) EditorTab {
	mut t := editor_clamp(tab)
	r := t.content.runes()
	mut out := []rune{}
	out << r[..t.cursor]
	out << s.runes()
	out << r[t.cursor..]
	t.content = out.string()
	t.cursor += s.runes().len
	t.dirty = true
	return t
}

// editor_backspace deletes the rune before the cursor.
fn editor_backspace(tab EditorTab) EditorTab {
	mut t := editor_clamp(tab)
	if t.cursor == 0 {
		return t
	}
	r := t.content.runes()
	mut out := []rune{}
	out << r[..t.cursor - 1]
	out << r[t.cursor..]
	t.content = out.string()
	t.cursor--
	t.dirty = true
	return t
}

// editor_move_left moves the cursor one rune toward the buffer start.
fn editor_move_left(tab EditorTab) EditorTab {
	mut t := editor_clamp(tab)
	if t.cursor > 0 {
		t.cursor--
	}
	return t
}

// editor_move_right moves the cursor one rune toward the buffer end.
fn editor_move_right(tab EditorTab) EditorTab {
	mut t := editor_clamp(tab)
	if t.cursor < t.content.runes().len {
		t.cursor++
	}
	return t
}

// editor_line_col resolves the cursor to a (line, col) pair, both 0-based.
fn editor_line_col(tab EditorTab) (int, int) {
	t := editor_clamp(tab)
	r := t.content.runes()
	mut line := 0
	mut col := 0
	for i in 0 .. t.cursor {
		if r[i] == `\n` {
			line++
			col = 0
		} else {
			col++
		}
	}
	return line, col
}

// editor_line_bounds returns the rune offsets [start, end) of a line.
// A nonexistent line resolves to (len, len).
fn editor_line_bounds(tab EditorTab, line int) (int, int) {
	r := tab.content.runes()
	mut cur := 0
	mut start := 0
	for i, ch in r {
		if ch == `\n` {
			if cur == line {
				return start, i
			}
			cur++
			start = i + 1
		}
	}
	if cur == line {
		return start, r.len
	}
	return r.len, r.len
}

// editor_move_up keeps the visual column on the previous line.
fn editor_move_up(tab EditorTab) EditorTab {
	mut t := editor_clamp(tab)
	line, col := editor_line_col(t)
	if line == 0 {
		t.cursor = 0
		return t
	}
	start, end := editor_line_bounds(t, line - 1)
	width := end - start
	t.cursor = start + if col < width { col } else { width }
	return t
}

// editor_active returns the focused tab or none when no tab is usable.
fn editor_active(app &GuiApp) ?EditorTab {
	if !app.editor_focused || app.memory_search_focus {
		return none
	}
	if app.active_tab < 0 || app.active_tab >= app.editor_tabs.len {
		return none
	}
	return app.editor_tabs[app.active_tab]
}

// editor_save_active persists the active tab through the Engine's validated
// write path. The receipt revision replaces the message; every failure names
// its cause. Never writes when there is nothing to write.
fn editor_save_active(mut app GuiApp) {
	if app.active_tab < 0 || app.active_tab >= app.editor_tabs.len {
		app.editor_msg = 'nothing open to save'
		return
	}
	tab := app.editor_tabs[app.active_tab]
	if !editor_editable(tab) {
		app.editor_msg = 'read-only: file too large to edit'
		return
	}
	if !tab.dirty {
		app.editor_msg = 'no changes to save'
		return
	}
	if app.desktop == unsafe { nil } {
		app.editor_msg = 'save unavailable: engine detached'
		return
	}
	eng_tab := desktop_engine.EditorTab{
		path: tab.path
		title: tab.title
		content: tab.content
		syntax: tab.syntax
		dirty: tab.dirty
		cursor: tab.cursor
	}
	rev := app.desktop.engine_save_editor_tab(eng_tab) or {
		app.editor_msg = 'save failed: ${err.msg()}'
		return
	}
	mut clean := tab
	clean.dirty = false
	app.editor_tabs[app.active_tab] = clean
	app.editor_msg = 'saved · rev ${rev}'
}

// editor_key routes one key event to the focused editor tab. Returns true
// when the key was consumed. Read-only (oversized) tabs consume edits with
// an honest message instead of leaking keystrokes into the memory query.
fn editor_key(mut app GuiApp, e &gg.Event) bool {
	if editor_active(app) == none {
		return false
	}
	tab := app.editor_tabs[app.active_tab]
	if e.key_code == .escape {
		app.editor_focused = false
		app.editor_msg = ''
		return true
	}
	is_ctrl := (e.modifiers & u32(gg.Modifier.ctrl)) != 0
		|| (e.modifiers & u32(gg.Modifier.super)) != 0
	if is_ctrl && e.key_code == .s {
		editor_save_active(mut app)
		return true
	}
	if e.key_code == .left {
		app.editor_tabs[app.active_tab] = editor_move_left(tab)
		return true
	}
	if e.key_code == .right {
		app.editor_tabs[app.active_tab] = editor_move_right(tab)
		return true
	}
	if e.key_code == .up {
		app.editor_tabs[app.active_tab] = editor_move_up(tab)
		return true
	}
	if e.key_code == .down {
		app.editor_tabs[app.active_tab] = editor_move_down(tab)
		return true
	}
	if !editor_editable(tab) {
		if e.key_code == .backspace || e.key_code == .enter
			|| ((e.char_code >= 32 && e.char_code < 127) || e.char_code > 127) {
			app.editor_msg = 'read-only: file too large to edit'
			return true
		}
		return false
	}
	if e.key_code == .backspace {
		app.editor_tabs[app.active_tab] = editor_backspace(tab)
		app.editor_msg = ''
		return true
	}
	if e.key_code == .enter {
		app.editor_tabs[app.active_tab] = editor_insert(tab, '\n')
		app.editor_msg = ''
		return true
	}
	if !is_ctrl && ((e.char_code >= 32 && e.char_code < 127) || e.char_code > 127) {
		app.editor_tabs[app.active_tab] = editor_insert(tab, rune(e.char_code).str())
		app.editor_msg = ''
		return true
	}
	return false
}

// editor_move_down keeps the visual column on the next line, pinning to the
// buffer end past the last line.
fn editor_move_down(tab EditorTab) EditorTab {
	mut t := editor_clamp(tab)
	n := t.content.runes().len
	line, col := editor_line_col(t)
	start, end := editor_line_bounds(t, line + 1)
	if start >= n {
		t.cursor = n
		return t
	}
	width := end - start
	t.cursor = start + if col < width { col } else { width }
	return t
}
