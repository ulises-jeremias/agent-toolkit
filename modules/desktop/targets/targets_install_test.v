module targets

import os
import desktop_engine

// Library targets lifecycle (slice C): preview/dry-run/verify surfacing.
// All three are read-only; summaries carry counts, never bare claims.

fn new_targets_lifecycle_test_engine(suffix string) (string, &desktop_engine.Engine) {
	tmp := os.join_path(os.temp_dir(), 'targets-install-${suffix}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut e := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { panic(err.msg()) }
	e.start() or { panic(err.msg()) }
	return tmp, e
}

fn test_targets_preview_is_dry_run_and_names_changes() {
	tmp, mut e := new_targets_lifecycle_test_engine('preview')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_targets_viewmodel(mut e)
	rev_before := e.revision()
	summary := vm.preview_summary(['cursor'])
	assert summary.starts_with('preview:'), 'preview must render the diff: ${summary}'
	assert e.revision() == rev_before, 'preview must never mutate'
	empty := vm.preview_summary([])
	assert empty.starts_with('preview:'), 'empty preview must still render: ${empty}'
	assert e.revision() == rev_before
}

fn test_targets_dry_run_renders_plan_without_mutating() {
	tmp, mut e := new_targets_lifecycle_test_engine('dryrun')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_targets_viewmodel(mut e)
	rev_before := e.revision()
	plan := vm.dry_run_text(['cursor'])
	assert plan != '', 'dry run must render a plan, never an empty claim'
	assert e.revision() == rev_before, 'dry run must never mutate'
}

fn test_targets_verify_recomputes_receipt_evidence() {
	tmp, mut e := new_targets_lifecycle_test_engine('verify')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_targets_viewmodel(mut e)
	summary := vm.verify_summary()
	assert summary != '', 'verify must report evidence either way'
	assert summary.contains('verified clean') || summary.contains('receipt issue:'),
		'verify reports clean-with-count or the first diagnostic: ${summary}'
}

fn test_targets_receipts_list_is_engine_truth() {
	tmp, mut e := new_targets_lifecycle_test_engine('receipts')
	defer {
		e.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut vm := new_targets_viewmodel(mut e)
	receipts := vm.receipts()
	assert receipts.len == e.list_install_receipts().len, 'viewmodel receipts must match Engine truth'
}
