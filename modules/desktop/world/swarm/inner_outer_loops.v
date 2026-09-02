module swarm

import sync
import time
import x.json2
import desktop_engine.state as engine_state
import desktop_engine.eventbus
import desktop_engine

// LoopStageKind distinguishes inner vs outer loop stage.
pub enum LoopStageKind {
	inner // per-handoff iteration within a swarm run
	outer // scheduled mission cadence (daily/1h/etc)
}

// LoopExitCondition enumerates when loop stops.
pub enum LoopExitCondition {
	goal_met
	budget_exhausted
	human_escalation
	max_iterations
	timeout
}

// InnerLoop tracks per-role iteration inside a swarm run (e.g., implement→review→fix cycle).
// Bounded by max_role_round_trips (default 2) per SWARM_RECIPES.md.
pub struct InnerLoop {
pub mut:
	loop_id        string
	run_id         string
	role           string
	iteration      int
	max_iterations int
	goal           string
	status         string // running | completed | awaiting_approval | failed
	budget_spent   int
	budget_total   int
	trace          []string // process_log trace lines
	exit           LoopExitCondition
}

// OuterLoop is the scheduled mission (e.g., daily-triage L1 1d, ci-sweeper L2 15m).
// Runs via Engine.loops_catalog with cadence cron.
pub struct OuterLoop {
pub:
	name         string
	goal         string
	cadence      string
	tier         desktop_engine.LoopTier
	enabled      bool
	next_run     string
	last_run     string
	last_exit    string
	budget_total int
	budget_spent int
	schedule     string // cron expr derived from cadence
}

// LoopsViewModel projects inner+outer loops for Swarm Room Mission Board.
pub struct LoopsViewModel {
pub:
	inner    []InnerLoop
	outer    []OuterLoop
	revision u64
}

// LoopMissionBoard aggregates inner/outer loops with budget ledger.
pub struct LoopMissionBoard {
mut:
	inner_loops map[string]InnerLoop // loop_id → InnerLoop
	outer_loops map[string]OuterLoop // name → OuterLoop
	bus         &eventbus.ToolkitEventBus
	repo        &engine_state.StateRepository
	mu          sync.RwMutex
	revision    u64
	emitted     u64
}

// new_loop_mission_board creates board bound to repo/bus.
pub fn new_loop_mission_board(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &LoopMissionBoard {
	return &LoopMissionBoard{
		bus: bus
		repo: repo
		inner_loops: map[string]InnerLoop{}
		outer_loops: map[string]OuterLoop{}
	}
}

// derive_outer_from_state projects State snapshot outer loops via Engine loops_catalog.
pub fn derive_outer_from_state(s engine_state.State) []OuterLoop {
	// use naming convention from loops_service: goal-observe etc.
	// Also check State data keys loops/<name>/goal
	mut names := []string{}
	for k, _ in s.data {
		if k.starts_with('loops/') && k.ends_with('/goal') {
			name := k.all_after('loops/').all_before('/goal')
			if name !in names {
				names << name
			}
		}
	}
	mut out := []OuterLoop{}
	if names.len > 0 {
		for n in names {
			goal := s.data['loops/${n}/goal'] or { 'Goal ${n}' }
			tier_str := s.data['loops/${n}/tier'] or { 'l1' }
			tier := match tier_str {
				'l2' { desktop_engine.LoopTier.l2 }
				'l3' { desktop_engine.LoopTier.l3 }
				else { desktop_engine.LoopTier.l1 }
			}
			cadence := s.data['loops/${n}/cadence'] or { '1d' }
			btotal_str := s.data['loops/${n}/budget'] or { '100' }
			bspent_str := s.data['loops/${n}/spent'] or { '0' }
			enabled := (s.data['loops/${n}/cron'] or { 'false' }) == 'true'
			next_run := s.data['loops/${n}/next_run'] or { '' }
			last_run := s.data['loops/${n}/last_run'] or { '' }
			out << OuterLoop{
				name: n
				goal: goal
				cadence: cadence
				tier: tier
				enabled: enabled
				next_run: next_run
				last_run: last_run
				budget_total: btotal_str.int()
				budget_spent: bspent_str.int()
				schedule: cadence_to_cron(cadence)
			}
		}
		return out
	}
	// fallback fixture outer loops
	return [
		OuterLoop{ name: 'daily-triage', goal: 'Triage open issues', cadence: '1d', tier: .l1, enabled: true, schedule: '0 0 * * *', budget_total: 100, budget_spent: 20 },
		OuterLoop{ name: 'ci-sweeper', goal: 'Sweep CI failures', cadence: '15m', tier: .l2, enabled: false, schedule: '*/15 * * * *', budget_total: 100, budget_spent: 40 },
		OuterLoop{ name: 'swarm-watch', goal: 'Monitor swarm handoffs', cadence: '15m', tier: .l1, enabled: true, schedule: '*/15 * * * *', budget_total: 50, budget_spent: 10 },
	]
}

fn cadence_to_cron(cadence string) string {
	return match cadence {
		'15m' { '*/15 * * * *' }
		'1h', '60m' { '0 * * * *' }
		'4h' { '0 */4 * * *' }
		'1d' { '0 0 * * *' }
		'1w' { '0 0 * * 0' }
		else { '0 0 * * *' }
	}
}

// start_inner creates an inner loop for a swarm run role iteration.
pub fn (mut mb LoopMissionBoard) start_inner(run_id string, role string, goal string, max_iter int) InnerLoop {
	mut max_i := max_iter
	if max_i <= 0 {
		max_i = 2
	}
	if max_i > 10 {
		max_i = 10
	}
	loop_id := 'inner-${run_id}-${role}-${time.now().unix_nano() % 1000000:06d}'
	inner := InnerLoop{
		loop_id: loop_id
		run_id: run_id
		role: role
		iteration: 0
		max_iterations: max_i
		goal: goal
		status: 'running'
		budget_total: 100
		budget_spent: 0
		trace: []string{}
	}
	mb.mu.lock()
	mb.inner_loops[loop_id] = inner
	mb.mu.unlock()
	mut tx := mb.repo.begin('inner-loop-start')
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/role', role)
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/goal', goal)
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/iteration', '0')
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/max', max_i.str())
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/status', 'running')
	rev := tx.commit() or { return inner }
	mb.mu.lock()
	mb.revision = rev.revision
	mb.emitted++
	mb.mu.unlock()
	mb.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_inner_tick
		revision: rev.revision
		path: 'swarm:${run_id}:inner:${loop_id}'
		payload: json2.encode({
			'loop_id':   loop_id
			'run_id':    run_id
			'role':      role
			'iteration': '0'
			'max':       max_i.str()
			'status':    'running'
		})
	})
	return inner
}

// tick_inner advances inner loop iteration, records trace, publishes loop_inner_tick.
pub fn (mut mb LoopMissionBoard) tick_inner(loop_id string, trace_line string, budget_spent int) bool {
	mb.mu.lock()
	mut inner := mb.inner_loops[loop_id] or {
		mb.mu.unlock()
		return false
	}
	if inner.status != 'running' {
		mb.mu.unlock()
		return false
	}
	if inner.iteration >= inner.max_iterations {
		// already at max — require approval gate
		inner.status = 'awaiting_approval'
		inner.exit = .max_iterations
		mb.inner_loops[loop_id] = inner
		mb.mu.unlock()
		return false
	}
	inner.iteration++
	inner.budget_spent += budget_spent
	if trace_line.len > 0 {
		inner.trace << trace_line
	}
	// check budget exhausted
	if inner.budget_spent >= inner.budget_total {
		inner.status = 'failed'
		inner.exit = .budget_exhausted
	}
	mb.inner_loops[loop_id] = inner
	mb.mu.unlock()
	mut tx := mb.repo.begin('inner-loop-tick')
	tx.set('swarm/${inner.run_id}/inner_loops/${loop_id}/iteration', inner.iteration.str())
	tx.set('swarm/${inner.run_id}/inner_loops/${loop_id}/budget_spent', inner.budget_spent.str())
	tx.set('swarm/${inner.run_id}/inner_loops/${loop_id}/status', inner.status)
	if trace_line.len > 0 {
		existing := mb.repo.snapshot().data['swarm/${inner.run_id}/inner_loops/${loop_id}/trace'] or { '' }
		trace_val := if existing.len > 0 { existing + '\n' + trace_line } else { trace_line }
		tx.set('swarm/${inner.run_id}/inner_loops/${loop_id}/trace', trace_val)
	}
	rev := tx.commit() or { return true }
	mb.mu.lock()
	mb.revision = rev.revision
	mb.emitted++
	mb.mu.unlock()
	mb.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_inner_tick
		revision: rev.revision
		path: 'swarm:${inner.run_id}:inner:${loop_id}:tick:${inner.iteration}'
		payload: json2.encode({
			'loop_id':      loop_id
			'iteration':    inner.iteration.str()
			'trace':        trace_line
			'budget_spent': inner.budget_spent.str()
			'status':       inner.status
		})
	})
	mb.bus.publish(eventbus.ToolkitEvent{
		kind: .process_log
		revision: rev.revision
		path: 'inner:${loop_id}'
		payload: trace_line
	})
	return true
}

// complete_inner marks inner loop done.
pub fn (mut mb LoopMissionBoard) complete_inner(loop_id string, exit LoopExitCondition) bool {
	mb.mu.lock()
	mut inner := mb.inner_loops[loop_id] or {
		mb.mu.unlock()
		return false
	}
	inner.status = 'completed'
	inner.exit = exit
	mb.inner_loops[loop_id] = inner
	mb.mu.unlock()
	mut tx := mb.repo.begin('inner-loop-complete')
	tx.set('swarm/${inner.run_id}/inner_loops/${loop_id}/status', 'completed')
	tx.set('swarm/${inner.run_id}/inner_loops/${loop_id}/exit', exit.str())
	rev := tx.commit() or { return false }
	mb.mu.lock()
	mb.revision = rev.revision
	mb.emitted++
	mb.mu.unlock()
	mb.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_inner_tick
		revision: rev.revision
		path: 'swarm:${inner.run_id}:inner:${loop_id}:completed'
		payload: json2.encode({
			'loop_id': loop_id
			'exit':    exit.str()
		})
	})
	return true
}

// mission_board returns view model for canvas + inspector (Mission Board).
pub fn (mb LoopMissionBoard) mission_board() LoopsViewModel {
	mb.mu.rlock()
	defer { mb.mu.runlock() }
	mut inner := []InnerLoop{}
	for _, v in mb.inner_loops {
		inner << v
	}
	inner.sort_with_compare(fn (a &InnerLoop, b &InnerLoop) int {
		if a.loop_id < b.loop_id {
			return -1
		}
		if a.loop_id > b.loop_id {
			return 1
		}
		return 0
	})
	// outer derived from repo snapshot if available, else cached
	snap := mb.repo.snapshot()
	outer := derive_outer_from_state(snap)
	return LoopsViewModel{
		inner: inner
		outer: outer
		revision: mb.revision
	}
}

// on_bus_event handles EventBus→loop board tick distinct-until-changed.
pub fn (mut mb LoopMissionBoard) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .loop_inner_tick && ev.kind != .loop_outer_tick && ev.kind != .state_changed && ev.kind != .process_log {
		return false
	}
	if snap.revision == mb.revision {
		return false
	}
	mb.mu.lock()
	mb.revision = snap.revision
	mb.emitted++
	mb.mu.unlock()
	return true
}
