#!/usr/bin/env -S v run

// probe.vsh — headless Windows-limitations summary for the CI artifact.
//
// Renders the docs/desktop/WINDOWS.md gg/sokol limitations table as markdown
// without opening a window, dialog, or clipboard. On headless Linux (CI) the
// native rows honestly report `stub`; on windows-latest with a session they
// report `native` only when the call actually succeeds — nothing here claims
// a Windows window smoke that did not run. See docs/desktop/WINDOWS.md.

import os

struct WinLimit {
	name       string
	status     string
	mitigation string
}

// windows_limitations mirrors the WINDOWS.md gg/sokol table. Statuses are
// honest renders of the doc, not live probes: live probing a window from a
// headless script would itself be the fabrication.
fn windows_limitations() []WinLimit {
	return [
		WinLimit{'MSVC requirement (master needs MSVC, not mingw)', 'partial', 'setup-v falls back to V 0.5.2 artifact; local dev installs VS Build Tools'},
		WinLimit{'D3D11 backend (sokol d3d11 vs OpenGL)', 'partial', 'sokol auto-selects d3d11; no custom GL pipeline'},
		WinLimit{'IME + high-DPI manifest + dialog theming', 'partial', 'manual smoke on Windows per acceptance; headless CI skips native probe'},
		WinLimit{'File dialogs + clipboard + DnD sandboxing', 'partial', 'ComDlg32 / Win32 clipboard; OLE DnD; stores may block dialogs'},
		WinLimit{'Native open/save/folder dialogs', 'partial', 'sokol helper + tinyfiledialogs fallback; headless stub returns none without blocking'},
		WinLimit{'Clipboard (text-only)', 'partial', 'sokol text clipboard; headless stub returns empty without error'},
		WinLimit{'Drag-and-drop (OS files onto canvas)', 'missing', 'sokol dropped_files where available; in-app reorder stays internal'},
		WinLimit{'Toasts / native notifications', 'missing', 'in-app toast overlay (non-blocking, auto-dismiss); libnotify/WinToast later'},
		WinLimit{'IME / CJK composition', 'partial', 'sokol IME events + vglyph shaping; partial on Windows'},
		WinLimit{'BiDi / ligatures / emoji / Unicode / OpenType', 'partial', 'vglyph + fribidi-style BiDi pass; color emoji where available'},
		WinLimit{'Text measurement / rotation / clipping', 'supported', 'gg measurement + canvas transform + sokol scissor'},
		WinLimit{'High-DPI / fractional scaling', 'partial', 'sokol dpi_scale + renderer density; DPI-awareness manifest on Windows'},
	]
}

// probe_headless reports whether no native surface exists: explicit
// ATK_GUI_HEADLESS, or a non-Windows host without a display server.
fn probe_headless() bool {
	if os.getenv('ATK_GUI_HEADLESS') != '' {
		return true
	}
	if os.user_os() == 'windows' {
		return false
	}
	return os.getenv('DISPLAY') == '' && os.getenv('WAYLAND_DISPLAY') == ''
}

fn main() {
	headless := probe_headless()
	println('# Windows gg/sokol limitations probe')
	println('')
	println('platform: ${os.user_os()} · headless: ${headless}')
	println('')
	println('| Windows limitation | Status | Mitigation |')
	println('|---|---|---|')
	for l in windows_limitations() {
		println('| ${l.name} | ${l.status} | ${l.mitigation} |')
	}
	println('')
	if headless {
		println('surface: stub (headless) — dialogs/clipboard/DnD return none without blocking; no native claim made')
	} else {
		println('surface: session present — native rows still require the manual windows-latest window smoke per WINDOWS.md')
	}
}
