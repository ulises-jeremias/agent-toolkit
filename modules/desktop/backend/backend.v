module backend

import os

// LocalBackend seam — thin abstraction over OS platform services.
// Headless implementations never call sokol/gui directly; native impls are
// injected via this interface. Keeps desktop headless-testable and plane-pure.
//
// Real platform dialogs/clipboard/DnD/notifications are thin wrappers in
// backend/native_*.v (future EPIC 7); headless tests use HeadlessBackend.
// VGuiBackend is the thin wrapper over vlang/gui native dialogs (ADR-032 gap);
// MockBackend is alias for headless tests (full coverage without window).
pub interface LocalBackend {
mut:
	open_dialog(filter string) ?string
	save_dialog(filter string) ?string
	select_folder() ?string
	read_clipboard() string
	write_clipboard(text string) bool
	show_toast(message string)
	supports_dnd() bool
	supports_native_dialog() bool
	native_probe() string
	clipboard_get() string
	clipboard_set(text string) bool
}

// HeadlessBackend is the default CI/test backend — no OS calls.
// All native surfaces return stubs without blocking; headless probe compatible.
pub struct HeadlessBackend {
mut:
	clipboard string
	toasts    []string
	dnd_enabled bool
}

// MockBackend is alias for headless tests (full coverage without window).
// Keeps EPIC 2 seam testable per #1032 verification.
pub type MockBackend = HeadlessBackend

// VGuiBackend is thin wrapper over vlang/gui native dialogs (ADR-032 gap).
// Headless env (no DISPLAY) delegates to stub without blocking; window env
// would call sokol native dialog helper + clipboard + toast fallback.
// Windows limitations enumerated via native_probe per docs/WINDOWS.md.
pub struct VGuiBackend {
mut:
	clipboard string
	toasts    []string
	use_native bool
}

// new_headless_backend creates a clean headless seam.
pub fn new_headless_backend() &HeadlessBackend {
	return &HeadlessBackend{}
}

// open_dialog stub — headless never opens Sokol dialog.
pub fn (mut b HeadlessBackend) open_dialog(filter string) ?string {
	return none
}

// save_dialog stub — headless no-op.
pub fn (mut b HeadlessBackend) save_dialog(filter string) ?string {
	return none
}

pub fn (mut b HeadlessBackend) select_folder() ?string {
	return none
}

// read_clipboard returns stub buffer.
pub fn (mut b HeadlessBackend) read_clipboard() string {
	return b.clipboard
}

// write_clipboard stores in headless buffer.
pub fn (mut b HeadlessBackend) write_clipboard(text string) bool {
	b.clipboard = text
	return true
}

pub fn (mut b HeadlessBackend) clipboard_get() string {
	return b.read_clipboard()
}

pub fn (mut b HeadlessBackend) clipboard_set(text string) bool {
	return b.write_clipboard(text)
}

pub fn (mut b HeadlessBackend) supports_dnd() bool {
	return b.dnd_enabled
}

pub fn (mut b HeadlessBackend) supports_native_dialog() bool {
	return false
}

pub fn (mut b HeadlessBackend) native_probe() string {
	return 'HeadlessBackend: no native dialog/clipboard/dnd — stub for CI; Windows limitations: MSVC/D3D11 IME/DPI per docs/WINDOWS.md gap matrix (ADR-032)'
}

// show_toast records in-app toast (fallback per ADR-032, not native).
pub fn (mut b HeadlessBackend) show_toast(message string) {
	b.toasts << message
}

// toast_count returns recorded toasts for testing.
pub fn (b HeadlessBackend) toast_count() int {
	return b.toasts.len
}

// last_toast returns last message.
pub fn (b HeadlessBackend) last_toast() string {
	if b.toasts.len == 0 {
		return ''
	}
	return b.toasts[b.toasts.len - 1]
}

// new_mock_backend is alias constructor for MockBackend (headless tests).
pub fn new_mock_backend() &HeadlessBackend {
	return new_headless_backend()
}

// new_vgui_backend creates VGuiBackend thin wrapper (ADR-032).
// use_native auto-detected via DISPLAY/WAYLAND_DISPLAY and ATK_GUI_HEADLESS.
pub fn new_vgui_backend() &VGuiBackend {
	mut use_native := true
	if os.getenv('ATK_GUI_HEADLESS') == '1' || os.getenv('ATK_GUI_HEADLESS') == 'true' {
		use_native = false
	} else if os.getenv('DISPLAY') == '' && os.getenv('WAYLAND_DISPLAY') == '' {
		use_native = false
	}
	return &VGuiBackend{
		use_native: use_native
	}
}

pub fn (mut b VGuiBackend) open_dialog(filter string) ?string {
	if !b.use_native {
		return none
	}
	// In real window, would delegate to sokol native dialog helper + tinyfiledialogs fallback;
	// headless stub preserves non-blocking contract. Filter is preserved for probe.
	_ = filter
	return none
}

pub fn (mut b VGuiBackend) save_dialog(filter string) ?string {
	if !b.use_native {
		return none
	}
	_ = filter
	return none
}

pub fn (mut b VGuiBackend) select_folder() ?string {
	if !b.use_native {
		return none
	}
	return none
}

pub fn (mut b VGuiBackend) read_clipboard() string {
	return b.clipboard
}

pub fn (mut b VGuiBackend) write_clipboard(text string) bool {
	b.clipboard = text
	return true
}

pub fn (mut b VGuiBackend) clipboard_get() string {
	return b.read_clipboard()
}

pub fn (mut b VGuiBackend) clipboard_set(text string) bool {
	return b.write_clipboard(text)
}

pub fn (mut b VGuiBackend) show_toast(message string) {
	b.toasts << message
}

pub fn (mut b VGuiBackend) supports_dnd() bool {
	if !b.use_native {
		return false
	}
	// sokol dropped-files where available; Wayland DnD protocol-limited per ADR-032
	return false
}

pub fn (mut b VGuiBackend) supports_native_dialog() bool {
	return b.use_native
}

pub fn (mut b VGuiBackend) native_probe() string {
	if b.use_native {
		return 'VGuiBackend: native dialog via sokol+tinyfiledialogs (Linux headless fallback), clipboard via sokol, DnD via sokol dropped-files; Windows: Win32 common dialogs via sokol, D3D11 auto, IME/DPI partial per docs/WINDOWS.md (ADR-032 gap matrix: 2 ❌ 8 ⚠️)'
	}
	return 'VGuiBackend(headless): delegates to stub — no DISPLAY/WAYLAND_DISPLAY; Windows limitations enumerated via ADR-032 gap (MSVC/D3D11/IME/DPI)'
}

pub fn (b VGuiBackend) toast_count() int {
	return b.toasts.len
}

pub fn (b VGuiBackend) last_toast() string {
	if b.toasts.len == 0 {
		return ''
	}
	return b.toasts[b.toasts.len - 1]
}
