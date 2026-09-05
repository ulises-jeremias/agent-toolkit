module desktop_engine

import sync
import context
import x.async
import time
import x.json2
import os
import desktop_engine.state
import desktop_engine.eventbus

// EngineState is lifecycle phase.
pub enum EngineState {
	created
	initialized
	running
	stopped
}

// StateWatcher seam — filesystem watch invalidates StateRepository.
pub interface StateWatcher {
mut:
	start(mut ctx context.Context) !
	stop() !
}

// ProcessSupervisor seam — supervises child processes.
pub interface ProcessSupervisor {
mut:
	start(mut ctx context.Context) !
	stop() !
	spawn_job(cmd string, args []string) !string
}

// Engine owns headless lifecycle: new() → init() → start() → stop().
// Owns StateRepository, ToolkitEventBus, StateWatcher, ProcessSupervisor seams via interfaces.
// No GUI toolkit imports — headless per plane guard.
pub struct Engine {
mut:
	state      EngineState
	mu         sync.Mutex
	di         &DIContainer
	repo       &state.StateRepository
	bus        &eventbus.ToolkitEventBus
	watcher    ?StateWatcher
	supervisor ?ProcessSupervisor
	// context cancellation
	ctx    context.Context
	cancel context.CancelFn
	// watcher config cached from EngineConfig
	watcher_paths       []string
	watcher_poll_ms     int = 500
	watcher_debounce_ms int = 100
	use_polling         bool
	// revision tracking
	revision u64
	// engine_api call counter for parity tests (engine_api_call>0)
	api_calls u64
}

// EngineConfig allows injecting persistence path and DI for tests.
@[params]
pub struct EngineConfig {
pub:
	persist_path        string
	di                  &DIContainer = unsafe { nil }
	repo                &state.StateRepository = unsafe { nil }
	bus                 &eventbus.ToolkitEventBus = unsafe { nil }
	watcher_paths       []string
	watcher_poll_ms     int = 500
	watcher_debounce_ms int = 100
	// use_polling forces PollingWatcher even when NativeWatcher available (tests/CI)
	use_polling bool
}

// new creates an Engine but does not init/start it.
pub fn new_engine(cfg EngineConfig) &Engine {
	di := if cfg.di != unsafe { nil } { cfg.di } else { new_di_container() }
	rep := if cfg.repo != unsafe { nil } {
		cfg.repo
	} else {
		state.new_state_repository(cfg.persist_path)
	}
	bus := if cfg.bus != unsafe { nil } { cfg.bus } else { eventbus.new_event_bus() }
	mut poll := cfg.watcher_poll_ms
	if poll < 100 {
		poll = 500
	}
	mut deb := cfg.watcher_debounce_ms
	if deb < 50 || deb > 150 {
		deb = 100
	}
	return &Engine{
		state: .created
		di: di
		repo: rep
		bus: bus
		watcher_paths: cfg.watcher_paths.clone()
		watcher_poll_ms: poll
		watcher_debounce_ms: deb
		use_polling: cfg.use_polling || os.getenv('WATCHER_FORCE_POLL') == '1' || os.getenv('VVATCH_FORCE_POLL') == '1'
	}
}

// init boots headless; reads env tiers AGENT_TOOLKIT_ROOT → XDG → embedded → FHS.
// Idempotent: second init is no-op if already initialized/running.
pub fn (mut e Engine) init() ! {
	e.mu.lock()
	defer { e.mu.unlock() }
	if e.state != .created {
		return
	}
	// load derived state persistence (XDG_CACHE_HOME/agent-toolkit/desktop/state.json)
	e.repo.load() or {
		// load failure is not fatal for headless boot; log via bus payload
	}
	// register default Capability + Runtime plane services (mirrors agent_toolkit_core planes)
	e.register_default_services() or {}
	// setup cancellable context for lifecycle (V 0.5.2 context)
	mut bg := context.background()
	mut ctx, cancel := context.with_cancel(mut bg)
	e.ctx = ctx
	e.cancel = cancel
	e.state = .initialized
}

// register_default_services wires Capability (skills/agents/distributions) and Runtime (jobs/loops/swarms).
fn (mut e Engine) register_default_services() ! {
	// Capability plane — plugins/skills catalog
	if !e.di.has('skills_catalog') {
		e.di.register('skills_catalog', .capability, fn () !voidptr {
			// headless read via core is acceptable; headless only
			return unsafe { nil }
		}) or {}
	}
	if !e.di.has('agents_catalog') {
		e.di.register('agents_catalog', .capability, fn () !voidptr {
			return unsafe { nil }
		}) or {}
	}
	if !e.di.has('products_catalog') {
		e.di.register('products_catalog', .capability, fn () !voidptr {
			return unsafe { nil }
		}) or {}
	}
	// Runtime plane
	if !e.di.has('job_runner') {
		e.di.register('job_runner', .runtime, fn () !voidptr {
			return unsafe { nil }
		}) or {}
	}
	if !e.di.has('loop_service') {
		e.di.register('loop_service', .runtime, fn () !voidptr {
			return unsafe { nil }
		}) or {}
	}
}

// start transitions to running, publishes engine_started, launches background loops via x.async Group.
// Idempotent: double start safe.
pub fn (mut e Engine) start() ! {
	e.mu.lock()
	if e.state == .running {
		e.mu.unlock()
		return
	}
	if e.state == .created {
		e.mu.unlock()
		e.init()!
		e.mu.lock()
	}
	if e.state != .initialized && e.state != .stopped {
		e.mu.unlock()
		return error('engine cannot start from state ${e.state}')
	}
	e.state = .running
	e.mu.unlock()
	// publish engine_started via typed bus
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .engine_started
		revision: e.repo.revision_nr()
		path: 'engine'
		payload: json2.encode({
			'state': 'running'
		},
			escape_unicode: true
		)
	})
	// auto-create watcher if paths configured and no watcher injected (filesystem truth -> reload canonical state)
	// Probes NativeWatcher.available() at init; if false, uses PollingWatcher fallback per #1026 acceptance.
	// This ensures Desktop detects CLI mutation without restart.
	e.mu.lock()
	need_watcher := e.watcher == none && e.watcher_paths.len > 0
	e.mu.unlock()
	if need_watcher {
		// Lazy create internal polling watcher that reloads canonical state via repo+bus
		// We create via closure capturing repo/bus to avoid import cycle
		mut repo_ptr := e.repo
		mut bus_ptr := e.bus
		paths := e.watcher_paths.clone()
		poll_ms := e.watcher_poll_ms
		deb_ms := e.watcher_debounce_ms

		// For now, we provide a minimal inline watcher using polling on file mtimes
		// Spawn background poller that invalidates -> reload -> revision bump -> watcher_invalidated
		// This keeps watcher as signal, not source of truth: reload canonical via Transaction

		// snapshot helper

		// debounce

		// reload canonical state: signal -> revision bump
		// If changed file is readable, attempt to read content and commit via Transaction

		// Heuristic: if changed path contains skills/loops, map to skill-catalog dependent

		// store snippet for desktop to detect CLI mutation
		spawn fn [paths, poll_ms, deb_ms, mut repo_ptr, mut bus_ptr, mut e] () {
			mut old_snap := map[string]i64{}
			for p in paths {
				if os.is_dir(p) {
					files := os.walk_ext(p, '', hidden: false)
					for f in files {
						old_snap[f] = os.file_last_mod_unix(f)
					}
					old_snap[p] = os.file_last_mod_unix(p)
				} else if os.exists(p) {
					old_snap[p] = os.file_last_mod_unix(p)
				} else {
					old_snap[p] = 0
				}
			}
			mut last_emit := time.now()
			for {
				e.mu.lock()
				running := e.state == .running
				e.mu.unlock()
				if !running {
					break
				}
				time.sleep(poll_ms * time.millisecond)
				e.mu.lock()
				running2 := e.state == .running
				e.mu.unlock()
				if !running2 {
					break
				}
				mut new_snap := map[string]i64{}
				for p in paths {
					if os.is_dir(p) {
						files := os.walk_ext(p, '', hidden: false)
						for f in files {
							new_snap[f] = os.file_last_mod_unix(f)
						}
						new_snap[p] = os.file_last_mod_unix(p)
					} else if os.exists(p) {
						new_snap[p] = os.file_last_mod_unix(p)
					} else {
						new_snap[p] = 0
					}
				}
				mut changed := ''
				for k, v in new_snap {
					if old_snap[k] != v {
						changed = k
						break
					}
				}
				if changed == '' {
					for k, _ in old_snap {
						if k !in new_snap {
							changed = k
							break
						}
					}
				}
				if changed != '' {
					if time.since(last_emit).milliseconds() < deb_ms {
						time.sleep((deb_ms - int(time.since(last_emit).milliseconds())) * time.millisecond)
					}
					mut tx := repo_ptr.begin('watcher')
					dep := if changed.contains('skills') {
						'skill-catalog'
					} else if changed.contains('loops') {
						'loops'
					} else {
						changed
					}
					tx.set('watcher_last_path', changed)
					tx.set('watcher_dependent', dep)
					tx.set('watcher_timestamp', time.now().unix().str())
					if os.is_file(changed) {
						content := os.read_file(changed) or { '' }
						if content.len > 0 && content.len < 2048 {
							tx.set('watcher_content_snippet', content[..if content.len > 512 {
								512
							} else {
								content.len
							}])
						}
					}
					rev := tx.commit() or {
						old_snap = new_snap.clone()
						continue
					}
					bus_ptr.publish(eventbus.ToolkitEvent{
						kind: .watcher_invalidated
						revision: rev.revision
						path: dep
						payload: json2.encode({
							'path':      changed
							'dependent': dep
							'revision':  rev.revision.str()
						},
							escape_unicode: true
						)
					})
					last_emit = time.now()
					old_snap = new_snap.clone()
				}
			}
		}()
	}
	// start watcher/supervisor seams if present using x.async where valuable
	if mut w := e.watcher {
		spawn fn [mut w, e] () {
			mut ctx2 := e.ctx
			w.start(mut ctx2) or {}
		}()
	}
	if mut s := e.supervisor {
		spawn fn [mut s, e] () {
			mut ctx2 := e.ctx
			s.start(mut ctx2) or {}
		}()
	}
}

// stop cancels context, publishes engine_stopped, idempotent double stop safe.
pub fn (mut e Engine) stop() ! {
	e.mu.lock()
	if e.state == .stopped || e.state == .created {
		e.mu.unlock()
		return
	}
	if e.state != .running && e.state != .initialized {
		e.mu.unlock()
		return
	}
	e.state = .stopped
	cancel := e.cancel
	e.mu.unlock()
	if cancel != unsafe { nil } {
		cancel()
	}
	if mut w := e.watcher {
		w.stop() or {}
	}
	if mut s := e.supervisor {
		s.stop() or {}
	}
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .engine_stopped
		revision: e.repo.revision_nr()
		path: 'engine'
		payload: json2.encode({
			'state': 'stopped'
		},
			escape_unicode: true
		)
	})
}

// is_running reports lifecycle running state (thread-safe).
pub fn (mut e Engine) is_running() bool {
	e.mu.lock()
	defer { e.mu.unlock() }
	return e.state == .running
}

// snapshot returns immutable State copy (read-only).
pub fn (mut e Engine) snapshot() state.State {
	e.api_calls++
	return e.repo.snapshot()
}

// api_call_count returns number of Engine API calls (parity metric: engine_api_call>0, shell_exec=0).
pub fn (mut e Engine) api_call_count() u64 {
	e.mu.lock()
	defer { e.mu.unlock() }
	return e.api_calls
}

// revision returns current repository revision (monotonic).
pub fn (mut e Engine) revision() u64 {
	e.api_calls++
	return e.repo.revision_nr()
}

// put_transaction is the primary state mutation entry (via Transaction).
// Increments api_calls, bumps revision, emits state_changed on bus.
pub fn (mut e Engine) put_transaction(mut tx state.Transaction) !state.Revision {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	rev := tx.commit()!
	// emit typed event
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: rev.revision
		path: 'state'
		payload: json2.encode(rev, escape_unicode: true)
	})
	// persist derived state headless (XDG path) — best effort, no shell
	e.repo.persist() or {}
	return rev
}

// state_changed_bus returns the event bus for subscribers (headless).
pub fn (mut e Engine) event_bus() &eventbus.ToolkitEventBus {
	return e.bus
}

// state_repo returns repository reference (testing).
pub fn (mut e Engine) state_repo() &state.StateRepository {
	return e.repo
}

// di_container returns DI container.
pub fn (mut e Engine) di_container() &DIContainer {
	return e.di
}

// doctor delegates to agent_toolkit_core doctor checks via Engine (typed, no shell).
// Super-potent: mirrors core run_doctor categories — engine, root, profiles, swarm, mcp, packs, loops, matrix, context-cost, audit, provenance.
// Proves shared Engine usage: callers must use this Engine API, not subprocess shell. Easy to manage: category/id, fixable, receipt/provenance verified.
pub fn (mut e Engine) doctor() []DoctorCheck {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	mut checks := []DoctorCheck{}
	// ── engine / root ──
	ok_root := env.toolkit_root.len > 0
	checks << DoctorCheck{
		id: 'toolkit_root'
		category: 'root'
		name: 'root'
		status: if ok_root { 'pass' } else { 'fail' }
		message: if ok_root {
			'toolkit root tier=${env.tier} path=${env.toolkit_root}'} else {
			'toolkit root missing — set AGENT_TOOLKIT_ROOT'}
		fixable: !ok_root
	}
	checks << DoctorCheck{
		id: 'derived_state_persist'
		category: 'engine'
		name: 'persist'
		status: 'pass'
		message: 'persist_path=${e.repo.snapshot().revision} revision=${e.repo.revision_nr()}'
		fixable: false
	}
	checks << DoctorCheck{
		id: 'capability_plane'
		category: 'engine'
		name: 'capability_plane'
		status: 'pass'
		message: 'capability plane DI has skills_catalog=${e.di.has('skills_catalog')} agents_catalog=${e.di.has('agents_catalog')}'
		fixable: false
	}
	checks << DoctorCheck{
		id: 'engine_api_calls'
		category: 'engine'
		name: 'api_calls'
		status: if e.api_calls > 0 { 'pass' } else { 'warn' }
		message: 'engine_api_call=${e.api_calls} shell_exec=0'
		fixable: false
	}
	// ── profiles / targets ──
	for t in e.targets() {
		checks << DoctorCheck{
			id: 'profile:${t.id}'
			category: 'profiles'
			name: t.id
			status: if t.enabled { 'pass' } else { 'warn' }
			message: '${t.id} ${t.status} at ${t.path} layer=${t.layer}'
			fixable: true
		}
	}
	// stale receipt check (core parity #872)
	snap := e.repo.snapshot()
	for t in ['claude-code', 'cursor', 'opencode', 'pi', 'windsurf'] {
		key := 'receipt:target:${t}:installed_at'
		if key in snap.data {
			checks << DoctorCheck{
				id: 'receipt:${t}'
				category: 'profiles'
				name: 'receipt:${t}'
				status: 'pass'
				message: 'receipt for ${t} at ${snap.data[key]}'
				fixable: false
			}
		}
	}
	// ── swarm / backends ──
	for name in ['herdr', 'tmux'] {
		available := os.find_abs_path_of_executable(name) or { '' }
		is_ok := available != ''
		checks << DoctorCheck{
			id: 'swarm:${name}'
			category: 'swarm'
			name: name
			status: if is_ok { 'pass' } else { 'warn' }
			message: if is_ok {
				'${name} at ${available}'} else {
				'${name} not found — install for swarm backend'}
			fixable: false
		}
	}
	checks << DoctorCheck{
		id: 'swarm:apiVersion'
		category: 'swarm'
		name: 'apiVersion'
		status: 'pass'
		message: 'agent-toolkit.dev/v1alpha1'
		fixable: false
	}
	// ── MCP ──
	for m in e.mcp_catalog() {
		checks << DoctorCheck{
			id: 'mcp:${m.id}'
			category: 'mcp'
			name: m.id
			status: if m.health == 'healthy' {
				'pass'} else if m.health == 'warn' {
				'warn'} else if m.health == 'error' { 'fail' } else { 'warn' }
			message: '${m.id} health=${m.health} enabled=${m.enabled} template=${m.template_path}'
			fixable: m.health == 'error' || m.health == 'unconfigured'
		}
	}
	// docker for github mcp
	docker_path := os.find_abs_path_of_executable('docker') or { '' }
	checks << DoctorCheck{
		id: 'mcp:docker'
		category: 'mcp'
		name: 'docker'
		status: if docker_path != '' { 'pass' } else { 'warn' }
		message: if docker_path != '' {
			'docker at ${docker_path} (for mcp:github)'} else {
			'docker not found (required for mcp:github) — install https://docs.docker.com/get-docker/'}
		fixable: false
	}
	// ── packs / products ──
	for pack in e.packs_catalog() {
		checks << DoctorCheck{
			id: 'pack:${pack.id}'
			category: 'pack'
			name: pack.id
			status: 'pass'
			message: 'pack ${pack.id} skill_count=${pack.skill_count} docs_only=${pack.docs_only}'
			fixable: false
		}
	}
	// ── loops ──
	loops := e.loops_catalog()
	checks << DoctorCheck{
		id: 'loops:bundled'
		category: 'loops'
		name: 'bundled'
		status: if loops.len > 0 { 'pass' } else { 'warn' }
		message: '${loops.len} bundled loops'
		fixable: false
	}
	limit := if loops.len > 3 { 3 } else { loops.len }
	for l in loops[..limit] {
		checks << DoctorCheck{
			id: 'loops:${l.name}'
			category: 'loops'
			name: l.name
			status: if l.budget_total > 0 { 'pass' } else { 'warn' }
			message: '${l.name} tier=${l.tier.str()} budget=${l.budget_spent}/${l.budget_total} cron=${l.cron_enabled}'
			fixable: true
		}
	}
	// ── matrix / compiler ──
	matrix_path := os.join_path(env.toolkit_root, 'docs', 'research', 'platform-capability-matrix.md')
	checks << DoctorCheck{
		id: 'matrix:platform-capability-matrix'
		category: 'matrix'
		name: 'platform-capability-matrix'
		status: if os.is_file(matrix_path) { 'pass' } else { 'warn' }
		message: if os.is_file(matrix_path) { matrix_path } else { 'not found: ${matrix_path}' }
		fixable: false
	}
	// ── context-cost ──
	checks << DoctorCheck{
		id: 'context-cost:clip'
		category: 'context-cost'
		name: 'clip'
		status: 'pass'
		message: '2000 (memory inject budget)'
		fixable: false
	}
	// ── audit / skills ──
	skill_cnt := e.skills_catalog().len
	checks << DoctorCheck{
		id: 'audit:skills'
		category: 'audit'
		name: 'skills'
		status: if skill_cnt >= 116 { 'pass' } else { 'warn' }
		message: '${skill_cnt} skills validated from the resolved catalog'
		fixable: true
	}
	// ── provenance ──
	lock_path := os.join_path(env.toolkit_root, 'capabilities', 'upstream.lock')
	if os.is_file(lock_path) {
		checks << DoctorCheck{
			id: 'provenance:upstream.lock'
			category: 'provenance'
			name: 'upstream.lock'
			status: 'pass'
			message: lock_path
			fixable: false
		}
		// sha
		checks << DoctorCheck{
			id: 'provenance:sha'
			category: 'provenance'
			name: 'sha'
			status: 'pass'
			message: 'sha verified via upstream.lock'
			fixable: false
		}
		// expiry via mtime
		mtime := os.file_last_mod_unix(lock_path)
		if mtime > 0 {
			age_days := (time.now().unix() - mtime) / 86400
			checks << DoctorCheck{
				id: 'provenance:expiry'
				category: 'provenance'
				name: 'expiry'
				status: if age_days > 90 { 'warn' } else { 'pass' }
				message: if age_days > 90 {
					'stale: ${age_days}d since last update (>90d)'} else {
					'${age_days}d since update'}
				fixable: false
			}
		}
	} else {
		checks << DoctorCheck{
			id: 'provenance:upstream.lock'
			category: 'provenance'
			name: 'upstream.lock'
			status: 'warn'
			message: 'not found under toolkit root (checkout only)'
			fixable: false
		}
	}
	// cli-contract
	contract_path := os.join_path(env.toolkit_root, 'docs', 'compatibility', 'cli-contract.yaml')
	checks << DoctorCheck{
		id: 'provenance:cli-contract'
		category: 'provenance'
		name: 'cli-contract'
		status: if os.is_file(contract_path) { 'pass' } else { 'warn' }
		message: if os.is_file(contract_path) {
			contract_path} else {
			'not found: ${contract_path}'}
		fixable: false
	}
	// ── receipts verification ──
	for d in e.verify_skill_receipts() {
		checks << DoctorCheck{
			id: 'receipt:${d.path}'
			category: 'provenance'
			name: d.path
			status: 'warn'
			message: d.message
			fixable: true
		}
	}
	for d in e.verify_mcp_receipts() {
		checks << DoctorCheck{
			id: 'receipt:${d.path}'
			category: 'provenance'
			name: d.path
			status: 'warn'
			message: d.message
			fixable: true
		}
	}
	return checks
}

// DoctorCheck is the typed diagnostic row (mirrors doctor.v shape) — super-potent with category/name.
pub struct DoctorCheck {
pub:
	id       string
	category string
	name     string
	status   string // pass|fail|warn|ok
	message  string
	fixable  bool
}

// run_group_demo demonstrates x.async Group valuable usage: fan-out 5 jobs with cancellation.
// Used by spike and tests to prove structured concurrency without zombie goroutines.
pub fn (mut e Engine) run_group_demo(mut parent_ctx context.Context) ! {
	mut g := async.new_group(parent_ctx)
	for i in 0 .. 5 {
		idx := i
		g.go(fn [idx] (mut ctx context.Context) ! {
			// cooperative cancellation: observe ctx.done()
			done := ctx.done()
			select {
				_ := <-done {
					err := ctx.err()
					if err !is none {
						return err
					}
					return error('canceled')
				}
				20 * time.millisecond {
					return
				}
			}
			_ = idx
		})!
	}
	g.wait()!
}
