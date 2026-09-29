module main

// Measured text fitting: fit_text/fit_chars/measure_text must fit from real
// widths, never from the old fixed-average heuristic. Tests run gg-less
// (&GuiApp{} has a nil gg context): a fake monospace cache (7px/rune)
// stands in for gg measurements, and cache-miss paths fall back to est_adv.

const fake_adv = 7.0

fn fake_mono_app(s string, size int) GuiApp {
	mut app := GuiApp{}
	app.global_zoom = 1.0
	rs := s.runes()
	for i in 1 .. rs.len + 1 {
		p := rs[..i].string()
		app.text_measure_cache[measure_key(size, false, false, 1.0, p)] = f32(i) * fake_adv
	}
	app.text_measure_cache[measure_key(size, false, false, 1.0, '…')] = fake_adv
	return app
}

fn test_measure_key_separates_configs() {
	a := measure_key(12, false, false, 1.0, 'x')
	assert measure_key(13, false, false, 1.0, 'x') != a
	assert measure_key(12, true, false, 1.0, 'x') != a
	assert measure_key(12, false, true, 1.0, 'x') != a
	assert measure_key(12, false, false, 1.5, 'x') != a, 'zoom must key the cache'
	assert measure_key(12, false, false, 1.0, 'y') != a
}

fn test_measure_text_cache_hit_needs_no_gg() {
	mut app := GuiApp{}
	app.global_zoom = 1.0
	app.text_measure_cache[measure_key(12, false, false, 1.0, 'hello')] = 33.5
	assert measure_text(mut app, 'hello', 12, false, false) == 33.5
	assert measure_text(mut app, '', 12, false, false) == 0
}

fn test_measure_text_nil_gg_falls_back_to_estimate() {
	mut app := GuiApp{}
	app.global_zoom = 1.0
	// 5 runes × est_adv(12)=7 — the fallback, never gg.
	assert measure_text(mut app, 'hello', 12, false, false) == 35.0
}

fn test_fit_text_returns_whole_when_it_fits() {
	mut app := fake_mono_app('hi', 12)
	assert fit_text(mut app, 'hi', 40, 12, false, false) == 'hi'
	assert fit_text(mut app, '', 40, 12, false, false) == ''
	assert fit_text(mut app, 'hi', 0, 12, false, false) == ''
}

fn test_fit_text_truncates_to_measured_budget() {
	mut app := fake_mono_app('hello world', 12)
	// px=34: full is 77px; budget after '…'(7px) is 27px → 3 runes + '…'.
	// The old heuristic (text_fit_chars(34,12)=4, silent cut) gave 'hell'.
	assert fit_text(mut app, 'hello world', 34, 12, false, false) == 'hel…'
}

fn test_fit_text_never_splits_multibyte() {
	mut app := fake_mono_app('áéíóú', 12)
	got := fit_text(mut app, 'áéíóú', 20, 12, false, false)
	assert got.runes().len <= 3
	assert got.ends_with('…')
}

fn test_fit_chars_uses_measured_average() {
	mut app := GuiApp{}
	app.global_zoom = 1.0
	abc := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,—…'
	app.text_measure_cache[measure_key(12, false, false, 1.0, abc)] = f32(abc.runes().len) * fake_adv
	assert fit_chars(mut app, 40, 12, false, false) == 5
	assert fit_chars(mut app, 0, 12, false, false) == 0
}
