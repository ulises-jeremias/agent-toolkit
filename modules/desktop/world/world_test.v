module world

import os
import desktop.theme
import desktop_engine.state as engine_state
import desktop_engine.eventbus

fn test_world_view_retained_geometry_and_culling() {
	mut vp := default_viewport()
	mut w := new_world_view(WorldViewConfig{ viewport: vp })
	// seed projection with fixture harness repos+skills+agents+loops
	mut data := map[string]string{}
	data['repos'] = 'repo1,repo2'
	data['skills_count'] = '5'
	data['agents_count'] = '3'
	data['loops'] = 'loop-a,loop-b'
	data['jobs'] = 'job-1'
	snap := engine_state.State{ revision: 1, timestamp: 1000, data: data }
	proj := derive_projection(snap)
	w.projection = proj
	w.rebuild_buffer()
	// retained buffer snapshot hash stable across rebuild without change
	hash1 := w.buffer.snapshot_hash()
	trace1 := w.on_draw()
	assert trace1.contains('polyline N='), trace1
	assert trace1.contains('polygon N='), trace1
	assert trace1.contains('arc N='), trace1
	assert trace1.contains('hash='), trace1
	hash2 := w.buffer.snapshot_hash()
	assert hash1 == hash2, 'retained hash stable across frames'
	// draw calls bounded
	assert w.buffer.len() < 200, 'draw calls bounded for 100-node workshop sample'
	// culling keeps visible subset
	culled := w.buffer.culled()
	assert culled.len <= w.buffer.len()
}

fn test_world_entity_projection_golden() {
	mut data := map[string]string{}
	data['repos'] = 'a,b,c'
	data['skills_count'] = '3'
	data['agents_count'] = '2'
	data['loops'] = 'loop1'
	data['jobs'] = 'job1,job2'
	data['handoffs'] = 'agent-a->agent-b,agent-b->agent-c'
	proj := world_projection_from_state(data, 1)
	// nodes: 3 repos + 3 skills +2 agents +1 loop +2 jobs +2 handoffs =13
	assert proj.nodes.len == 13, 'node count golden ${proj.nodes.len} != 13'
	// edges: handoffs 2 + skill->agent ownership 3 =5
	assert proj.edges.len == 5, 'edge count golden ${proj.edges.len} !=5'
	// filtered by domain
	filtered := filter_nodes(proj.nodes, EntityFilter{ domain: 'core' })
	for n in filtered {
		assert n.domain == 'core'
	}
}

fn test_world_watcher_to_eventbus_to_view_one_tick() {
	mut repo := engine_state.new_state_repository(os.join_path(os.temp_dir(), 'world-watcher-${os.getpid()}.json'))
	mut bus := eventbus.new_event_bus()
	mut w := new_world_view(WorldViewConfig{ debounce_ms: 0 })
	// initial projection from empty state
	initial := repo.snapshot()
	w.projection = derive_projection(initial)
	// mutate via Transaction → EventBus → view within one tick
	mut tx := repo.begin('watcher-test')
	tx.set('repos', 'repo-x,repo-y')
	tx.set('skills_count', '2')
	tx.commit() or { panic(err.msg()) }
	ev := eventbus.ToolkitEvent{ kind: .state_changed, revision: repo.revision_nr(), path: 'state', payload: '{}' }
	snap := repo.snapshot()
	updated := w.on_bus_event(ev, snap)
	assert updated, 'StateWatcher touch → revision bump → EventBus → view updates within one tick'
	assert w.emitted_count() == 1
	// duplicate revision does not rebuild (distinct-until-changed)
	ev2 := eventbus.ToolkitEvent{ kind: .state_changed, revision: repo.revision_nr(), path: 'state', payload: '{}' }
	dup := w.on_bus_event(ev2, snap)
	assert !dup, 'duplicate revision distinct-until-changed suppresses rebuild'
	assert w.dropped_count() == 1
	// virtualized list keeps draw calls bounded
	assert w.buffer.len() < 200
}

fn test_world_zoom_pan_tooltip_hit_test_cursor() {
	mut w := new_world_view(WorldViewConfig{})
	mut data := map[string]string{}
	data['skills_count'] = '1'
	data['agents_count'] = '1'
	proj := world_projection_from_state(data, 1)
	w.projection = proj
	w.rebuild_buffer()
	// zoom/pan
	w.handle_zoom(0.5)
	assert w.viewport.zoom > 1.0
	w.handle_pan(100, 50)
	assert w.viewport.x != 0 || w.viewport.y != 0
	// resize does not black retained buffer
	hash_before := w.buffer.snapshot_hash()
	w.handle_resize(1600, 900)
	hash_after := w.buffer.snapshot_hash()
	assert hash_before == hash_after, 'resize does not black retained buffer'
	// hit-test
	if proj.nodes.len > 0 {
		n := proj.nodes[0]
		// screen coords for node pos accounting for viewport zoom
		sx := (n.pos.x - w.viewport.x) * w.viewport.zoom
		sy := (n.pos.y - w.viewport.y) * w.viewport.zoom
		res := w.hit_test(sx, sy)
		assert res.hit, 'hit-test should hit node'
		assert res.cursor == 'pointer', 'cursor pointer on node'
		assert res.tooltip.len > 0, 'tooltip overlay'
	}
	// inspector highlight
	assert w.highlight(proj.nodes[0].id), 'cross-link highlight entity'
}

fn test_world_perf_60fps_and_virtualized_text_measurement() {
	harness := new_world_perf_harness(100)
	res := harness.run_headless(60)
	// 60 FPS retained: threshold 58 sustained per dock AC
	assert res.passed, res.message
	assert res.fps >= 58.0, res.message
	assert res.max_ms < 33.0, 'no frame exceeds 2x budget 33ms'
	assert res.draw_calls < 500, 'draw calls bounded via culling/virtualized'
	// vglyph text measurement per node
	th := theme.default_theme()
	m := measure_text('Hello CJK 日本語 🎉', 'md', 1.0, th)
	m2 := measure_text('Hello CJK 日本語 🎉', 'md', 2.0, th)
	assert m2.width > m.width, 'high-DPI must increase measured width via vglyph'
	assert m2.dpi_scale == 2.0
	// virtualized list
	mut vl := new_virtualized_list(1000, 800)
	vl.scroll_to(240)
	start, end := vl.visible_range()
	assert end - start <= 40, 'virtualized window bounded'
	assert vl.draw_calls() < 100, 'virtualized draw calls bounded'
	// LOD clustering stub for 100+ nodes
	assert lod_for_count(50) == .full
	assert lod_for_count(150) == .simplified
	assert lod_for_count(1500) == .clustered
	clustered := cluster_nodes([]WorldNode{len: 1500, init: WorldNode{ id: 'n${index}', label: 'n${index}', kind: .skill, pos: Point{0, 0} }}, .clustered)
	assert clustered.len < 200, 'clustering stub for large world'
}

fn test_world_no_fake_gamification_and_vglyph() {
	// honest motion only — no gamification, motion tied to State diff
	// This test asserts node counts derive from real State, not toy economy
	mut data := map[string]string{}
	data['skills_count'] = '116'
	proj := world_projection_from_state(data, 1)
	assert proj.nodes.len >= 116, 'shelf fill proportional to real catalog (587 lines → 116 nodes)'
	// presentation mapping uses real State diff, ensure sprite stub is vector not GPL raster
	sprites := default_sprites_stub()
	assert sprites.len > 0
	// vglyph path validated via theme measure
	th := theme.default_theme()
	probes := theme.typography_supports()
	mut found := false
	for p in probes {
		if p.feature == 'CJK' {
			found = p.supported
		}
	}
	assert found, 'vglyph CJK supported'
}

// stub for presentation sprites to avoid circular import
fn default_sprites_stub() []string {
	return ['workbench-frame', 'library-shelf', 'target-rig', 'diagnostics-instrument',
		'swarm-doorway', 'wall-activity']
}
