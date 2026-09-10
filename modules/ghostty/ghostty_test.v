module ghostty

import agent_toolkit_core
import os

// hermetic Ghostty VT tests: pure computation, no I/O, no sleeps, no network.
// os is used for the TMPDIR-honoring temp-dir lifecycle proof (cleanup via defer).

fn clean_term(cols int, rows int) GhosttyTerminal {
	mut t := new_terminal(cols, rows)
	t.clear()
	return t
}

fn test_sgr_basic_colors_30_37() {
	mut t := clean_term(80, 18)
	// note: feed flushes the pending line at each SGR boundary, so no
	// trailing newline here — it would append one extra empty line.
	t.feed('\x1b[31merr\x1b[0m')
	assert t.lines == ['err']
	assert t.colors.last() == [2, 2, 2]
}

fn test_sgr_full_low_palette() {
	codes := ['30', '31', '32', '33', '34', '35', '36', '37']
	wants := [4, 2, 3, 1, 6, 5, 6, 0]
	for i, code in codes {
		mut t := clean_term(80, 18)
		t.feed('\x1b[${code}mx\x1b[0m')
		assert t.lines == ['x'], 'SGR ${code} line'
		assert t.colors.last() == [wants[i]], 'SGR ${code} color'
	}
}

fn test_sgr_bright_palette_90_97() {
	codes := ['90', '91', '92', '93', '94', '95', '96', '97']
	wants := [4, 2, 3, 1, 6, 5, 6, 0]
	for i, code in codes {
		mut t := clean_term(80, 18)
		t.feed('\x1b[${code}mx\x1b[0m')
		assert t.lines == ['x'], 'SGR ${code} line'
		assert t.colors.last() == [wants[i]], 'SGR ${code} color'
	}
}

fn test_ed_2j_clears_scrollback() {
	mut t := clean_term(80, 18)
	t.feed('one\ntwo\n')
	assert t.lines.len == 2
	t.feed('\x1b[2J')
	assert t.lines.len == 0
	assert t.colors.len == 0
}

fn test_scrollback_caps_at_1000_lines() {
	mut t := clean_term(80, 18)
	for i in 0 .. 1010 {
		t.feed('line ${i}\n')
	}
	assert t.lines.len == 1000
	assert t.colors.len == 1000
	// trim drops the oldest: first visible line is line 10
	assert t.lines[0] == 'line 10'
	assert t.lines.last() == 'line 1009'
}

fn test_resize_keeps_scroll_pinned_at_bottom() {
	mut t := clean_term(80, 5)
	for i in 0 .. 20 {
		t.feed('line ${i}\n')
	}
	t.scroll_to_bottom()
	assert t.scroll == t.lines.len
	t.resize(100, 10)
	assert t.scroll == t.lines.len
}

fn test_push_line_wrap_is_rune_safe() {
	mut t := clean_term(4, 18)
	t.feed('abcdefghij\n')
	assert t.lines == ['abcd', 'efgh', 'ij']
}

fn test_push_line_cjk_wrap_never_splits_rune() {
	// regression seed shared with the palette utf8_truncate test (#1168):
	// CJK runes are 3 bytes each; byte-slicing cols=4 would split mid-rune.
	cjk := '工作区设置向导'
	assert cjk.len == 21 // 7 runes x 3 bytes
	mut t := clean_term(4, 18)
	t.feed(cjk + '\n')
	assert t.lines.len == 2
	assert t.lines[0] == '工作区设'
	assert t.lines[1] == '置向导'
	assert t.lines.join('') == cjk
	// every wrapped chunk is valid UTF-8 with matching color cells
	for i, ln in t.lines {
		assert ln.runes().len <= 4
		assert t.colors[i].len == ln.runes().len
	}
}

fn test_push_line_emoji_wrap_never_splits_rune() {
	// emoji are 4-byte runes: cols=2 must not split them
	mut t := clean_term(2, 18)
	t.feed('a👍b\n')
	assert t.lines == ['a👍', 'b']
	for i, ln in t.lines {
		assert t.colors[i].len == ln.runes().len
	}
}

fn test_scroll_to_bottom_semantics() {
	mut t := clean_term(80, 5)
	for i in 0 .. 20 {
		t.feed('line ${i}\n')
	}
	assert t.scroll == t.lines.len
	t.scroll_up(10)
	assert t.scroll < t.lines.len
	t.scroll_to_bottom()
	assert t.scroll == t.lines.len
	// visible window shows the last `rows` lines when pinned
	vis := t.visible_lines()
	assert vis.len == 5
	assert vis.last() == 'line 19'
	assert t.copy_visible() == vis.join('\n')
}

fn test_version_reports_core_version() {
	mut t := clean_term(80, 18)
	t.submit_input_void_helper('version')
	want := 'Agent Toolkit Desktop ${agent_toolkit_core.resolve_toolkit_version()}'
	assert t.lines.last().starts_with(want), 'got: ${t.lines.last()}'
}

// submit_input_void_helper drives the version branch without touching history
// semantics under test elsewhere.
fn (mut t GhosttyTerminal) submit_input_void_helper(line string) {
	t.input = line
	t.cursor = line.len
	t.submit_input()
}

fn test_tmpdir_honored_for_temp_paths() {
	base := os.temp_dir()
	assert base.len > 0
	dir := os.join_path(base, 'atk-ghostty-${os.getpid()}')
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	assert os.is_dir(dir)
}
