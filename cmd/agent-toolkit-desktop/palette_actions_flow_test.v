module main

import desktop
import desktop.palette
import os
import time

// Production-flow tests: preview → confirm → execute through the real
// registry, honest unavailability, requested-vs-running, canonical deep-link.

struct PaletteActionFlowFixture {
mut:
	app &GuiApp = unsafe { nil }
	d   &desktop.Desktop = unsafe { nil }
	scratch_dir string
}

// boot_palette_flow_app boots a headless Desktop + GuiApp with the registry bound. The
// fixture owns its exact temp directory and removes it in cleanup().
fn boot_palette_flow_app(label string) &PaletteActionFlowFixture {
	scratch_dir := os.join_path(os.temp_dir(), 'atk-palette-flow-${label}-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(scratch_dir) or { panic(err.msg()) }
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
	return &PaletteActionFlowFixture{
		app: app
		d: d
		scratch_dir: scratch_dir
	}
}

// cleanup stops the Desktop and removes this fixture's exact temp path.
fn (mut f PaletteActionFlowFixture) cleanup() {
	f.d.shutdown() or {}
	if f.scratch_dir != '' {
		os.rmdir_all(f.scratch_dir) or {}
		f.scratch_dir = ''
	}
}

fn find_row(rows []PaletteRow, pred fn (PaletteRow) bool) ?PaletteRow {
	for r in rows {
		if pred(r) {
			return r
		}
	}
	return none
}

// preview → informed execution: the real dry-run is shown first and the
// execution mutates real configuration state.
fn test_palette_action_flow_preview_then_execute() {
	mut f := boot_palette_flow_app('flow')
	defer {
		f.cleanup()
	}
	rows := filtered_palette(mut f.app)
	skill := find_row(rows, fn (r PaletteRow) bool {
		return r.is_entity && !r.is_action && r.kind == palette.EntityKind.skill
	}) or { panic('no skill row in palette') }
	f.app.palette_expanded = skill.id
	rows2 := filtered_palette(mut f.app)
	inst := find_row(rows2, fn (r PaletteRow) bool {
		return r.is_action && r.action_kind == palette.ActionKind.skill_install
	}) or { panic('skill_install action row missing after expansion') }
	assert inst.available
	// preview step: real diff lines, no mutation
	run_palette_action(mut f.app, inst)
	assert f.app.palette_preview.len > 0
	assert f.app.palette_preview_for == inst.id
	rev_before := f.d.engine_revision()
	// Enter again = informed confirmation → real execution
	run_palette_action(mut f.app, inst)
	assert f.app.inspector_msg.contains('installed')
	assert !f.app.inspector_msg.starts_with('Failed')
	assert f.d.engine_revision() > rev_before
	// palette flow state reset after execution
	assert !f.app.palette_open
	assert f.app.palette_preview.len == 0
	assert f.app.palette_expanded == ''
}

// unavailable action rows never fake success.
fn test_palette_action_unavailable_honest() {
	mut f := boot_palette_flow_app('unavail')
	defer {
		f.cleanup()
	}
	rows := filtered_palette(mut f.app)
	skill := find_row(rows, fn (r PaletteRow) bool {
		return r.is_entity && !r.is_action && r.kind == palette.EntityKind.skill
	}) or { panic('no skill row') }
	f.app.palette_expanded = skill.id
	rows2 := filtered_palette(mut f.app)
	rm := find_row(rows2, fn (r PaletteRow) bool {
		return r.is_action && r.action_kind == palette.ActionKind.skill_remove
	}) or { panic('skill_remove action row missing') }
	assert !rm.available
	rev_before := f.d.engine_revision()
	run_palette_action(mut f.app, rm)
	assert f.app.inspector_msg.starts_with('Unavailable —')
	assert f.app.inspector_msg.contains('not installed')
	// nothing changed
	assert f.d.engine_revision() == rev_before
}

// swarm launch routes to the swarm panel launch form (task text + recipe +
// backend are real typed inputs the palette cannot provide honestly).
fn test_palette_swarm_launch_routes_to_panel_form() {
	mut f := boot_palette_flow_app('swarm')
	defer {
		f.cleanup()
	}
	rows := filtered_palette(mut f.app)
	swarm := find_row(rows, fn (r PaletteRow) bool {
		return r.is_entity && !r.is_action && r.id == 'nav:/swarm'
	}) or { panic('nav:/swarm row missing') }
	f.app.palette_expanded = swarm.id
	rows2 := filtered_palette(mut f.app)
	launch := find_row(rows2, fn (r PaletteRow) bool {
		return r.is_action && r.action_kind == palette.ActionKind.swarm_launch
	}) or { panic('swarm_launch action row missing') }
	run_palette_action(mut f.app, launch)
	// routed to the launch form; no run was fabricated by the palette
	assert f.app.selected_panel == 8
	assert !f.app.palette_open
	assert f.d.swarm_list().len == 0
}

// deep-link preserves canonical entity identity: selection is resolved by id.
fn test_deep_link_selects_canonical_skill() {
	mut f := boot_palette_flow_app('deeplink')
	defer {
		f.cleanup()
	}
	rows := filtered_palette(mut f.app)
	skill := find_row(rows, fn (r PaletteRow) bool {
		return r.is_entity && !r.is_action && r.kind == palette.EntityKind.skill
	}) or { panic('no skill row') }
	deep_link_select(mut f.app, skill.kind, skill.entity_id)
	entries := skills_filtered_entries(mut f.app)
	assert app_selection_matches(mut f.app, entries, skill.entity_id)
}

// app_selection_matches asserts the panel selection points at the canonical id.
fn app_selection_matches(mut app GuiApp, entries []SkillEntryProxy, id string) bool {
	if app.skills_selected < 0 || app.skills_selected >= entries.len {
		return false
	}
	return entries[app.skills_selected].id == id
}
