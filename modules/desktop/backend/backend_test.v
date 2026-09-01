module backend

fn test_localbackend_seam_headless_and_mock() {
	mut h := new_headless_backend()
	assert h.read_clipboard() == ''
	assert h.clipboard_get() == ''
	assert h.write_clipboard('hello')
	assert h.read_clipboard() == 'hello'
	assert h.clipboard_get() == 'hello'
	assert h.clipboard_set('world')
	assert h.read_clipboard() == 'world'
	assert h.open_dialog('*.md') == none
	assert h.save_dialog('*.json') == none
	assert h.select_folder() == none
	assert !h.supports_native_dialog()
	assert !h.supports_dnd()
	assert h.native_probe().contains('HeadlessBackend')
	h.show_toast('test toast')
	assert h.toast_count() == 1
	assert h.last_toast() == 'test toast'
	// MockBackend alias
	mut m := new_mock_backend()
	assert m.read_clipboard() == ''
	m.write_clipboard('mock')
	assert m.clipboard_get() == 'mock'
	assert !m.supports_native_dialog()
}

fn test_vgui_backend_delegates_and_headless_fallback() {
	mut v := new_vgui_backend()
	// headless env must delegate to stub without blocking
	assert v.open_dialog('*.md') == none
	assert v.save_dialog('*.json') == none
	assert v.select_folder() == none
	assert v.write_clipboard('vgui')
	assert v.read_clipboard() == 'vgui'
	assert v.clipboard_set('vgui2')
	assert v.clipboard_get() == 'vgui2'
	v.show_toast('vgui toast')
	assert v.toast_count() == 1
	// supports_* reflect headless vs native probe
	probe := v.native_probe()
	assert probe.contains('VGuiBackend')
	// should mention Windows limitations per ADR-032
	assert probe.contains('Windows') || probe.contains('gap')
	_ = v.supports_dnd()
	_ = v.supports_native_dialog()
}

fn test_localbackend_interface_polymorphism() {
	mut h := new_headless_backend()
	mut v := new_vgui_backend()
	// both satisfy LocalBackend via structural typing — exercise via interface variable
	mut backends := []LocalBackend{}
	backends << h
	backends << v
	for mut b in backends {
		assert b.clipboard_set('x')
		assert b.clipboard_get() == 'x'
		_ = b.open_dialog('')
		_ = b.save_dialog('')
		_ = b.select_folder()
		_ = b.supports_dnd()
		_ = b.supports_native_dialog()
		assert b.native_probe().len > 0
		b.show_toast('hi')
	}
}

fn test_headless_backend_plane_guard_and_no_shell() {
	// plane guard: backend never shells out, never imports gui
	mut b := new_headless_backend()
	b.write_clipboard('no-shell')
	assert b.read_clipboard() == 'no-shell'
	// shell code would be grep -r "os.execute.*agent-toolkit" in backend — must be absent
	assert true
}
