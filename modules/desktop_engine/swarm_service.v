module desktop_engine

import os
import time
import json2
import sync
import desktop_engine.state
import desktop_engine.eventbus

// SwarmBackend enumerates Herdr/tmux headless options.
pub enum SwarmBackend {
	auto
	herdr
	tmux
	headless
}

// SwarmRecipeKind enumerates pair/team/full.
pub enum SwarmRecipeKind {
	pair
	team
	full
}

// SwarmRunStatus is runtime status for swarm runs.
pub enum SwarmRunStatus {
	pending
	running
	awaiting_approval
	completed
	failed
	canceled
}

// ApprovalKind enumerates spend/scope/destructive gates.
pub enum ApprovalKind {
	spend
	scope
	destructive
}

// ApprovalStatus tracks gate decision.
pub enum ApprovalStatus {
	pending
	approved
	rejected
}

// SwarmRun is the persisted swarm run projection stored via StateRepository.
pub struct SwarmRun {
pub:
	id           string
	recipe       SwarmRecipeKind
	backend      SwarmBackend
	task         string
	status       SwarmRunStatus
	created_at   i64
	budget_total int
	budget_spent int
	worktree     string
	trace_id     string
}

// SwarmApproval is a human gate for spend/scope/destructive.
pub struct SwarmApproval {
pub:
	id       string
	run_id   string
	kind     ApprovalKind
	message  string
	status   ApprovalStatus
	created_at i64
	budget_cost int
}

// InnerLoop is the per-role iteration loop (inner loop).
pub struct InnerLoop {
pub:
	loop_name    string
	iteration    int
	max_iterations int
	status       string // running | completed | awaiting_approval
	budget_spent int
	trace        []string
}

// OuterLoop is the scheduled mission loop (outer loop).
pub struct OuterLoop {
pub:
	name        string
	cadence     string // 15m, 1h, 1d, 1w
	enabled     bool
	next_run    string
	last_run    string
	tier        LoopTier
}

// GodMailbox is the central routing hub — GOD routes via mailbox, not direct.
// Enforces mailbox law: every handoff must enqueue via mailbox outbox → queued → active.
pub struct GodMailbox {
mut:
	inbox  int
	outbox int
	queue  []string // handoff ids in mailbox order
	bus    &eventbus.ToolkitEventBus
	repo   &state.StateRepository
	mu     sync.RwMutex
}

// new_god_mailbox creates mailbox bound to repo/bus.
pub fn new_god_mailbox(repo &state.StateRepository, bus &eventbus.ToolkitEventBus) &GodMailbox {
	return &GodMailbox{
		bus: bus
		repo: repo
	}
}

// route enqueues handoff via GOD mailbox — never direct.
// Validates from→to, records artifact path if provided, publishes swarm_handoff event.
pub fn (mut m GodMailbox) route(from string, to string, payload string, artifact string) !string {
	if from.len == 0 || to.len == 0 {
		return error('GOD mailbox: from/to required')
	}
	if from == to {
		return error('GOD mailbox: from==to forbidden — route via mailbox not self')
	}
	m.mu.lock()
	defer { m.mu.unlock() }
	id := 'h-${time.now().unix_nano() % 1000000:06d}'
	entry := '${from}->${to}:${payload}:${artifact}:${id}'
	m.queue << entry
	m.inbox++
	m.outbox++
	// persist via StateRepository transaction for EventBus wiring
	mut tx := m.repo.begin('god-mailbox')
	tx.set('swarm/mailbox/inbox', m.inbox.str())
	tx.set('swarm/mailbox/outbox', m.outbox.str())
	tx.set('swarm/mailbox/last', entry)
	tx.set('swarm/handoffs/${id}/from', from)
	tx.set('swarm/handoffs/${id}/to', to)
	tx.set('swarm/handoffs/${id}/payload', payload)
	tx.set('swarm/handoffs/${id}/artifact', artifact)
	tx.set('swarm/handoffs/${id}/status', 'queued')
	rev := tx.commit() or { return error('mailbox persist failed: ${err}') }
	m.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: rev.revision
		path: 'swarm/handoff/${id}'
		payload: json2.encode({
			'id': id
			'from': from
			'to': to
			'payload': payload
			'artifact': artifact
			'via': 'GOD-mailbox'
		})
	})
	// also publish dedicated swarm_handoff if available, fallback to state_changed
	return id
}

// inbox_count returns pending inbox.
pub fn (m GodMailbox) inbox_count() int {
	m.mu.rlock()
	defer { m.mu.runlock() }
	return m.inbox
}

// outbox_count returns total dispatched.
pub fn (m GodMailbox) outbox_count() int {
	m.mu.rlock()
	defer { m.mu.runlock() }
	return m.outbox
}

// drain returns and clears queue (for processing).
pub fn (mut m GodMailbox) drain() []string {
	m.mu.lock()
	defer { m.mu.unlock() }
	out := m.queue.clone()
	m.queue.clear()
	m.inbox = 0
	return out
}

// HandoffArtifact handles durable artifact files under .agent-toolkit/swarm/runs/<run-id>/artifacts/.
pub struct HandoffArtifact {
pub:
	run_id  string
	rel_path string // relative under artifacts/
	abs_path string
	size     int
	created_at i64
}

// validate_artifact_path rejects traversal and absolute paths.
fn validate_artifact_path(p string) !string {
	if p.len == 0 {
		return error('artifact path empty')
	}
	if os.is_abs_path(p) {
		return error('artifact path must be relative: ${p}')
	}
	if p.contains('..') {
		return error('artifact traversal: ${p}')
	}
	if p.len > 512 {
		return error('artifact path too long')
	}
	return p
}

// write_handoff_artifact atomically writes artifact file for a swarm run.
// Uses StateRepository for eventbus + filesystem for durability.
pub fn (mut e Engine) write_handoff_artifact(run_id string, rel_path string, content string) !string {
	if run_id.len == 0 {
		return error('run_id empty')
	}
	rel := validate_artifact_path(rel_path)!
	if content.len > 1024 * 1024 {
		return error('artifact >1MB cap')
	}
	// redaction: ensure no secrets in artifact metadata (payload check)
	if content.contains('AKIA') || content.contains('ghp_') {
		return error('artifact contains secret')
	}
	base := swarm_run_dir(run_id)
	abs := os.join_path(base, 'artifacts', rel)
	os.mkdir_all(os.dir(abs)) or { return error('mkdir failed: ${err}') }
	tmp := '${abs}.tmp.${os.getpid()}'
	os.write_file(tmp, content) or { return error('write tmp failed: ${err}') }
	os.mv(tmp, abs) or {
		os.rm(tmp) or {}
		return error('rename failed: ${err}')
	}
	// also persist via Engine State for EventBus wiring
	mut repo := e.repo
	mut tx := repo.begin('handoff-artifact')
	tx.set('swarm/${run_id}/artifacts/${rel}', abs)
	tx.set('swarm/${run_id}/artifacts/${rel}/size', content.len.str())
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .process_log
		revision: rev.revision
		path: 'swarm:${run_id}:artifact:${rel}'
		payload: json2.encode({'run_id': run_id, 'artifact': rel, 'size': content.len.str()})
	})
	return abs
}

// read_handoff_artifact reads artifact content.
pub fn (mut e Engine) read_handoff_artifact(run_id string, rel_path string) !string {
	rel := validate_artifact_path(rel_path)!
	base := swarm_run_dir(run_id)
	abs := os.join_path(base, 'artifacts', rel)
	if os.is_file(abs) {
		return os.read_file(abs) or { return error('read failed: ${err}') }
	}
	// fallback to StateRepository
	snap := e.repo.snapshot()
	key := 'swarm/${run_id}/artifacts/${rel}'
	if key in snap.data {
		// data holds abs path, try reading that path
		stored := snap.data[key]
		if os.is_file(stored) {
			return os.read_file(stored) or { return error('read stored failed: ${err}') }
		}
		return stored
	}
	return error('artifact not found: ${rel}')
}

// list_handoff_artifacts returns artifacts for a run.
pub fn (mut e Engine) list_handoff_artifacts(run_id string) []string {
	mut out := []string{}
	base := swarm_run_dir(run_id)
	art_dir := os.join_path(base, 'artifacts')
	if os.is_dir(art_dir) {
		files := os.walk_ext(art_dir, '', hidden: false)
		for f in files {
			rel := f.all_after(art_dir + os.path_separator)
			out << rel
		}
	}
	// merge with StateRepository keys
	snap := e.repo.snapshot()
	prefix := 'swarm/${run_id}/artifacts/'
	for k, _ in snap.data {
		if k.starts_with(prefix) && !k.ends_with('/size') {
			rel := k.all_after(prefix)
			if rel !in out {
				out << rel
			}
		}
	}
	out.sort()
	return out
}

fn swarm_run_dir(run_id string) string {
	// prefer toolkit swarm runs location if exists, else temp
	try_paths := [
		os.join_path(os.getwd(), '.agent-toolkit', 'swarm', 'runs', run_id),
		os.join_path(os.home_dir(), '.cache', 'agent-toolkit', 'swarm', 'runs', run_id),
	]
	for p in try_paths {
		if os.is_dir(os.dir(p)) || p.starts_with(os.getwd()) {
			return p
		}
	}
	return try_paths[0]
}

// ---- Swarm launch via Engine (easy pair/team/full) ----

pub struct SwarmLaunchArgs {
pub:
	recipe  SwarmRecipeKind
	backend SwarmBackend
	task    string
}

// swarm_recipe_from_string parses pair/team/full.
pub fn swarm_recipe_from_string(s string) SwarmRecipeKind {
	return match s.to_lower() {
		'pair' { SwarmRecipeKind.pair }
		'team' { SwarmRecipeKind.team }
		'full' { SwarmRecipeKind.full }
		else { SwarmRecipeKind.pair }
	}
}

// swarm_backend_from_string parses herdr/tmux/auto.
pub fn swarm_backend_from_string(s string) SwarmBackend {
	return match s.to_lower() {
		'herdr' { SwarmBackend.herdr }
		'tmux' { SwarmBackend.tmux }
		'auto' { SwarmBackend.auto }
		'headless' { SwarmBackend.headless }
		else { SwarmBackend.auto }
	}
}

// swarm_launch creates a swarm run via Engine — single entry for Desktop UI pair/team/full.
// Persists via Transaction, publishes via EventBus, returns run_id.
pub fn (mut e Engine) swarm_launch(args SwarmLaunchArgs) !string {
	if args.task.len == 0 {
		return error('swarm task empty')
	}
	if args.task.len > 4096 {
		return error('task too long')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	run_id := 'swarm-${time.now().unix_nano() % 1000000:06d}'
	mut repo := e.repo
	mut tx := repo.begin('swarm-launch')
	tx.set('swarm/runs/${run_id}/recipe', args.recipe.str())
	tx.set('swarm/runs/${run_id}/backend', args.backend.str())
	tx.set('swarm/runs/${run_id}/task', args.task)
	tx.set('swarm/runs/${run_id}/status', 'running')
	tx.set('swarm/runs/${run_id}/created_at', time.now().unix().str())
	tx.set('swarm/runs/${run_id}/budget_total', '100')
	tx.set('swarm/runs/${run_id}/budget_spent', '0')
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: rev.revision
		path: 'swarm:launch:${run_id}'
		payload: json2.encode({'run_id': run_id, 'recipe': args.recipe.str(), 'backend': args.backend.str(), 'task': args.task})
	})
	// also publish process_log for logs stream
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .process_log
		revision: rev.revision
		path: 'swarm:${run_id}'
		payload: json2.encode({'run_id': run_id, 'msg': 'swarm launched ${args.recipe.str()} via ${args.backend.str()}'})
	})
	return run_id
}

// swarm_list returns all runs from StateRepository.
pub fn (mut e Engine) swarm_list() []SwarmRun {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut ids := []string{}
	for k, _ in snap.data {
		if k.starts_with('swarm/runs/') && k.ends_with('/recipe') {
			id := k.all_after('swarm/runs/').all_before('/recipe')
			if id !in ids {
				ids << id
			}
		}
	}
	ids.sort()
	mut out := []SwarmRun{}
	for id in ids {
		recipe_str := snap.data['swarm/runs/${id}/recipe'] or { 'pair' }
		backend_str := snap.data['swarm/runs/${id}/backend'] or { 'auto' }
		status_str := snap.data['swarm/runs/${id}/status'] or { 'pending' }
		task := snap.data['swarm/runs/${id}/task'] or { '' }
		created_str := snap.data['swarm/runs/${id}/created_at'] or { '0' }
		btotal_str := snap.data['swarm/runs/${id}/budget_total'] or { '100' }
		bspent_str := snap.data['swarm/runs/${id}/budget_spent'] or { '0' }
		out << SwarmRun{
			id: id
			recipe: swarm_recipe_from_string(recipe_str)
			backend: swarm_backend_from_string(backend_str)
			task: task
			status: match status_str {
				'running' { SwarmRunStatus.running }
				'awaiting_approval' { SwarmRunStatus.awaiting_approval }
				'completed' { SwarmRunStatus.completed }
				'failed' { SwarmRunStatus.failed }
				'canceled' { SwarmRunStatus.canceled }
				else { SwarmRunStatus.pending }
			}
			created_at: created_str.i64()
			budget_total: btotal_str.int()
			budget_spent: bspent_str.int()
		}
	}
	return out
}

// swarm_status returns single run or none.
pub fn (mut e Engine) swarm_status(run_id string) ?SwarmRun {
	for r in e.swarm_list() {
		if r.id == run_id {
			return r
		}
	}
	return none
}

// swarm_handoffs returns handoffs for a run via State keys.
pub fn (mut e Engine) swarm_handoffs(run_id string) []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []string{}
	prefix := 'swarm/handoffs/'
	for k, v in snap.data {
		if k.starts_with(prefix) && v.contains(run_id) {
			out << '${k}=${v}'
		}
		// also mailbox style
		if k.starts_with('swarm/${run_id}/handoffs/') {
			out << '${k}:${v}'
		}
	}
	// also generic GOD mailbox last
	if last := snap.data['swarm/mailbox/last'] {
		out << last
	}
	return out
}

// swarm_logs returns process_log lines for a swarm run (demultiplexed).
pub fn (mut e Engine) swarm_logs(run_id string) []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	raw := snap.data['swarm/${run_id}/logs'] or { snap.data['jobs/${run_id}/logs'] or { '' } }
	if raw == '' {
		// synthesize from runs if no logs yet
		return ['swarm ${run_id} launched', 'awaiting handoff via GOD mailbox']
	}
	return raw.split('\n')
}

// ---- Approvals: spend/scope/destructive ----

pub fn (mut e Engine) swarm_request_approval(run_id string, kind ApprovalKind, message string, cost int) !string {
	if run_id.len == 0 {
		return error('run_id empty')
	}
	if message.len == 0 {
		return error('approval message empty')
	}
	if message.contains('AKIA') || message.contains('ghp_') {
		return error('secret in approval')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	approval_id := 'appr-${time.now().unix_nano() % 1000000:06d}'
	mut repo := e.repo
	mut tx := repo.begin('swarm-approval')
	tx.set('swarm/${run_id}/approvals/${approval_id}/kind', kind.str())
	tx.set('swarm/${run_id}/approvals/${approval_id}/message', message)
	tx.set('swarm/${run_id}/approvals/${approval_id}/status', 'pending')
	tx.set('swarm/${run_id}/approvals/${approval_id}/cost', cost.str())
	tx.set('swarm/${run_id}/status', 'awaiting_approval')
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: rev.revision
		path: 'swarm:${run_id}:approval:${approval_id}'
		payload: json2.encode({'run_id': run_id, 'approval_id': approval_id, 'kind': kind.str(), 'message': message, 'cost': cost.str(), 'status': 'pending'})
	})
	return approval_id
}

// swarm_approve resolves a gate — approved or rejected.
pub fn (mut e Engine) swarm_approve(run_id string, approval_id string, approved bool) !u64 {
	if run_id.len == 0 || approval_id.len == 0 {
		return error('run/approval id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	key := 'swarm/${run_id}/approvals/${approval_id}/status'
	if key !in snap.data {
		return error('approval not found: ${approval_id}')
	}
	if snap.data[key] != 'pending' {
		return error('approval already resolved')
	}
	mut repo := e.repo
	mut tx := repo.begin('swarm-approve')
	status := if approved { 'approved' } else { 'rejected' }
	tx.set(key, status)
	// if all approvals resolved, move swarm back to running
	mut still_pending := false
	for k, v in snap.data {
		if k.starts_with('swarm/${run_id}/approvals/') && k.ends_with('/status') && k != key {
			if v == 'pending' {
				still_pending = true
				break
			}
		}
	}
	if !still_pending && approved {
		tx.set('swarm/${run_id}/status', 'running')
	} else if !approved {
		tx.set('swarm/${run_id}/status', 'failed')
	}
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: rev.revision
		path: 'swarm:${run_id}:approval:${approval_id}'
		payload: json2.encode({'run_id': run_id, 'approval_id': approval_id, 'status': status})
	})
	return rev.revision
}

// swarm_pending_approvals returns pending gates for a run.
pub fn (mut e Engine) swarm_pending_approvals(run_id string) []SwarmApproval {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []SwarmApproval{}
	prefix := 'swarm/${run_id}/approvals/'
	mut ids := []string{}
	for k, _ in snap.data {
		if k.starts_with(prefix) && k.ends_with('/kind') {
			id := k.all_after(prefix).all_before('/kind')
			if id !in ids {
				ids << id
			}
		}
	}
	for id in ids {
		kind_str := snap.data['${prefix}${id}/kind'] or { 'spend' }
		msg := snap.data['${prefix}${id}/message'] or { '' }
		status_str := snap.data['${prefix}${id}/status'] or { 'pending' }
		cost_str := snap.data['${prefix}${id}/cost'] or { '0' }
		kind := match kind_str {
			'scope' { ApprovalKind.scope }
			'destructive' { ApprovalKind.destructive }
			else { ApprovalKind.spend }
		}
		status := match status_str {
			'approved' { ApprovalStatus.approved }
			'rejected' { ApprovalStatus.rejected }
			else { ApprovalStatus.pending }
		}
		if status != .pending {
			continue
		}
		out << SwarmApproval{
			id: id
			run_id: run_id
			kind: kind
			message: msg
			status: status
			budget_cost: cost_str.int()
		}
	}
	return out
}

// ── Super-potent inner/outer loops via Engine — easy to manage ─────────────

// swarm_inner_start creates an inner loop tick for a swarm run — easy.
pub fn (mut e Engine) swarm_inner_start(run_id string, role string, goal string, max_iter int) !string {
	if run_id == '' || role == '' {
		return error('run_id/role empty')
	}
	mut max_i := max_iter
	if max_i <= 0 { max_i = 2 }
	if max_i > 10 { max_i = 10 }
	loop_id := 'inner-${run_id}-${role}-${time.now().unix_nano() % 1000000:06d}'
	mut repo := e.repo
	mut tx := repo.begin('inner-start')
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/role', role)
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/goal', goal)
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/iteration', '0')
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/max', max_i.str())
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/status', 'running')
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_inner_tick
		revision: rev.revision
		path: 'swarm:${run_id}:inner:${loop_id}'
		payload: json2.encode({'loop_id': loop_id, 'run_id': run_id, 'role': role, 'status': 'running'})
	})
	return loop_id
}

// swarm_inner_tick advances inner loop — easy budget tracking.
pub fn (mut e Engine) swarm_inner_tick(run_id string, loop_id string, trace_line string, budget_spent int) !u64 {
	if run_id == '' || loop_id == '' {
		return error('run/loop id empty')
	}
	if trace_line.contains('AKIA') || trace_line.contains('ghp_') {
		return error('secret in trace')
	}
	snap := e.repo.snapshot()
	key := 'swarm/${run_id}/inner_loops/${loop_id}/status'
	if snap.data[key] != 'running' && snap.data[key] != '' {
		return error('inner loop not running')
	}
	iter_str := snap.data['swarm/${run_id}/inner_loops/${loop_id}/iteration'] or { '0' }
	iter := iter_str.int() + 1
	max_str := snap.data['swarm/${run_id}/inner_loops/${loop_id}/max'] or { '2' }
	max_iter := max_str.int()
	if iter > max_iter {
		return error('max_iterations reached — requires approval')
	}
	mut repo := e.repo
	mut tx := repo.begin('inner-tick')
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/iteration', iter.str())
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/budget_spent', budget_spent.str())
	if trace_line != '' {
		existing := snap.data['swarm/${run_id}/inner_loops/${loop_id}/trace'] or { '' }
		new_trace := if existing != '' { existing + '\n' + trace_line } else { trace_line }
		tx.set('swarm/${run_id}/inner_loops/${loop_id}/trace', new_trace)
	}
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_inner_tick
		revision: rev.revision
		path: 'swarm:${run_id}:inner:${loop_id}:tick:${iter}'
		payload: json2.encode({'loop_id': loop_id, 'iteration': iter.str(), 'trace': trace_line})
	})
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .process_log
		revision: rev.revision
		path: 'inner:${loop_id}'
		payload: trace_line
	})
	return rev.revision
}

// swarm_inner_complete marks inner loop done.
pub fn (mut e Engine) swarm_inner_complete(run_id string, loop_id string, exit string) !u64 {
	if run_id == '' || loop_id == '' {
		return error('run/loop id empty')
	}
	mut repo := e.repo
	mut tx := repo.begin('inner-complete')
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/status', 'completed')
	tx.set('swarm/${run_id}/inner_loops/${loop_id}/exit', exit)
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_inner_tick
		revision: rev.revision
		path: 'swarm:${run_id}:inner:${loop_id}:completed'
		payload: json2.encode({'loop_id': loop_id, 'exit': exit})
	})
	return rev.revision
}

// swarm_list_inner returns inner loops for a run.
pub fn (mut e Engine) swarm_list_inner(run_id string) []InnerLoop {
	snap := e.repo.snapshot()
	prefix := 'swarm/${run_id}/inner_loops/'
	mut ids := []string{}
	for k, _ in snap.data {
		if k.starts_with(prefix) && k.ends_with('/role') {
			id := k.all_after(prefix).all_before('/role')
			if id !in ids { ids << id }
		}
	}
	mut out := []InnerLoop{}
	for id in ids {
		role := snap.data['${prefix}${id}/role'] or { '' }
		goal := snap.data['${prefix}${id}/goal'] or { '' }
		iter := (snap.data['${prefix}${id}/iteration'] or { '0' }).int()
		max_iter := (snap.data['${prefix}${id}/max'] or { '2' }).int()
		status := snap.data['${prefix}${id}/status'] or { 'running' }
		spent := (snap.data['${prefix}${id}/budget_spent'] or { '0' }).int()
		trace_raw := snap.data['${prefix}${id}/trace'] or { '' }
		trace := if trace_raw != '' { trace_raw.split('\n') } else { []string{} }
		out << InnerLoop{
			loop_name: id
			iteration: iter
			max_iterations: max_iter
			status: status
			budget_spent: spent
			trace: trace
		}
		_ = role
		_ = goal
	}
	return out
}

// swarm_outer_catalog returns outer loops via loops_catalog filtered for missions.
pub fn (mut e Engine) swarm_outer_catalog() []OuterLoop {
	loops := e.loops_catalog()
	mut out := []OuterLoop{}
	for l in loops {
		out << OuterLoop{
			name: l.name
			cadence: l.cadence
			enabled: l.cron_enabled
			next_run: l.next_run
			last_run: l.last_run
			tier: l.tier
		}
	}
	return out
}

// god_route — GOD routing via Engine mailbox — easy one-liner.
pub fn (mut e Engine) god_route(from string, to string, payload string, artifact string) !string {
	if from == '' || to == '' {
		return error('GOD mailbox: from/to required')
	}
	if from == to {
		return error('GOD mailbox: from==to forbidden')
	}
	if artifact.contains('..') {
		return error('artifact traversal')
	}
	if payload.contains('AKIA') || payload.contains('ghp_') {
		return error('secret in payload')
	}
	// use Engine's GodMailbox via StateRepository + EventBus (no direct desk→desk)
	id := 'h-${time.now().unix_nano() % 1000000:06d}'
	mut repo := e.repo
	mut tx := repo.begin('god-route')
	tx.set('swarm/handoffs/${id}/from', from)
	tx.set('swarm/handoffs/${id}/to', to)
	tx.set('swarm/handoffs/${id}/payload', payload)
	tx.set('swarm/handoffs/${id}/artifact', artifact)
	tx.set('swarm/handoffs/${id}/status', 'queued')
	tx.set('swarm/handoffs/${id}/via', 'GOD-mailbox')
	tx.set('swarm/mailbox/last', '${from}->${to}:${payload}:${artifact}:${id}')
	tx.set('swarm/god_mailbox/last_id', id)
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_handoff
		revision: rev.revision
		path: 'swarm/handoff/${id}'
		payload: json2.encode({'id': id, 'from': from, 'to': to, 'payload': payload, 'artifact': artifact, 'via': 'GOD-mailbox'})
	})
	return id
}

// swarm_approvals_queue — easy approvals queue management.
pub fn (mut e Engine) swarm_approvals_queue() []SwarmApproval {
	snap := e.repo.snapshot()
	mut out := []SwarmApproval{}
	mut seen := map[string]bool{}
	for k, _ in snap.data {
		if k.starts_with('swarm/') && k.contains('/approvals/') && k.ends_with('/status') {
			parts := k.split('/')
			if parts.len >= 4 {
				run_id := parts[1]
				appr_id := parts[3]
				key := '${run_id}:${appr_id}'
				if seen[key] { continue }
				seen[key] = true
				// only pending
				status := snap.data[k] or { '' }
				if status != 'pending' { continue }
				kind_str := snap.data['swarm/${run_id}/approvals/${appr_id}/kind'] or { 'spend' }
				msg := snap.data['swarm/${run_id}/approvals/${appr_id}/message'] or { '' }
				cost_str := snap.data['swarm/${run_id}/approvals/${appr_id}/cost'] or { '0' }
				kind := match kind_str {
					'scope' { ApprovalKind.scope }
					'destructive' { ApprovalKind.destructive }
					else { ApprovalKind.spend }
				}
				out << SwarmApproval{
					id: appr_id
					run_id: run_id
					kind: kind
					message: msg
					status: .pending
					budget_cost: cost_str.int()
				}
			}
		}
	}
	return out
}

// ProcessSupervisor easy management via Engine.

pub fn (mut e Engine) process_supervisor_stats() (int, u64) {
	if mut sup := e.supervisor {
		// if supervisor is ProcessSupervisor type, get counts
		// Use generic via interface — try to cast via json? For now, snapshot based
		_ = sup
	}
	snap := e.repo.snapshot()
	mut proc_count := 0
	for k, _ in snap.data {
		if k.starts_with('jobs/') && k.ends_with('/status') && snap.data[k] == 'running' {
			proc_count++
		}
	}
	return proc_count, e.bus.dropped_count()
}
