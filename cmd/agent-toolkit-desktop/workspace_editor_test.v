module main

// Slice F editor model: insert/delete/cursor/dirty, rune-safe.

fn f_tab(content string) EditorTab {
	return EditorTab{
		path: 'note.md'
		title: 'note.md'
		content: content
		syntax: 'markdown'
		dirty: false
		cursor: 0
	}
}

fn test_editor_insert_marks_dirty_at_cursor() {
	mut base := f_tab('ac')
	base.cursor = 1
	t := editor_insert(base, 'b')
	assert t.content == 'abc'
	assert t.cursor == 2
	assert t.dirty
}

fn test_editor_insert_unicode_keeps_rune_cursor() {
	mut t := f_tab('aé')
	t = editor_move_right(editor_move_right(t))
	t = editor_insert(t, '!')
	assert t.content == 'aé!'
	assert t.cursor == 3
}

fn test_editor_backspace_at_zero_is_noop() {
	t := editor_backspace(f_tab('ab'))
	assert t.content == 'ab'
	assert !t.dirty
}

fn test_editor_backspace_deletes_before_cursor() {
	mut t := f_tab('abc')
	t.cursor = 3
	t = editor_backspace(t)
	assert t.content == 'ab'
	assert t.cursor == 2
	assert t.dirty
}

fn test_editor_cursor_vertical_keeps_column() {
	mut t := f_tab('abcdef\ngh\nijklmnop')
	// line 0, col 4 → down keeps col 2 on the short line, then col 2 below
	t.cursor = 4
	t = editor_move_down(t)
	_, col := editor_line_col(t)
	assert col == 2, 'short line clamps the column'
	t = editor_move_down(t)
	line, col2 := editor_line_col(t)
	assert line == 2 && col2 == 2
	t = editor_move_up(t)
	line_u, col_u := editor_line_col(t)
	assert line_u == 1 && col_u == 2
}

fn test_editor_move_down_past_end_pins() {
	mut t := f_tab('ab')
	t.cursor = 2
	t = editor_move_down(t)
	assert t.cursor == 2
}

fn test_editor_moves_never_mark_dirty() {
	t := editor_move_left(editor_move_right(editor_move_up(editor_move_down(f_tab('a\nb')))))
	assert !t.dirty
}

fn test_editor_editable_limit() {
	assert editor_editable(f_tab('tiny'))
	mut big := f_tab('')
	big.content = 'x'.repeat(editor_max_edit_bytes + 1)
	assert !editor_editable(big), 'oversized buffers stay read-only'
}

fn save_test_app(tab EditorTab) GuiApp {
	return GuiApp{
		editor_tabs: [tab]
		active_tab: 0
	}
}

fn test_editor_save_refuses_without_open_tab() {
	mut app := GuiApp{
		editor_tabs: []EditorTab{}
		active_tab: -1
	}
	editor_save_active(mut app)
	assert app.editor_msg == 'nothing open to save'
}

fn test_editor_save_refuses_oversized_tab() {
	mut big := f_tab('x'.repeat(editor_max_edit_bytes + 1))
	big.dirty = true
	mut app := save_test_app(big)
	editor_save_active(mut app)
	assert app.editor_msg == 'read-only: file too large to edit'
	assert app.editor_tabs[0].dirty, 'refused save never clears dirty'
}

fn test_editor_save_refuses_clean_tab() {
	mut app := save_test_app(f_tab('saved already'))
	editor_save_active(mut app)
	assert app.editor_msg == 'no changes to save'
}

fn test_editor_save_refuses_detached_engine() {
	mut tab := f_tab('unsaved work')
	tab.dirty = true
	mut app := save_test_app(tab)
	editor_save_active(mut app)
	assert app.editor_msg == 'save unavailable: engine detached'
	assert app.editor_tabs[0].dirty, 'failed save never clears dirty'
}
