module swarm

// Approvals Board — Dunder Mifflin HR handoff wall, Scranton Branch.
// Spend ($ brass), scope (◧ slate), and destructive (⚠ oxide) gates glow with
// paper-clip brass rivets. Each card is an envelope awaiting Michael's sign-off;
// the command deck streams jobs/loops live beneath, 60 FPS corkboard with
// perforated dots. Super potent via Engine approvals queue + EventBus handoff UI.
import sync
import time
import json2
import desktop_engine.state as engine_state
import desktop_engine.eventbus

// ApprovalGateKind enumerates spend/scope/destructive per spec.
pub enum ApprovalGateKind {
	spend
	scope
	destructive
}

// ApprovalDecision tracks human gate outcome.
pub enum ApprovalDecision {
	pending
	approved
	rejected
}

// ApprovalGate is a human gate for spend/scope/destructive.
pub struct ApprovalGate {
pub mut:
	id          string
	run_id      string
	kind        ApprovalGateKind
	title       string
	message     string
	cost_usd    f64
	tokens      int
	scope_path  string // for scope/destructive: affected file/branch
	decision    ApprovalDecision
	created_at  i64
	resolved_at i64
	actor       string // who approved
}

// ApprovalsBoard manages gates per swarm run, wire to EventBus + StateRepository.
pub struct ApprovalsBoard {
mut:
	gates   map[string]ApprovalGate // id → gate
	by_run  map[string][]string // run_id → gate ids
	bus     &eventbus.ToolkitEventBus
	repo    &engine_state.StateRepository
	mu      sync.RwMutex
	emitted u64
}

// new_approvals_board creates board bound to repo/bus.
pub fn new_approvals_board(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &ApprovalsBoard {
	return &ApprovalsBoard{
		bus: bus
		repo: repo
		gates: map[string]ApprovalGate{}
		by_run: map[string][]string{}
	}
}

// gate_color returns color per kind via tokens (#C45A3C spend, #C9A86B scope, #9B3A2B destructive).
pub fn gate_color(kind ApprovalGateKind) string {
	return match kind {
		.spend { '#C9A86B' }
		.scope { '#4F9FAF' }
		.destructive { '#C45A3C' }
	}
}

// gate_icon returns icon per kind.
pub fn gate_icon(kind ApprovalGateKind) string {
	return match kind {
		.spend { '\$' }
		.scope { '◧' }
		.destructive { '⚠' }
	}
}

// request creates a new gate — spend, scope, or destructive.
// Publishes approval_requested event and persists via Transaction.
pub fn (mut b ApprovalsBoard) request(run_id string, kind ApprovalGateKind, title string, message string, cost_usd f64, tokens int, scope_path string) !string {
	if run_id.len == 0 {
		return error('approvals: run_id empty')
	}
	if title.len == 0 {
		return error('approvals: title empty')
	}
	if message.contains('AKIA') || message.contains('ghp_') {
		return error('approvals: secret in message')
	}
	if scope_path.contains('..') {
		return error('approvals: scope traversal')
	}
	// spend gate thresholds: if cost exceeds budget 80%, auto-requires approval
	// scope gate: writes outside allowlist always require
	// destructive gate: git reset --hard, push, delete branch
	id := 'gate-${time.now().unix_nano() % 1000000:06d}'
	gate := ApprovalGate{
		id: id
		run_id: run_id
		kind: kind
		title: title
		message: message
		cost_usd: cost_usd
		tokens: tokens
		scope_path: scope_path
		decision: .pending
		created_at: time.now().unix()
	}
	b.mu.lock()
	b.gates[id] = gate
	if run_id !in b.by_run {
		b.by_run[run_id] = []string{}
	}
	b.by_run[run_id] << id
	b.mu.unlock()
	mut tx := b.repo.begin('approval-request')
	tx.set('swarm/${run_id}/approvals/${id}/kind', kind.str())
	tx.set('swarm/${run_id}/approvals/${id}/title', title)
	tx.set('swarm/${run_id}/approvals/${id}/message', message)
	tx.set('swarm/${run_id}/approvals/${id}/cost', cost_usd.str())
	tx.set('swarm/${run_id}/approvals/${id}/tokens', tokens.str())
	tx.set('swarm/${run_id}/approvals/${id}/scope', scope_path)
	tx.set('swarm/${run_id}/approvals/${id}/status', 'pending')
	tx.set('swarm/${run_id}/status', 'awaiting_approval')
	rev := tx.commit() or { return error('approval persist failed: ${err}') }
	b.mu.lock()
	b.emitted++
	b.mu.unlock()
	b.bus.publish(eventbus.ToolkitEvent{
		kind: .approval_requested
		revision: rev.revision
		path: 'swarm:${run_id}:approval:${id}'
		payload: json2.encode({
			'run_id':  run_id
			'gate_id': id
			'kind':    kind.str()
			'title':   title
			'message': message
			'cost':    cost_usd.str()
			'tokens':  tokens.str()
			'scope':   scope_path
			'status':  'pending'
		})
	})
	b.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_approval
		revision: rev.revision
		path: 'swarm:approval:${id}'
		payload: json2.encode(gate)
	})
	return id
}

// approve resolves a gate as approved — human authorizes spend/scope/destructive.
// Idempotent second approve is no-op per spec.
pub fn (mut b ApprovalsBoard) approve(gate_id string, actor string) bool {
	b.mu.lock()
	mut gate := b.gates[gate_id] or {
		b.mu.unlock()
		return false
	}
	if gate.decision != .pending {
		b.mu.unlock()
		return false // idempotent no-op
	}
	gate.decision = .approved
	gate.actor = actor
	gate.resolved_at = time.now().unix()
	b.gates[gate_id] = gate
	b.mu.unlock()
	mut tx := b.repo.begin('approval-approve')
	tx.set('swarm/${gate.run_id}/approvals/${gate_id}/status', 'approved')
	tx.set('swarm/${gate.run_id}/approvals/${gate_id}/actor', actor)
	// if no pending left, move run back to running
	snap := b.repo.snapshot()
	mut still_pending := false
	for k, v in snap.data {
		if k.starts_with('swarm/${gate.run_id}/approvals/') && k.ends_with('/status') && k != 'swarm/${gate.run_id}/approvals/${gate_id}/status' {
			if v == 'pending' {
				still_pending = true
				break
			}
		}
	}
	if !still_pending {
		tx.set('swarm/${gate.run_id}/status', 'running')
	}
	rev := tx.commit() or { return false }
	b.mu.lock()
	b.emitted++
	b.mu.unlock()
	b.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_approval
		revision: rev.revision
		path: 'swarm:${gate.run_id}:approval:${gate_id}:approved'
		payload: json2.encode({
			'gate_id':  gate_id
			'actor':    actor
			'decision': 'approved'
			'kind':     gate.kind.str()
		})
	})
	b.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: rev.revision
		path: 'swarm:approval:${gate_id}'
		payload: 'approved'
	})
	return true
}

// reject resolves gate as rejected.
pub fn (mut b ApprovalsBoard) reject(gate_id string, actor string, reason string) bool {
	b.mu.lock()
	mut gate := b.gates[gate_id] or {
		b.mu.unlock()
		return false
	}
	if gate.decision != .pending {
		b.mu.unlock()
		return false
	}
	gate.decision = .rejected
	gate.actor = actor
	gate.resolved_at = time.now().unix()
	b.gates[gate_id] = gate
	b.mu.unlock()
	mut tx := b.repo.begin('approval-reject')
	tx.set('swarm/${gate.run_id}/approvals/${gate_id}/status', 'rejected')
	tx.set('swarm/${gate.run_id}/status', 'failed')
	rev := tx.commit() or { return false }
	b.mu.lock()
	b.emitted++
	b.mu.unlock()
	b.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_approval
		revision: rev.revision
		path: 'swarm:${gate.run_id}:approval:${gate_id}:rejected'
		payload: json2.encode({
			'gate_id':  gate_id
			'actor':    actor
			'decision': 'rejected'
			'reason':   reason
		})
	})
	return true
}

// pending_for returns pending gates for a run (for Inspector wall).
pub fn (b ApprovalsBoard) pending_for(run_id string) []ApprovalGate {
	b.mu.rlock()
	defer { b.mu.runlock() }
	ids := b.by_run[run_id] or { return []ApprovalGate{} }
	mut out := []ApprovalGate{}
	for id in ids {
		if gate := b.gates[id] {
			if gate.decision == .pending {
				out << gate
			}
		}
	}
	return out
}

// all_for returns all gates for a run ordered by created_at.
pub fn (b ApprovalsBoard) all_for(run_id string) []ApprovalGate {
	b.mu.rlock()
	defer { b.mu.runlock() }
	ids := b.by_run[run_id] or { return []ApprovalGate{} }
	mut out := []ApprovalGate{}
	for id in ids {
		if gate := b.gates[id] {
			out << gate
		}
	}
	out.sort_with_compare(fn (a &ApprovalGate, b &ApprovalGate) int {
		if a.created_at < b.created_at {
			return -1
		}
		if a.created_at > b.created_at {
			return 1
		}
		return 0
	})
	return out
}

// is_blocked reports whether run is blocked on any pending approval.
pub fn (b ApprovalsBoard) is_blocked(run_id string) bool {
	return b.pending_for(run_id).len > 0
}

// on_bus_event handles EventBus tick for approvals (distinct-until-changed).
pub fn (mut b ApprovalsBoard) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .approval_requested && ev.kind != .swarm_approval && ev.kind != .state_changed {
		return false
	}
	_ = snap
	b.mu.lock()
	b.emitted++
	b.mu.unlock()
	return true
}

// ── Dunder office charm — approvals handoff UI helpers ──────────────────

// approval_card_title returns the HR-wall card title with office prefix.
// Office charm: "HR Approval — Budget \(brass paper-clips\) — $0.42 Jim → Pam"
pub fn approval_card_title(g ApprovalGate) string {
	icon := gate_icon(g.kind)
	kind_label := match g.kind {
		.spend { 'Budget' }
		.scope { 'Scope' }
		.destructive { 'Destructive' }
	}
	return '${icon} ${kind_label} — ${g.title} — Scranton HR'
}

// approval_card_glow returns brass/oxide glow alpha for pending approvals.
// Pending → pulsing 28→18 brass, approved→mint 14, rejected→oxide 20.
pub fn approval_card_glow(g ApprovalGate) int {
	return match g.decision {
		.pending { 24 }
		.approved { 12 }
		.rejected { 20 }
	}
}

// approval_handoff_line renders the envelope line that created this gate.
// Used in command deck streaming: "₮ spend \$0.42 @architect — swarm-1 — HR holds envelope #8"
pub fn approval_handoff_line(g ApprovalGate) string {
	return '${gate_icon(g.kind)} ${g.kind} ${g.title} — ${g.run_id} — ${g.message}'
}

// is_spend_scope_destructive helpers for UI chips — office corkboard filters.
pub fn is_spend_gate(g ApprovalGate) bool {
	return g.kind == .spend
}

pub fn is_scope_gate(g ApprovalGate) bool {
	return g.kind == .scope
}

pub fn is_destructive_gate(g ApprovalGate) bool {
	return g.kind == .destructive
}
