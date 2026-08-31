module world

import desktop.theme

// VirtualizedList implements viewport culling + row pool for 1000+ rows / 5k events.
pub struct VirtualizedList {
pub mut:
	total_rows    int
	row_height    int = 24
	viewport_h    int = 800
	scroll_offset int
	// metrics
	visible_start int
	visible_end   int
	rendered_rows int
}

// new_virtualized_list creates a list for total rows.
pub fn new_virtualized_list(total_rows int, viewport_h int) VirtualizedList {
	return VirtualizedList{
		total_rows: total_rows
		viewport_h: if viewport_h <= 0 { 800 } else { viewport_h }
	}
}

// visible_range computes start/end indices for current scroll.
pub fn (mut v VirtualizedList) visible_range() (int, int) {
	rows_in_view := v.viewport_h / v.row_height + 2 // +2 overscan
	mut start := v.scroll_offset / v.row_height
	if start < 0 {
		start = 0
	}
	if start > v.total_rows {
		start = v.total_rows
	}
	mut end := start + rows_in_view
	if end > v.total_rows {
		end = v.total_rows
	}
	v.visible_start = start
	v.visible_end = end
	v.rendered_rows = end - start
	return start, end
}

// scroll_to sets scroll offset.
pub fn (mut v VirtualizedList) scroll_to(offset int) {
	v.scroll_offset = offset
	if v.scroll_offset < 0 {
		v.scroll_offset = 0
	}
	mut max := v.total_rows * v.row_height - v.viewport_h
	if max < 0 {
		max = 0
	}
	if v.scroll_offset > max {
		v.scroll_offset = max
	}
}

// draw_calls returns bounded draw calls for visible window (not total).
pub fn (mut v VirtualizedList) draw_calls() int {
	_, _ = v.visible_range()
	return v.rendered_rows * 2 // row bg + text per row
}

// measure_row_text uses theme.measure_text for label virtualization.
pub fn measure_row_text(text string, th theme.Theme) TextMetrics {
	return measure_text(text, 'sm', 1.0, th)
}

// CullingLOD describes level of detail for large worlds.
pub enum LodLevel {
	full
	simplified
	clustered
}

// lod_for_count selects LOD based on node count (100+ → simplified, 1000+ → clustered).
pub fn lod_for_count(count int) LodLevel {
	if count >= 1000 {
		return .clustered
	}
	if count >= 100 {
		return .simplified
	}
	return .full
}

// cluster_nodes stubs clustering for large worlds (1000+).
pub fn cluster_nodes(nodes []WorldNode, lod LodLevel) []WorldNode {
	if lod == .full {
		return nodes.clone()
	}
	if lod == .clustered {
		// stub: sample every 10th node + cluster marker
		mut out := []WorldNode{cap: nodes.len / 10 + 1}
		for i, n in nodes {
			if i % 10 == 0 {
				out << n
			}
		}
		if out.len == 0 && nodes.len > 0 {
			out << nodes[0]
		}
		return out
	}
	// simplified: keep all but reduce detail flag could be set
	return nodes.clone()
}
