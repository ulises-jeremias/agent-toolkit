module swarm

import sync
import desktop_engine.state as engine_state
import desktop_engine.eventbus

// SwarmTopologyKind enumerates pair/team/full.
pub enum SwarmTopologyKind {
	pair
	team
	full
}

// SwarmHandoffStatus for human gates.
pub enum HandoffStatus {
	pending
	awaiting_approval
	approved
	rejected
	completed
}

// SwarmHandoff is durable directed DAG edge with payload + from→to + ts + budget_spent.
pub struct SwarmHandoff {
pub:
	id           string
	from         string
	to           string
	payload      string
	ts           i64
	status       HandoffStatus
	budget_spent int
	trace_id     string
}

// SwarmBudget tracks per-swarm spend.
pub struct SwarmBudget {
pub:
	swarm_id  string
	total     int
	spent     int
	remaining int
}

// budget_color per thresholds warning 80% / red 100%.
pub fn budget_color(b SwarmBudget) string {
	pct := if b.total > 0 { f64(b.spent) / f64(b.total) * 100.0 } else { 0.0 }
	if pct >= 100.0 {
		return '#dc2626'
	}
	if pct >= 80.0 {
		return '#eab308'
	}
	return '#16a34a'
}

// SwarmRoom is the World View chamber for swarm orchestration.
pub struct SwarmRoom {
mut:
	topology SwarmTopologyKind
	handoffs []SwarmHandoff
	budgets  map[string]SwarmBudget
	traces   map[string][]string // trace_id → process_log lines
	mu       sync.RwMutex
	bus      &eventbus.ToolkitEventBus
	repo     &engine_state.StateRepository
	revision u64
	emitted  u64
}

// SwarmViewModel is derived for canvas + inspector.
pub struct SwarmViewModel {
pub:
	revision u64
	topology SwarmTopologyKind
	handoffs []SwarmHandoff
	budgets  map[string]SwarmBudget
}

// default_swarm_fixture returns pair/team/full fixture.
pub fn default_swarm_fixture(topology SwarmTopologyKind) []SwarmHandoff {
	match topology {
		.pair {
			return [
				SwarmHandoff{ id: 'h1', from: 'agent-a', to: 'agent-b', payload: 'review', ts: 1000, status: .completed, budget_spent: 30, trace_id: 'trace-1' },
				SwarmHandoff{ id: 'h2', from: 'agent-b', to: 'agent-a', payload: 'approve', ts: 1001, status: .awaiting_approval, budget_spent: 20, trace_id: 'trace-2' },
			]
		}
		.team {
			return [
				SwarmHandoff{ id: 'h1', from: 'herdr', to: 'agent-1', payload: 'task', ts: 1000, status: .completed, budget_spent: 25, trace_id: 'trace-1' },
				SwarmHandoff{ id: 'h2', from: 'agent-1', to: 'agent-2', payload: 'handoff', ts: 1001, status: .pending, budget_spent: 15, trace_id: 'trace-3' },
				SwarmHandoff{ id: 'h3', from: 'agent-2', to: 'agent-3', payload: 'handoff', ts: 1002, status: .awaiting_approval, budget_spent: 10, trace_id: 'trace-4' },
			]
		}
		.full {
			return [
				SwarmHandoff{ id: 'h1', from: 'agent-1', to: 'agent-2', payload: 'p1', ts: 1000, status: .completed, budget_spent: 10, trace_id: 'trace-1' },
				SwarmHandoff{ id: 'h2', from: 'agent-2', to: 'agent-3', payload: 'p2', ts: 1001, status: .completed, budget_spent: 15, trace_id: 'trace-2' },
				SwarmHandoff{ id: 'h3', from: 'agent-3', to: 'agent-1', payload: 'p3', ts: 1002, status: .pending, budget_spent: 20, trace_id: 'trace-3' },
				SwarmHandoff{ id: 'h4', from: 'agent-1', to: 'agent-3', payload: 'p4', ts: 1003, status: .awaiting_approval, budget_spent: 5, trace_id: 'trace-5' },
			]
		}
	}
}

// new_swarm_room creates room.
pub fn new_swarm_room(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus, topology SwarmTopologyKind) &SwarmRoom {
	handoffs := default_swarm_fixture(topology)
	mut budgets := map[string]SwarmBudget{}
	budgets['swarm-1'] = SwarmBudget{ swarm_id: 'swarm-1', total: 100, spent: 0, remaining: 100 }
	for h in handoffs {
		if h.swarm_id() in budgets {
			mut b := budgets[h.swarm_id()]
			b.spent += h.budget_spent
			b.remaining = b.total - b.spent
			budgets[h.swarm_id()] = b
		}
	}
	return &SwarmRoom{
		topology: topology
		handoffs: handoffs
		budgets: budgets
		traces: map[string][]string{}
		bus: bus
		repo: repo
	}
}

// swarm_id helper.
fn (h SwarmHandoff) swarm_id() string {
	return 'swarm-1'
}

// derive_from_state projects State snapshot (swarm_state/ via repo data).
pub fn derive_swarm_from_state(s engine_state.State, topology SwarmTopologyKind) []SwarmHandoff {
	if 'swarm_handoffs' in s.data {
		parts := s.data['swarm_handoffs'].split(',')
		mut out := []SwarmHandoff{}
		for i, p in parts {
			if p.trim_space() == '' {
				continue
			}
			out << SwarmHandoff{ id: 'h${i}', from: 'agent-${i}', to: 'agent-${i + 1}', payload: p.trim_space(), ts: 1000 + i, status: .pending, budget_spent: 10, trace_id: 'trace-${i}' }
		}
		return out
	}
	return default_swarm_fixture(topology)
}

// on_bus_event handles StateWatcher → EventBus.swarm_changed within debounce.
pub fn (mut r SwarmRoom) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .state_changed && ev.kind != .watcher_invalidated {
		return false
	}
	next := derive_swarm_from_state(snap, r.topology)
	if snap.revision == r.revision && next.len == r.handoffs.len {
		return false
	}
	r.mu.lock()
	r.handoffs = next
	r.revision = snap.revision
	r.mu.unlock()
	r.emitted++
	return true
}

// current returns view model.
pub fn (r SwarmRoom) current() SwarmViewModel {
	r.mu.rlock()
	defer { r.mu.runlock() }
	return SwarmViewModel{
		revision: r.revision
		topology: r.topology
		handoffs: r.handoffs.clone()
		budgets: r.budgets.clone()
	}
}

// approve handles human gate: awaiting_approval → approved via Engine.swarm_approve.
pub fn (mut r SwarmRoom) approve(handoff_id string, approved bool) bool {
	r.mu.lock()
	defer { r.mu.unlock() }
	for i, h in r.handoffs {
		if h.id == handoff_id && h.status == .awaiting_approval {
			// budget check before approve
			b := r.budgets['swarm-1'] or { SwarmBudget{ swarm_id: 'swarm-1', total: 100, spent: 0, remaining: 100 } }
			if approved && b.remaining < h.budget_spent {
				// over-budget blocked with toast (via bus)
				r.bus.publish(eventbus.ToolkitEvent{
					kind: .state_changed
					revision: r.revision
					path: 'swarm:budget:block'
					payload: 'over-budget ${handoff_id}'
				})
				return false
			}
			r.handoffs[i].status = if approved { .approved } else { .rejected }
			r.bus.publish(eventbus.ToolkitEvent{
				kind: .state_changed
				revision: r.revision + 1
				path: 'swarm:${handoff_id}'
				payload: if approved { 'approved' } else { 'rejected' }
			})
			r.emitted++
			return true
		}
		if h.id == handoff_id && h.status != .awaiting_approval {
			// idempotent second approve no-op
			return false
		}
	}
	return false
}

// budget_after_spend updates budget (serialized, no overspend race under VJOBS=2).
pub fn (mut r SwarmRoom) spend(swarm_id string, amount int) SwarmBudget {
	r.mu.lock()
	defer { r.mu.unlock() }
	mut b := r.budgets[swarm_id] or { SwarmBudget{ swarm_id: swarm_id, total: 100, spent: 0, remaining: 100 } }
	// serialized: check race
	if b.spent + amount > b.total {
		// cap at total, remaining not negative
		amount_capped := b.total - b.spent
		if amount_capped < 0 {
			amount_capped = 0
		}
		b.spent += amount_capped
	} else {
		b.spent += amount
	}
	b.remaining = b.total - b.spent
	if b.remaining < 0 {
		b.remaining = 0
	}
	r.budgets[swarm_id] = b
	r.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: r.revision
		path: 'swarm:budget:${swarm_id}'
		payload: 'spent=${b.spent} remaining=${b.remaining}'
	})
	return b
}

// add_trace_log adds process_log line for trace_id (demultiplexed, backpressure cap 1024).
pub fn (mut r SwarmRoom) add_trace_log(trace_id string, line string) {
	r.mu.lock()
	defer { r.mu.unlock() }
	mut lst := r.traces[trace_id] or { []string{} }
	if lst.len >= 1024 {
		// drop-oldest + metric (headless: remove first)
		lst.delete(0)
	}
	lst << line
	r.traces[trace_id] = lst
}

// trace_slice returns ordered process_log for trace_id isolated (no cross-talk).
pub fn (r SwarmRoom) trace_slice(trace_id string) []string {
	r.mu.rlock()
	defer { r.mu.runlock() }
	return r.traces[trace_id] or { []string{} }
}

// worktree_lanes returns per-agent lanes for topology.
pub fn (r SwarmRoom) worktree_lanes() []string {
	return match r.topology {
		.pair { ['agent-a lane', 'agent-b lane'] }
		.team { ['herdr lane', 'agent-1 lane', 'agent-2 lane', 'agent-3 lane'] }
		.full { ['agent-1 lane', 'agent-2 lane', 'agent-3 lane', 'agent-4 lane'] }
	}
}
