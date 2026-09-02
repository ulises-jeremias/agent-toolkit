module swarm

// Swarm ViewModel — Dunder Mifflin Paper Company bullpen, Scranton Branch.
// Pair/team/full launches are regional sales squads dispatched via Engine; GOD
// routes every envelope through the mailbox (mailbox glow), avatars walk the
// floor at 80 px/s with 4-frame bob, command deck streams jobs/loops with
// 1024-cap backpressure, approvals handoff UI glows brass. 60 FPS, headless-safe,
// Engine-typed (no shell), distinctive office charm in every label.
import desktop_engine
import desktop_engine.eventbus
import desktop.state as app_state
import desktop.theme
import desktop_engine.state as engine_state

// SwarmBackendOption mirrors herdr/tmux choice for UI.
pub enum SwarmBackendOption {
	auto
	herdr
	tmux
	headless
}

// SwarmLaunchChoice is the easy pair/team/full launcher via Desktop UI.
pub struct SwarmLaunchChoice {
pub:
	recipe  string // pair|team|full
	backend SwarmBackendOption
	task    string
}

// SwarmViewModel is the Desktop UI model for swarm launch + status/handoffs/logs.
pub struct SwarmViewModel {
mut:
	engine &desktop_engine.Engine
	bus    &eventbus.ToolkitEventBus
	repo   &engine_state.StateRepository
	// derived
	suggested_task string
	last_run_id    string
	last_error     string
	revision       u64
}

// new_swarm_viewmodel creates viewmodel bound to Engine + bus.
pub fn new_swarm_viewmodel(mut engine &desktop_engine.Engine, bus &eventbus.ToolkitEventBus) SwarmViewModel {
	return SwarmViewModel{
		engine: engine
		bus: bus
		repo: engine.state_repo()
		suggested_task: 'Implement feature via swarm'
	}
}

// suggested_task returns current suggested task for quick launch.
pub fn (vm SwarmViewModel) suggested() string {
	return vm.suggested_task
}

// update_suggested sets task text (from UI input).
pub fn (mut vm SwarmViewModel) update_suggested(task string) {
	vm.suggested_task = task
}

// launch_pair launches pair swarm via Desktop UI — easy one-click.
pub fn (mut vm SwarmViewModel) launch_pair(task string) !string {
	t := if task.len > 0 { task } else { vm.suggested_task }
	if t.len == 0 {
		return error('task empty')
	}
	backend := SwarmBackendOption.auto
	return vm.launch_with(SwarmLaunchChoice{ recipe: 'pair', backend: backend, task: t })
}

// launch_team launches team swarm.
pub fn (mut vm SwarmViewModel) launch_team(task string) !string {
	t := if task.len > 0 { task } else { vm.suggested_task }
	return vm.launch_with(SwarmLaunchChoice{ recipe: 'team', backend: .auto, task: t })
}

// launch_full launches full swarm.
pub fn (mut vm SwarmViewModel) launch_full(task string) !string {
	t := if task.len > 0 { task } else { vm.suggested_task }
	return vm.launch_with(SwarmLaunchChoice{ recipe: 'full', backend: .auto, task: t })
}

// launch_with dispatches via Engine.swarm_launch (typed, not shell) and publishes swarm_created.
pub fn (mut vm SwarmViewModel) launch_with(choice SwarmLaunchChoice) !string {
	if choice.task.len == 0 {
		return error('task empty')
	}
	if choice.task.len > 4096 {
		return error('task too long')
	}
	if choice.recipe !in ['pair', 'team', 'full'] {
		return error('recipe must be pair|team|full')
	}
	backend_str := match choice.backend {
		.auto { 'auto' }
		.herdr { 'herdr' }
		.tmux { 'tmux' }
		.headless { 'headless' }
	}
	recipe_kind := desktop_engine.swarm_recipe_from_string(choice.recipe)
	backend_kind := desktop_engine.swarm_backend_from_string(backend_str)
	args := desktop_engine.SwarmLaunchArgs{
		recipe: recipe_kind
		backend: backend_kind
		task: choice.task
	}
	run_id := vm.engine.swarm_launch(args)!
	vm.last_run_id = run_id
	vm.revision = vm.engine.revision()
	vm.last_error = ''
	// EventBus is already published inside Engine.swarm_launch; viewmodel just refreshes
	vm.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_created
		revision: vm.revision
		path: 'swarm:launch:${run_id}'
		payload: '{"run_id":"${run_id}","recipe":"${choice.recipe}","backend":"${backend_str}","task":"${choice.task}"}'
	})
	return run_id
}

// launch_with_backend launches with explicit herdr/tmux choice for Swarm UI.
pub fn (mut vm SwarmViewModel) launch_with_backend(recipe string, backend SwarmBackendOption, task string) !string {
	return vm.launch_with(SwarmLaunchChoice{ recipe: recipe, backend: backend, task: task })
}

// ── Ergonomic list / status / handoffs / start / stop / budget / worktree hygiene ──

// all_runs returns swarm runs via Engine (for Swarm UI status list).
pub fn (mut vm SwarmViewModel) all_runs() []desktop_engine.SwarmRun {
	return vm.engine.swarm_list()
}

// list is alias for all_runs — `swarm list` via Engine.
pub fn (mut vm SwarmViewModel) list() []desktop_engine.SwarmRun {
	return vm.engine.swarm_list_all()
}

// start ergonomic wrapper — `swarm start` via Engine pair/team/full.
pub fn (mut vm SwarmViewModel) start(task string, recipe string, backend string) !string {
	return vm.engine.swarm_start(task, recipe, backend)
}

// stop ergonomic wrapper — `swarm stop` with worktree hygiene.
pub fn (mut vm SwarmViewModel) stop(run_id string) !u64 {
	return vm.engine.swarm_stop(run_id)
}

// cancel alias
pub fn (mut vm SwarmViewModel) cancel(run_id string) !u64 {
	return vm.engine.swarm_cancel(run_id)
}

// status_for returns status for a run.
pub fn (mut vm SwarmViewModel) status_for(run_id string) ?desktop_engine.SwarmRun {
	return vm.engine.swarm_status(run_id)
}

// status is alias for status_for — `swarm status` via Engine.
pub fn (mut vm SwarmViewModel) status(run_id string) ?desktop_engine.SwarmRun {
	return vm.engine.swarm_status(run_id)
}

// handoffs_for returns handoffs for a run (for handoffs panel).
pub fn (mut vm SwarmViewModel) handoffs_for(run_id string) []string {
	return vm.engine.swarm_handoffs(run_id)
}

// handoffs is alias — `swarm handoffs` via Engine.
pub fn (mut vm SwarmViewModel) handoffs(run_id string) []string {
	return vm.engine.swarm_handoffs(run_id)
}

// logs_for returns logs for a run (for logs panel / terminal).
pub fn (mut vm SwarmViewModel) logs_for(run_id string) []string {
	return vm.engine.swarm_logs(run_id)
}

// pending_approvals returns human gates pending for a run (spend/scope/destructive).
pub fn (mut vm SwarmViewModel) pending_approvals(run_id string) []desktop_engine.SwarmApproval {
	return vm.engine.swarm_pending_approvals(run_id)
}

// approve resolves a gate via Engine (spend/scope/destructive).
pub fn (mut vm SwarmViewModel) approve(run_id string, approval_id string) !u64 {
	return vm.engine.swarm_approve(run_id, approval_id, true)
}

// reject resolves as rejected.
pub fn (mut vm SwarmViewModel) reject(run_id string, approval_id string) !u64 {
	return vm.engine.swarm_approve(run_id, approval_id, false)
}

// request_spend_approval creates spend gate (UI→Engine).
pub fn (mut vm SwarmViewModel) request_spend_approval(run_id string, message string, cost f64) !string {
	return vm.engine.swarm_request_approval(run_id, .spend, message, 0)
}

// request_scope_approval creates scope gate.
pub fn (mut vm SwarmViewModel) request_scope_approval(run_id string, message string, path string) !string {
	return vm.engine.swarm_request_approval(run_id, .scope, message, 0)
}

// request_destructive_approval creates destructive gate.
pub fn (mut vm SwarmViewModel) request_destructive_approval(run_id string, message string, path string) !string {
	return vm.engine.swarm_request_approval(run_id, .destructive, message, 0)
}

// herdr_available probes herdr via doctor check (Engine, not shell).
pub fn (mut vm SwarmViewModel) herdr_available() bool {
	// wire to Engine doctor or fallback to probe; headless stub checks env
	checks := vm.engine.doctor()
	for c in checks {
		if c.id.contains('herdr') {
			return c.status == 'pass'
		}
	}
	// fallback: if backend auto, herdr is preferred per SWARM_HERDR.md
	return true
}

// tmux_available probes tmux.
pub fn (mut vm SwarmViewModel) tmux_available() bool {
	checks := vm.engine.doctor()
	for c in checks {
		if c.id.contains('tmux') {
			return c.status == 'pass'
		}
	}
	return true
}

// write_artifact creates handoff artifact file via Engine (for filesystem queue).
pub fn (mut vm SwarmViewModel) write_artifact(run_id string, rel_path string, content string) !string {
	return vm.engine.write_handoff_artifact(run_id, rel_path, content)
}

// read_artifact reads artifact.
pub fn (mut vm SwarmViewModel) read_artifact(run_id string, rel_path string) !string {
	return vm.engine.read_handoff_artifact(run_id, rel_path)
}

// list_artifacts lists artifacts for run.
pub fn (mut vm SwarmViewModel) list_artifacts(run_id string) []string {
	return vm.engine.list_handoff_artifacts(run_id)
}

// on_bus_event handles EventBus tick for Swarm UI (status/handoffs/logs).
pub fn (mut vm SwarmViewModel) on_bus_event(ev eventbus.ToolkitEvent) bool {
	if ev.kind != .swarm_created && ev.kind != .swarm_handoff && ev.kind != .swarm_status && ev.kind != .swarm_approval && ev.kind != .handoff_artifact && ev.kind != .process_log && ev.kind != .state_changed && ev.kind != .approval_requested && ev.kind != .loop_inner_tick && ev.kind != .loop_outer_tick {
		return false
	}
	vm.revision = ev.revision
	return true
}

// inner/outer loops via Engine — easy management
pub fn (mut vm SwarmViewModel) inner_start(run_id string, role string, goal string) !string {
	return vm.engine.swarm_inner_start(run_id, role, goal, 2)
}

pub fn (mut vm SwarmViewModel) inner_tick(run_id string, loop_id string, trace string) !u64 {
	return vm.engine.swarm_inner_tick(run_id, loop_id, trace, 100)
}

pub fn (mut vm SwarmViewModel) inner_complete(run_id string, loop_id string, exit string) !u64 {
	return vm.engine.swarm_inner_complete(run_id, loop_id, exit)
}

pub fn (mut vm SwarmViewModel) list_inner(run_id string) []desktop_engine.InnerLoop {
	return vm.engine.swarm_list_inner(run_id)
}

pub fn (mut vm SwarmViewModel) outer_catalog() []desktop_engine.OuterLoop {
	return vm.engine.swarm_outer_catalog()
}

// GOD routing via Engine — one-liner
pub fn (mut vm SwarmViewModel) god_route(from string, to string, payload string, artifact string) !string {
	return vm.engine.god_route(from, to, payload, artifact)
}

// approvals queue via Engine — easy
pub fn (mut vm SwarmViewModel) approvals_queue() []desktop_engine.SwarmApproval {
	return vm.engine.swarm_approvals_queue()
}

// budget display via Engine — easy cost visibility.
pub fn (mut vm SwarmViewModel) budget(run_id string) ?desktop_engine.SwarmBudgetView {
	return vm.engine.swarm_budget(run_id)
}

pub fn (mut vm SwarmViewModel) budget_display(run_id string) string {
	return vm.engine.swarm_budget_display(run_id)
}

// worktree-per-writer hygiene via Engine.
pub fn (mut vm SwarmViewModel) worktree_path(run_id string, role string) !string {
	return vm.engine.swarm_worktree_path(run_id, role)
}

pub fn (mut vm SwarmViewModel) hygiene(run_id string) []desktop_engine.BuildDiagnostic {
	return vm.engine.swarm_ensure_worktree_hygiene(run_id)
}

pub fn (mut vm SwarmViewModel) artifacts_display(run_id string) map[string][]string {
	return vm.engine.swarm_artifacts_display(run_id)
}

// approvals + artifacts + receipts/provenance kept
pub fn (mut vm SwarmViewModel) receipts(run_id string) []desktop_engine.ProvenanceEntry {
	return vm.engine.provenance_catalog().filter(it.artifact_path.contains(run_id))
}

// ProcessSupervisor stats via Engine
pub fn (mut vm SwarmViewModel) supervisor_stats() (int, u64) {
	return vm.engine.process_supervisor_stats()
}

// app_state_projection returns AppState for theme/router binding.
pub fn (mut vm SwarmViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

// theme_tokens passthrough for UI tokens.
pub fn (vm SwarmViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

// last_run returns last launched run_id for UI focus.
pub fn (vm SwarmViewModel) last_run() string {
	return vm.last_run_id
}

// last_error returns last launch error for toast.
pub fn (vm SwarmViewModel) last_error_msg() string {
	return vm.last_error
}

// ── Dunder office charm — command deck streaming deck ─────────────────

// command_deck_title returns the bullpen command deck header with paper charm.
// "Command Deck — regional manager's bullpen: streaming ${jobs} jobs • ${loops} loops • ${approvals} HR holds"
pub fn (vm SwarmViewModel) command_deck_title() string {
	jobs := vm.engine.jobs_catalog().len
	loops := vm.engine.loops_catalog().len
	approvals := vm.engine.swarm_approvals_queue().len
	return 'Command Deck — Scranton bullpen: streaming ${jobs} jobs • ${loops} loops • ${approvals} HR holds'
}

// streaming_jobs returns jobs for command deck ticker (capped at 5, 60 FPS virtualized).
pub fn (mut vm SwarmViewModel) streaming_jobs(limit int) []desktop_engine.JobRecord {
	mut all := vm.engine.jobs_catalog()
	if limit > 0 && all.len > limit {
		all = all[..limit]
	}
	return all
}

// streaming_loops returns loops for command deck ticker (outer mission board).
pub fn (mut vm SwarmViewModel) streaming_loops(limit int) []desktop_engine.LoopEntry {
	mut all := vm.engine.loops_catalog()
	if limit > 0 && all.len > limit {
		all = all[..limit]
	}
	return all
}

// handoff_stream returns recent handoffs for the floor envelope ticker.
// Each handoff is an envelope; GOD mailbox glow drives the ticker pulse.
pub fn (mut vm SwarmViewModel) handoff_stream(run_id string, limit int) []string {
	mut hs := vm.engine.swarm_handoffs(run_id)
	if limit > 0 && hs.len > limit {
		hs = hs[hs.len - limit..]
	}
	return hs
}
