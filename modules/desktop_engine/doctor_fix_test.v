module desktop_engine

import os

// Doctor dry-run preview + real per-check repair (#1108).
// A fixed warn row must flip to pass on re-check; the preview must describe
// the mutations without writing anything.
fn test_doctor_fix_preview_and_repair_flip() {
	tmp := os.join_path(os.temp_dir(), 'doc-fix-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	// cursor ships disabled → warn + fixable row exists out of the box
	mut cursor_status := ''
	for c in eng.doctor() {
		if c.id == 'profile:cursor' {
			cursor_status = c.status
			assert c.fixable
		}
	}
	assert cursor_status == 'warn'

	// preview describes the repair and writes nothing
	prev := eng.doctor_fix_preview('profile:cursor') or { panic(err.msg()) }
	assert prev.len == 2
	assert prev[0] == 'set target:cursor:enabled = true'
	still_disabled := eng.targets().filter(it.id == 'cursor')[0]
	assert still_disabled.enabled == false

	// fix performs the real repair — the row flips to pass on re-check
	rev := eng.doctor_fix('profile:cursor') or { panic(err.msg()) }
	assert rev >= 1
	enabled := eng.targets().filter(it.id == 'cursor')[0]
	assert enabled.enabled == true
	mut after := ''
	for c in eng.doctor() {
		if c.id == 'profile:cursor' {
			after = c.status
		}
	}
	assert after == 'pass'

	// unknown check: preview errors honestly, fix stays idempotent-success
	eng.doctor_fix_preview('nope:missing') or { assert err.msg().contains('unknown doctor check') }
	rev2 := eng.doctor_fix('bogus:check') or { panic(err.msg()) }
	assert rev2 >= 1

	// already-passing check previews as stamp-only
	prev_pass := eng.doctor_fix_preview('profile:cursor') or { panic(err.msg()) }
	assert prev_pass[0].contains('already passes')
}

// Facet-chip category fix repairs every fixable row in the category (#1108).
fn test_doctor_fix_category_repairs_profiles() {
	tmp := os.join_path(os.temp_dir(), 'doc-cat-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	eng.set_target_enabled('opencode', false) or { panic(err.msg()) }
	rev := eng.doctor_fix_category('profiles') or { panic(err.msg()) }
	assert rev >= 1
	for c in eng.doctor() {
		if c.category == 'profiles' && c.fixable {
			assert c.status == 'pass'
		}
	}
	// nothing fixable → 0, not an error
	assert eng.doctor_fix_category('pack')! == 0
	eng.doctor_fix_category('') or { assert err.msg().contains('category empty') }
}
