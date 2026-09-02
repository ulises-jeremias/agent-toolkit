module swarm

import sync
import json2
import desktop_engine.state as engine_state
import desktop_engine.eventbus

// SwarmEventKind maps ToolkitEventKind swarm variants for UI.
pub enum SwarmEventKind {
	created
	handoff
	status
	approval
	artifact
	log
	inner_tick
	outer_tick
	unknown
}

// swarm_kind_from_event maps ToolkitEvent → SwarmEventKind.
pub fn swarm_kind_from_event(kind eventbus.ToolkitEventKind) SwarmEventKind {
	return match kind {
		.swarm_created { .created }
		.swarm_handoff { .handoff }
		.swarm_status { .status }
		.swarm_approval { .approval }
		.handoff_artifact { .artifact }
		.process_log { .log }
		.loop_inner_tick { .inner_tick }
		.loop_outer_tick { .outer_tick }
		.approval_requested { .approval }
		else { .unknown }
	}
}

// SwarmStatus aggregates status per run for Swarm UI.
pub struct SwarmStatus {
pub:
	run_id            string
	recipe            string
	backend           string // herdr|tmux|auto|headless
	status            string // pending|running|awaiting_approval|completed|failed
	task              string
	budget_total      int
	budget_spent      int
	approvals_pending int
	handoffs_pending  int
	worktree_lanes    []string
}

// SwarmLogEntry is a demultiplexed log line per swarm run.
pub struct SwarmLogEntry {
pub:
	run_id   string
	trace_id string
	stream   string // stdout|stderr
	line     string
	ts       i64
}

// SwarmEventHub wires desktop_engine EventBus → Swarm UI status/handoffs/logs.
// Single source: EventBus. Shows swarm status, handoffs, logs within one tick.
pub struct SwarmEventHub {
mut:
	statuses map[string]SwarmStatus // run_id → status
	handoffs map[string][]string // run_id → handoff payloads
	logs     map[string][]SwarmLogEntry // run_id → logs
	bus      &eventbus.ToolkitEventBus
	repo     &engine_state.StateRepository
	mu       sync.RwMutex
	revision u64
	emitted  u64
	dropped  u64
}

// new_swarm_event_hub creates hub bound to repo/bus with replay backfill.
pub fn new_swarm_event_hub(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &SwarmEventHub {
	mut hub := &SwarmEventHub{
		bus: bus
		repo: repo
		statuses: map[string]SwarmStatus{}
		handoffs: map[string][]string{}
		logs: map[string][]SwarmLogEntry{}
	}
	// backfill from EventBus replay for late subscribers
	if ev := bus.replay_for(.swarm_status) {
		hub.on_bus_event(ev, repo.snapshot())
	}
	if ev := bus.replay_for(.swarm_handoff) {
		hub.on_bus_event(ev, repo.snapshot())
	}
	if ev := bus.replay_for(.process_log) {
		hub.on_bus_event(ev, repo.snapshot())
	}
	return hub
}

// status_for returns status for run_id (for Swarm UI panel + inspector).
pub fn (h SwarmEventHub) status_for(run_id string) ?SwarmStatus {
	h.mu.rlock()
	defer { h.mu.runlock() }
	return h.statuses[run_id]
}

// all_statuses returns all swarm statuses sorted by run_id.
pub fn (h SwarmEventHub) all_statuses() []SwarmStatus {
	h.mu.rlock()
	defer { h.mu.runlock() }
	mut out := []SwarmStatus{}
	for _, s in h.statuses {
		out << s
	}
	out.sort_with_compare(fn (a &SwarmStatus, b &SwarmStatus) int {
		if a.run_id < b.run_id {
			return -1
		}
		if a.run_id > b.run_id {
			return 1
		}
		return 0
	})
	return out
}

// handoffs_for returns handoff payloads for run_id.
pub fn (h SwarmEventHub) handoffs_for(run_id string) []string {
	h.mu.rlock()
	defer { h.mu.runlock() }
	return h.handoffs[run_id] or { []string{} }
}

// logs_for returns logs for run_id.
pub fn (h SwarmEventHub) logs_for(run_id string) []SwarmLogEntry {
	h.mu.rlock()
	defer { h.mu.runlock() }
	return h.logs[run_id] or { []SwarmLogEntry{} }
}

// derive_statuses projects State snapshot → SwarmStatus list.
fn derive_statuses_from_state(s engine_state.State) map[string]SwarmStatus {
	mut ids := []string{}
	for k, _ in s.data {
		if k.starts_with('swarm/runs/') && k.ends_with('/recipe') {
			id := k.all_after('swarm/runs/').all_before('/recipe')
			if id !in ids { ids << id }
		}
	}
	mut out := map[string]SwarmStatus{}
	for id in ids {
		recipe := s.data['swarm/runs/${id}/recipe'] or { 'pair' }
		backend := s.data['swarm/runs/${id}/backend'] or { 'auto' }
		status := s.data['swarm/runs/${id}/status'] or { 'pending' }
		task := s.data['swarm/runs/${id}/task'] or { '' }
		btotal := (s.data['swarm/runs/${id}/budget_total'] or { '100' }).int()
		bspent := (s.data['swarm/runs/${id}/budget_spent'] or { '0' }).int()
		// count pending approvals via keys
		mut appr_pending := 0
		for k, v in s.data {
			if k.starts_with('swarm/${id}/approvals/') && k.ends_with('/status') && v == 'pending' {
				appr_pending++
			}
		}
		mut h_pending := 0
		for k, v in s.data {
			if k.starts_with('swarm/handoffs/') && v.contains(id) { h_pending++ }
		}
		lanes := match recipe {
			'pair' { ['implementer lane', 'reviewer lane'] }
			'team' { ['planner lane', 'implementer lane', 'reviewer lane', 'architect lane'] }
			'full' {
				['planner lane', 'implementer lane', 'refactorer lane', 'architect lane',
					'hardener lane', 'qa lane']
			}
			else { ['lane'] }
		}
		out[id] = SwarmStatus{
			run_id: id
			recipe: recipe
			backend: backend
			status: status
			task: task
			budget_total: btotal
			budget_spent: bspent
			approvals_pending: appr_pending
			handoffs_pending: h_pending
			worktree_lanes: lanes
		}
	}
	return out
}

// on_bus_event handles ToolkitEvent → status/handoffs/logs within one EventBus→frame tick.
// Distinct-until-changed: duplicate revision does not emit.
pub fn (mut h SwarmEventHub) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	kind := swarm_kind_from_event(ev.kind)
	if kind == .unknown {
		// also handle state_changed that encodes swarm data
		if ev.kind != .state_changed && ev.kind != .watcher_invalidated {
			return false
		}
		// if state_changed path indicates swarm, treat as status
		if !ev.path.contains('swarm') && !ev.payload.contains('swarm') {
			// still derive from snapshot for status projection
		}
	}
	if snap.revision == h.revision && h.statuses.len > 0 && ev.payload == '' {
		h.dropped++
		return false
	}
	// derive statuses from snapshot (State → View pure projection)
	next_statuses := derive_statuses_from_state(snap)
	h.mu.lock()
	h.statuses = next_statuses.clone()
	h.revision = snap.revision
	h.emitted++
	h.mu.unlock()

	// also handle handoff/log payload append
	match ev.kind {
		.swarm_handoff, .handoff_artifact {
			// payload contains run_id → append to handoffs map
			run_id := extract_run_id(ev.payload, ev.path)
			if run_id.len > 0 {
				h.mu.lock()
				if run_id !in h.handoffs {
					h.handoffs[run_id] = []string{}
				}
				h.handoffs[run_id] << ev.payload
				// cap backpressure per run 1024
				if h.handoffs[run_id].len > 1024 {
					h.handoffs[run_id].delete(0)
					h.dropped++
				}
				h.mu.unlock()
			}
		}
		.process_log {
			run_id := extract_run_id(ev.payload, ev.path)
			if run_id.len > 0 {
				entry := SwarmLogEntry{
					run_id: run_id
					trace_id: run_id
					stream: 'stdout'
					line: ev.payload
					ts: i64(snap.revision)
				}
				h.mu.lock()
				if run_id !in h.logs {
					h.logs[run_id] = []SwarmLogEntry{}
				}
				h.logs[run_id] << entry
				if h.logs[run_id].len > 1024 {
					h.logs[run_id].delete(0)
					h.dropped++
				}
				h.mu.unlock()
			}
		}
		else {}
	}
	return true
}

fn extract_run_id(payload string, path string) string {
	// try payload json first, then path
	if payload.contains('run_id') {
		// crude extract: find run_id value
		parts := payload.split('run_id')
		if parts.len > 1 {
			rest := parts[1]
			// find quoted value
			mut start := -1
			mut end := -1
			for i, c in rest {
				if c == `"` {
					if start == -1 {
						start = i
					} else {
						end = i
						break
					}
				}
			}
			if start != -1 && end != -1 && end > start {
				return rest[start + 1..end]
			}
		}
	}
	if path.contains('swarm') {
		// path like swarm:launch:swarm-123 or swarm/handoff/swarm-123
		segments := path.split('/')
		for seg in segments {
			if seg.starts_with('swarm-') {
				return seg
			}
		}
		segments2 := path.split(':')
		for seg in segments2 {
			if seg.starts_with('swarm-') {
				return seg
			}
		}
	}
	return ''
}

// current_view returns aggregated view model for Swarm UI panel.
pub struct SwarmHubViewModel {
pub:
	revision       u64
	statuses       []SwarmStatus
	total          int
	handoffs_total int
	logs_total     int
}

pub fn (h SwarmEventHub) current_view() SwarmHubViewModel {
	h.mu.rlock()
	defer { h.mu.runlock() }
	mut tot_h := 0
	for _, lst in h.handoffs {
		tot_h += lst.len
	}
	mut tot_l := 0
	for _, lst in h.logs {
		tot_l += lst.len
	}
	mut sts := []SwarmStatus{}
	for _, s in h.statuses {
		sts << s
	}
	sts.sort_with_compare(fn (a &SwarmStatus, b &SwarmStatus) int {
		if a.run_id < b.run_id {
			return -1
		}
		if a.run_id > b.run_id {
			return 1
		}
		return 0
	})
	return SwarmHubViewModel{
		revision: h.revision
		statuses: sts
		total: sts.len
		handoffs_total: tot_h
		logs_total: tot_l
	}
}

// json_view encodes status for inspector (uses json2).
pub fn (h SwarmEventHub) json_view() string {
	vm := h.current_view()
	return json2.encode(vm)
}
