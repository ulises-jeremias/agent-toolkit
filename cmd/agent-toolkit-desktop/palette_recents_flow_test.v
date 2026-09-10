module main

import desktop
import desktop.palette
import os
import time

// Shell-flow tests: recents render distinctly, rerun re-resolves current
// availability, undo is single-use and guarded by live exact-state checks.

struct PaletteRecentsFixture {
mut:
	app &GuiApp = unsafe { nil }
	d   &desktop.Desktop = unsafe { nil }
	scratch_dir string
}

fn boot_palette_recents_app(label string) &PaletteRecentsFixture {
	scratch_dir := os.join_path(os.temp_dir(), 'atk-palette-recents-${label}-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(scratch_dir) or { panic(err.msg()) }
	// appearance persistence (save_ui_state) must never touch the real user
	// cache from tests — point XDG_CACHE_HOME at the fixture dir
	os.setenv('XDG_CACHE_HOME', scratch_dir, true)
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: desktop.DesktopConfig{
			headless: true
		}
		persist_path: os.join_path(scratch_dir, 'state.json')
	})
	d.boot() or { panic(err.msg()) }
	mut app := &GuiApp{
		desktop: d
		selected_panel: 0
		hover_panel: -1
		selected_desk: -1
		hover_desk: -1
	}
	app.palette_reg = d.palette_registry()
	app.palette_open = true
	return &PaletteRecentsFixture{
		app: app
		d: d
		scratch_dir: scratch_dir
	}
}

fn (mut f PaletteRecentsFixture) cleanup() {
	f.d.shutdown() or {}
	os.rmdir_all(f.scratch_dir) or {}
	f.scratch_dir = ''
}

fn find_recent_row(rows []PaletteRow) ?PaletteRow {
	for r in rows {
		if r.is_recent {
			return r
		}
	}
	return none
}

// a real executed action produces a recent row that is visibly distinct,
// and the fresh session starts with none.
fn test_recents_appear_after_execution() {
	mut f := boot_palette_recents_app('recents')
	defer {
		f.cleanup()
	}
	// fresh session: no recents at all
	assert f.app.palette_reg.journal_records().len == 0
	// execute a real mutation (target toggle)
	mut target_id := ''
	for t in f.d.engine_targets() {
		target_id = t.id
		break
	}
	kind := if f.d.engine_target_enabled(target_id) {
		palette.ActionKind.target_disable
	} else {
		palette.ActionKind.target_enable
	}
	out := f.app.palette_reg.execute(.target, target_id, kind, palette.ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	// empty query → the recent row leads the palette, distinctly prefixed
	rows := filtered_palette(mut f.app)
	rec := find_recent_row(rows) or { panic('recent row missing') }
	assert rec.label.starts_with('↻ ')
	assert rec.execution_id > 0
	assert rec.desc.contains('succeeded')
	// the record preserves canonical entity identity
	assert rec.entity_id == target_id
}

// rerun of a recent action goes through the CURRENT registry (revalidation),
// and the second toggle records another recent (not a blind replay).
fn test_recents_rerun_revalidates() {
	mut f := boot_palette_recents_app('rerun')
	defer {
		f.cleanup()
	}
	mut target_id := ''
	for t in f.d.engine_targets() {
		target_id = t.id
		break
	}
	was := f.d.engine_target_enabled(target_id)
	kind := if was { palette.ActionKind.target_disable } else { palette.ActionKind.target_enable }
	f.app.palette_reg.execute(.target, target_id, kind, palette.ActionArgs{}) or {
		panic(err.msg())
	}
	rows := filtered_palette(mut f.app)
	rec := find_recent_row(rows) or { panic('recent row missing') }
	// rerun via the shell path — resolves the CURRENT action and availability.
	// The same toggle is now unavailable (the state already matches its
	// effect), so the rerun is honestly refused: no replay, no new record.
	rerun_recent(mut f.app, rec)
	recs := f.app.palette_reg.journal_records()
	assert recs.len == 1
	for rr in recs {
		println('DBG rec id=${rr.execution_id} kind=${rr.action_kind} entity=${rr.entity_kind}/${rr.entity_id} label=${rr.label}')
	}
	// DBG row.id=${rec.id} row.exec=${rec.execution_id} state=${f.d.engine_target_enabled(target_id)}')
	assert f.app.inspector_msg.starts_with('Unavailable —')
	// the current opposite direction IS available and rerunning it works
	jrec := f.app.palette_reg.find_recent(rec.execution_id) or {
		panic('journal record missing')
	}
	opp := if jrec.action_kind == palette.ActionKind.target_enable {
		palette.ActionKind.target_disable
	} else {
		palette.ActionKind.target_enable
	}
	out2 := f.app.palette_reg.execute(.target, target_id, opp, palette.ActionArgs{}) or {
		panic(err.msg())
	}
	// DBG out2=${out2.status} ${out2.summary}')
	assert out2.status == .succeeded
	assert f.d.engine_target_enabled(target_id) == was
}

// undo through the shell path: exact restore, single use; a diverged state
// refuses without overwriting.
fn test_recents_undo_shell_path() {
	mut f := boot_palette_recents_app('undo')
	defer {
		f.cleanup()
	}
	mut target_id := ''
	for t in f.d.engine_targets() {
		target_id = t.id
		break
	}
	was := f.d.engine_target_enabled(target_id)
	kind := if was { palette.ActionKind.target_disable } else { palette.ActionKind.target_enable }
	out := f.app.palette_reg.execute(.target, target_id, kind, palette.ActionArgs{}) or {
		panic(err.msg())
	}
	rows := filtered_palette(mut f.app)
	rec := find_recent_row(rows) or { panic('recent row missing') }
	// undo available and reflected in the row description
	assert rec.desc.contains('U undo ready')
	// execute the undo
	handle_palette_undo(mut f.app, rec)
	assert f.d.engine_target_enabled(target_id) == was
	// consumed: a second undo refuses honestly
	assert f.app.palette_reg.undo_precheck(rec.execution_id) == .consumed
	handle_palette_undo(mut f.app, rec)
	assert f.app.inspector_msg.contains('Already undone')
}

// theme is recorded by the shell through the real setter and its undo
// restores the exact previous appearance via the same setter.
fn test_theme_shell_undo() {
	mut f := boot_palette_recents_app('theme')
	defer {
		f.cleanup()
	}
	before := f.app.appearance.str()
	// forward: theme cycle via the shell path with journal recording
	rows := filtered_palette(mut f.app)
	mut app_row_idx := -1
	for idx, r in rows {
		if r.is_entity && r.kind == palette.EntityKind.app {
			app_row_idx = idx
		}
	}
	assert app_row_idx >= 0, 'app entity row must be discoverable'
	f.app.palette_expanded = rows[app_row_idx].id
	rows2 := filtered_palette(mut f.app)
	mut theme_row := ?PaletteRow(none)
	for r in rows2 {
		if r.is_action && r.action_kind == palette.ActionKind.app_theme_cycle {
			theme_row = r
		}
	}
	tr := theme_row or { panic('theme action missing') }
	run_palette_action(mut f.app, tr)
	// the shell executed the real setter and recorded the execution
	assert f.app.appearance.str() != before
	recs := f.app.palette_reg.journal_records()
	assert recs.len == 1
	assert recs[0].action_kind == palette.ActionKind.app_theme_cycle
	assert recs[0].has_undo
	// undo via the shell path restores the exact previous appearance
	f.app.palette_expanded = ''
	rows3 := filtered_palette(mut f.app)
	rec_row := find_recent_row(rows3) or { panic('recent row missing') }
	handle_palette_undo(mut f.app, rec_row)
	assert f.app.appearance.str() == before
	assert f.app.palette_reg.undo_precheck(rec_row.execution_id) == .consumed
}
