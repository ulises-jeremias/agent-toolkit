module desktop

import os

fn test_floor_layout_defaults_three_zones() {
	l := default_floor_layout()
	l.validate() or { panic(err.msg()) }
	assert l.visible_zones() == ['rail', 'floor', 'dashboard']
	assert l.active == .floor
	assert l.dashboard_visible
	assert !l.rail_collapsed
	assert l.rail_width == 184
	// 1280 window: floor takes the remainder
	fw := l.zone_width('floor', 1280) or { panic(err.msg()) }
	assert fw == 1280 - 184 - 320
	assert (l.zone_width('rail', 1280) or { 0 }) == 184
	assert (l.zone_width('dashboard', 1280) or { 0 }) == 320
}

fn test_floor_layout_collapse_expand_pure() {
	l := default_floor_layout()
	collapsed := l.set_zone_collapsed(.rail, true) or { panic(err.msg()) }
	assert collapsed.visible_zones() == ['floor', 'dashboard']
	assert (collapsed.zone_width('rail', 1280) or { 0 }) == collapsed_strip_w
	// pure: original untouched
	assert l.visible_zones() == ['rail', 'floor', 'dashboard']
	expanded := collapsed.set_zone_collapsed_by_id('rail', false) or { panic(err.msg()) }
	assert expanded.visible_zones() == ['rail', 'floor', 'dashboard']
	// dashboard collapse hides it but keeps visibility pref
	dc := l.set_zone_collapsed(.dashboard, true) or { panic(err.msg()) }
	assert dc.visible_zones() == ['rail', 'floor']
	assert dc.dashboard_visible
}

fn test_floor_layout_dashboard_toggle() {
	l := default_floor_layout()
	hidden := l.toggle_dashboard()
	assert hidden.visible_zones() == ['rail', 'floor']
	assert (hidden.zone_width('dashboard', 1280) or { -1 }) == 0
	shown := hidden.toggle_dashboard()
	assert shown.visible_zones() == ['rail', 'floor', 'dashboard']
	// focusing the dashboard re-shows it (focus, not a blank zone)
	refocused := hidden.set_active(.dashboard)
	assert refocused.visible_zones() == ['rail', 'floor', 'dashboard']
}

fn test_floor_layout_rejects_floor_collapse_and_bad_ids() {
	l := default_floor_layout()
	if _ := l.set_zone_collapsed(.floor, true) {
		assert false, 'floor canvas must never collapse'
	}
	if _ := l.set_zone_collapsed_by_id('mezzanine', true) {
		assert false, 'unknown zone must error, never guess'
	}
	if _ := l.zone_width('mezzanine', 1280) {
		assert false, 'unknown zone width must error'
	}
	mut bad := default_floor_layout()
	bad.rail_width = 8
	if _ := bad.validate() {
		assert false, 'rail below strip must fail validation'
	}
	bad = default_floor_layout()
	bad.dashboard_width = 9000
	if _ := bad.validate() {
		assert false, 'oversize dashboard must fail validation'
	}
	// narrow window never inverts the floor canvas
	narrow := l.zone_width('floor', 200) or { panic(err.msg()) }
	assert narrow == 320
}

fn test_desktop_floor_prefs_roundtrip_via_engine() {
	tmp := os.join_path(os.temp_dir(), 'desk-floor-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut d := new_desktop(DesktopBootArgs{
		config: DesktopConfig{
			title: 'Floor Test'
			width: 1280
			height: 800
			headless: true
		}
		persist_path: persist
	})
	d.boot() or { panic(err.msg()) }
	defer { d.shutdown() or {} }
	// boot restores defaults when the Engine mirror is absent (honest-empty)
	assert d.floor_visible_zones() == ['rail', 'floor', 'dashboard']
	// collapse rail via the Engine: revision receipt, zones update
	rev := d.set_floor_zone_collapsed('rail', true) or { panic(err.msg()) }
	assert rev > 0
	assert d.floor_visible_zones() == ['floor', 'dashboard']
	snap := d.current_engine_state()
	assert (snap.data['ui/floor/rail_collapsed'] or { '' }) == 'true'
	// dashboard toggle mirrored too
	d.toggle_floor_dashboard() or { panic(err.msg()) }
	assert d.floor_visible_zones() == ['floor']
	snap2 := d.current_engine_state()
	assert (snap2.data['ui/floor/dashboard_visible'] or { '' }) == 'false'
	// floor itself refuses to collapse through the Desktop seam
	if _ := d.set_floor_zone_collapsed('floor', true) {
		assert false, 'Desktop must refuse floor collapse'
	}
	// a fresh Desktop on the same persist path restores Engine prefs
	mut d2 := new_desktop(DesktopBootArgs{
		config: DesktopConfig{
			title: 'Floor Test'
			width: 1280
			height: 800
			headless: true
		}
		persist_path: persist
	})
	d2.boot() or { panic(err.msg()) }
	defer { d2.shutdown() or {} }
	assert d2.floor_visible_zones() == ['floor']
	assert d2.floor_layout().rail_collapsed
	assert !d2.floor_layout().dashboard_visible
}
