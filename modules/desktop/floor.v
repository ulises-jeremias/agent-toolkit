module desktop

// Floor IA — three-zone office floor for the Desktop shell.
//
// Zones: rail (left filing-cabinet nav) | floor (center workshop canvas) |
// dashboard (right regional-manager command strip). The floor canvas is the
// permanent center: it never collapses and always renders, even when the
// rail is collapsed to its brass strip and the dashboard is hidden. Collapse
// and dashboard visibility are derived UI prefs persisted through the Engine
// (ui/floor/* keys, single writer); this file never touches the filesystem
// and never invents Engine state — absent keys decode to explicit defaults.

// FloorZone is one of the three floor zones.
pub enum FloorZone {
	rail
	floor
	dashboard
}

// floor_zone_from_string parses a zone id; unknown ids error (never guessed).
pub fn floor_zone_from_string(s string) !FloorZone {
	clean := s.trim_space().to_lower()
	match clean {
		'rail' { return .rail }
		'floor' { return .floor }
		'dashboard' { return .dashboard }
		else { return error('unknown floor zone: ${s}') }
	}
}

// id returns the stable zone id used in Engine keys and payloads.
pub fn (z FloorZone) id() string {
	match z {
		.rail { return 'rail' }
		.floor { return 'floor' }
		.dashboard { return 'dashboard' }
	}
}

// collapsed_strip_w is the px strip a collapsed side zone keeps (brass edge).
pub const collapsed_strip_w = 48

// FloorLayout is the derived three-zone layout (in-memory; Engine mirrors
// the collapse/dashboard prefs, never the pixel math).
pub struct FloorLayout {
pub mut:
	rail_width        int = 184
	dashboard_width   int = 320
	rail_collapsed    bool
	dashboard_visible bool = true
	dashboard_collapsed bool
	active            FloorZone = .floor
}

// default_floor_layout returns the canonical floor: rail 184px (matches the
// dock_w filing-cabinet), 320px dashboard, nothing collapsed, floor active.
pub fn default_floor_layout() FloorLayout {
	return FloorLayout{}
}

// validate checks invariants (width ranges, no fabricated geometry).
pub fn (l FloorLayout) validate() ! {
	if l.rail_width < collapsed_strip_w || l.rail_width > 400 {
		return error('rail width out of range: ${l.rail_width} (48..400)')
	}
	if l.dashboard_width < 200 || l.dashboard_width > 640 {
		return error('dashboard width out of range: ${l.dashboard_width} (200..640)')
	}
}

// clone returns a copy for pure transitions (V alias safety).
pub fn (l FloorLayout) clone() FloorLayout {
	return FloorLayout{
		rail_width: l.rail_width
		dashboard_width: l.dashboard_width
		rail_collapsed: l.rail_collapsed
		dashboard_visible: l.dashboard_visible
		dashboard_collapsed: l.dashboard_collapsed
		active: l.active
	}
}

// set_zone_collapsed collapses/expands a side zone (pure, no mutation).
// The floor canvas itself can never collapse — requesting it errors instead
// of silently degrading the center.
pub fn (l FloorLayout) set_zone_collapsed(zone FloorZone, collapsed bool) !FloorLayout {
	mut next := l.clone()
	match zone {
		.rail { next.rail_collapsed = collapsed }
		.dashboard {
			next.dashboard_collapsed = collapsed
			if collapsed {
				next.dashboard_visible = true
			}
		}
		.floor { return error('floor zone cannot collapse: center canvas is permanent') }
	}
	return next
}

// set_zone_collapsed_by_id parses the zone then collapses/expands it.
pub fn (l FloorLayout) set_zone_collapsed_by_id(zone_id string, collapsed bool) !FloorLayout {
	zone := floor_zone_from_string(zone_id)!
	return l.set_zone_collapsed(zone, collapsed)
}

// toggle_dashboard flips dashboard visibility (pure).
pub fn (l FloorLayout) toggle_dashboard() FloorLayout {
	mut next := l.clone()
	next.dashboard_visible = !l.dashboard_visible
	return next
}

// set_active moves keyboard/pointer focus to a zone (pure). Hidden zones
// cannot take focus: focusing the dashboard re-shows it, focusing a
// collapsed rail keeps the strip (focus, not expansion).
pub fn (l FloorLayout) set_active(zone FloorZone) FloorLayout {
	mut next := l.clone()
	next.active = zone
	if zone == .dashboard {
		next.dashboard_visible = true
	}
	return next
}

// visible_zones returns the zones actually rendered, left-to-right.
// The floor canvas is always present (honest-empty center, never blank).
pub fn (l FloorLayout) visible_zones() []string {
	mut out := []string{}
	if !l.rail_collapsed {
		out << 'rail'
	}
	out << 'floor'
	if l.dashboard_visible && !l.dashboard_collapsed {
		out << 'dashboard'
	}
	return out
}

// zone_width returns the px width of a zone inside a window_width window.
// Collapsed side zones keep the brass strip; a hidden dashboard is 0; the
// floor takes the remainder (floored at 320 so the canvas never inverts).
// Unknown zone ids error; nothing is guessed.
pub fn (l FloorLayout) zone_width(zone_id string, window_width int) !int {
	zone := floor_zone_from_string(zone_id)!
	match zone {
		.rail {
			if l.rail_collapsed {
				return collapsed_strip_w
			}
			return l.rail_width
		}
		.dashboard {
			if !l.dashboard_visible || l.dashboard_collapsed {
				return 0
			}
			return l.dashboard_width
		}
		.floor {
			mut used := 0
			if !l.rail_collapsed {
				used += l.rail_width
			} else {
				used += collapsed_strip_w
			}
			if l.dashboard_visible && !l.dashboard_collapsed {
				used += l.dashboard_width
			}
			rest := window_width - used
			if rest < 320 {
				return 320
			}
			return rest
		}
	}
}

// persist_payload serializes the Engine-mirrored prefs (collapse/visibility/
// active only — pixel widths are session geometry, not persisted).
pub fn (l FloorLayout) persist_payload() string {
	return '{"rail_collapsed":${l.rail_collapsed},"dashboard_visible":${l.dashboard_visible},' + '"dashboard_collapsed":${l.dashboard_collapsed},"active":"${l.active.id()}"}'
}

// floor_prefs_from_snapshot decodes Engine ui/floor/* keys onto defaults.
// Absent or malformed keys stay at defaults — never fabricated.
pub fn floor_prefs_from_snapshot(data map[string]string) FloorLayout {
	mut l := default_floor_layout()
	if v := data['ui/floor/rail_collapsed'] {
		l.rail_collapsed = v.trim_space().to_lower() == 'true'
	}
	if v := data['ui/floor/dashboard_visible'] {
		l.dashboard_visible = v.trim_space().to_lower() != 'false'
	}
	if v := data['ui/floor/dashboard_collapsed'] {
		l.dashboard_collapsed = v.trim_space().to_lower() == 'true'
	}
	if v := data['ui/floor/active'] {
		l.active = floor_zone_from_string(v) or { FloorZone.floor }
	}
	return l
}

// floor_prefs_to_keys encodes the Engine-mirrored prefs for one transaction.
pub fn (l FloorLayout) floor_prefs_to_keys() map[string]string {
	return {
		'ui/floor/rail_collapsed':      if l.rail_collapsed { 'true' } else { 'false' }
		'ui/floor/dashboard_visible':   if l.dashboard_visible { 'true' } else { 'false' }
		'ui/floor/dashboard_collapsed': if l.dashboard_collapsed { 'true' } else { 'false' }
		'ui/floor/active':              l.active.id()
	}
}
