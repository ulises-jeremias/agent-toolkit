module agent_toolkit_core

import crypto.sha256
import x.json2
import os
import time

// Handoff protocol — durable filesystem queue with validation.
// Port of Python packages/pypi/agent-toolkit-cli/src/agent_toolkit/swarm/handoff.py (fbb2280).

// handoff_version mirrors Python models.HANDOFF_VERSION.
const handoff_version = 1

// allowed_handoff_types mirrors Python handoff.ALLOWED_TYPES.
const allowed_handoff_types = ['artifact', 'commit', 'feedback', 'decision_request']

// HandoffRecord is the on-disk handoff payload (handoffs/<state>/<id>.json).
// JSON keys match the Python dict written by write_handoff_outbox.
pub struct HandoffRecord {
pub mut:
	version    int
	htype      string @[json: 'type']
	from_role  string @[json: 'from']
	to_role    string @[json: 'to']
	priority   int
	artifact   string
	commit     string
	branch     string
	blocking   bool
	handoff_id string
	created_at string
}

// handoff_role_valid mirrors Python ROLE_RE ^[a-z][a-z0-9_-]{1,31}$.
fn handoff_role_valid(s string) bool {
	if s.len < 2 || s.len > 32 {
		return false
	}
	c0 := s[0]
	if !(c0 >= `a` && c0 <= `z`) {
		return false
	}
	for c in s[1..] {
		if !((c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `_` || c == `-`) {
			return false
		}
	}
	return true
}

// handoff_sha_valid mirrors Python SHA_RE ^[0-9a-f]{40}$.
fn handoff_sha_valid(s string) bool {
	if s.len != 40 {
		return false
	}
	for c in s {
		if !((c >= `0` && c <= `9`) || (c >= `a` && c <= `f`)) {
			return false
		}
	}
	return true
}

// handoff_id_for returns the first 16 hex chars of the SHA256 of the canonical
// struct encoding — mirrors Python handoff_id_for (sha256(sorted JSON)[:16]).
fn handoff_id_for(rec HandoffRecord) string {
	sum := sha256.hexhash(json2.encode(rec, escape_unicode: true))
	if sum.len <= 16 {
		return sum
	}
	return sum[..16]
}

// handoff_paths returns the five handoff state dirs (outbox/queued/active/completed/failed).
fn handoff_states() []string {
	return ['outbox', 'queued', 'active', 'completed', 'failed']
}

// handoff_exists reports whether a handoff id already exists in any state dir.
fn handoff_exists(run_dir string, hid string) bool {
	for st in handoff_states() {
		if os.is_file(os.join_path(run_dir, 'handoffs', st, '${hid}.json')) {
			return true
		}
	}
	return false
}

// validate_artifact_path rejects absolute paths, traversal, and symlink escapes.
// Returns the joined (relative-safe) path on success — mirrors Python store.validate_artifact_path.
fn validate_artifact_path(run_dir string, artifact string) !string {
	if os.is_abs_path(artifact) {
		return error('Artifact path must be relative: ${artifact}')
	}
	if artifact.contains('..') {
		return error('Artifact path traversal: ${artifact}')
	}
	p := os.join_path(run_dir, artifact)
	// Best-effort symlink containment when the artifact already exists.
	if os.exists(p) {
		rp := os.real_path(p)
		base := os.real_path(run_dir)
		sep := os.path_separator
		prefix := base.trim_right('/\\') + sep
		if rp != base && !rp.starts_with(prefix) {
			return error('Artifact escape: ${artifact}')
		}
		return rp
	}
	return p
}

// validate_handoff mirrors Python handoff.validate_handoff (fbb2280).
fn validate_handoff(rec HandoffRecord, run_dir string, roles []string) []string {
	mut errors := []string{}
	if rec.version != handoff_version {
		errors << 'version must be ${handoff_version}'
	}
	htype := rec.htype
	if htype !in allowed_handoff_types {
		errors << 'type must be one of [${allowed_handoff_types.join(', ')}], got ${htype}'
	}
	frm := rec.from_role
	to := rec.to_role
	if !handoff_role_valid(frm) {
		errors << 'from invalid: ${frm}'
	} else if frm !in roles && frm != 'human' {
		errors << 'unknown from role: ${frm}'
	}
	if to != 'human' && !handoff_role_valid(to) {
		errors << 'to invalid: ${to}'
	} else if to !in roles && to != 'human' {
		errors << 'unknown to role: ${to}'
	}
	if rec.priority < 0 || rec.priority > 100 {
		errors << 'priority must be int 0..100'
	}
	artifact := rec.artifact
	if artifact.len > 0 {
		if artifact.len > 512 {
			errors << 'artifact path too long'
		}
		validate_artifact_path(run_dir, artifact) or { errors << err.msg() }
	}
	if htype == 'commit' {
		if !handoff_sha_valid(rec.commit.to_lower()) {
			errors << 'commit must be 40 hex chars'
		}
		if rec.branch.len == 0 {
			errors << 'branch required for commit handoff'
		} else if rec.branch.contains('..') || rec.branch.starts_with('/') {
			errors << 'branch traversal'
		}
	}
	// htype == 'feedback': blocking is a typed bool in HandoffRecord, so the
	// Python "blocking must be bool" check is structural and always satisfied.
	return errors
}

// write_handoff_outbox atomically writes handoffs/outbox/<id>.json and returns its path.
// Mirrors Python handoff.write_handoff_outbox (tmpfile + os.replace, dedup across 5 dirs).
fn write_handoff_outbox(run_dir string, mut rec HandoffRecord) !string {
	if rec.handoff_id.len == 0 {
		rec.handoff_id = handoff_id_for(rec)
	}
	if rec.created_at.len == 0 {
		rec.created_at = swarm_now_ts()
	}
	if rec.version == 0 {
		rec.version = handoff_version
	}
	outbox := os.join_path(run_dir, 'handoffs', 'outbox')
	os.mkdir_all(outbox) or { return err }
	mut hid := rec.handoff_id
	mut tried := 0
	for handoff_exists(run_dir, hid) {
		hid = handoff_id_for(rec) + ((time.ticks() + i64(tried)) & 0xffff).hex()
		tried++
		if tried > 5 {
			break
		}
	}
	rec.handoff_id = hid
	payload := json2.encode(rec, escape_unicode: true) + '\n'
	tmp := os.join_path(outbox, '.tmp-${hid}')
	os.write_file(tmp, payload) or { return err }
	dest := os.join_path(outbox, '${hid}.json')
	os.mv(tmp, dest) or { return err }
	return dest
}

// move_handoff moves a handoff between state dirs; returns none if the source is missing.
fn move_handoff(run_dir string, hid string, from_state string, to_state string) ?string {
	src := os.join_path(run_dir, 'handoffs', from_state, '${hid}.json')
	dst := os.join_path(run_dir, 'handoffs', to_state, '${hid}.json')
	if !os.is_file(src) {
		return none
	}
	os.mkdir_all(os.dir(dst)) or { return none }
	os.mv(src, dst) or { return none }
	return dst
}

// list_handoffs returns all decoded handoffs in a state dir, sorted by filename.
fn list_handoffs(run_dir string, state string) []HandoffRecord {
	d := os.join_path(run_dir, 'handoffs', state)
	if !os.is_dir(d) {
		return []
	}
	mut names := os.ls(d) or { return [] }
	names.sort()
	mut items := []HandoffRecord{}
	for p in names {
		if !p.ends_with('.json') {
			continue
		}
		text := os.read_file(os.join_path(d, p)) or { continue }
		rec := json2.decode[HandoffRecord](text) or { continue }
		items << rec
	}
	return items
}

// validate_commit_exists mirrors Python handoff.validate_commit_exists (git cat-file -t).
fn validate_commit_exists(repo_root string, sha string) bool {
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv: ['git', 'cat-file', '-t', sha]
		cwd: repo_root
		timeout: 5 * time.second
	}) or { return false }
	return res.exit_code == 0 && res.stdout.trim_space() == 'commit'
}

// resolve_sha resolves an abbreviated SHA via git rev-parse --verify <abbrev>^{commit}.
fn resolve_sha(repo_root string, abbrev string) ?string {
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv: ['git', 'rev-parse', '--verify', '${abbrev}^{commit}']
		cwd: repo_root
		timeout: 5 * time.second
	}) or { return none }
	if res.exit_code != 0 {
		return none
	}
	out := res.stdout.trim_space()
	if !handoff_sha_valid(out) {
		return none
	}
	return out
}

// swarm_now_ts returns the current UTC timestamp in RFC3339 form (Z suffix).
fn swarm_now_ts() string {
	return time.utc().format_rfc3339()
}
