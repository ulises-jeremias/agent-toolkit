module desktop_engine

import os
import time

// Slice F editor persistence: brokered open + validated save roundtrip,
// secret refusal, escape refusal. Behavior-named, real Engine over tmp.

struct EtFixture {
mut:
	tmp string
	ws  string
	eng &Engine = unsafe { nil }
}

fn et_fixture() &EtFixture {
	tmp := os.join_path(os.temp_dir(), 'atk-et-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut f := &EtFixture{
		tmp: tmp
	}
	ws := os.join_path(tmp, 'ws')
	os.mkdir_all(os.join_path(ws, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(ws, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	os.write_file(os.join_path(ws, 'note.md'), 'hello\n') or { panic(err.msg()) }
	f.ws = ws
	eng_dir := os.join_path(tmp, 'engine')
	os.mkdir_all(eng_dir) or { panic(err.msg()) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(eng_dir, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	eng.switch_workspace(ws) or { panic(err.msg()) }
	f.eng = eng
	return f
}

fn (mut f EtFixture) cleanup() {
	f.eng.stop() or {}
	os.rmdir_all(f.tmp) or {}
}

fn test_editor_open_and_save_roundtrip() {
	mut f := et_fixture()
	defer {
		f.cleanup()
	}
	tab := f.eng.open_file_brokered(f.ws, os.join_path(f.ws, 'note.md')) or { panic('open must succeed: ${err.msg()}') }
	assert tab.content == 'hello\n'
	assert !tab.dirty
	mut edited := tab
	edited.content = 'hello edited\n'
	edited.dirty = true
	rev := f.eng.save_editor_tab(edited) or { panic('save must succeed: ${err.msg()}') }
	assert rev > 0, 'save returns a ledger revision as receipt'
	assert os.read_file(os.join_path(f.ws, 'note.md')) or { panic(err.msg()) } == 'hello edited\n'
}

fn test_editor_save_refuses_secrets() {
	mut f := et_fixture()
	defer {
		f.cleanup()
	}
	tab := f.eng.open_file_brokered(f.ws, os.join_path(f.ws, 'note.md')) or { panic(err.msg()) }
	mut edited := tab
	edited.content = 'key = AKIAIOSFODNN7EXAMPLE\n'
	edited.dirty = true
	if _ := f.eng.save_editor_tab(edited) {
		assert false, 'secret-bearing content must never be written'
	} else {
		assert err.msg().contains('secret'), 'refusal names the cause: ${err.msg()}'
	}
	assert os.read_file(os.join_path(f.ws, 'note.md')) or { panic(err.msg()) } == 'hello\n'
}

fn test_editor_open_refuses_escape() {
	mut f := et_fixture()
	defer {
		f.cleanup()
	}
	if _ := f.eng.open_file_brokered(f.ws, os.join_path(f.tmp, 'outside.md')) {
		assert false, 'path escape must be refused'
	} else {
		assert err.msg() != '', 'refusal carries a reason'
	}
}
