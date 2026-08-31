module agent_toolkit_gui

fn test_ping() {
	assert ping() == 'ok'
}

fn test_spike_version() {
	assert spike_version() == 'phase0-spike-1018-v-master'
}

fn test_hello_world_available() {
	assert hello_world_available() == true
}

fn test_default_gui_config() {
	cfg := default_gui_config()
	assert cfg.title.len > 0
	assert cfg.width == 1280
	assert cfg.height == 800
	cfg.validate() or { panic(err) }
}

fn test_gui_config_validate_rejects_empty_title() {
	cfg := GuiConfig{
		title: ''
		width: 800
		height: 600
	}
	if _ := cfg.validate() {
		assert false, 'expected error for empty title'
	} else {
		assert err.msg().len > 0
	}
}

fn test_gui_config_validate_rejects_tiny() {
	cfg := GuiConfig{
		title: 't'
		width: 10
		height: 10
	}
	if _ := cfg.validate() {
		assert false, 'expected error for tiny window'
	} else {
		assert true
	}
}

fn test_vendoring_plan() {
	plan := vendoring_plan()
	assert plan.contains('VMODULES=modules')
	assert plan.contains('vlang/gui')
}

fn test_gap_matrix_sizes() {
	widgets := default_gap_matrix()
	assert widgets.len == 10
	native := native_probe_entries()
	assert native.len == 8
	win := windows_limitations()
	assert win.len == 4
	all := gap_matrix_all()
	assert all.len == 10 + 8 + 4
}

fn test_gap_matrix_status_coverage() {
	all := gap_matrix_all()
	mut has_supported := false
	mut has_partial := false
	mut has_missing := false
	for e in all {
		match e.status {
			.supported { has_supported = true }
			.partial { has_partial = true }
			.missing { has_missing = true }
		}
		assert e.widget.len > 0
		assert e.mitigation.len > 0
		assert e.upstream_ref.len > 0
	}
	assert has_supported
	assert has_partial
	assert has_missing
}

fn test_gap_matrix_markdown_contains_headers() {
	md := gap_matrix_markdown()
	assert md.contains('Required widget')
	assert md.contains('Status')
	assert md.contains('Mitigation')
	assert md.contains('Window + flexbox')
	assert md.contains('Data-grid')
}

fn test_native_probe_markdown() {
	md := native_probe_markdown()
	assert md.contains('Native surface')
	assert md.contains('clipboard')
}

fn test_windows_probe_markdown() {
	md := windows_probe_markdown()
	assert md.contains('Windows limitation')
	assert md.contains('MSVC')
}

fn test_perf_harness_1000_widgets_60fps() {
	h := new_perf_harness(1000)
	res := h.run_headless(60)
	assert res.samples.len == 60
	assert res.fps > 0
	assert res.avg_dt_ms > 0
	assert res.max_dt_ms > 0
	// Threshold is 58 FPS sustained on 1000 widgets (dock requirement 58+)
	assert res.passed, res.message
	assert res.fps >= pass_threshold_fps()
}

fn test_perf_harness_default_widget_count() {
	h := new_perf_harness(0)
	assert h.widget_count == 1000
	h2 := new_perf_harness(-5)
	assert h2.widget_count == 1000
}

fn test_perf_target_constants() {
	assert target_frame_ms() > 16.0 && target_frame_ms() < 17.0
	assert pass_threshold_fps() == 58.0
}

fn test_perf_artifact_json() {
	h := new_perf_harness(1000)
	res := h.run_headless(10)
	j := res.artifact_json()
	assert j.contains('widget_count')
	assert j.contains('fps')
	assert j.contains('passed')
}

fn test_native_probe_headless_safe() {
	r := probe_native()
	assert r.probes.len == 7
	assert r.windows_md.len > 0
	summary := r.summary()
	assert summary.contains('native probe')
	md := r.markdown()
	assert md.contains('Surface')
	assert md.contains('Windows limitation')
}

fn test_smoke_message() {
	cfg := GuiConfig{
		title: 'test'
		width: 800
		height: 600
		headless: true
	}
	h := new_perf_harness(1000)
	res := h.run_headless(5)
	msg := smoke_message(cfg, res)
	assert msg.contains('test')
	assert msg.contains('headless')
}

fn test_gap_entry_labels() {
	assert GuiStatus.supported.label().contains('supported')
	assert GuiStatus.partial.label().contains('partial')
	assert GuiStatus.missing.label().contains('missing')
	assert GuiStatus.supported.icon() == '✅'
	assert GuiStatus.partial.icon() == '⚠️'
	assert GuiStatus.missing.icon() == '❌'
}
