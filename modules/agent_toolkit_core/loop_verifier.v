module agent_toolkit_core

import os
import x.json2

// Supervisor verifier pass for receipt-gated loop actions (#1650).
//
// L3 loops may allowlist merge/close, but those actions require a fresh
// verifier receipt and nothing in the run path used to mint one: the
// acting runner must never authorize itself. The supervisor now owns
// the flow end to end:
//
//   1. The acting runner records intended receipt-gated actions in
//      run_dir/proposals.jsonl instead of calling gh merge/close.
//   2. The supervisor runs the loop's verifier as a separate runner
//      invocation (tier L1 gate: read-only) that writes verdicts to
//      run_dir/verdicts.jsonl.
//   3. For each approved proposal the supervisor — never the acting
//      runner process — mints a target-bound receipt, re-evaluates the
//      gate with that receipt, and executes the real gh argv itself.
//
// Outcomes land in run_dir/executed.jsonl; unapproved or unproposed
// actions are never executed.

pub struct LoopProposal {
pub:
	action    string
	repo      string
	number    string
	rationale string
}

pub struct LoopVerdict {
pub:
	action   string
	repo     string
	number   string
	approved bool
	reason   string
}

// loop_proposals_path / loop_verdicts_path / loop_executed_path are the
// supervisor-owned artifacts of one run.
pub fn loop_proposals_path(run_dir string) string {
	return os.join_path(run_dir, 'proposals.jsonl')
}

pub fn loop_verdicts_path(run_dir string) string {
	return os.join_path(run_dir, 'verdicts.jsonl')
}

pub fn loop_executed_path(run_dir string) string {
	return os.join_path(run_dir, 'executed.jsonl')
}

fn loop_json_str(m map[string]json2.Any, k string) string {
	v := m[k] or { return '' }
	return v.str()
}

fn loop_json_bool(m map[string]json2.Any, k string) bool {
	v := m[k] or { return false }
	return v.bool()
}

// loop_read_proposals parses proposals.jsonl (malformed lines skipped:
// a bad line can never become an executed action).
pub fn loop_read_proposals(run_dir string) []LoopProposal {
	raw := os.read_file(loop_proposals_path(run_dir)) or { return []LoopProposal{} }
	mut out := []LoopProposal{}
	for line in raw.split('\n') {
		trimmed := line.trim_space()
		if trimmed == '' {
			continue
		}
		obj := json2.decode[map[string]json2.Any](trimmed) or { continue }
		proposal := LoopProposal{
			action:    loop_json_str(obj, 'action')
			repo:      loop_json_str(obj, 'repo')
			number:    loop_json_str(obj, 'number')
			rationale: loop_json_str(obj, 'rationale')
		}
		if proposal.action in gate_receipt_required && proposal.repo != '' && proposal.number != '' {
			out << proposal
		}
	}
	return out
}

// loop_read_verdicts parses verdicts.jsonl written by the verifier pass.
pub fn loop_read_verdicts(run_dir string) []LoopVerdict {
	raw := os.read_file(loop_verdicts_path(run_dir)) or { return []LoopVerdict{} }
	mut out := []LoopVerdict{}
	for line in raw.split('\n') {
		trimmed := line.trim_space()
		if trimmed == '' {
			continue
		}
		obj := json2.decode[map[string]json2.Any](trimmed) or { continue }
		out << LoopVerdict{
			action:   loop_json_str(obj, 'action')
			repo:     loop_json_str(obj, 'repo')
			number:   loop_json_str(obj, 'number')
			approved: loop_json_bool(obj, 'approved')
			reason:   loop_json_str(obj, 'reason')
		}
	}
	return out
}

fn loop_verdict_for(verdicts []LoopVerdict, proposal LoopProposal) ?LoopVerdict {
	for verdict in verdicts {
		if verdict.action == proposal.action && verdict.repo == proposal.repo && verdict.number == proposal.number {
			return verdict
		}
	}
	return none
}

// loop_gate_argv builds the real gh argv the supervisor executes for an
// approved proposal. Only receipt-gated actions are constructible.
pub fn loop_gate_argv(proposal LoopProposal) []string {
	return match proposal.action {
		'merge' { ['pr', 'merge', proposal.number, '--repo', proposal.repo, '--squash'] }
		'close' { ['pr', 'close', proposal.number, '--repo', proposal.repo] }
		else { []string{} }
	}
}

fn loop_write_executed(run_dir string, proposal LoopProposal, actor string, ok bool, detail string) {
	line := '{"action":' + gate_json_escape(proposal.action) + ',"repo":' + gate_json_escape(proposal.repo) + ',"number":' + gate_json_escape(proposal.number) + ',"actor":' + gate_json_escape(actor) + ',"ok":${ok},"detail":' + gate_json_escape(detail) + '}\n'
	existing := os.read_file(loop_executed_path(run_dir)) or { '' }
	os.write_file(loop_executed_path(run_dir), existing + line) or {}
}

// loop_verifier_prompt is the read-only verification request. The marker
// first line lets fake runners in tests recognize the pass.
pub fn loop_verifier_prompt(loop_name string, verifier string, run_dir string, proposals []LoopProposal) string {
	mut lines := ['ATK-LOOP-VERIFIER-PASS']
	lines << 'You are the independent verifier "${verifier}" for loop "${loop_name}".'
	lines << 'Review each proposed receipt-gated action below. You are read-only: do not run gh merge/close or any mutating command.'
	lines << 'Write one JSON object per line to ${loop_verdicts_path(run_dir)} :'
	lines << '{"action":"merge","repo":"owner/name","number":"123","approved":true,"reason":"why"}'
	lines << 'Approve only actions the evidence supports. Anything you do not approve is not executed.'
	lines << 'Proposals:'
	for proposal in proposals {
		lines << '- {"action":${gate_json_escape(proposal.action)},"repo":${gate_json_escape(proposal.repo)},"number":${gate_json_escape(proposal.number)},"rationale":${gate_json_escape(proposal.rationale)}}'
	}
	return lines.join('\n')
}

// loop_supervisor_verify_and_execute runs the verifier pass and executes
// approved proposals. Returns a human-readable summary line. Called by
// run_loop_llm only when the loop names a verifier; the acting runner
// process never mints receipts.
pub fn loop_supervisor_verify_and_execute(ws string, meta LoopMeta, run_dir string, runner_name string, wall int, model string) string {
	proposals := loop_read_proposals(run_dir)
	if proposals.len == 0 {
		return ''
	}
	if meta.verifier == '' {
		return '[loop] ${proposals.len} receipt-gated proposal(s) recorded but loop has no verifier — none executed'
	}
	verifier_dir := os.join_path(run_dir, 'verifier')
	os.mkdir_all(verifier_dir) or {}
	prompt := loop_verifier_prompt(meta.name, meta.verifier, run_dir, proposals)
	sysp := 'You are a read-only verifier for an agent-toolkit loop run. Write only the verdicts file described in the prompt.'
	verifier_gate := GatePolicy{
		tier:      'L1'
		allowlist: meta.allowlist.clone()
		deny:      meta.deny.clone()
		run_dir:   verifier_dir
		run_id:    meta.name
	}
	res := execute_loop_runner(runner_name, prompt, sysp, ws, verifier_dir, wall, verifier_gate, model)
	if !res.ok {
		return '[loop] verifier pass failed to spawn (${runner_name}) — no receipt-gated actions executed'
	}
	verdicts := loop_read_verdicts(run_dir)
	secret := os.getenv('ATK_GATE_SECRET')
	policy := GatePolicy{
		tier:      meta.tier
		allowlist: meta.allowlist.clone()
		deny:      meta.deny.clone()
		run_dir:   run_dir
		run_id:    meta.name
	}
	real_gh := os.find_abs_path_of_executable('gh') or { '' }
	mut executed := 0
	mut refused := 0
	for proposal in proposals {
		verdict := loop_verdict_for(verdicts, proposal) or {
			refused++
			loop_write_executed(run_dir, proposal, meta.verifier, false, 'no verifier verdict')
			continue
		}
		if !verdict.approved {
			refused++
			loop_write_executed(run_dir, proposal, meta.verifier, false, 'verifier refused: ${verdict.reason}')
			continue
		}
		// The supervisor mints the receipt; the acting runner never can.
		gate_issue_receipt(run_dir, proposal.action, meta.verifier, proposal.repo, proposal.number, gate_receipt_max_age_sec, secret) or {
			refused++
			loop_write_executed(run_dir, proposal, meta.verifier, false, 'receipt issue failed')
			continue
		}
		found := gate_find_receipt(run_dir, proposal.action, proposal.repo, proposal.number, secret) or {
			GateReceipt{}
		}
		allowed, reason := gate_evaluate(policy, proposal.action, found.action != '')
		if !allowed {
			refused++
			loop_write_executed(run_dir, proposal, meta.verifier, false, 'gate denied: ${reason}')
			continue
		}
		argv := loop_gate_argv(proposal)
		if argv.len == 0 || real_gh == '' {
			refused++
			loop_write_executed(run_dir, proposal, meta.verifier, false, 'no executable gh action')
			continue
		}
		mut parts := [sh_quote(real_gh)]
		for a in argv {
			parts << sh_quote(a)
		}
		result := os.execute(parts.join(' '))
		if result.exit_code == 0 {
			executed++
			loop_write_executed(run_dir, proposal, meta.verifier, true, 'executed by supervisor')
		} else {
			refused++
			loop_write_executed(run_dir, proposal, meta.verifier, false, 'gh exit ${result.exit_code}')
		}
	}
	return '[loop] verifier "${meta.verifier}": ${executed} receipt-gated action(s) executed by supervisor, ${refused} refused (see executed.jsonl)'
}
