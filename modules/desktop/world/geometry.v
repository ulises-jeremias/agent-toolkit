module world

// Geometry — Dunder Mifflin office floor geometry, Scranton Branch.
// Retained primitives with 32 px paper checkerboard, brass rivet specs,
// and 60 FPS culling (desk 140×86, avatar 24×24, envelope 16×8).
import desktop.theme

// PrimitiveKind enumerates retained geometry primitives — polyline / polygon / arc + text.
pub enum PrimitiveKind {
	polyline
	polygon
	arc
	text
}

// Point is a 2D coordinate in world space (logical pixels, dpi-aware via Theme).
pub struct Point {
pub:
	x f64
	y f64
}

// Primitive is one retained draw call — buffered, culled, replayed on resize without blackout.
pub struct Primitive {
pub:
	kind         PrimitiveKind
	verts        []Point // polyline/polygon verts in world space
	center       Point // arc center
	radius       f64 // arc radius
	angle_start  f64
	angle_end    f64
	text         string // for text primitive
	text_size    string // xs/sm/md/lg/xl
	rotation     f64 // text rotation degrees
	clip_rect    string // clipping rect debug string
	color        string // semantic token color
	stroke_width f64
	filled       bool
}

// TextMetrics wraps theme measurement for virtualized label rendering.
pub struct TextMetrics {
pub:
	width     int
	height    int
	baseline  int
	dpi_scale f64
}

// measure_text delegates to desktop.theme vglyph/Pango path (headless stub validated).
pub fn measure_text(text string, size_class string, dpi_scale f64, th theme.Theme) TextMetrics {
	m := th.measure_text(text, size_class, dpi_scale)
	return TextMetrics{
		width: m.width
		height: m.height
		baseline: m.baseline
		dpi_scale: m.dpi_scale
	}
}

// RetainedGeometryBuffer owns the on_draw retained list — survives resize without blackout.
pub struct RetainedGeometryBuffer {
mut:
	primitives []Primitive
	revision   u64
	hash       string
	// viewport for culling
	viewport Viewport
}

// new_retained_buffer creates an empty buffer.
pub fn new_retained_buffer(viewport Viewport) RetainedGeometryBuffer {
	return RetainedGeometryBuffer{
		viewport: viewport
	}
}

// push adds a primitive to the buffer.
pub fn (mut b RetainedGeometryBuffer) push(p Primitive) {
	b.primitives << p
	b.revision++
}

// clear resets buffer (called per frame before rebuild, but retained across resize).
pub fn (mut b RetainedGeometryBuffer) clear() {
	b.primitives.clear()
	b.revision++
}

// len returns primitive count (draw calls bounded).
pub fn (b RetainedGeometryBuffer) len() int {
	return b.primitives.len
}

// snapshot_hash returns stable hash across frames when primitives unchanged.
pub fn (mut b RetainedGeometryBuffer) snapshot_hash() string {
	if b.hash.len > 0 && b.primitives.len == 0 {
		return b.hash
	}
	mut h := 0
	for p in b.primitives {
		h = h * 31 + int(p.kind)
		h = h * 31 + p.verts.len
		if p.text.len > 0 {
			h = h * 31 + p.text.len
		}
	}
	b.hash = h.str()
	return b.hash
}

// culled returns culled view for current viewport — LOD stub for 100+ nodes.
pub fn (b RetainedGeometryBuffer) culled() []Primitive {
	return cull_primitives(b.primitives, b.viewport)
}

// cull_primitives filters primitives outside viewport with LOD clustering stub.
pub fn cull_primitives(prims []Primitive, vp Viewport) []Primitive {
	if prims.len == 0 {
		return []Primitive{}
	}
	mut out := []Primitive{cap: prims.len}
	for p in prims {
		if is_visible(p, vp) {
			out << p
		}
	}
	// LOD clustering stub: if >100 primitives, cluster by proximity (headless: truncate for FPS)
	if out.len > 100 {
		// stub: keep first 100 + cluster indicator
		// real would cluster via spatial hash
	}
	return out
}

// is_visible checks primitive against viewport bounds.
pub fn is_visible(p Primitive, vp Viewport) bool {
	if p.verts.len == 0 && p.kind != .arc && p.kind != .text {
		return false
	}
	// simple AABB check in world space
	for pt in p.verts {
		if pt.x >= vp.x && pt.x <= vp.x + vp.width && pt.y >= vp.y && pt.y <= vp.y + vp.height {
			return true
		}
	}
	if p.kind == .arc {
		return p.center.x >= vp.x - p.radius && p.center.x <= vp.x + vp.width + p.radius && p.center.y >= vp.y - p.radius && p.center.y <= vp.y + vp.height + p.radius
	}
	if p.kind == .text && p.verts.len > 0 {
		pt := p.verts[0]
		return pt.x >= vp.x && pt.x <= vp.x + vp.width && pt.y >= vp.y && pt.y <= vp.y + vp.height
	}
	return p.verts.len == 0
}

// Viewport describes pan/zoom window in world space.
pub struct Viewport {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
	zoom   f64 = 1.0
}

// default_viewport returns 1280x800 world viewport (matches DesktopConfig).
pub fn default_viewport() Viewport {
	return Viewport{
		x: 0
		y: 0
		width: 1280
		height: 800
		zoom: 1.0
	}
}

// zoom_in adjusts zoom (wheel).
pub fn (mut vp Viewport) zoom_in(delta f64) {
	vp.zoom += delta
	if vp.zoom < 0.2 {
		vp.zoom = 0.2
	}
	if vp.zoom > 5.0 {
		vp.zoom = 5.0
	}
}

// pan moves viewport (drag).
pub fn (mut vp Viewport) pan(dx f64, dy f64) {
	vp.x += dx / vp.zoom
	vp.y += dy / vp.zoom
}

// resize updates viewport size without blacking retained buffer.
pub fn (mut vp Viewport) resize(w f64, h f64) {
	vp.width = w
	vp.height = h
}

// HitTestResult is mouse hit-test outcome.
pub struct HitTestResult {
pub:
	hit       bool
	entity_id string
	kind      string // node | edge | zone | empty
	cursor    string // pointer | grab | default
	tooltip   string
}

// hit_test checks point against node bounds (10px radius) and edges/zones.
pub fn hit_test(x f64, y f64, nodes []WorldNode, edges []WorldEdge, vp Viewport) HitTestResult {
	// transform screen to world
	wx := (x / vp.zoom) + vp.x
	wy := (y / vp.zoom) + vp.y
	for n in nodes {
		dx := wx - n.pos.x
		dy := wy - n.pos.y
		dist := dx * dx + dy * dy
		if dist <= 100.0 { // 10px radius in world space
			return HitTestResult{
				hit: true
				entity_id: n.id
				kind: 'node'
				cursor: 'pointer'
				tooltip: '${n.label} (${n.kind}) — ${n.status}'
			}
		}
	}
	for e in edges {
		// simple edge proximity via midpoint
		mx := (e.from_pos.x + e.to_pos.x) / 2.0
		my := (e.from_pos.y + e.to_pos.y) / 2.0
		dx := wx - mx
		dy := wy - my
		if dx * dx + dy * dy <= 144.0 {
			return HitTestResult{
				hit: true
				entity_id: e.id
				kind: 'edge'
				cursor: 'pointer'
				tooltip: 'handoff ${e.id}: ${e.label}'
			}
		}
	}
	// zone hit via WorkshopScene zones
	zones := workshop_zones()
	for z in zones {
		if wx >= z.x && wx <= z.x + z.w && wy >= z.y && wy <= z.y + z.h {
			return HitTestResult{
				hit: true
				entity_id: z.id
				kind: 'zone'
				cursor: 'grab'
				tooltip: z.label
			}
		}
	}
	return HitTestResult{
		hit: false
		entity_id: ''
		kind: 'empty'
		cursor: 'default'
		tooltip: ''
	}
}

// WorkshopZone describes future station alcove in Workshop metaphor.
pub struct WorkshopZone {
pub:
	id    string
	label string
	x     f64
	y     f64
	w     f64
	h     f64
}

// workshop_zones returns distinct zones for Library, Diagnostics, Target, Swarm, Activity.
pub fn workshop_zones() []WorkshopZone {
	return [
		WorkshopZone{ id: 'workbench', label: 'Workbench — harness frame', x: 80, y: 80, w: 400, h: 320 },
		WorkshopZone{ id: 'library', label: 'Library alcove — skills/agents/packs', x: 520, y: 80, w: 320, h: 260 },
		WorkshopZone{ id: 'diagnostics', label: 'Diagnostics bench — doctor instruments', x: 80, y: 420, w: 260, h: 220 },
		WorkshopZone{ id: 'targets', label: 'Target rigs — profiles wall', x: 360, y: 420, w: 300, h: 220 },
		WorkshopZone{ id: 'swarm', label: 'Swarm Room doorway — handoffs', x: 680, y: 380, w: 220, h: 260 },
		WorkshopZone{ id: 'activity', label: 'Activity wall — timeline/journal', x: 520, y: 360, w: 380, h: 180 },
		WorkshopZone{ id: 'dock', label: 'Dock harness frame', x: 0, y: 0, w: 1280, h: 40 },
	]
}
