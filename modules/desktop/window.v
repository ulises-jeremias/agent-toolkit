module desktop

import os
import desktop.theme
import desktop.shell
import desktop.nav
import desktop.state as app_state
import desktop.backend
import desktop_engine
import desktop_engine.eventbus
import desktop_engine.state as engine_state

// DesktopConfig describes the native window boot (V 0.5.2 + vlang/gui).
// Headless CI (no DISPLAY) does not create Sokol window; harness runs via perf.
pub struct DesktopConfig {
pub:
	title    string = 'Agent Toolkit — Desktop'
	width    int = 1280
	height   int = 800
	headless bool
}

// default_desktop_config returns canonical 1280×800 window config (ADR-032).
pub fn default_desktop_config() DesktopConfig {
	return DesktopConfig{
		title: 'Agent Toolkit — Desktop'
		width: 1280
		height: 800
		headless: is_headless_env()
	}
}

// is_headless_env checks DISPLAY / WAYLAND_DISPLAY and ATK_GUI_HEADLESS.
pub fn is_headless_env() bool {
	if os.getenv('ATK_GUI_HEADLESS') != '' {
		v := os.getenv('ATK_GUI_HEADLESS')
		return v == '1' || v == 'true'
	}
	display := os.getenv('DISPLAY')
	wayland := os.getenv('WAYLAND_DISPLAY')
	return display == '' && wayland == ''
}

// validate checks invariants.
pub fn (c DesktopConfig) validate() ! {
	if c.title == '' {
		return error('window title must not be empty')
	}
	if c.width < 320 || c.height < 240 {
		return error('window too small: ${c.width}x${c.height} (min 320x240)')
	}
	if c.width > 8192 || c.height > 8192 {
		return error('window too large: ${c.width}x${c.height}')
	}
}

// Desktop is the shell entrypoint — native window boot via vlang/gui on V master.
// Wires Engine boot (EPIC #1008), AppState placeholder, LocalBackend seam, no vlang/gui
// import cycle. Plane guard: desktop imports agent_toolkit_core never reverse.
pub struct Desktop {
mut:
	config    DesktopConfig
	engine    &desktop_engine.Engine
	backend   backend.HeadlessBackend
	theme     theme.Theme
	app_state app_state.AppState
	dock      shell.DockLayout
	router    &nav.Router
	bus       &eventbus.ToolkitEventBus
}

// DesktopBootArgs allows injecting seams for headless tests.
@[params]
pub struct DesktopBootArgs {
pub:
	config       DesktopConfig
	persist_path string
	backend      &backend.HeadlessBackend = unsafe { nil }
}

// new_desktop creates but does not boot desktop (new → init → start).
pub fn new_desktop(args DesktopBootArgs) &Desktop {
	cfg := if args.config.title == '' { default_desktop_config() } else { args.config }
	persist := if args.persist_path.len > 0 {
		args.persist_path
	} else {
		default_desktop_persist_path()
	}
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: persist
	})
	backend_inst := if args.backend != unsafe { nil } {
		args.backend
	} else {
		backend.new_headless_backend()
	}
	return &Desktop{
		config: cfg
		engine: eng
		backend: *backend_inst
		theme: theme.default_theme()
		dock: shell.default_dock_layout()
		router: nav.new_router()
		bus: eng.event_bus()
	}
}

// default_desktop_persist_path returns derived state path for desktop shell.
fn default_desktop_persist_path() string {
	base := os.getenv('XDG_CACHE_HOME')
	home := os.home_dir()
	cache := if base.len > 0 { base } else { os.join_path(home, '.cache') }
	return os.join_path(cache, 'agent-toolkit', 'desktop', 'engine_state.json')
}

// boot headless boots Engine (headless) and derives initial AppState.
// Idempotent: safe to call twice. No window created when headless.
pub fn (mut d Desktop) boot() ! {
	d.config.validate()!
	d.engine.init()!
	d.engine.start()!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
}

// shutdown stops Engine and drains UI channel.
pub fn (mut d Desktop) shutdown() ! {
	d.engine.stop()!
}

// is_running reports engine running (window would be open in non-headless).
pub fn (mut d Desktop) is_running() bool {
	return d.engine.is_running()
}

// app_state_snapshot returns current AppState (derived within one EventBus→frame tick).
pub fn (mut d Desktop) app_state_snapshot() app_state.AppState {
	return d.app_state.clone()
}

// mutate_via_engine proves Desktop never shells out to CLI for state reads.
// Mutates Engine via Transaction → EventBus → AppState within one tick.
pub fn (mut d Desktop) mutate_via_engine(key string, value string) !u64 {
	mut repo := d.engine.state_repo()
	mut tx := repo.begin('desktop-shell')
	tx.set(key, value)
	rev := d.engine.put_transaction(mut tx)!
	// also update local derived snapshot (real Desktop would receive via bus projection)
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	// router projection (State→View) within one EventBus tick
	if _ := d.router.project_app_state(d.app_state) {
	}
	return rev.revision
}

// toggle_theme switches light/dark instantly (<1 frame).
pub fn (mut d Desktop) toggle_theme() {
	d.theme = d.theme.toggle()
}

// set_reduced_motion toggles motion instantly.
pub fn (mut d Desktop) set_reduced_motion(enabled bool) {
	rm := if enabled { theme.reduced_motion_enabled() } else { theme.reduced_motion_disabled() }
	d.theme = d.theme.with_reduced_motion(rm)
}

// dock_layout returns current dock layout.
pub fn (d Desktop) dock_layout() shell.DockLayout {
	return d.dock
}

// update_dock persists derived layout (not canonical) and bumps app_state.
pub fn (mut d Desktop) update_dock(layout shell.DockLayout) ! {
	layout.validate()!
	d.dock = layout
	// persist derived (best-effort, never blocks boot)
	d.dock.persist('') or { eprintln('dock persist ignored: ${err}') }
	// also reflect in Engine state for cross-restart (derived)
	mut v := d.mutate_via_engine('dock_layout', 'rev:${layout.revision}') or {
		eprintln('mutate ignored: ${err}')
		return
	}
	_ = v
}

// theme_snapshot returns current theme.
pub fn (d Desktop) theme_snapshot() theme.Theme {
	return d.theme
}

// router_snapshot returns router for nav integration.
pub fn (mut d Desktop) router_snapshot() &nav.Router {
	return d.router
}

// backend_seam returns LocalBackend seam (injected, not direct OS calls).
pub fn (mut d Desktop) backend_seam() &backend.HeadlessBackend {
	return &d.backend
}

// engine_api_calls proves Engine typed API usage (engine_api_call>0, shell_exec=0).
pub fn (mut d Desktop) engine_api_calls() u64 {
	return d.engine.api_call_count()
}

// smoke_message returns manual smoke log (mirrors agent_toolkit_gui window.v).
pub fn (mut d Desktop) smoke_message() string {
	mode := if d.config.headless {
		'headless (no DISPLAY)'
	} else {
		'window ${d.config.width}x${d.config.height}'
	}
	status := if d.is_running() { 'RUNNING' } else { 'STOPPED' }
	return '${status}: desktop "${d.config.title}" | mode=${mode} | engine_api_calls=${d.engine_api_calls()} | app_state_rev=${d.app_state.revision}'
}

// hello_world_available reports whether desktop window path is available.
// Always true when V master + engine boot succeeds; headless still true.
pub fn hello_world_available() bool {
	return true
}

// import_guard_marker proves plane guard: desktop imports core never reverse.
// Callers grep for "import.*gui" / "import.*desktop" in core — must be absent.
// This file itself imports desktop_engine and agent_toolkit_core via desktop_engine.
pub fn plane_guard_marker() string {
	return 'desktop imports agent_toolkit_core via desktop_engine, never reverse'
}

// current_engine_state returns engine raw snapshot for parity tests.
pub fn (mut d Desktop) current_engine_state() engine_state.State {
	return d.engine.snapshot()
}

// ---- Super-potent swarms integration: GOD mailbox, handoff artifacts, inner/outer loops, Swarm UI, approvals ----

// swarm_launch launches via Engine pair/team/full with Herdr/tmux — easy Desktop UI.
pub fn (mut d Desktop) swarm_launch(recipe string, backend_name string, task string) !string {
	rk := desktop_engine.swarm_recipe_from_string(recipe)
	bk := desktop_engine.swarm_backend_from_string(backend_name)
	args := desktop_engine.SwarmLaunchArgs{
		recipe: rk
		backend: bk
		task: task
	}
	run_id := d.engine.swarm_launch(args)!
	// also update local AppState within one tick
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	if _ := d.router.project_app_state(d.app_state) {}
	return run_id
}

// swarm_list returns Engine swarm runs for Swarm UI status.
pub fn (mut d Desktop) swarm_list() []desktop_engine.SwarmRun {
	return d.engine.swarm_list()
}

// swarm_status returns single run status.
pub fn (mut d Desktop) swarm_status(run_id string) ?desktop_engine.SwarmRun {
	return d.engine.swarm_status(run_id)
}

// swarm_handoffs returns handoffs for a run (GOD mailbox routing via Engine).
pub fn (mut d Desktop) swarm_handoffs(run_id string) []string {
	return d.engine.swarm_handoffs(run_id)
}

// swarm_logs returns demultiplexed logs for a run.
pub fn (mut d Desktop) swarm_logs(run_id string) []string {
	return d.engine.swarm_logs(run_id)
}

// swarm_approvals returns pending approvals spend/scope/destructive.
pub fn (mut d Desktop) swarm_approvals(run_id string) []desktop_engine.SwarmApproval {
	return d.engine.swarm_pending_approvals(run_id)
}

// swarm_approve resolves a gate (approve or reject).
pub fn (mut d Desktop) swarm_approve(run_id string, approval_id string, approved bool) !u64 {
	return d.engine.swarm_approve(run_id, approval_id, approved)
}

// swarm_request_approval creates spend/scope/destructive gate.
pub fn (mut d Desktop) swarm_request_approval(run_id string, kind desktop_engine.ApprovalKind, message string) !string {
	return d.engine.swarm_request_approval(run_id, kind, message, 0)
}

// god_mailbox_counts returns GOD inbox/outbox derived from State for Workshop floor.
pub fn (mut d Desktop) god_mailbox_counts() (int, int) {
	snap := d.engine.snapshot()
	inbox_str := snap.data['swarm/god_mailbox/inbox'] or { snap.data['swarm/mailbox/inbox'] or { '0' } }
	outbox_str := snap.data['swarm/god_mailbox/outbox'] or { snap.data['swarm/mailbox/outbox'] or { '0' } }
	return inbox_str.int(), outbox_str.int()
}

// handoff_artifacts lists artifact files for a run (via Engine filesystem + State).
pub fn (mut d Desktop) handoff_artifacts(run_id string) []string {
	return d.engine.list_handoff_artifacts(run_id)
}

// write_handoff_artifact creates artifact file (durable under artifacts/).
pub fn (mut d Desktop) write_handoff_artifact(run_id string, rel_path string, content string) !string {
	return d.engine.write_handoff_artifact(run_id, rel_path, content)
}

// loops_catalog proxies outer loops (cadence) for outer/inner mission board.
pub fn (mut d Desktop) loops_catalog() []desktop_engine.LoopEntry {
	return d.engine.loops_catalog()
}

// inner_loops_for returns inner loops map snapshot for a swarm run (via State keys).
pub fn (mut d Desktop) inner_loops_for(run_id string) map[string]string {
	snap := d.engine.snapshot()
	mut out := map[string]string{}
	prefix := 'swarm/${run_id}/inner_loops/'
	for k, v in snap.data {
		if k.starts_with(prefix) {
			out[k.all_after(prefix)] = v
		}
	}
	return out
}

// ── Jobs & ProcessSupervisor — super-potent process health via Engine ──
pub fn (mut d Desktop) engine_jobs_catalog() []desktop_engine.JobRecord {
	return d.engine.jobs_catalog()
}

pub fn (mut d Desktop) engine_job_stats() desktop_engine.JobStats {
	return d.engine.job_stats()
}

pub fn (mut d Desktop) engine_jobs_by_status(status desktop_engine.JobStatus) []desktop_engine.JobRecord {
	return d.engine.jobs_by_status(status)
}

pub fn (mut d Desktop) engine_job_logs(job_id string) []string {
	return d.engine.job_logs(job_id)
}

pub fn (mut d Desktop) engine_process_supervisor_stats() (int, u64) {
	return d.engine.process_supervisor_stats()
}

pub fn (mut d Desktop) engine_approvals_queue() []desktop_engine.SwarmApproval {
	return d.engine.swarm_approvals_queue()
}

pub fn (mut d Desktop) engine_loop_history(loop_name string) []desktop_engine.LoopHistory {
	return d.engine.loops_history(loop_name)
}

pub fn (mut d Desktop) engine_loop_budget_ledger(name string) (int, int, int) {
	return d.engine.loop_budget_ledger(name)
}

// event_bus exposes ToolkitEventBus for Swarm UI wiring (status/handoffs/logs within one tick).
pub fn (mut d Desktop) event_bus() &eventbus.ToolkitEventBus {
	return d.bus
}

// engine_revision returns snapshot revision for EventBus→frame tick assertion.
pub fn (mut d Desktop) engine_revision() u64 {
	return d.engine.revision()
}

// ── IDE + git + skills + memory — brokered, super potent, easy to manage ──────
// Each method is a one-liner proxy to Engine typed API (no shell, no direct os access).
// GUI (main.v) calls these, not Engine directly, keeping plane guard + backend seam.
pub fn (mut d Desktop) engine_skills_catalog() []desktop_engine.SkillEntry {
	return d.engine.skills_catalog()
}

pub fn (mut d Desktop) engine_skills_search(query string, domain string) []desktop_engine.SkillEntry {
	return d.engine.skills_search(query, domain)
}

pub fn (mut d Desktop) engine_skill_detail(id string) !desktop_engine.SkillEntry {
	return d.engine.skill_detail(id)
}

pub fn (mut d Desktop) engine_build_file_tree(harness_root string, max_depth int) []FileNodeProxy {
	nodes := d.engine.build_file_tree(harness_root, max_depth) or { return []FileNodeProxy{} }
	mut out := []FileNodeProxy{}
	for n in nodes {
		out << FileNodeProxy{
			name: n.name
			path: n.path
			kind: if n.kind == .dir { 'dir' } else { 'file' }
			expanded: n.expanded
			depth: n.depth
			git_status: n.git_status
		}
	}
	return out
}

pub struct FileNodeProxy {
pub:
	name       string
	path       string
	kind       string
	expanded   bool
	depth      int
	git_status string
}

pub fn (mut d Desktop) engine_open_file_brokered(harness_root string, path string) !desktop_engine.EditorTab {
	return d.engine.open_file_brokered(harness_root, path)
}

pub fn (mut d Desktop) engine_highlight_syntax(content string, syntax string) [][]desktop_engine.SyntaxToken {
	return desktop_engine.highlight_syntax(content, syntax)
}

pub fn (mut d Desktop) engine_git_changes() []desktop_engine.GitChange {
	return d.engine.git_changes()
}

pub fn (mut d Desktop) engine_git_history(limit int) []desktop_engine.GitCommit {
	return d.engine.git_history(limit)
}

pub fn (mut d Desktop) engine_git_graph(limit int) desktop_engine.CommitGraph {
	return d.engine.git_commit_graph(limit)
}

pub fn (mut d Desktop) engine_git_diff(target string) []desktop_engine.DiffHunk {
	return d.engine.git_diff(target)
}

pub fn (mut d Desktop) engine_git_compare(base string, target string) []desktop_engine.DiffHunk {
	return d.engine.git_compare(base, target)
}

pub fn (mut d Desktop) engine_memory_entries() []desktop_engine.MemoryPalaceEntry {
	return d.engine.memory_palace_entries()
}

pub fn (mut d Desktop) engine_memory_recall(query string, limit int) []desktop_engine.MemoryRecallResult {
	return d.engine.memory_semantic_recall(query, limit)
}

pub fn (mut d Desktop) engine_open_path_validated(harness_root string, path string) !string {
	return d.engine.open_path_validated(harness_root, path)
}

// ── Super-potent onboarding / capability / target / product / workspace / persona — Engine wiring ──
// Everything is possible and easy to manage: Desktop proxies every Engine mutation (no shell).
pub fn (mut d Desktop) onboarding_status(harness_root string) desktop_engine.OnboardingStatus {
	return d.engine.onboarding_status(harness_root)
}

pub fn (mut d Desktop) onboarding_ensure_workspace(target string) !u64 {
	return d.engine.onboarding_ensure_workspace(target)
}

pub fn (mut d Desktop) onboarding_ensure_personas(harness_root string) !u64 {
	return d.engine.onboarding_ensure_personas(harness_root)
}

pub fn (mut d Desktop) onboarding_bulk_install_skills(ids []string) !u64 {
	return d.engine.onboarding_bulk_install_skills(ids)
}

pub fn (mut d Desktop) onboarding_bulk_remove_skills(ids []string) !u64 {
	return d.engine.onboarding_bulk_remove_skills(ids)
}

pub fn (mut d Desktop) onboarding_set_targets_bulk(ids []string) !u64 {
	return d.engine.onboarding_set_targets_bulk(ids)
}

pub fn (mut d Desktop) onboarding_set_products_bulk(ids []string) !u64 {
	return d.engine.onboarding_set_products_bulk(ids)
}

pub fn (mut d Desktop) onboarding_complete(harness_root string) !u64 {
	rev := d.engine.onboarding_complete(harness_root)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	if _ := d.router.project_app_state(d.app_state) {}
	return rev
}

pub fn (mut d Desktop) onboarding_reset() !u64 {
	return d.engine.onboarding_reset()
}

pub fn (mut d Desktop) onboarding_init_with_templates(target string, with_personas bool) !u64 {
	rev := d.engine.workspace_init_with_templates(target, with_personas)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

// capability super-potent
pub fn (mut d Desktop) engine_install_skills(ids []string) !u64 {
	return d.engine.install_skills(ids)
}

pub fn (mut d Desktop) engine_skills_installed() []string {
	return d.engine.skills_installed()
}

pub fn (mut d Desktop) engine_skills_installed_detailed() []desktop_engine.SkillEntry {
	return d.engine.skills_installed_detailed()
}

pub fn (mut d Desktop) engine_skills_stats() desktop_engine.SkillStats {
	return d.engine.skills_stats()
}

pub fn (mut d Desktop) engine_skills_domains() []string {
	return d.engine.skills_domains()
}

pub fn (mut d Desktop) engine_skill_receipt(id string) ?desktop_engine.SkillReceiptInfo {
	return d.engine.skill_receipt(id)
}

pub fn (mut d Desktop) engine_toggle_skill(id string) !u64 {
	rev := d.engine.toggle_skill(id)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

// target/product super-potent
pub fn (mut d Desktop) engine_targets_enabled() []string {
	mut out := []string{}
	for t in d.engine.targets() {
		if t.enabled {
			out << t.id
		}
	}
	return out
}

pub fn (mut d Desktop) engine_set_targets_bulk(ids []string) !u64 {
	rev := d.engine.onboarding_set_targets_bulk(ids)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

pub fn (mut d Desktop) engine_products_catalog() []desktop_engine.ProductEntry {
	return d.engine.products_catalog()
}

pub fn (mut d Desktop) engine_packs_catalog() []desktop_engine.PackEntry {
	return d.engine.packs_catalog()
}

pub fn (mut d Desktop) engine_update_product_membership(product_id string, skill_ids []string) !u64 {
	return d.engine.update_product_membership(product_id, skill_ids)
}

pub fn (mut d Desktop) engine_set_pack_enabled(pack_id string, enabled bool) !u64 {
	return d.engine.set_pack_enabled(pack_id, enabled)
}

// workspace + persona super-potent
pub fn (mut d Desktop) engine_ensure_workspace_structure(harness_root string) !u64 {
	// wire via onboarding ensure (same scaffold)
	return d.engine.onboarding_ensure_workspace(harness_root)
}

pub fn (mut d Desktop) engine_bootstrap_personas(harness_root string) !u64 {
	return d.engine.onboarding_ensure_personas(harness_root)
}

pub fn (mut d Desktop) engine_personas_in_workspace(harness_root string) []string {
	clean := d.engine.open_path_validated(harness_root, harness_root) or { return []string{} }
	dir := os.join_path(clean, 'personas')
	ents := os.ls(dir) or { return []string{} }
	mut out := []string{}
	for en in ents {
		if en.ends_with('.md') {
			out << en.all_before('.md')
		}
	}
	out.sort()
	return out
}

pub fn (mut d Desktop) engine_is_first_run() bool {
	return d.engine.is_first_run()
}

pub fn (mut d Desktop) engine_doctor_fix(check_id string) !u64 {
	return d.engine.doctor_fix(check_id)
}


// ── super-potent unified: agents, MCP, doctor, receipts/provenance, install/update — easy management via Desktop ──
pub fn (mut d Desktop) engine_agents_search(query string, tier string) []desktop_engine.AgentEntry {
	return d.engine.agents_search(query, tier)
}

pub fn (mut d Desktop) engine_agents_stats() desktop_engine.AgentStats {
	return d.engine.agents_stats()
}

pub fn (mut d Desktop) engine_agents_by_tier() map[string][]desktop_engine.AgentEntry {
	return d.engine.agents_by_tier()
}

pub fn (mut d Desktop) engine_agent_receipt(id string) ?desktop_engine.AgentReceiptInfo {
	return d.engine.agent_receipt(id)
}

pub fn (mut d Desktop) engine_install_agent(id string) !u64 {
	rev := d.engine.install_agent(id)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

pub fn (mut d Desktop) engine_agents_delegation_graph() map[string][]string {
	return d.engine.agents_delegation_graph()
}

pub fn (mut d Desktop) engine_mcp_catalog() []desktop_engine.McpProvider {
	return d.engine.mcp_catalog()
}

pub fn (mut d Desktop) engine_mcp_search(query string) []desktop_engine.McpProvider {
	return d.engine.mcp_catalog_search(query)
}

pub fn (mut d Desktop) engine_mcp_stats() desktop_engine.McpStats {
	return d.engine.mcp_stats()
}

pub fn (mut d Desktop) engine_mcp_toggle(provider_id string) !u64 {
	rev := d.engine.mcp_toggle(provider_id)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

pub fn (mut d Desktop) engine_mcp_preview(provider_id string) (string, string) {
	return d.engine.mcp_preview(provider_id)
}

pub fn (mut d Desktop) engine_mcp_install_preview(provider_id string) desktop_engine.McpInstallPreview {
	return d.engine.mcp_install_preview(provider_id)
}

pub fn (mut d Desktop) engine_mcp_provenance_json(provider_id string) string {
	return d.engine.mcp_provenance_json(provider_id)
}

pub fn (mut d Desktop) engine_doctor() []desktop_engine.DoctorCheck {
	return d.engine.doctor()
}

pub fn (mut d Desktop) engine_doctor_fix_all() !u64 {
	rev := d.engine.doctor_fix_all()!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

pub fn (mut d Desktop) engine_doctor_by_category(cat string) []desktop_engine.DoctorCheck {
	mut out := []desktop_engine.DoctorCheck{}
	for c in d.engine.doctor() {
		if c.category == cat { out << c }
	}
	return out
}

pub fn (mut d Desktop) engine_receipts_catalog() []desktop_engine.ReceiptEntry {
	return d.engine.receipts_catalog()
}

pub fn (mut d Desktop) engine_provenance_catalog() []desktop_engine.ProvenanceEntry {
	return d.engine.provenance_catalog()
}

pub fn (mut d Desktop) engine_verify_receipts() []desktop_engine.BuildDiagnostic {
	return d.engine.verify_receipts()
}

pub fn (mut d Desktop) engine_install_preview(targets []string) desktop_engine.TargetDiff {
	return d.engine.install_preview(targets)
}

pub fn (mut d Desktop) engine_install_dry_run(targets []string) string {
	return d.engine.install_dry_run(targets)
}

pub fn (mut d Desktop) engine_list_install_receipts() []desktop_engine.InstallReceiptInfo {
	return d.engine.list_install_receipts()
}

pub fn (mut d Desktop) engine_install_with_options(opts desktop_engine.InstallOptionsEngine) !u64 {
	rev := d.engine.install_with_options(opts)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

pub fn (mut d Desktop) engine_toggle_target(target_id string) !u64 {
	rev := d.engine.toggle_target(target_id)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

pub fn (mut d Desktop) engine_check_for_update(current string, channel string) ?desktop_engine.UpdateInfoEngine {
	return d.engine.check_for_update(current, channel)
}

pub fn (mut d Desktop) engine_apply_update(version string) bool {
	ok := d.engine.apply_update(version)
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return ok
}

pub fn (mut d Desktop) engine_update_history() []desktop_engine.UpdateInfoEngine {
	return d.engine.update_history()
}

pub fn (mut d Desktop) engine_products_search(query string) []desktop_engine.ProductEntry {
	return d.engine.products_search(query)
}

pub fn (mut d Desktop) engine_packs_search(query string) []desktop_engine.PackEntry {
	return d.engine.packs_search(query)
}

pub fn (mut d Desktop) engine_product_provenance(product_id string) string {
	return d.engine.product_provenance(product_id)
}

pub fn (mut d Desktop) engine_resolve_paths_detailed() string {
	return d.engine.resolve_paths_detailed()
}

pub fn (mut d Desktop) engine_complete_onboarding() !u64 {
	rev := d.engine.complete_onboarding()!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}


pub fn (mut d Desktop) engine_resolve_paths() []string {
	return d.engine.resolve_paths()
}
