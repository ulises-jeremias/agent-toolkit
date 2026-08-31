module agent_toolkit_gui

// GuiStatus classifies vlang/gui readiness for a required widget/surface.
pub enum GuiStatus {
	supported // ✅ native in vlang/gui
	partial   // ⚠️ partial / experimental / OS-limited
	missing   // ❌ not present, needs wrapper/fallback
}

// label returns the human-readable status string.
pub fn (s GuiStatus) label() string {
	return match s {
		.supported { '✅ supported' }
		.partial { '⚠️ partial' }
		.missing { '❌ missing' }
	}
}

// icon returns the emoji icon for the status.
pub fn (s GuiStatus) icon() string {
	return match s {
		.supported { '✅' }
		.partial { '⚠️' }
		.missing { '❌' }
	}
}

// GapEntry is one row of the widget / native gap matrix (0.2 + 0.3).
pub struct GapEntry {
pub:
	widget       string // required capability
	category     string // docking | canvas | grid | markdown | menus | native | i18n | perf
	status       GuiStatus
	mitigation   string // wrap / fallback / custom canvas
	upstream_ref string // vlang/gui README / docs/ROADMAP.md / example / V stdlib
	notes        string
}

// default_gap_matrix returns the Phase 0 widget gap matrix (0.2).
// Covers: docking/drag-targets, canvas on_draw + retained buffer,
// data-grid/table, virtualized list/tree, markdown + syntax-highlighted code,
// menus/menubar/tabs/splitters/dialogs.
pub fn default_gap_matrix() []GapEntry {
	return [
		GapEntry{
			widget: 'Window + flexbox layout (row/column)'
			category: 'layout'
			status: .supported
			mitigation: 'Adopt as-is; vlang/gui Window + column/row + spacing (snake.v, dock_layout.v baseline)'
			upstream_ref: 'https://github.com/vlang/gui (README, examples/dock_layout.v)'
			notes: 'Baseline windowing and flexbox nesting validated on V master (gg/sokol)'
		},
		GapEntry{
			widget: 'Docking + drag docking targets + splitters + tabs'
			category: 'docking'
			status: .partial
			mitigation: 'Wrap: adopt gui dock_layout.v for chrome; custom drag-target layer + splitter gesture + tab bar; persist derived layout in SQLite (not canonical)'
			upstream_ref: 'vlang/gui examples/dock_layout.v, docs/ROADMAP.md (docking experimental)'
			notes: 'ROADMAP lists docking as experimental; drag targets lack persistence; splitter is manual'
		},
		GapEntry{
			widget: 'Canvas on_draw + retained geometry buffer (SDF/shadows/blur)'
			category: 'canvas'
			status: .partial
			mitigation: 'Wrap: use on_draw for immediate mode; own retained buffer (geometry list + culling) atop sokol; SDF shadows via custom shader if needed'
			upstream_ref: 'vlang/gui on_draw, examples/snake.v, vlib/sokol, vlib/gg'
			notes: 'on_draw exists; retained mode is caller-owned; shader/SVG stance deferred to ADR (wrap, not custom GL pipeline)'
		},
		GapEntry{
			widget: 'Data-grid / table (sortable, virtualized columns)'
			category: 'grid'
			status: .missing
			mitigation: 'Fallback canvas: virtualized row renderer + column layout in on_draw; reuse virtualized list harness; header sort via state filter'
			upstream_ref: 'vlang/gui docs/ROADMAP.md — no native grid widget'
			notes: 'Highest gap; grid must be built as canvas composition, not native widget'
		},
		GapEntry{
			widget: 'Virtualized list (1000+ rows, variable height)'
			category: 'virtualized'
			status: .partial
			mitigation: 'Wrap: viewport culling + row pool; measure via vglyph/Pango path; validate 1000-widget @ 60 FPS harness (perf.v)'
			upstream_ref: 'vlang/gui list example; vglyph/vlib/gg text measurement'
			notes: 'No built-in virtualization; achievable with culling + retained buffer; 60 FPS gate is 58+ sustained'
		},
		GapEntry{
			widget: 'Virtualized tree (collapsed/expanded nodes, 1000 nodes)'
			category: 'virtualized'
			status: .partial
			mitigation: 'Wrap: tree as virtualized list with indent + expand state in AppState; same culling as list'
			upstream_ref: 'vlang/gui tree example (experimental)'
			notes: 'Tree shares list virtualization path; expand state must be distinct-until-changed'
		},
		GapEntry{
			widget: 'Markdown + syntax-highlighted code blocks'
			category: 'markdown'
			status: .missing
			mitigation: 'Fallback: markdown parse → gui text runs (headings/bold/code) + external highlighter (e.g. tree-sitter or V highlighter) emitting styled spans; no webview'
			upstream_ref: 'vlang/gui — no markdown widget'
			notes: 'Out-of-scope Electron/webview per #1007; V-native markdown renderer required'
		},
		GapEntry{
			widget: 'Menus / menubar / context menu'
			category: 'menus'
			status: .partial
			mitigation: 'Wrap: app-level menu bar via row + popup overlay; context menu is overlay with focus trap; keyboard shortcuts via sokol key events'
			upstream_ref: 'vlang/gui menu example, vlib/sokol key handling'
			notes: 'Menubar not native OS menu; in-app only until native probe proves otherwise'
		},
		GapEntry{
			widget: 'Tabs + splitters + resizable panels'
			category: 'menus'
			status: .partial
			mitigation: 'Wrap: tab bar widget + splitter drag handle; flex weights updated via state; retained geometry for divider hit-test'
			upstream_ref: 'vlang/gui examples/dock_layout.v (tabs experimental)'
			notes: 'Splitters require manual pointer handling; tabs share docking chrome'
		},
		GapEntry{
			widget: 'Dialogs (in-app modal/alert/confirm)'
			category: 'dialogs'
			status: .partial
			mitigation: 'Wrap: modal overlay + focus trap + escape handling; reuses dialog primitives; not native yet'
			upstream_ref: 'vlang/gui dialog example'
			notes: 'In-app dialogs covered; native file dialogs are separate (native probe)'
		},
	]
}

// native_probe_entries returns the native surface probe matrix (0.3).
// Covers: native open/save/folder dialogs, clipboard, drag-and-drop,
// toasts/native notifications, IME/CJK, BiDi/ligatures/emoji,
// Unicode/OpenType, text measurement/rotation, high-DPI + Windows limits.
pub fn native_probe_entries() []GapEntry {
	return [
		GapEntry{
			widget: 'Native open / save / folder dialogs'
			category: 'native'
			status: .partial
			mitigation: 'Adopt sokol native dialog helper + tinyfiledialogs fallback; Windows: use Win32 common dialogs (via sokol); vet on Linux headless returns stub without blocking'
			upstream_ref: 'vlang/gui docs/WINDOWS.md, sokol_app native dialogs'
			notes: 'Linux uses zenity/kdialog fallback when DISPLAY unset; headless probe must not crash'
		},
		GapEntry{
			widget: 'Clipboard (copy/paste text + code)'
			category: 'native'
			status: .partial
			mitigation: 'Wrap sokol clipboard (text only); on Wayland/X11 verify via wl-copy/xclip bridge; headless stub returns empty without error'
			upstream_ref: 'vlib/sokol clipboard, vlang/gui clipboard example'
			notes: 'Image/rich clipboard not in scope Phase 0; text clipboard via sokol is partial on Linux'
		},
		GapEntry{
			widget: 'Drag-and-drop (files + text onto canvas)'
			category: 'native'
			status: .missing
			mitigation: 'Fallback: sokol dropped-files event where available; Wayland DnD is protocol-limited; in-app reorder remains internal drag, not OS DnD'
			upstream_ref: 'sokol_app dropped_files, vlang/gui DnD issue (no stable API)'
			notes: 'OS DnD not stable in gui master; defer to fallback; EPIC 7 enumerates Windows DnD limits'
		},
		GapEntry{
			widget: 'Toasts / native notifications'
			category: 'native'
			status: .missing
			mitigation: 'Fallback in-app toast overlay (non-blocking, auto-dismiss, reduced-motion instant); native libnotify/WinToast later, not Phase 0'
			upstream_ref: 'vlang/gui — no notification API; sokol_app'
			notes: 'No second toolkit; in-app toasts satisfy spike; native remains fallback per ADR'
		},
		GapEntry{
			widget: 'IME / CJK input'
			category: 'i18n'
			status: .partial
			mitigation: 'Wrap: rely on sokol IME composition events + vglyph shaping; test CJK composition on Linux/macOS; Windows IME via sokol_app composes partially'
			upstream_ref: 'sokol_app IME, vglyph, vlang/gui text input example, docs/WINDOWS.md IME notes'
			notes: 'IME composition events exist but require manual handling; verified via manual smoke'
		},
		GapEntry{
			widget: 'BiDi / ligatures / emoji / Unicode / OpenType'
			category: 'i18n'
			status: .partial
			mitigation: 'Wrap: vglyph + HarfBuzz-equivalent via sokol font path; emoji as color glyphs where available; BiDi via fribidi-style pass; ligatures via OpenType shaping stub'
			upstream_ref: 'vglyph, vlib/gg, HarfBuzz (external), vlang/gui typography'
			notes: 'Full BiDi/ligature shaping is partial on V master; spike records gap + mitigation, not production shaper'
		},
		GapEntry{
			widget: 'Text measurement / rotation / clipping'
			category: 'i18n'
			status: .supported
			mitigation: 'Adopt gg text measurement + vglyph metrics; rotation via canvas transform; clipping via sokol scissor'
			upstream_ref: 'vlib/gg text measurement, examples/snake.v canvas'
			notes: 'Measurement validated; rotation is transform-based, not glyph-level until shader stance decided'
		},
		GapEntry{
			widget: 'High-DPI / fractional scaling'
			category: 'native'
			status: .partial
			mitigation: 'Adopt sokol dpi_scale + gui density; test fractional 125%/150% on Linux/Wayland; Windows high-DPI quirks per WINDOWS.md (DPI awareness manifest)'
			upstream_ref: 'sokol dpi_scale, gui layout density, vlang/gui docs/WINDOWS.md high-DPI'
			notes: 'DPR >1 requires retained geometry scaling; Windows needs manifest DPI_AWARE; enumerate in ADR'
		},
	]
}

// windows_limitations enumerates Windows-specific limitations per vlang/gui/docs/WINDOWS.md.
// Kept as GapEntries with category windows for markdown rendering.
pub fn windows_limitations() []GapEntry {
	return [
		GapEntry{
			widget: 'Windows MSVC requirement (master needs MSVC, not mingw)'
			category: 'windows'
			status: .partial
			mitigation: 'ADR-031 fallback: on Windows CI/setup-v falls back to V 0.5.2 artifact when master requires MSVC; local dev installs Visual Studio Build Tools; document in ADR'
			upstream_ref: 'vlang/gui docs/WINDOWS.md (MSVC vs mingw), .github/actions/setup-v master branch Windows fallback'
			notes: 'setup-v on Windows falls back to 0.5.2 zip (see .github/actions/setup-v/action.yml Windows* branch)'
		},
		GapEntry{
			widget: 'Windows D3D11 backend (sokol d3d11 vs OpenGL)'
			category: 'windows'
			status: .partial
			mitigation: 'Wrap: sokol auto-selects d3d11 on Windows; no custom GL pipeline; shader uses sokol-shdc cross-compile'
			upstream_ref: 'vlib/sokol, sokol_gfx d3d11, vlang/gui WINDOWS.md backend notes'
			notes: 'Shader stance in ADR: prefer SDF/shadow via gui primitives, not custom D3D shaders until wrapped'
		},
		GapEntry{
			widget: 'Windows IME + high-DPI manifest + dialog theming'
			category: 'windows'
			status: .partial
			mitigation: 'Manual smoke on Windows required per acceptance; headless Linux CI skips native probe; ADR records manual checklist with screenshots'
			upstream_ref: 'vlang/gui docs/WINDOWS.md (IME, DPI, common dialogs)'
			notes: 'Windows notification/toast via WinToast not in Phase 0; in-app fallback covers Linux CI'
		},
		GapEntry{
			widget: 'Windows file dialogs + clipboard + DnD sandboxing'
			category: 'windows'
			status: .partial
			mitigation: 'Common dialogs via ComDlg32; clipboard via Win32; DnD requires OLE; all OS-limited — spike notes partial, not blocked'
			upstream_ref: 'windows.h ComDlg32, sokol_app Windows impl'
			notes: 'Sandboxed stores (MS Store) may block dialogs; note as Windows limitation, not fallback'
		},
	]
}

// gap_matrix_all combines widget + native + windows into one full matrix for
// ADR appendix and issue publishing.
pub fn gap_matrix_all() []GapEntry {
	mut all := []GapEntry{}
	all << default_gap_matrix()
	all << native_probe_entries()
	all << windows_limitations()
	return all
}

// gap_matrix_markdown renders a markdown table for issue + ADR appendix.
// Columns: Required widget → vlang/gui status ✅/⚠️/❌ + mitigation.
pub fn gap_matrix_markdown() string {
	entries := gap_matrix_all()
	mut out := ''
	out += '| Required widget / surface | Status | Mitigation / fallback |\n'
	out += '|---|---|---|\n'
	for e in entries {
		status := '${e.status.icon()} ${e.status.label()}'
		mit := e.mitigation.replace('|', '\\|')
		w := e.widget.replace('|', '\\|')
		out += '| ${w} | ${status} | ${mit} |\n'
	}
	return out
}

// native_probe_markdown renders only the native surface probe sub-table.
pub fn native_probe_markdown() string {
	entries := native_probe_entries()
	mut out := ''
	out += '| Native surface | Status | Mitigation |\n'
	out += '|---|---|---|\n'
	for e in entries {
		out += '| ${e.widget} | ${e.status.icon()} ${e.status.label()} | ${e.mitigation} |\n'
	}
	return out
}

// windows_probe_markdown renders the Windows limitations sub-table.
pub fn windows_probe_markdown() string {
	entries := windows_limitations()
	mut out := ''
	out += '| Windows limitation (per vlang/gui/docs/WINDOWS.md) | Status | Mitigation |\n'
	out += '|---|---|---|\n'
	for e in entries {
		out += '| ${e.widget} | ${e.status.icon()} ${e.status.label()} | ${e.mitigation} |\n'
	}
	return out
}
