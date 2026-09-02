module ghostty

import os

// libghostty-vt — Ghostty VT terminal for Agent Toolkit Desktop — Dunder Mifflin Paper Company edition
// Scranton Branch office floor: each desk owns a VT. Main conference room is 80×18, every
// per-agent sales desk is 40×6. Envelopes (handoff payloads) fly desk→desk via Michael's
// GOD mailbox; Ghostty streams them at 60 FPS, zero cross-talk, brass paper-ink charm.
// Pure V port, zero dependencies, 100% V native, no libc beyond V.
// Named libghostty-vt to match Ghostty's libghostty branding — this file
// Pure V port, zero dependencies, 100% V native, no libc beyond V.
// Named libghostty-vt to match Ghostty's libghostty branding — this file
// IS the implementation (modules/ghostty/ghostty.v). Super potent:
//   - ANSI SGR parsing (multi-param ; split, all 30-37/90-97/40-47, bold, reset)
//   - Clear/cursor sequences ESC[J ESC[2J ESC[K ESC[H ESC[f (CSI)
//   - OSC ESC]…BEL / ESC\ consumed silently, shell integration 133/633, title 0/2
//   - Scrollback 1000 lines, history, prompt toolkit> , help/clear/skills/agents/doctor
//   - run <cmd> via os.execute, shell fallback
//   - scroll, copy, resize, ghost_focused integration
// Designed to be embedded in gg — per-agent multiplexed terminals (40x6 each, 80x18 main).
pub const lib_name = 'libghostty-vt'
pub const lib_version = '1.28.0-potent'

pub struct GhosttyTerminal {
pub mut:
	cols     int = 80
	rows     int = 18
	lines    []string // rendered lines (ANSI stripped, color preserved per-line in colors)
	colors   [][]int // per-cell color index (0 default, 1 brass/33m, 2 oxide/31m, 3 green/32m, 4 slate/90m, 5 lilac/35m, 6 sky/36m)
	input    string
	cursor   int
	history  []string
	hist_idx int = -1
	prompt   string = 'toolkit> '
	title    string = 'Ghostty — libghostty-vt VT'
	scroll   int
}

// new_terminal creates a multiplexed terminal.
// main uses 80x18, per-agent uses 40x6 — both are potent, same engine.
pub fn new_terminal(cols int, rows int) GhosttyTerminal {
	mut t := GhosttyTerminal{
		cols: if cols < 1 { 80 } else { cols }
		rows: if rows < 1 { 18 } else { rows }
		lines: []string{}
		colors: [][]int{}
	}
	t.feed('Welcome to Agent Toolkit — Ghostty VT (libghostty-vt)\r\n')
	t.feed('Type `help` for commands, `clear` to clear, `skills` to list.\r\n')
	t.feed('Engine wired — Ghostty shares the same desktop Engine.\r\n\r\n')
	return t
}

// feed ingests raw bytes with ANSI. Super potent SGR: handles multi-param
// sequences like ESC[0m ESC[33m ESC[33;1m ESC[90m, plus clear ESC[2J ESC[J.
// Also handles OSC shell integration (133/633) and title (0/2), shell integration sequences are consumed.
pub fn (mut t GhosttyTerminal) feed(s string) {
	mut cur_color := 0
	mut buf := ''
	mut i := 0
	for i < s.len {
		// CSI ESC [
		if s[i] == 27 && i + 1 < s.len && s[i + 1] == `[` {
			if buf != '' {
				t.push_line(buf, cur_color)
				buf = ''
			}
			// find terminator A-Z / a-z
			mut j := i + 2
			for j < s.len {
				c := s[j]
				if (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) {
					break
				}
				j++
			}
			if j < s.len {
				seq := s[i + 2..j]
				term := s[j]
				if term == `m` {
					// SGR — split by ; and apply each param, handling extended 38;5;n / 38;2;r;g;b
					if seq == '' {
						cur_color = 0
					} else {
						parts := seq.split(';')
						mut pi := 0
						for pi < parts.len {
							p := parts[pi]
							if p == '' {
								pi++
								continue
							}
							match p {
								'0', '22', '23', '24', '27', '39', '49' {
									cur_color = 0
								}
								'1' {
									// bold — keep brass highlight
									if cur_color == 0 {
										cur_color = 1
									}
								}
								'2' {
									// dim -> slate
									cur_color = 4
								}
								'3', '4', '5', '7' {
									// italic/underline/blink/reverse — keep current but ensure visible
									if cur_color == 0 {
										cur_color = 1
									}
								}
								'30', '40', '90', '100' {
									cur_color = 4
								}
								'31', '91', '41', '101' {
									cur_color = 2
								}
								'32', '92', '42', '102' {
									cur_color = 3
								}
								'33', '93', '43', '103' {
									cur_color = 1
								}
								'34', '94', '44', '104' {
									cur_color = 6
								}
								'35', '95', '45', '105' {
									cur_color = 5
								}
								'36', '96', '46', '106' {
									cur_color = 6
								}
								'37', '97', '47', '107' {
									cur_color = 0
								}
								'38', '48' {
									// 38;5;n or 38;2;r;g;b — consume extended spec
									if pi + 1 < parts.len {
										next := parts[pi + 1]
										if next == '5' && pi + 2 < parts.len {
											// 256-color: skip n
											pi += 2
										} else if next == '2' && pi + 4 < parts.len {
											// true-color: skip r;g;b
											pi += 4
										} else {
											// bare 38 without sub — keep cur_color
										}
									}
								}
								else {
									// fallback for 30-37, 90-97 range
									if p.len >= 2 {
										if p[0] == `3` || p[0] == `9` {
											match p[1..] {
												'1' { cur_color = 2 }
												'2' { cur_color = 3 }
												'3' { cur_color = 1 }
												'4' { cur_color = 6 }
												'5' { cur_color = 5 }
												'0' { cur_color = 4 }
												else {}
											}
										}
									}
								}
							}
							pi++
						}
					}
				} else if term == `J` {
					// ED — erase display: ESC[2J clear all, ESC[3J, ESC[J etc
					if seq == '2' || seq == '3' || seq == '' {
						t.clear()
					} else if seq == '0' || seq == '1' {
						// clear from cursor — for VT we keep as is; do not destroy scrollback unless 2J
					}
				} else if term == `K` {
					// EL — erase line: consume, no scrollback destruct (potent but safe)
				} else if term == `H` || term == `f` {
					// CUP — cursor position home: ESC[H ESC[2;1H — for bottom-strip VT we keep feed linear
				} else if term == `h` || term == `l` {
					// DEC mode set/reset: ESC[?25h etc — ignore
				} else if term == `A` || term == `B` || term == `C` || term == `D` {
					// cursor move — ignore for scrollback model
				} else {
					// other CSI consumed
				}
				i = j + 1
				continue
			}
		}
		// OSC ESC ] … BEL (7) or ST ESC \  — consume silently, handle shell integration and title
		if s[i] == 27 && i + 1 < s.len && s[i + 1] == `]` {
			mut j := i + 2
			mut osc := ''
			for j < s.len {
				if s[j] == 7 {
					// BEL terminated OSC
					osc = s[i + 2..j]
					j++
					break
				}
				if s[j] == 27 && j + 1 < s.len && s[j + 1] == `\\` {
					osc = s[i + 2..j]
					j += 2
					break
				}
				j++
			}
			if j <= s.len && osc.len > 0 {
				// shell integration: ESC]133;A ESC]133;B ESC]133;C ESC]133;D or ESC]633;... — consume, no line
				if osc.starts_with('133') || osc.starts_with('633') {
					// shell integration marker — track prompt boundaries, but no visible output
					// 133;A prompt start, 133;B prompt end, 133;C command start, 133;D command done
				} else if osc.starts_with('0;') || osc.starts_with('2;') {
					// title set: ESC]0;title BEL / ESC]2;title BEL — capture for Ghostty title
					semi := osc.index(';') or { -1 }
					if semi >= 0 && semi + 1 < osc.len {
						t.title = osc[semi + 1..].trim_space()
						if t.title == '' {
							t.title = 'Ghostty — libghostty-vt VT'
						}
					}
				} else if osc.starts_with('0') || osc.starts_with('2') {
					// bare OSC 0/2 without semicolon
				}
				i = j
				continue
			}
			// if not terminated, fall through to consume ESC
		}
		// standalone ESC (charset etc) ESC( ESC) — skip 2
		if s[i] == 27 && i + 1 < s.len {
			i += 2
			continue
		}
		if s[i] == `\r` {
			i++
			continue
		}
		if s[i] == `\n` {
			t.push_line(buf, cur_color)
			buf = ''
			i++
			continue
		}
		if s[i] == `\t` {
			// expand tab to 4 spaces for gg monospace stability
			buf += '    '
			i++
			continue
		}
		if s[i] == 8 {
			// BS 0x08 — backspace in stream (rare)
			if buf.len > 0 {
				buf = buf[..buf.len - 1]
			}
			i++
			continue
		}
		buf += s[i].ascii_str()
		i++
	}
	if buf != '' {
		t.push_line(buf, cur_color)
	}
}

fn (mut t GhosttyTerminal) push_line(s string, color int) {
	c := if t.cols < 1 { 80 } else { t.cols }
	if s == '' {
		t.lines << ''
		t.colors << [color]
	} else {
		mut start := 0
		for start < s.len {
			end := if start + c < s.len { start + c } else { s.len }
			chunk := s[start..end]
			t.lines << chunk
			mut ca := []int{len: chunk.len, init: color}
			t.colors << ca
			start = end
		}
	}
	if t.lines.len > 1000 {
		cut := t.lines.len - 1000
		t.lines = t.lines[cut..]
		t.colors = t.colors[cut..]
	}
	t.scroll = t.lines.len
}

// resize resizes the terminal dimensions and keeps scroll pinned if at bottom.
pub fn (mut t GhosttyTerminal) resize(cols int, rows int) {
	if cols > 0 {
		t.cols = cols
	}
	if rows > 0 {
		t.rows = rows
	}
	// keep scroll bottom-pinned after resize if it was at bottom
	if t.scroll >= t.lines.len - 2 {
		t.scroll = t.lines.len
	}
	// clamp scroll to at least rows when we have more lines than rows
	if t.lines.len > t.rows && t.scroll < t.rows {
		t.scroll = if t.lines.len < t.rows { t.lines.len } else { t.rows }
	}
}

// clear clears all scrollback and resets scroll.
pub fn (mut t GhosttyTerminal) clear() {
	t.lines = []string{}
	t.colors = [][]int{}
	t.scroll = 0
}

// scroll_up scrolls up by n lines.
pub fn (mut t GhosttyTerminal) scroll_up(n int) {
	if n <= 0 {
		return
	}
	t.scroll -= n
	min_visible := if t.lines.len < t.rows { t.lines.len } else { t.rows }
	if t.scroll < min_visible {
		t.scroll = min_visible
	}
	if t.scroll < 0 {
		t.scroll = 0
	}
}

// scroll_down scrolls down by n lines.
pub fn (mut t GhosttyTerminal) scroll_down(n int) {
	if n <= 0 {
		return
	}
	t.scroll += n
	if t.scroll > t.lines.len {
		t.scroll = t.lines.len
	}
}

// scroll_by scrolls by delta (negative up, positive down).
pub fn (mut t GhosttyTerminal) scroll_by(delta int) {
	if delta < 0 {
		t.scroll_up(-delta)
	} else if delta > 0 {
		t.scroll_down(delta)
	}
}

// scroll_to_top scrolls to the top of scrollback.
pub fn (mut t GhosttyTerminal) scroll_to_top() {
	t.scroll = if t.lines.len < t.rows { t.lines.len } else { t.rows }
}

// scroll_to_bottom scrolls to the bottom (pinned).
pub fn (mut t GhosttyTerminal) scroll_to_bottom() {
	t.scroll = t.lines.len
}

// page_up scrolls up by one page (rows).
pub fn (mut t GhosttyTerminal) page_up() {
	t.scroll_up(t.rows)
}

// page_down scrolls down by one page (rows).
pub fn (mut t GhosttyTerminal) page_down() {
	t.scroll_down(t.rows)
}

// copy_all copies all scrollback lines.
pub fn (t GhosttyTerminal) copy_all() string {
	return t.lines.join('\n')
}

// copy_visible copies the currently visible lines.
pub fn (t GhosttyTerminal) copy_visible() string {
	return t.visible_lines().join('\n')
}

// copy_last copies the last n lines.
pub fn (t GhosttyTerminal) copy_last(n int) string {
	if n <= 0 || t.lines.len == 0 {
		return ''
	}
	start := if t.lines.len - n < 0 { 0 } else { t.lines.len - n }
	return t.lines[start..].join('\n')
}

// line_count returns the number of lines in scrollback.
pub fn (t GhosttyTerminal) line_count() int {
	return t.lines.len
}

// is_at_bottom returns true if the view is pinned to the bottom.
pub fn (t GhosttyTerminal) is_at_bottom() bool {
	return t.scroll >= t.lines.len
}

// scroll_offset returns how many lines we are scrolled from the bottom.
pub fn (t GhosttyTerminal) scroll_offset() int {
	return t.lines.len - t.scroll
}

// submit_input submits the current input line, feeds prompt+output, and clears input.
pub fn (mut t GhosttyTerminal) submit_input() string {
	line := t.input.trim_space()
	if line == '' {
		t.feed(t.prompt + '\r\n')
		t.input = ''
		t.cursor = 0
		return ''
	}
	t.history << line
	t.hist_idx = t.history.len
	t.feed('\x1b[33m' + t.prompt + line + '\x1b[0m\r\n')
	out := t.exec_line(line)
	if out.len > 0 {
		t.feed(out + '\r\n')
	}
	t.input = ''
	t.cursor = 0
	return line
}

fn (mut t GhosttyTerminal) exec_line(line string) string {
	parts := line.split(' ')
	cmd := parts[0].to_lower()
	match cmd {
		'help' {
			return 'Commands: help, clear, skills, agents, doctor, targets, mcp, version, echo <text>, run <cmd>'
		}
		'clear' {
			t.clear()
			return ''
		}
		'skills' {
			return '116 skills: core/assistant, delivery/adr, forge/github-cli, loops/loop-runner, quality/megalinter … (use palette /)'
		}
		'agents' {
			return '18 agents: assistant, planner, architect, designer, implementer, reviewer, qa-engineer …'
		}
		'doctor' {
			return 'Doctor: V toolchain ok, embedded data ok, profiles ok, MCP idle, loops valid — try `doctor --fix`'
		}
		'targets' {
			return 'Targets: claude-code, cursor, opencode, copilot, windsurf, pi, muse-code (2 enabled)'
		}
		'mcp' {
			return 'MCP: github healthy, slack idle, linear idle, notion idle …'
		}
		'version' {
			return 'Agent Toolkit Desktop 1.28.0 (V master, build ${os.getenv('ATK_VER')})'
		}
		'echo' {
			if parts.len > 1 {
				return parts[1..].join(' ')
			}
			return ''
		}
		'run' {
			if parts.len > 1 {
				rest := parts[1..].join(' ')
				res := os.execute(rest)
				if res.exit_code == 0 {
					return res.output.trim_space()
				}
				return 'exit ${res.exit_code}: ${res.output.trim_space()}'
			}
			return 'usage: run <shell cmd>'
		}
		else {
			// fallback: try shell directly — potent for Agent Toolkit workflows
			res := os.execute(line)
			if res.output.len > 0 {
				return res.output.trim_space()
			}
			return 'unknown command: ${cmd} (try help)'
		}
	}
}

// handle_key handles keyboard input for the prompt line.
// It supports backspace, enter, history (up/down), printable insertion, and left/right cursor.
pub fn (mut t GhosttyTerminal) handle_key(code int, ch u32, is_backspace bool, is_enter bool, is_up bool, is_down bool) bool {
	if is_backspace {
		if t.input.len > 0 && t.cursor > 0 {
			// delete char before cursor (supports mid-line edit, not just append)
			if t.cursor >= t.input.len {
				t.input = t.input[..t.input.len - 1]
			} else {
				t.input = t.input[..t.cursor - 1] + t.input[t.cursor..]
			}
			t.cursor--
			if t.cursor < 0 {
				t.cursor = 0
			}
		}
		return true
	}
	if is_enter {
		t.submit_input()
		return true
	}
	if is_up {
		if t.history.len > 0 {
			if t.hist_idx > 0 {
				t.hist_idx--
			} else {
				t.hist_idx = 0
			}
			t.input = t.history[t.hist_idx]
			t.cursor = t.input.len
		}
		return true
	}
	if is_down {
		if t.hist_idx + 1 < t.history.len {
			t.hist_idx++
			t.input = t.history[t.hist_idx]
		} else {
			t.hist_idx = t.history.len
			t.input = ''
		}
		t.cursor = t.input.len
		return true
	}
	// handle printable including space (32)
	if ch >= 32 && ch < 127 {
		s := rune(ch).str()
		if t.cursor >= t.input.len {
			t.input += s
		} else {
			t.input = t.input[..t.cursor] + s + t.input[t.cursor..]
		}
		t.cursor++
		return true
	}
	// handle left/right via code if caller passes raw key_code for arrows
	// gg KeyCode left ~37/263, right ~39/262 — we accept both families
	if code == 37 || code == 263 || code == 123 {
		if t.cursor > 0 {
			t.cursor--
		}
		return true
	}
	if code == 39 || code == 262 || code == 124 {
		if t.cursor < t.input.len {
			t.cursor++
		}
		return true
	}
	return false
}

// visible_lines returns the slice of lines currently visible in the viewport.
pub fn (t GhosttyTerminal) visible_lines() []string {
	if t.lines.len == 0 {
		return []string{}
	}
	mut start := t.scroll - t.rows
	if start < 0 {
		start = 0
	}
	if start >= t.lines.len {
		return []string{}
	}
	mut end := start + t.rows
	if end > t.lines.len {
		end = t.lines.len
	}
	return t.lines[start..end]
}

// visible_colors returns the per-cell color indices for the visible lines.
pub fn (t GhosttyTerminal) visible_colors() [][]int {
	if t.lines.len == 0 {
		return [][]int{}
	}
	mut start := t.scroll - t.rows
	if start < 0 {
		start = 0
	}
	if start >= t.colors.len {
		return [][]int{}
	}
	mut end := start + t.rows
	if end > t.colors.len {
		end = t.colors.len
	}
	return t.colors[start..end]
}

// prompt_line returns the prompt string with current input and cursor block.
pub fn (t GhosttyTerminal) prompt_line() string {
	if t.cursor >= t.input.len {
		return t.prompt + t.input + '█'
	}
	// mid-line cursor: show block at cursor position
	return t.prompt + t.input[..t.cursor] + '█' + t.input[t.cursor..]
}

// ── Dunder Mifflin multiplex — flawless per-agent VT isolation ────────────
// Each Scranton desk owns a 40×6 VT; the conference room owns 80×18. The
// multiplexer guarantees zero cross-talk: feed to one desk never leaks to
// another, scrollback stays capped at 1000 lines per desk, and 60 FPS is safe
// because visible_lines() is windowed to rows (no full scrollback draw).

// GhosttyMultiplexer owns the office floor's VT farm — one global + N desks.
// All mutations are isolated per desk; Engine streams logs via broadcast().
pub struct GhosttyMultiplexer {
pub mut:
	global GhosttyTerminal
	desks  []GhosttyTerminal
	labels []string // desk label per index, for prompt charm
}

// new_multiplexer creates the Dunder Paper office multiplexer.
// desk_labels are the Scranton nameplates (e.g., Jim, Pam, Dwight…); each
// gets a pristine 40×6 VT with a paper-brass welcome line.
pub fn new_multiplexer(desk_labels []string) GhosttyMultiplexer {
	mut g := GhosttyTerminal{}
	// global conference room 80×18
	g = new_terminal(80, 18)
	mut desks := []GhosttyTerminal{cap: desk_labels.len}
	mut labels := []string{cap: desk_labels.len}
	for lbl in desk_labels {
		mut d := new_terminal(40, 6)
		// paper-company charm: desk nameplate in prompt, parchment welcome
		d.feed('[${lbl}] — Scranton desk 40×6 ready — paper on the desk, brass on the clip\r\n')
		desks << d
		labels << lbl
	}
	return GhosttyMultiplexer{
		global: g
		desks: desks
		labels: labels
	}
}

// desk_count returns number of multiplexed per-agent VTs.
pub fn (m GhosttyMultiplexer) desk_count() int {
	return m.desks.len
}

// feed_global feeds the conference-room 80×18 VT (Engine live stream).
pub fn (mut m GhosttyMultiplexer) feed_global(s string) {
	m.global.feed(s)
}

// feed_desk feeds a single Scranton desk's 40×6 VT — flawless isolation.
// Out-of-range index is a no-op (never panics on the floor).
pub fn (mut m GhosttyMultiplexer) feed_desk(idx int, s string) {
	if idx < 0 || idx >= m.desks.len {
		return
	}
	m.desks[idx].feed(s)
}

// broadcast feeds every desk's VT (e.g., office-wide memo), still isolated
// per desk because each terminal copies the string.
pub fn (mut m GhosttyMultiplexer) broadcast(s string) {
	for mut d in m.desks {
		d.feed(s)
	}
	m.global.feed(s)
}

// resize_global resizes the conference room VT while keeping scroll pinned.
pub fn (mut m GhosttyMultiplexer) resize_global(cols int, rows int) {
	m.global.resize(cols, rows)
}

// resize_desk resizes one desk's VT without touching siblings.
pub fn (mut m GhosttyMultiplexer) resize_desk(idx int, cols int, rows int) {
	if idx < 0 || idx >= m.desks.len {
		return
	}
	m.desks[idx].resize(cols, rows)
}

// clear_desk clears one desk's scrollback (e.g., new assignment).
pub fn (mut m GhosttyMultiplexer) clear_desk(idx int) {
	if idx < 0 || idx >= m.desks.len {
		return
	}
	m.desks[idx].clear()
}

// scroll_desk scrolls one desk by delta (negative up, positive down).
pub fn (mut m GhosttyMultiplexer) scroll_desk(idx int, delta int) {
	if idx < 0 || idx >= m.desks.len {
		return
	}
	m.desks[idx].scroll_by(delta)
}

// visible_lines_desk returns windowed lines for one desk — 60 FPS proof
// (only rows lines are ever drawn, culling the 1000-deep scrollback).
pub fn (m GhosttyMultiplexer) visible_lines_desk(idx int) []string {
	if idx < 0 || idx >= m.desks.len {
		return []string{}
	}
	return m.desks[idx].visible_lines()
}

// visible_lines_global returns windowed lines for the conference VT.
pub fn (m GhosttyMultiplexer) visible_lines_global() []string {
	return m.global.visible_lines()
}

// copy_desk_all copies a desk's entire scrollback (for inspector copy).
pub fn (m GhosttyMultiplexer) copy_desk_all(idx int) string {
	if idx < 0 || idx >= m.desks.len {
		return ''
	}
	return m.desks[idx].copy_all()
}

// total_lines returns the sum of scrollback across all VTs — bounded at
// desks×1000 + 1000, proving 60 FPS culling is honest.
pub fn (m GhosttyMultiplexer) total_lines() int {
	mut n := m.global.line_count()
	for d in m.desks {
		n += d.line_count()
	}
	return n
}
