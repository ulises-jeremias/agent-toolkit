module loops

import desktop_engine
import desktop.theme
import desktop.state as app_state
import desktop_engine.eventbus

pub struct LoopsViewModel {
mut:
	engine   &desktop_engine.Engine
	loops    []desktop_engine.LoopEntry
	bus      &eventbus.ToolkitEventBus
	revision u64
}

pub fn new_loops_viewmodel(mut engine &desktop_engine.Engine, bus &eventbus.ToolkitEventBus) LoopsViewModel {
	return LoopsViewModel{
		engine: engine
		loops: engine.loops_catalog()
		bus: bus
		revision: engine.revision()
	}
}

pub fn (mut vm LoopsViewModel) refresh() {
	vm.loops = vm.engine.loops_catalog()
	vm.revision = vm.engine.revision()
}

pub fn (vm LoopsViewModel) all_loops() []desktop_engine.LoopEntry {
	return vm.loops.clone()
}

pub fn (mut vm LoopsViewModel) upsert(entry desktop_engine.LoopEntry) !u64 {
	rev := vm.engine.upsert_loop(entry)!
	vm.refresh()
	return rev
}

pub fn (mut vm LoopsViewModel) validate(name string, content string) []desktop_engine.BuildDiagnostic {
	return vm.engine.loop_validate(name, content)
}

pub fn (mut vm LoopsViewModel) run(name string) !string {
	id := vm.engine.run_loop(name)!
	vm.bus.publish(eventbus.ToolkitEvent{
		kind: .process_log
		revision: vm.revision
		path: name
		payload: '{"loop":"${name}","job_id":"${id}"}'
	})
	vm.refresh()
	return id
}

pub fn (mut vm LoopsViewModel) toggle_cron(name string, enabled bool) !u64 {
	rev := vm.engine.toggle_loop_cron(name, enabled)!
	vm.refresh()
	return rev
}

pub fn (mut vm LoopsViewModel) history(loop_name string) []desktop_engine.LoopHistory {
	return vm.engine.loops_history(loop_name)
}

// create — easy one-click via Engine.create_loop()
pub fn (mut vm LoopsViewModel) create(name string, tier string, cadence string, goal string) !u64 {
	rev := vm.engine.create_loop(name, tier, cadence, goal)!
	vm.refresh()
	return rev
}

pub fn (mut vm LoopsViewModel) delete(name string) !u64 {
	rev := vm.engine.delete_loop(name)!
	vm.refresh()
	return rev
}

pub fn (mut vm LoopsViewModel) detail(name string) ?desktop_engine.LoopEntry {
	return vm.engine.loop_detail(name)
}

pub fn (mut vm LoopsViewModel) update(name string, goal string, cadence string, budget desktop_engine.LoopBudget) !u64 {
	rev := vm.engine.update_loop(name, goal, cadence, budget)!
	vm.refresh()
	return rev
}

pub fn (mut vm LoopsViewModel) budget_ledger(name string) (int, int, int) {
	return vm.engine.loop_budget_ledger(name)
}

pub fn (mut vm LoopsViewModel) set_budget(name string, budget desktop_engine.LoopBudget) !u64 {
	rev := vm.engine.loop_set_budget(name, budget)!
	vm.refresh()
	return rev
}

// ── Ergonomic list / status / audit / cost / start / stop / budget display ──
pub fn (mut vm LoopsViewModel) list() []desktop_engine.LoopEntry {
	return vm.engine.loops_list()
}

pub fn (mut vm LoopsViewModel) status(name string) []desktop_engine.LoopEntry {
	return vm.engine.loops_status(name)
}

pub fn (mut vm LoopsViewModel) audit(name string) []desktop_engine.LoopAudit {
	return vm.engine.loops_audit(name)
}

pub fn (mut vm LoopsViewModel) cost(name string) ?desktop_engine.LoopCost {
	return vm.engine.loops_cost(name)
}

pub fn (mut vm LoopsViewModel) start(name string) !string {
	id := vm.engine.loops_start(name)!
	vm.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_outer_tick
		revision: vm.revision
		path: 'loops:${name}:start'
		payload: '{"loop":"${name}","job_id":"${id}"}'
	})
	vm.refresh()
	return id
}

pub fn (mut vm LoopsViewModel) stop(name string) !u64 {
	rev := vm.engine.loops_stop(name)!
	vm.refresh()
	return rev
}

pub fn (mut vm LoopsViewModel) budget_display(name string) string {
	return vm.engine.loops_budget_display(name)
}

pub fn (mut vm LoopsViewModel) worktree_path(loop_name string, run_id string) !string {
	return vm.engine.loop_worktree_path(loop_name, run_id)
}

pub fn (mut vm LoopsViewModel) hygiene(loop_name string) []desktop_engine.BuildDiagnostic {
	return vm.engine.ensure_loop_worktree_hygiene(loop_name)
}

pub fn (mut vm LoopsViewModel) receipts(loop_name string) []desktop_engine.ProvenanceEntry {
	return vm.engine.loop_receipts(loop_name)
}

pub fn (mut vm LoopsViewModel) all_tiers() []string {
	return ['L1', 'L2', 'L3']
}

pub fn (mut vm LoopsViewModel) mission_board() map[string]int {
	mut board := map[string]int{}
	for l in vm.loops {
		key := l.tier.str()
		board[key]++
	}
	jobs := vm.engine.jobs_catalog()
	for j in jobs {
		board[j.status.str()]++
	}
	return board
}

pub fn (mut vm LoopsViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm LoopsViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
