module main

import os

// Slice E export honesty: CSV escaping, empty refusal, write receipt.

fn test_export_csv_escapes_commas_and_quotes() {
	rows := [
		InsightsRow{
			kind: 'Job'
			id: 'j1'
			cells: ['j1', 'job · done', 'say "hi", ok']
		},
	]
	out := insights_export_csv(['Run / job', 'Kind · status', 'Note'], rows)
	assert out.contains('"say ""hi"", ok"'), 'commas and quotes must be quoted: ${out}'
	assert out.starts_with('Run / job,Kind · status,Note\n'), 'header first: ${out}'
}

fn test_export_write_refuses_empty_table() {
	t := InsightsTable{
		title: 'Cost ledger'
		cols: ['Run / job']
		rows: []InsightsRow{}
		empty: 'No runs recorded yet.'
	}
	if _ := insights_export_write('cost', t, 7) {
		assert false, 'empty ledger must never produce an export file'
	} else {
		assert err.msg().contains('nothing to export'), 'refusal names the cause: ${err.msg()}'
	}
}

fn test_export_write_roundtrip_receipt() {
	tmp := os.join_path(os.temp_dir(), 'insights-export-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer {
		os.rmdir_all(tmp) or {}
	}
	os.setenv('HOME', tmp, true)
	t := InsightsTable{
		title: 'Cost ledger'
		cols: ['Run / job', 'Kind · status']
		rows: [
			InsightsRow{
				kind: 'Swarm run'
				id: 's1'
				cells: ['s1', 'team · completed']
			},
		]
	}
	r := insights_export_write('cost', t, 42) or { panic('export must succeed: ${err.msg()}') }
	assert r.rows == 1
	assert r.tab == 'cost'
	assert r.rev == 42
	assert os.exists(r.path), 'receipt path must exist: ${r.path}'
	content := os.read_file(r.path) or { panic(err.msg()) }
	assert content.contains('s1'), 'file carries the row: ${content}'
	assert r.line().contains('rev 42') && r.line().contains(r.path), 'receipt line cites rev and path'
}
