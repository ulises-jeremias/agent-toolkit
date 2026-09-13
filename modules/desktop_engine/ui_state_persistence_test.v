module desktop_engine

import os

fn test_persisted_terminal_mode_clamps_session_modes() {
	assert persisted_terminal_mode(0) == 0
	assert persisted_terminal_mode(1) == 1
	assert persisted_terminal_mode(2) == 0, 'MAX is session-only, restarts compact'
	assert persisted_terminal_mode(3) == 3
	assert persisted_terminal_mode(9) == 3, 'out-of-range restarts hidden'
	assert persisted_terminal_mode(-1) == 3
}

fn test_ui_state_env_encode_decode_roundtrip() {
	s := UiShellState{
		term_mode: 2
		zoom: 1.25
		lang: 1
		insights_tab: 'waterfall'
		swarm_backend: 'local'
		appearance: 'ink'
	}
	text := encode_ui_state_env(s)
	assert text.contains('term_mode=0'), 'MAX encodes as compact: ${text}'
	assert text.contains('zoom=1.25')
	assert text.contains('lang=1')
	assert text.contains('appearance=ink')
	back := decode_ui_state_env(text)
	assert back.term_mode == 0
	assert back.zoom == 1.25
	assert back.lang == 1
	assert back.insights_tab == 'waterfall'
	assert back.swarm_backend == 'local'
	assert back.appearance == 'ink'
	// malformed lines are skipped, unknown keys ignored
	other := decode_ui_state_env('garbage\nterm_mode=1\nbogus=1')
	assert other.term_mode == 1
	assert other.appearance == 'paper'
}

fn test_ui_state_path_derivation_sibling_and_default() {
	persist := os.join_path('/tmp', 'scratch-${os.getpid()}', 'state.json')
	assert ui_state_path_for(persist) == os.join_path('/tmp', 'scratch-${os.getpid()}', ui_state_file_name)
	assert ui_state_path_for('') == ui_state_default_path()
	assert ui_state_default_path().ends_with(os.join_path('agent-toolkit', 'desktop', ui_state_file_name))
}

fn test_ui_shell_state_save_load_roundtrip_via_engine() {
	tmp := os.join_path(os.temp_dir(), 'engine-uistate-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	assert eng.ui_state_path() == os.join_path(tmp, ui_state_file_name)
	before := eng.api_call_count()
	rev := eng.save_ui_shell_state(UiShellState{
		term_mode: 2
		zoom: 1.25
		lang: 1
		insights_tab: 'waterfall'
		swarm_backend: 'local'
		appearance: 'ink'
	}) or { panic(err.msg()) }
	assert rev >= 1
	assert eng.api_call_count() > before, 'ui save must count as an Engine API call'
	// repository mirror holds the clamped layout
	snap := eng.snapshot()
	assert snap.data['ui/term_mode'] == '0', 'MAX mirrors as compact'
	assert snap.data['ui/lang'] == '1'
	assert snap.data['ui/appearance'] == 'ink'
	// derived file holds the same k=v layout
	path := eng.ui_state_path()
	assert os.is_file(path), 'derived ui_state.env must exist at ${path}'
	text := os.read_file(path) or { '' }
	assert text.contains('term_mode=0')
	assert text.contains('appearance=ink')
	// load returns the mirrored layout
	loaded := eng.load_ui_shell_state()
	assert loaded.term_mode == 0
	assert loaded.zoom == 1.25
	assert loaded.lang == 1
	assert loaded.insights_tab == 'waterfall'
	assert loaded.appearance == 'ink'
	eng.stop()!
	// restart: the mirror survives via state.json persistence
	mut reloaded := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	reloaded.init()!
	reloaded.start()!
	defer { reloaded.stop() or {} }
	again := reloaded.load_ui_shell_state()
	assert again.appearance == 'ink'
	assert again.lang == 1
}

fn test_ui_shell_state_load_falls_back_to_env_file() {
	tmp := os.join_path(os.temp_dir(), 'engine-uistate-file-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	// pre-migration layout: env file exists, repository has no ui/* keys
	os.write_file(os.join_path(tmp, ui_state_file_name), 'term_mode=1\nzoom=1.0\nlang=2\ninsights_tab=cost\nswarm_backend=auto\nappearance=paper') or {
		panic(err.msg())
	}
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	loaded := eng.load_ui_shell_state()
	assert loaded.term_mode == 1
	assert loaded.lang == 2
	assert loaded.appearance == 'paper'
}

fn test_ui_shell_state_load_defaults_when_nothing_persisted() {
	tmp := os.join_path(os.temp_dir(), 'engine-uistate-fresh-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	loaded := eng.load_ui_shell_state()
	assert loaded == default_ui_shell_state()
}
