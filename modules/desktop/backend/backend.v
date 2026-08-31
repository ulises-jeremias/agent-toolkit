module backend

// LocalBackend seam — thin abstraction over OS platform services.
// Headless implementations never call sokol/gui directly; native impls are
// injected via this interface. Keeps desktop headless-testable and plane-pure.
//
// Real platform dialogs/clipboard/DnD/notifications are thin wrappers in
// backend/native_*.v (future EPIC 7); headless tests use HeadlessBackend.
pub interface LocalBackend {
mut:
	open_dialog(filter string) ?string
	save_dialog(filter string) ?string
	read_clipboard() string
	write_clipboard(text string) bool
	show_toast(message string)
}

// HeadlessBackend is the default CI/test backend — no OS calls.
// All native surfaces return stubs without blocking; headless probe compatible.
pub struct HeadlessBackend {
mut:
	clipboard string
	toasts    []string
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

// read_clipboard returns stub buffer.
pub fn (mut b HeadlessBackend) read_clipboard() string {
	return b.clipboard
}

// write_clipboard stores in headless buffer.
pub fn (mut b HeadlessBackend) write_clipboard(text string) bool {
	b.clipboard = text
	return true
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
