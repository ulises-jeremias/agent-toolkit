module desktop

import desktop_engine

// Office attention surface — domain projection (slice A, #1228).
//
// Pure Engine → viewmodel mapping for the Office attention surface. No I/O,
// no shell, no GUI: the Engine stays the domain authority and this file only
// projects its records (jobs, swarm runs, loop histories, approvals queue)
// into run-backed rows with explicit states.
//
// State model: idle / running / waiting / blocked / needs-me / failed, plus
// unknown. waiting (queued, expecting runtime) != blocked (cannot proceed:
// budget exhausted on a live run) != needs-me (a human gate waits in the
// Engine approvals queue). Anything unprovable stays unknown or empty —
// never fabricated. Jobs and swarm runs carry no agent attribution and no
// provider/model fields, so those columns stay honestly empty until the
// Engine records them (see missing ops in the final report).

// OfficeRunState is the explicit per-run attention state.
pub enum OfficeRunState {
	unknown
	idle
	running
	waiting
	blocked
	needs_me
	failed
}

// key returns the stable semantic key for pills and filters.
pub fn (s OfficeRunState) key() string {
	return match s {
		.unknown { 'unknown' }
		.idle { 'idle' }
		.running { 'running' }
		.waiting { 'waiting' }
		.blocked { 'blocked' }
		.needs_me { 'needs-me' }
		.failed { 'failed' }
	}
}

// label returns the human pill label.
pub fn (s OfficeRunState) label() string {
	return match s {
		.unknown { 'Unknown' }
		.idle { 'Idle' }
		.running { 'Running' }
		.waiting { 'Waiting' }
		.blocked { 'Blocked' }
		.needs_me { 'Needs me' }
		.failed { 'Failed' }
	}
}

// OfficeRunRow is one run-backed attention row projected from an Engine
// record. ref_idx points back into the source Engine list for selection
// mapping (jobs/swarms); loop rows map by loop_name instead. agent and
// provider_model stay empty unless the Engine proves them.
pub struct OfficeRunRow {
pub:
	kind           string // 'job' | 'swarm' | 'loop'
	id             string
	title          string
	agent          string
	provider_model string
	workspace      string
	activity       string
	state          OfficeRunState
	attention      bool
	approval_id    string // pending approval gating this run, else ''
	ref_idx        int
	loop_name      string
	evidence       []string
}

// OfficeApprovalItem is a pending gate projected over the Engine approvals
// queue. Projection only — the record stays in the domain.
pub struct OfficeApprovalItem {
pub:
	id          string
	run_id      string
	run_title   string
	kind        string
	message     string
	budget_cost int
}

// OfficeCompletion is a recent finished run with evidence drill-down.
pub struct OfficeCompletion {
pub:
	kind     string // 'job' | 'swarm' | 'loop'
	id       string
	title    string
	detail   string
	evidence []string
	ts       i64
}

// OfficeAction is one currently-valid inspector action. engine_op names the
// Desktop Engine op to invoke (cancel_job, retry_job, swarm_approve,
// run_loop). Only valid actions are ever returned — no dead buttons.
pub struct OfficeAction {
pub:
	label      string
	kind       string // 'cancel' | 'retry' | 'approve' | 'reject' | 'run'
	engine_op  string
	primary    bool
	danger     bool
}

// office_job_state maps a job status to the attention state.
pub fn office_job_state(status desktop_engine.JobStatus) OfficeRunState {
	return match status {
		.queued { .waiting }
		.running { .running }
		.done { .idle }
		.canceled { .idle }
		.failed { .failed }
	}
}

// office_budget_exhausted reports whether a live run consumed its whole
// budget (real Engine counters, not a guess).
pub fn office_budget_exhausted(total int, spent int) bool {
	return total > 0 && spent >= total
}

// office_swarm_state maps a swarm run status to the attention state.
// A pending approval in the Engine queue (has_pending_approval) or the
// awaiting_approval status means needs-me; an exhausted budget on a
// non-terminal run means blocked.
pub fn office_swarm_state(status desktop_engine.SwarmRunStatus, has_pending_approval bool, budget_exhausted bool) OfficeRunState {
	if status == .failed {
		return .failed
	}
	if status == .awaiting_approval || has_pending_approval {
		return .needs_me
	}
	if status == .completed || status == .canceled {
		return .idle
	}
	if budget_exhausted {
		return .blocked
	}
	return match status {
		.running { .running }
		else { .waiting }
	}
}

// office_reconcile_liveness guards a claimed running state against
// supervisor liveness: a run the supervisor does not report active is
// unknown, not running. Never fabricates activity.
pub fn office_reconcile_liveness(state OfficeRunState, supervisor_reports_active bool) OfficeRunState {
	if state == .running && !supervisor_reports_active {
		return .unknown
	}
	return state
}

// office_loop_history_state maps a free-form loop history status to the
// attention state. Unrecognized statuses stay unknown.
pub fn office_loop_history_state(status string) OfficeRunState {
	s := status.trim_space().to_lower()
	if s in ['completed', 'complete', 'done', 'success', 'succeeded', 'ok'] {
		return .idle
	}
	if s in ['failed', 'failure', 'error', 'errored'] {
		return .failed
	}
	if s in ['running', 'started', 'in_progress'] {
		return .running
	}
	if s in ['queued', 'pending', 'waiting', 'scheduled'] {
		return .waiting
	}
	if s == 'blocked' {
		return .blocked
	}
	if s in ['awaiting_approval', 'needs_approval', 'needs-me'] {
		return .needs_me
	}
	return .unknown
}

// office_format_ms renders milliseconds compactly ('—' when unmeasured).
pub fn office_format_ms(ms int) string {
	if ms <= 0 {
		return '—'
	}
	if ms < 1000 {
		return '${ms}ms'
	}
	s := ms / 1000
	if s < 60 {
		return '${s}s'
	}
	m := s / 60
	if m < 60 {
		return '${m}m ${s % 60:02d}s'
	}
	return '${m / 60}h ${m % 60:02d}m'
}

// office_pending_approval_for returns the id of the pending approval gating
// run_id, or '' when none exists.
fn office_pending_approval_for(approvals []desktop_engine.SwarmApproval, run_id string) string {
	for a in approvals {
		if a.run_id == run_id && a.status == .pending {
			return a.id
		}
	}
	return ''
}

// office_project_runs projects jobs, swarm runs and loop histories into
// run-backed rows, attention rows (needs-me/failed/blocked) first, stable.
pub fn office_project_runs(jobs []desktop_engine.JobRecord, swarms []desktop_engine.SwarmRun, histories []desktop_engine.LoopHistory, approvals []desktop_engine.SwarmApproval, supervisor_active bool) []OfficeRunRow {
	mut rows := []OfficeRunRow{}
	for i, j in jobs {
		title := if j.cmd.trim_space() != '' { j.cmd.trim_space() } else { j.id }
		mut activity := j.args.join(' ').trim_space()
		if activity == '' {
			activity = title
		}
		state := office_reconcile_liveness(office_job_state(j.status), supervisor_active)
		mut evidence := []string{}
		if j.status == .running || j.status == .queued {
			evidence << 'status ${j.status.str()}'
		} else {
			evidence << 'exit ${j.exit_code}'
			evidence << 'ran ${office_format_ms(j.duration_ms)}'
		}
		if j.work_dir.trim_space() != '' {
			evidence << 'work dir ${j.work_dir}'
		}
		if j.retry_count > 0 {
			evidence << 'retries ${j.retry_count}'
		}
		if j.logs.len > 0 {
			evidence << 'log: ${j.logs[j.logs.len - 1]}'
		}
		rows << OfficeRunRow{
			kind: 'job'
			id: j.id
			title: title
			agent: ''
			provider_model: ''
			workspace: j.work_dir
			activity: activity
			state: state
			attention: state == .failed
			ref_idx: i
			evidence: evidence
		}
	}
	for i, s in swarms {
		appr := office_pending_approval_for(approvals, s.id)
		exhausted := office_budget_exhausted(s.budget_total, s.budget_spent)
		state := office_swarm_state(s.status, appr != '', exhausted)
		title := if s.task.trim_space() != '' { s.task.trim_space() } else { s.id }
		mut evidence := []string{}
		evidence << 'status ${s.status.str()}'
		if s.budget_total > 0 {
			evidence << 'budget ${s.budget_spent}/${s.budget_total}'
		}
		if s.worktree.trim_space() != '' {
			evidence << 'worktree ${s.worktree}'
		}
		if appr != '' {
			evidence << 'gated by approval ${appr}'
		}
		rows << OfficeRunRow{
			kind: 'swarm'
			id: s.id
			title: title
			agent: ''
			provider_model: ''
			workspace: s.worktree
			activity: '${s.recipe.str()} · ${s.backend.str()}'
			state: state
			attention: state == .needs_me || state == .failed || state == .blocked
			approval_id: appr
			ref_idx: i
			evidence: evidence
		}
	}
	for h in histories {
		state := office_loop_history_state(h.status)
		title := if h.loop_name.trim_space() != '' { h.loop_name } else { h.run_id }
		mut evidence := []string{}
		if h.exit_condition.trim_space() != '' {
			evidence << 'exit: ${h.exit_condition}'
		}
		evidence << 'status ${if h.status.trim_space() != '' { h.status } else { 'unknown' }}'
		evidence << 'ran ${office_format_ms(h.duration_ms)}'
		if h.budget_spent > 0 {
			evidence << 'budget spent ${h.budget_spent}'
		}
		rows << OfficeRunRow{
			kind: 'loop'
			id: if h.run_id != '' { h.run_id } else { h.loop_name }
			title: title
			agent: ''
			provider_model: ''
			workspace: ''
			activity: if h.exit_condition.trim_space() != '' { h.exit_condition } else { 'loop run' }
			state: state
			attention: state == .failed || state == .blocked || state == .needs_me
			ref_idx: -1
			loop_name: h.loop_name
			evidence: evidence
		}
	}
	// stable partition: attention rows first, Engine order otherwise kept
	mut hot := []OfficeRunRow{}
	mut cold := []OfficeRunRow{}
	for r in rows {
		if r.attention {
			hot << r
		} else {
			cold << r
		}
	}
	hot << cold
	return hot
}

// office_pending_approvals projects the Engine approvals queue to pending
// gates only, in queue order. Decided gates stay in the domain.
pub fn office_pending_approvals(approvals []desktop_engine.SwarmApproval, run_title_for fn (string) string) []OfficeApprovalItem {
	mut out := []OfficeApprovalItem{}
	for a in approvals {
		if a.status != .pending {
			continue
		}
		out << OfficeApprovalItem{
			id: a.id
			run_id: a.run_id
			run_title: run_title_for(a.run_id)
			kind: a.kind.str()
			message: a.message
			budget_cost: a.budget_cost
		}
	}
	return out
}

// office_recent_completions collects successful terminals newest-first with
// evidence, capped at limit (limit <= 0 means all).
pub fn office_recent_completions(jobs []desktop_engine.JobRecord, swarms []desktop_engine.SwarmRun, histories []desktop_engine.LoopHistory, limit int) []OfficeCompletion {
	mut out := []OfficeCompletion{}
	for j in jobs {
		if j.status != .done {
			continue
		}
		title := if j.cmd.trim_space() != '' { j.cmd.trim_space() } else { j.id }
		mut evidence := []string{}
		evidence << 'exit ${j.exit_code}'
		evidence << 'ran ${office_format_ms(j.duration_ms)}'
		if j.work_dir.trim_space() != '' {
			evidence << 'work dir ${j.work_dir}'
		}
		if j.logs.len > 0 {
			evidence << 'log: ${j.logs[j.logs.len - 1]}'
		}
		ts := if j.finished_at > 0 { j.finished_at } else { j.started_at }
		out << OfficeCompletion{
			kind: 'job'
			id: j.id
			title: title
			detail: 'done · ${office_format_ms(j.duration_ms)}'
			evidence: evidence
			ts: ts
		}
	}
	for s in swarms {
		if s.status != .completed {
			continue
		}
		title := if s.task.trim_space() != '' { s.task.trim_space() } else { s.id }
		mut evidence := []string{}
		evidence << 'task ${title}'
		if s.budget_total > 0 {
			evidence << 'budget ${s.budget_spent}/${s.budget_total}'
		}
		if s.worktree.trim_space() != '' {
			evidence << 'worktree ${s.worktree}'
		}
		out << OfficeCompletion{
			kind: 'swarm'
			id: s.id
			title: title
			detail: 'completed'
			evidence: evidence
			ts: s.created_at
		}
	}
	for h in histories {
		if office_loop_history_state(h.status) != .idle {
			continue
		}
		title := if h.loop_name.trim_space() != '' { h.loop_name } else { h.run_id }
		mut evidence := []string{}
		if h.exit_condition.trim_space() != '' {
			evidence << 'exit: ${h.exit_condition}'
		}
		evidence << 'ran ${office_format_ms(h.duration_ms)}'
		out << OfficeCompletion{
			kind: 'loop'
			id: if h.run_id != '' { h.run_id } else { h.loop_name }
			title: title
			detail: if h.exit_condition.trim_space() != '' { h.exit_condition } else { 'done' }
			evidence: evidence
			ts: h.started_at
		}
	}
	out.sort(a.ts > b.ts)
	if limit > 0 && out.len > limit {
		out = out[..limit]
	}
	return out
}

// office_run_actions lists only the currently-valid actions for a row.
// Anything unavailable stays hidden; office_no_actions_hint explains why.
pub fn office_run_actions(row OfficeRunRow) []OfficeAction {
	match row.kind {
		'job' {
			if row.state == .waiting || row.state == .running {
				return [OfficeAction{'Cancel', 'cancel', 'cancel_job', false, true}]
			}
			if row.state == .failed || row.state == .idle {
				return [OfficeAction{'Retry', 'retry', 'retry_job', true, false}]
			}
			return []
		}
		'swarm' {
			if row.state == .needs_me && row.approval_id != '' {
				return [
					OfficeAction{'Approve', 'approve', 'swarm_approve', true, false},
					OfficeAction{'Reject', 'reject', 'swarm_approve', false, true},
				]
			}
			return []
		}
		'loop' {
			if row.state != .unknown {
				return [OfficeAction{'Run again', 'run', 'run_loop', true, false}]
			}
			return []
		}
		else {
			return []
		}
	}
}

// office_no_actions_hint explains why a row offers no actions ('' when it
// offers some). Shown in the inspector instead of dead buttons.
pub fn office_no_actions_hint(row OfficeRunRow) string {
	if office_run_actions(row).len > 0 {
		return ''
	}
	if row.state == .unknown {
		return 'State unknown — actions hidden until the Engine reports live run state.'
	}
	if row.kind == 'swarm' && (row.state == .running || row.state == .waiting) {
		return 'No stop control is exposed for swarm runs yet — needs engine_swarm_cancel.'
	}
	if row.kind == 'swarm' {
		return 'Terminal swarm run with no pending approvals — nothing to act on.'
	}
	return 'Nothing to act on for this run.'
}
