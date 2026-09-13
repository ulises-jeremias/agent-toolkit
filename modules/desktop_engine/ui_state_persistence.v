module desktop_engine

import os

// UI shell persistence — Engine-owned derived persistence for shell layout.
//
// The ui_state.env key=value file (term_mode, zoom, lang, insights_tab,
// swarm_backend, appearance) is derived state, never canonical. The Engine
// owns the path derivation, the atomic file write, and the StateRepository
// mirror (ui/* keys) behind one typed struct. Views map their enums to the
// plain fields and never touch the filesystem.

// ui_state_file_name is the derived shell-layout file next to the state file.
pub const ui_state_file_name = 'ui_state.env'

// UiShellState is the typed shell-layout projection. lang is the Lang int,
// appearance the appearance string ('paper' | 'ink' | 'system'); the view
// owns the enum mapping, the Engine owns clamping + persistence.
pub struct UiShellState {
pub mut:
	term_mode     int
	zoom          f64
	lang          int
	insights_tab  string
	swarm_backend string
	appearance    string
}

// default_ui_shell_state returns the fresh-session shell layout.
pub fn default_ui_shell_state() UiShellState {
	return UiShellState{
		term_mode: 3
		zoom: 1.0
		lang: 0
		insights_tab: 'cost'
		swarm_backend: 'auto'
		appearance: 'paper'
	}
}

// persisted_terminal_mode clamps a terminal mode for persistence. MAX (2) is
// session-only: restart it as compact (0) rather than covering the whole
// application before the user asks again. Out-of-range restarts hidden (3).
pub fn persisted_terminal_mode(mode int) int {
	if mode == 2 {
		return 0
	}
	return if mode >= 0 && mode <= 3 { mode } else { 3 }
}

// encode_ui_state_env serializes shell state to the ui_state.env k=v format.
pub fn encode_ui_state_env(s UiShellState) string {
	lines := [
		'term_mode=${persisted_terminal_mode(s.term_mode)}',
		'zoom=${s.zoom}',
		'lang=${s.lang}',
		'insights_tab=${s.insights_tab}',
		'swarm_backend=${s.swarm_backend}',
		'appearance=${s.appearance}',
	]
	return lines.join('\n')
}

// decode_ui_state_env parses the ui_state.env k=v format onto defaults.
// Unknown keys are ignored; malformed lines are skipped.
pub fn decode_ui_state_env(text string) UiShellState {
	mut s := default_ui_shell_state()
	for line in text.split('\n') {
		kv := line.split('=')
		if kv.len != 2 {
			continue
		}
		k, v := kv[0], kv[1]
		match k {
			'term_mode' {
				s.term_mode = persisted_terminal_mode(v.int())
			}
			'zoom' {
				s.zoom = v.f64()
			}
			'lang' {
				s.lang = v.int()
			}
			'insights_tab' {
				s.insights_tab = v
			}
			'swarm_backend' {
				s.swarm_backend = v
			}
			'appearance' {
				s.appearance = v
			}
			else {}
		}
	}
	return s
}

// ui_state_default_path derives the default shell-layout path from XDG cache
// (cache/agent-toolkit/desktop/ui_state.env). Used when the Engine has no
// explicit persist path.
pub fn ui_state_default_path() string {
	base := os.getenv('XDG_CACHE_HOME')
	home := os.home_dir()
	cache := if base.len > 0 { base } else { os.join_path(home, '.cache') }
	return os.join_path(cache, 'agent-toolkit', 'desktop', ui_state_file_name)
}

// ui_state_path_for derives the shell-layout file for a repository persist
// path: a sibling of the state file so tests and custom layouts stay
// isolated. Empty persist_path falls back to the XDG default.
pub fn ui_state_path_for(persist_path string) string {
	if persist_path.trim_space() == '' {
		return ui_state_default_path()
	}
	return os.join_path(os.dir(persist_path), ui_state_file_name)
}

// ui_state_path returns this Engine's derived shell-layout file path.
pub fn (mut e Engine) ui_state_path() string {
	return ui_state_path_for(e.repo.persist_path_of())
}

// save_ui_shell_state persists shell layout: clamps, mirrors into the
// StateRepository via a single Transaction (one revision bump), and writes
// the derived ui_state.env file atomically. Strict: file errors return.
pub fn (mut e Engine) save_ui_shell_state(s UiShellState) !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	clamped := UiShellState{
		term_mode: persisted_terminal_mode(s.term_mode)
		zoom: s.zoom
		lang: s.lang
		insights_tab: s.insights_tab
		swarm_backend: s.swarm_backend
		appearance: s.appearance
	}
	mut tx := e.repo.begin('ui-state')
	tx.set('ui/term_mode', clamped.term_mode.str())
	tx.set('ui/zoom', clamped.zoom.str())
	tx.set('ui/lang', clamped.lang.str())
	tx.set('ui/insights_tab', clamped.insights_tab)
	tx.set('ui/swarm_backend', clamped.swarm_backend)
	tx.set('ui/appearance', clamped.appearance)
	rev := e.put_transaction(mut tx)!
	path := ui_state_path_for(e.repo.persist_path_of())
	os.mkdir_all(os.dir(path)) or { return error('mkdir failed: ${err}') }
	tmp := '${path}.tmp.${os.getpid()}'
	os.write_file(tmp, encode_ui_state_env(clamped)) or { return error('write tmp failed: ${err}') }
	os.mv(tmp, path) or {
		os.rm(tmp) or {}
		return error('rename failed: ${err}')
	}
	return rev.revision
}

// load_ui_shell_state returns the persisted shell layout: repository mirror
// first, the derived env file (pre-migration layouts) second, defaults when
// neither exists. Zoom is NOT clamped here — callers clamp for their range.
pub fn (mut e Engine) load_ui_shell_state() UiShellState {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	if 'ui/term_mode' in snap.data {
		return UiShellState{
			term_mode: persisted_terminal_mode((snap.data['ui/term_mode'] or { '3' }).int())
			zoom: (snap.data['ui/zoom'] or { '1.0' }).f64()
			lang: (snap.data['ui/lang'] or { '0' }).int()
			insights_tab: snap.data['ui/insights_tab'] or { 'cost' }
			swarm_backend: snap.data['ui/swarm_backend'] or { 'auto' }
			appearance: snap.data['ui/appearance'] or { 'paper' }
		}
	}
	path := ui_state_path_for(e.repo.persist_path_of())
	if os.is_file(path) {
		if text := os.read_file(path) {
			return decode_ui_state_env(text)
		}
	}
	return default_ui_shell_state()
}
