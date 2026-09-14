module main

import os

// Insights export (slice E, #1236): the current tab's ledger table as CSV,
// written to the desktop exports dir with a receipt. Nothing is estimated:
// the receipt carries tab, row count, path and the Engine revision the rows
// were read at (0 when no Engine is attached, e.g. headless tests).

struct InsightsExportReceipt {
	path string
	tab  string
	rows int
	rev  u64
}

fn (r InsightsExportReceipt) line() string {
	return 'Exported ${r.rows} ${r.tab} rows → ${r.path} (rev ${r.rev})'
}

// insights_csv_escape quotes a cell only when it needs it.
fn insights_csv_escape(s string) string {
	if !s.contains(',') && !s.contains('"') && !s.contains('\n') {
		return s
	}
	return '"' + s.replace('"', '""') + '"'
}

// insights_export_csv renders header + one line per row cell set.
fn insights_export_csv(cols []string, rows []InsightsRow) string {
	mut out := []string{}
	mut head := []string{}
	for c in cols {
		head << insights_csv_escape(c)
	}
	out << head.join(',')
	for r in rows {
		mut line := []string{}
		for c in r.cells {
			line << insights_csv_escape(c)
		}
		out << line.join(',')
	}
	return out.join('\n') + '\n'
}

// insights_export_btn_rect is the single source of Export-button geometry,
// shared by draw_insights_table and insights_click. Layout-only inputs.
fn insights_export_btn_rect(l InsightsLayout) (int, int, int, int) {
	bottom := l.content_y + l.content_h
	return l.inner_x + l.inner_w - 150, bottom - 28, 150, 22
}

// insights_export_dir is the desktop exports dir under the OS cache root.
fn insights_export_dir() string {
	base := if os.home_dir() != '' { os.join_path(os.home_dir(), '.cache') } else { os.temp_dir() }
	return os.join_path(base, 'agent-toolkit', 'desktop', 'exports')
}

// insights_export_write refuses an empty table (no empty-file theater) and
// records the receipt of a real write. Write failures return the error.
fn insights_export_write(tab string, t InsightsTable, rev u64) !InsightsExportReceipt {
	if t.rows.len == 0 {
		return error('nothing to export: the ${tab} tab has no rows')
	}
	dir := insights_export_dir()
	os.mkdir_all(dir) or { return error('export dir unreachable: ${err.msg()}') }
	path := os.join_path(dir, 'insights-${tab}-rev${rev}.csv')
	os.write_file(path, insights_export_csv(t.cols, t.rows)) or {
		return error('export write failed: ${err.msg()}')
	}
	return InsightsExportReceipt{
		path: path
		tab: tab
		rows: t.rows.len
		rev: rev
	}
}

// insights_export_at performs the click-path export for the live app: table
// at the current revision, message set for the detail column either way.
fn insights_export_at(mut app GuiApp, tab string, t InsightsTable) {
	rev := if app.desktop != unsafe { nil } { app.desktop.app_state_snapshot().revision } else { u64(0) }
	if r := insights_export_write(tab, t, rev) {
		app.insights_export_msg = r.line()
	} else {
		app.insights_export_msg = 'Export failed: ${err.msg()}'
	}
	app.insights_cache_frame = -1
}
