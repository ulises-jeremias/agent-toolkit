module agent_toolkit_core

import crypto.hmac
import crypto.sha256
import os
import time
import x.json2

// In-process gh-gate enforcement for LLM loop runners (PR2).
// Ports bin/loop-gh-gate policy into the toolkit so no shim repo files are
// needed: receipts (optional HMAC, 1h TTL), AI attribution, denial audit log,
// plus a per-run gate-bin/gh generator that calls back into the hidden
// `loop gate-exec` subcommand. Classification itself stays in loop_gate.v.

// Actions that always need a human verifier receipt (merge/close at L3).
pub const gate_receipt_required = ['merge', 'close']
pub const gate_receipt_max_age_sec = 3600
pub const gate_attribution_marker = '> 🤖 AI-assisted'

pub struct GatePolicy {
pub:
	tier      string
	allowlist []string
	deny      []string
	run_dir   string
	run_id    string
}

pub struct GateReceipt {
pub:
	action     string
	actor      string
	repo       string // bound target owner/name ('' = any)
	number     string // bound target PR/issue number ('' = any)
	issued_at  string
	expires_at string
	nonce      string
	signature  string
}

// gate_policy_from_env reads the enforcement context the runner exports.
pub fn gate_policy_from_env() GatePolicy {
	return GatePolicy{
		tier:      os.getenv('ATK_GATE_TIER')
		allowlist: split_csv(os.getenv('ATK_GATE_ALLOW'))
		deny:      split_csv(os.getenv('ATK_GATE_DENY'))
		run_dir:   os.getenv('ATK_GATE_RUNDIR')
		run_id:    os.getenv('ATK_GATE_RUNID')
	}
}

// gate_evaluate mirrors Python gh_gate.evaluate_action: returns (allowed,
// reason). Tier forbids first (L1 everything; L2 all writes), then deny,
// then allowlist; receipt-gated actions additionally need a fresh receipt.
pub fn gate_evaluate(policy GatePolicy, action string, has_receipt bool) (bool, string) {
	if action == '' {
		return true, ''
	}
	t := policy.tier.to_upper()
	if t.starts_with('L1') || t == '1' {
		return false, "tier L1 is read-only; mutating action '${action}' denied"
	}
	if (t.starts_with('L2') || t == '2') && action in ['merge', 'close', 'approve', 'push', 'commit', 'force-push', 'delete'] {
		return false, "tier L2 forbids '${action}' (allow comment/label/assign only)"
	}
	if action in policy.deny {
		return false, "denied by loop deny list: '${action}'"
	}
	if policy.allowlist.len == 0 {
		return false, 'empty loop allowlist denies everything'
	}
	if action !in policy.allowlist {
		return false, "action '${action}' is not in the loop allowlist"
	}
	if action in gate_receipt_required && !has_receipt {
		return false, "action '${action}' requires a fresh verifier receipt (loop gate-issue-receipt)"
	}
	return true, ''
}

// gate_json_escape renders a JSON string literal (canonical payload needs it).
fn gate_json_escape(s string) string {
	mut out := []u8{cap: s.len + 2}
	out << `"`
	for c in s.bytes() {
		match c {
			`"` { out << '\\"'.bytes() }
			`\\` { out << '\\\\'.bytes() }
			`\n` { out << '\\n'.bytes() }
			`\r` { out << '\\r'.bytes() }
			`\t` { out << '\\t'.bytes() }
			else {
				if c < 0x20 {
					out << ('\\u00' + c.hex()).bytes()
				} else {
					out << c
				}
			}
		}
	}
	out << `"`
	return out.bytestr()
}

// gate_canonical_payload builds the signed payload (sort_keys + compact
// separators over action/actor/repo/number/issued_at/expires_at/nonce).
// The bound target travels inside the signature so a receipt minted for one
// PR cannot authorize another (Python verifier-receipt parity).
pub fn gate_canonical_payload(action string, actor string, repo string, number string, issued_at string, expires_at string, nonce string) string {
	return '{"action":' + gate_json_escape(action) + ',"actor":' + gate_json_escape(actor) + ',"expires_at":' + gate_json_escape(expires_at) + ',"issued_at":' + gate_json_escape(issued_at) + ',"nonce":' + gate_json_escape(nonce) + ',"number":' + gate_json_escape(number) + ',"repo":' + gate_json_escape(repo) + '}'
}

// gate_sign_receipt HMAC-SHA256 hex over the canonical payload (empty secret
// yields '' — unsigned receipts verify only when no secret is configured).
pub fn gate_sign_receipt(canonical string, secret string) string {
	if secret == '' {
		return ''
	}
	mac := hmac.new(secret.bytes(), canonical.bytes(), sha256.sum, sha256.block_size)
	return mac.hex()
}

// gate_receipt_path is the verifier receipt location for a run.
pub fn gate_receipt_path(run_dir string) string {
	return os.join_path(run_dir, 'gate-receipt.json')
}

// gate_issue_receipt mints and stores a receipt for action, optionally bound
// to a target repo/number ('' = unbound, matches any target).
pub fn gate_issue_receipt(run_dir string, action string, actor string, repo string, number string, ttl_seconds int, secret string) !GateReceipt {
	now := time.utc()
	issued := now.format_rfc3339()
	expires := now.add_seconds(if ttl_seconds > 0 { ttl_seconds } else { gate_receipt_max_age_sec }).format_rfc3339()
	nonce := '${now.unix_micro()}-${os.getpid()}'
	canonical := gate_canonical_payload(action, actor, repo, number, issued, expires, nonce)
	rec := GateReceipt{
		action:     action
		actor:      actor
		repo:       repo
		number:     number
		issued_at:  issued
		expires_at: expires
		nonce:      nonce
		signature:  gate_sign_receipt(canonical, secret)
	}
	doc := '{"action":' + gate_json_escape(rec.action) + ',"actor":' + gate_json_escape(rec.actor) + ',"repo":' + gate_json_escape(rec.repo) + ',"number":' + gate_json_escape(rec.number) + ',"issued_at":' + gate_json_escape(rec.issued_at) + ',"expires_at":' + gate_json_escape(rec.expires_at) + ',"nonce":' + gate_json_escape(rec.nonce) + ',"signature":' + gate_json_escape(rec.signature) + '}\n'
	os.write_file(gate_receipt_path(run_dir), doc)!
	return rec
}

// gate_read_receipt parses a receipt file (none on any error; old receipts
// without repo/number read as unbound).
fn gate_read_receipt(path string) ?GateReceipt {
	raw := os.read_file(path) or { return none }
	obj := json2.decode[map[string]json2.Any](raw) or { return none }
	str := fn (m map[string]json2.Any, k string) string {
		v := m[k] or { return '' }
		return v.str()
	}
	return GateReceipt{
		action:     str(obj, 'action')
		actor:      str(obj, 'actor')
		repo:       str(obj, 'repo')
		number:     str(obj, 'number')
		issued_at:  str(obj, 'issued_at')
		expires_at: str(obj, 'expires_at')
		nonce:      str(obj, 'nonce')
		signature:  str(obj, 'signature')
	}
}

// gate_receipt_expired reports TTL exhaustion (fail-closed on unparsable time).
fn gate_receipt_expired(rec GateReceipt) bool {
	exp := time.parse_iso8601(rec.expires_at) or { return true }
	return time.utc() > exp
}

// gate_find_receipt loads a live receipt for action bound to repo/number
// (none when missing, mismatched, expired, target-mismatched, or badly
// signed when a secret is configured). Empty receipt or expected fields act
// as wildcards (Python require_receipt parity).
pub fn gate_find_receipt(run_dir string, action string, repo string, number string, secret string) ?GateReceipt {
	rec := gate_read_receipt(gate_receipt_path(run_dir)) or { return none }
	if rec.action == '' || rec.action != action {
		return none
	}
	if rec.repo != '' && repo != '' && rec.repo != repo {
		return none
	}
	if rec.number != '' && number != '' && rec.number != number {
		return none
	}
	if gate_receipt_expired(rec) {
		return none
	}
	if secret != '' {
		canonical := gate_canonical_payload(rec.action, rec.actor, rec.repo, rec.number, rec.issued_at, rec.expires_at, rec.nonce)
		if gate_sign_receipt(canonical, secret) != rec.signature {
			return none
		}
	}
	return rec
}

// gate_denials_path is the audit log for denied gh calls.
pub fn gate_denials_path(run_dir string) string {
	return os.join_path(run_dir, 'gate-denials.jsonl')
}

// gate_write_denial appends one audit record (best-effort, never fails).
pub fn gate_write_denial(run_dir string, action string, tier string, argv []string, reason string) {
	if run_dir == '' {
		return
	}
	ts := time.utc().format_rfc3339()
	mut redacted := []string{}
	for i, a in argv {
		prev := if i > 0 { argv[i - 1].to_lower() } else { '' }
		if prev.contains('token') || prev.contains('secret') {
			redacted << '[redacted]'
		} else {
			redacted << a
		}
	}
	mut parts := []string{}
	for a in redacted {
		parts << gate_json_escape(a)
	}
	line := '{"ts":' + gate_json_escape(ts) + ',"action":' + gate_json_escape(action) + ',"tier":' + gate_json_escape(tier) + ',"argv":[' + parts.join(',') + '],"reason":' + gate_json_escape(reason) + '}\n'
	existing := os.read_file(gate_denials_path(run_dir)) or { '' }
	os.write_file(gate_denials_path(run_dir), existing + line) or {}
}

// gate_attribution_prefix builds the marker block for outbound prose.
pub fn gate_attribution_prefix(actor string, run_id string) string {
	return '\n\n${gate_attribution_marker} by @${actor} in run `${run_id}`\n'
}

// gate_apply_attribution prepends the marker unless already present.
pub fn gate_apply_attribution(body string, actor string, run_id string) string {
	if body.contains(gate_attribution_marker) {
		return body
	}
	return gate_attribution_prefix(actor, run_id) + '\n' + body
}

// gate_rewrite_argv injects attribution into --body / --body-file values
// (-f / --field forms are left untouched, mirroring the shim).
pub fn gate_rewrite_argv(argv []string, actor string, run_id string) []string {
	mut out := argv.clone()
	mut i := 0
	for i < argv.len {
		a := argv[i]
		if (a == '--body' || a == '--body-file') && i + 1 < argv.len {
			if a == '--body' {
				out[i + 1] = gate_apply_attribution(argv[i + 1], actor, run_id)
			} else {
				path := argv[i + 1]
				content := os.read_file(path) or { '' }
				if content != '' {
					os.write_file(path, gate_apply_attribution(content, actor, run_id)) or {}
				}
			}
			i += 2
			continue
		}
		i++
	}
	return out
}

// loop_gate_issue_receipt_cmd implements hidden
// `loop gate-issue-receipt <run_dir> <action> [--actor NAME] [--repo R]
// [--number N] [--ttl SECS]` using ATK_GATE_SECRET when set. The receipt is
// bound to repo/number so it cannot authorize another target.
pub fn loop_gate_issue_receipt_cmd() LoopReport {
	rest := gate_cmd_rest('gate-issue-receipt')
	mut run_dir := ''
	mut action := ''
	mut actor := os.getenv('ATK_GATE_ACTOR')
	mut repo := ''
	mut number := ''
	mut ttl := gate_receipt_max_age_sec
	if actor == '' {
		actor = 'verifier'
	}
	mut positionals := []string{}
	mut i := 0
	for i < rest.len {
		a := rest[i]
		if a == '--actor' && i + 1 < rest.len {
			actor = rest[i + 1]
			i += 2
			continue
		}
		if a == '--repo' && i + 1 < rest.len {
			repo = rest[i + 1]
			i += 2
			continue
		}
		if a == '--number' && i + 1 < rest.len {
			number = rest[i + 1]
			i += 2
			continue
		}
		if a == '--ttl' && i + 1 < rest.len {
			ttl = rest[i + 1].int()
			i += 2
			continue
		}
		if a == '--secret' && i + 1 < rest.len {
			os.setenv('ATK_GATE_SECRET', rest[i + 1], true)
			i += 2
			continue
		}
		positionals << a
		i++
	}
	if positionals.len >= 1 {
		run_dir = positionals[0]
	}
	if positionals.len >= 2 {
		action = positionals[1]
	}
	if run_dir == '' || action == '' {
		return LoopReport{
			ok:      false
			message: 'usage: agent-toolkit loop gate-issue-receipt <run_dir> <action> [--actor NAME] [--repo R] [--number N] [--ttl SECS]'
			data:    {
				'subcommand': 'gate-issue-receipt'
				'status':     'usage_error'
			}
		}
	}
	secret := os.getenv('ATK_GATE_SECRET')
	rec := gate_issue_receipt(run_dir, action, actor, repo, number, ttl, secret) or {
		return LoopReport{
			ok:      false
			message: 'receipt issue failed: ${err.msg()}'
			data:    {
				'subcommand': 'gate-issue-receipt'
				'status':     'error'
			}
		}
	}
	bound := if rec.repo != '' || rec.number != '' { ' bound to ${rec.repo}#${rec.number}' } else { '' }
	return LoopReport{
		ok:      true
		message: 'receipt issued for ${rec.action} (actor ${rec.actor}, expires ${rec.expires_at})${bound} → ${gate_receipt_path(run_dir)}'
		data:    {
			'subcommand': 'gate-issue-receipt'
			'status':     'issued'
			'action':     rec.action
		}
	}
}

// loop_gate_check_cmd implements hidden
// `loop gate-check [--tier T] [--allow a,b] [--deny d] [--secret S] [gh argv...]`:
// prints classification + decision without executing anything. Dashed gh flags
// cannot survive CLI parsing — set GH_ARGV (newline-joined) for those.
pub fn loop_gate_check_cmd() LoopReport {
	rest := gate_cmd_rest('gate-check')
	// GH_ARGV (newline-joined) wins when set, so dashed gh flags never need
	// to survive CLI parsing; trailing positionals are the fallback.
	raw_argv := os.getenv('GH_ARGV')
	mut tier := os.getenv('ATK_GATE_TIER')
	mut allow_raw := os.getenv('ATK_GATE_ALLOW')
	mut deny_raw := os.getenv('ATK_GATE_DENY')
	mut argv := []string{}
	mut i := 0
	for i < rest.len {
		a := rest[i]
		if (a == '--tier' || a == '--allow' || a == '--deny' || a == '--secret') && i + 1 < rest.len {
			match a {
				'--tier' {
					tier = rest[i + 1]
				}
				'--allow' {
					allow_raw = rest[i + 1]
				}
				'--deny' {
					deny_raw = rest[i + 1]
				}
				else {
					os.setenv('ATK_GATE_SECRET', rest[i + 1], true)
				}
			}
			i += 2
			continue
		}
		// trailing positionals double as gh argv (no dashed flags: those
		// would be rejected by CLI parsing — use GH_ARGV for those)
		if !a.starts_with('-') {
			argv << a
		}
		i++
	}
	if raw_argv != '' {
		argv = []string{}
		for line in raw_argv.split('\n') {
			if line != '' {
				argv << line
			}
		}
	}
	policy := GatePolicy{
		tier:      tier
		allowlist: split_csv(allow_raw)
		deny:      split_csv(deny_raw)
		run_dir:   os.getenv('ATK_GATE_RUNDIR')
		run_id:    os.getenv('ATK_GATE_RUNID')
	}
	action := classify_gh_argv(argv)
	secret := os.getenv('ATK_GATE_SECRET')
	mut has_receipt := false
	if action in gate_receipt_required && policy.run_dir != '' {
		repo, number := gate_target_from_argv(argv)
		if repo != '' && number != '' {
			found := gate_find_receipt(policy.run_dir, action, repo, number, secret) or {
				GateReceipt{}
			}
			has_receipt = found.action != ''
		}
	}
	allowed, reason := gate_evaluate(policy, action, has_receipt)
	verdict := if allowed { 'allow' } else { 'deny' }
	mut msg := 'action=${action} verdict=${verdict} tier=${tier} receipt=${has_receipt}'
	if reason != '' {
		msg += ' reason=${reason}'
	}
	return LoopReport{
		ok:      allowed
		message: msg
		data:    {
			'subcommand': 'gate-check'
			'action':     action
			'verdict':    verdict
		}
	}
}

// split_csv parses comma lists for policy flags.
fn split_csv(raw string) []string {
	mut out := []string{}
	for part in raw.split(',') {
		t := part.trim_space()
		if t != '' {
			out << t
		}
	}
	return out
}

// gate_cmd_rest returns os.args after the named hidden subcommand.
fn gate_cmd_rest(sub string) []string {
	args := os.args
	for i, a in args {
		if a == sub {
			return args[i + 1..].clone()
		}
	}
	return []
}

// gate_write_shim generates run_dir/gate-bin/gh: a dumb pipe that stashes the
// gh argv in GH_ARGV (newline-joined, so no flag can confuse CLI parsing),
// exports the enforcement context, and execs the toolkit's hidden gate-exec.
pub fn gate_write_shim(gate_bin_dir string, toolkit_bin string, real_gh string) ! {
	os.mkdir_all(gate_bin_dir)!
	script := '#!/bin/sh\nGH_ARGV=$(printf \'%s\\n\' "$@")\nexport GH_ARGV\nATK_REAL_GH=' + sh_quote(real_gh) + ' exec ' + sh_quote(toolkit_bin) + ' loop gate-exec\n'
	path := os.join_path(gate_bin_dir, 'gh')
	os.write_file(path, script)!
	os.chmod(path, 0o755)!
}

// gate_resolve_real_gh returns the bypass binary (fail-closed when unset so
// gate-exec can never recurse through the shim).
fn gate_resolve_real_gh() string {
	p := os.getenv('ATK_REAL_GH')
	if p != '' && os.is_file(p) {
		return p
	}
	return ''
}

// gate_exec_args returns the gh argv: GH_ARGV (newline-joined, set by the
// shim so dashed flags never touch CLI parsing), else os.args after the
// `gate-exec` token (direct human use without dashed flags).
fn gate_exec_args() []string {
	raw := os.getenv('GH_ARGV')
	if raw != '' {
		mut out := []string{}
		for line in raw.split('\n') {
			if line != '' {
				out << line
			}
		}
		return out
	}
	args := os.args
	for i, a in args {
		if a == 'gate-exec' {
			return args[i + 1..].clone()
		}
	}
	return []
}

// loop_gate_exec implements hidden `loop gate-exec -- <gh argv>`: classify,
// enforce, optionally attribute, forward. Returns a LoopReport (ok=false on
// denial with exit-2 semantics in the message; gh's own code on forward).
pub fn loop_gate_exec() LoopReport {
	return gate_exec_with(gate_policy_from_env(), gate_exec_args(), os.getenv('ATK_GATE_SECRET'))
}

// gate_exec_with enforces policy over argv (testable core of gate-exec).
// Receipt-gated actions need a receipt bound to the call's target: unknown
// targets fail closed (Python require_receipt parity).
pub fn gate_exec_with(policy GatePolicy, argv []string, secret string) LoopReport {
	action := classify_gh_argv(argv)
	mut has_receipt := false
	if action in gate_receipt_required && policy.run_dir != '' {
		repo, number := gate_target_from_argv(argv)
		if repo != '' && number != '' {
			found := gate_find_receipt(policy.run_dir, action, repo, number, secret) or {
				GateReceipt{}
			}
			has_receipt = found.action != ''
		}
	}
	return gate_forward(policy, argv, action, has_receipt)
}

// gate_deny records and reports a denial (exit-2 semantics).
fn gate_deny(policy GatePolicy, argv []string, action string, reason string) LoopReport {
	gate_write_denial(policy.run_dir, action, policy.tier, argv, reason)
	msg := "[gate] denied (${reason}): tier=${policy.tier} action='${action}' (exit 2)"
	return LoopReport{
		ok:      false
		message: msg
		data:    {
			'subcommand': 'gate-exec'
			'status':     'denied'
			'action':     action
		}
	}
}

// gate_forward enforces then execs real gh with inherited stdio.
fn gate_forward(policy GatePolicy, argv []string, action string, has_receipt bool) LoopReport {
	allowed, reason := gate_evaluate(policy, action, has_receipt)
	if !allowed {
		return gate_deny(policy, argv, action, reason)
	}
	real_gh := gate_resolve_real_gh()
	if real_gh == '' {
		return gate_deny(policy, argv, action, 'ATK_REAL_GH unset — refusing to recurse through the shim')
	}
	mut final_argv := argv.clone()
	if action == 'comment' {
		mut actor := os.getenv('ATK_GATE_ACTOR')
		run_id := os.getenv('ATK_GATE_RUNID')
		if actor == '' {
			actor = 'loop-agent'
		}
		final_argv = gate_rewrite_argv(argv, actor, run_id)
	}
	res := os.execute(real_gh + ' ' + final_argv.map(sh_quote).join(' '))
	out := res.output.trim_space()
	ok := res.exit_code == 0
	msg := if out != '' { out } else { '[gate] allowed: ${action} (exit ${res.exit_code})' }
	return LoopReport{
		ok:      ok
		message: msg
		data:    {
			'subcommand': 'gate-exec'
			'status':     if ok { 'allowed' } else { 'gh_error' }
			'action':     action
		}
	}
}
