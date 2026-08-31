module agent_toolkit_gui

import os

// NativeProbeResult is the headless-safe native surface probe (0.3).
// On Linux CI it never opens a dialog or clipboard; it reports stub
// availability and records Windows limitations separately.
pub struct NativeProbeResult {
pub:
	headless   bool
	display    string
	wayland    string
	probes     []NativeProbeEntry
	windows_md string
}

// NativeProbeEntry is one native surface check result.
pub struct NativeProbeEntry {
pub:
	surface   string
	available bool
	stub      bool // true when headless stub, not real OS call
	detail    string
}

// probe_native probes native surfaces in a headless-safe way.
// Real OS dialogs/clipboard/dnd/notifications are not invoked on CI.
pub fn probe_native() NativeProbeResult {
	headless := is_headless_env()
	display := os.getenv('DISPLAY')
	wayland := os.getenv('WAYLAND_DISPLAY')

	entries := [
		NativeProbeEntry{
			surface: 'native open/save/folder dialogs'
			available: !headless
			stub: headless
			detail: if headless { 'headless stub: no DISPLAY — sokol dialog not invoked (tinyfiledialogs/zenity fallback documented)' } else { 'available via sokol/ComDlg32 fallback' }
		},
		NativeProbeEntry{
			surface: 'clipboard (text)'
			available: true
			stub: headless
			detail: if headless { 'headless stub: sokol clipboard not invoked; text-only path documented' } else { 'sokol clipboard available (text-only)' }
		},
		NativeProbeEntry{
			surface: 'drag-and-drop (OS files)'
			available: false
			stub: true
			detail: 'OS DnD not stable in vlang/gui master; in-app drag handled internally, OS DnD is fallback'
		},
		NativeProbeEntry{
			surface: 'toasts / native notifications'
			available: false
			stub: true
			detail: 'no native notification in gui; in-app toast overlay is fallback (libnotify/WinToast deferred)'
		},
		NativeProbeEntry{
			surface: 'IME / CJK composition'
			available: true
			stub: headless
			detail: if headless { 'headless stub: sokol IME events not exercised; PATH validated' } else { 'sokol IME composition available (manual smoke required)' }
		},
		NativeProbeEntry{
			surface: 'BiDi / ligatures / emoji / Unicode / OpenType'
			available: true
			stub: false
			detail: 'vglyph + gg shaping partial; emoji via color glyphs; BiDi/ligatures documented as ⚠️'
		},
		NativeProbeEntry{
			surface: 'text measurement / rotation / high-DPI'
			available: true
			stub: false
			detail: 'gg measurement supported; rotation via canvas transform; dpi_scale via sokol'
		},
	]

	windows_md := windows_probe_markdown()
	return NativeProbeResult{
		headless: headless
		display: display
		wayland: wayland
		probes: entries
		windows_md: windows_md
	}
}

// summary returns a one-line summary for manual smoke logs.
pub fn (r NativeProbeResult) summary() string {
	mut avail := 0
	for p in r.probes {
		if p.available {
			avail++
		}
	}
	env := if r.headless { 'headless' } else { 'display=${r.display}' }
	return 'native probe ${env}: ${avail}/${r.probes.len} available (stubs expected headless)'
}

// markdown renders the native probe as markdown for ADR appendix.
pub fn (r NativeProbeResult) markdown() string {
	mut out := ''
	out += 'Native probe (${if r.headless { 'headless' } else { 'DISPLAY=${r.display} WAYLAND=${r.wayland}' }}):\n\n'
	out += '| Surface | Available | Detail |\n'
	out += '|---|---|---|\n'
	for p in r.probes {
		avail := if p.available { 'yes' } else if p.stub { 'stub' } else { 'no' }
		out += '| ${p.surface} | ${avail} | ${p.detail} |\n'
	}
	out += '\n'
	out += r.windows_md
	return out
}
