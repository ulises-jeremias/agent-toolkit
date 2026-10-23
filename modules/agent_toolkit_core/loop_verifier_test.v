module agent_toolkit_core

import os

// Fake runner (claude) + fake gh: the verifier pass must let the
// supervisor execute only the approved merge, never the refused one,
// and receipts must be minted by the supervisor with the verifier as
// actor — never by the acting runner.
fn test_supervisor_executes_only_verifier_approved_actions() {
	root := os.join_path(os.temp_dir(), 'at-loop-verifier-${os.getpid()}')
	bin := os.join_path(root, 'bin')
	run_dir := os.join_path(root, 'run')
	os.mkdir_all(bin) or { assert false, err.msg() }
	os.mkdir_all(run_dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	previous_path := os.getenv('PATH')
	defer {
		os.setenv('PATH', previous_path, true)
	}

	// Fake verifier runner: approves #42, refuses #43. It discovers the
	// verdicts path from the prompt argv (the supervisor passes it).
	fake_claude := os.join_path(bin, 'claude')
	claude_script := '#!/bin/sh\n' +
		'for a in "$@"; do case "$a" in *verdicts.jsonl*) OUT=$(printf %s "$a" | grep -o "[^ ]*verdicts.jsonl" | head -1);; esac; done\n' +
		'printf \'%s\\n\' \'{"action":"merge","repo":"acme/widgets","number":"42","approved":true,"reason":"ci green"}\' \'{"action":"merge","repo":"acme/widgets","number":"43","approved":false,"reason":"ci red"}\' > "$OUT"\n'
	os.write_file(fake_claude, claude_script) or { assert false, err.msg() }
	os.chmod(fake_claude, 0o755) or { assert false, err.msg() }

	// Fake gh: logs every invocation, always succeeds.
	gh_log := os.join_path(root, 'gh.log')
	fake_gh := os.join_path(bin, 'gh')
	os.write_file(fake_gh, '#!/bin/sh\necho "$@" >> ${gh_log}\nexit 0\n') or {
		assert false, err.msg()
	}
	os.chmod(fake_gh, 0o755) or { assert false, err.msg() }
	os.setenv('PATH', '${bin}:${previous_path}', true)

	proposals := '{"action":"merge","repo":"acme/widgets","number":"42","rationale":"dependabot ci green"}\n{"action":"merge","repo":"acme/widgets","number":"43","rationale":"dependabot ci red"}\n{"action":"comment","repo":"acme/widgets","number":"44","rationale":"not receipt-gated"}\nnot json\n'
	os.write_file(loop_proposals_path(run_dir), proposals) or { assert false, err.msg() }

	meta := LoopMeta{
		name:      'oss-pr-monitor'
		tier:      'L3'
		allowlist: ['merge', 'close', 'comment']
		deny:      []string{}
		verifier:  'fake-verifier'
	}
	summary := loop_supervisor_verify_and_execute(root, meta, run_dir, 'claude', 60, '')
	assert summary.contains('1 receipt-gated action(s) executed'), summary
	assert summary.contains('1 refused'), summary

	// Only the approved merge reached gh, with the supervisor argv.
	logged := os.read_file(gh_log) or { '' }
	assert logged.contains('pr merge 42 --repo acme/widgets --squash'), logged
	assert !logged.contains(' 43 '), logged

	// The receipt on disk is bound to the approved target and minted
	// for the verifier actor.
	receipt := gate_find_receipt(run_dir, 'merge', 'acme/widgets', '42', '') or {
		assert false, 'receipt missing'
		GateReceipt{}
	}
	assert receipt.actor == 'fake-verifier'
	assert receipt.repo == 'acme/widgets'
	assert receipt.number == '42'

	// executed.jsonl records both outcomes.
	executed := os.read_file(loop_executed_path(run_dir)) or { '' }
	assert executed.contains('"number":"42","actor":"fake-verifier","ok":true'), executed
	assert executed.contains('"number":"43","actor":"fake-verifier","ok":false'), executed
}

fn test_supervisor_without_verifier_executes_nothing() {
	root := os.join_path(os.temp_dir(), 'at-loop-noverifier-${os.getpid()}')
	run_dir := os.join_path(root, 'run')
	os.mkdir_all(run_dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	os.write_file(loop_proposals_path(run_dir),
		'{"action":"merge","repo":"acme/widgets","number":"42","rationale":"x"}\n') or {
		assert false, err.msg()
	}
	meta := LoopMeta{
		name:      'oss-pr-monitor'
		tier:      'L3'
		allowlist: ['merge']
		deny:      []string{}
	}
	summary := loop_supervisor_verify_and_execute(root, meta, run_dir, 'claude', 60, '')
	assert summary.contains('no verifier'), summary
	assert !os.is_file(loop_executed_path(run_dir))
}
