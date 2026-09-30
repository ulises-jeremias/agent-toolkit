module agent_toolkit_core

import os

// SwarmRunInfo is one filesystem swarm run (list row).
pub struct SwarmRunInfo {
pub:
	run_id     string
	recipe     string
	backend    string
	run_state  string
	created_at string
	task       string
}

pub struct SwarmListResponse {
pub:
	ok   bool
	runs []SwarmRunInfo
}

pub struct SwarmBudgetView {
pub:
	max_total_tokens int
	total_tokens     int
	max_cost_usd     f64
	total_cost       f64
	max_wall_seconds int
	cost_status      string
}

pub struct SwarmHandoffView {
pub:
	id         string
	htype      string
	from_role  string
	to_role    string
	priority   int
	artifact   string
	commit     string
	branch     string
	blocking   bool
	state      string
	created_at string
}

pub struct SwarmTaskView {
pub:
	id             string
	status         string
	priority       int
	owner          string
	from_role      string
	dependencies   string
	blocked_reason string
	created_at     string
}

pub struct SwarmArtifactView {
pub:
	name string
	path string
	size int
}

pub struct SwarmRunResponse {
pub:
	ok         bool
	run        SwarmRunInfo
	runner     string
	model      string
	budget     SwarmBudgetView
	approvals  []SwarmGate
	handoffs   []SwarmHandoffView
	tasks      []SwarmTaskView
	artifacts  []SwarmArtifactView
	trace_tail []string
}

pub struct SwarmHandoffsResponse {
pub:
	ok       bool
	run_id   string
	handoffs []SwarmHandoffView
}

pub struct SwarmTasksResponse {
pub:
	ok     bool
	run_id string
	tasks  []SwarmTaskView
}

pub struct SwarmApprovalsResponse {
pub:
	ok        bool
	run_id    string
	approvals []SwarmGate
}

pub struct SwarmArtifactsResponse {
pub:
	ok        bool
	run_id    string
	artifacts []SwarmArtifactView
}

pub struct SwarmActionResponse {
pub:
	ok      bool
	message string
	run_id  string
	status  string
}

// list_swarm_runs_typed reads .agent-toolkit/swarm/runs from the workspace.
pub fn list_swarm_runs_typed(workspace string) SwarmListResponse {
	ws := find_swarm_workspace(workspace)
	mut runs := []SwarmRunInfo{}
	for rd in list_all_swarm_runs(ws) {
		st := read_swarm_state(rd) or { continue }
		runs << swarm_run_info(st)
	}
	return SwarmListResponse{
		ok: true
		runs: runs
	}
}

pub fn get_swarm_run_typed(workspace string, run_id string) !SwarmRunResponse {
	ws, rd, st := require_swarm_run(workspace, run_id)!
	_ = ws
	return SwarmRunResponse{
		ok: true
		run: swarm_run_info(st)
		runner: st.runner
		model: st.model_profile
		budget: swarm_budget_view(st)
		approvals: read_swarm_approvals(rd)
		handoffs: collect_swarm_handoffs(rd)
		tasks: swarm_tasks_from_handoffs(collect_swarm_handoffs(rd))
		artifacts: collect_swarm_artifacts(rd)
		trace_tail: swarm_trace_tail(rd)
	}
}

pub fn list_swarm_handoffs_typed(workspace string, run_id string) !SwarmHandoffsResponse {
	_, rd, _ := require_swarm_run(workspace, run_id)!
	return SwarmHandoffsResponse{
		ok: true
		run_id: run_id
		handoffs: collect_swarm_handoffs(rd)
	}
}

pub fn list_swarm_tasks_typed(workspace string, run_id string) !SwarmTasksResponse {
	_, rd, _ := require_swarm_run(workspace, run_id)!
	return SwarmTasksResponse{
		ok: true
		run_id: run_id
		tasks: swarm_tasks_from_handoffs(collect_swarm_handoffs(rd))
	}
}

pub fn list_swarm_approvals_typed(workspace string, run_id string) !SwarmApprovalsResponse {
	_, rd, _ := require_swarm_run(workspace, run_id)!
	return SwarmApprovalsResponse{
		ok: true
		run_id: run_id
		approvals: read_swarm_approvals(rd)
	}
}

pub fn list_swarm_artifacts_typed(workspace string, run_id string) !SwarmArtifactsResponse {
	_, rd, _ := require_swarm_run(workspace, run_id)!
	return SwarmArtifactsResponse{
		ok: true
		run_id: run_id
		artifacts: collect_swarm_artifacts(rd)
	}
}

pub fn approve_swarm_gate_typed(workspace string, run_id string, gate_id string) SwarmActionResponse {
	report := run_swarm(SwarmOptions{
		subcommand: 'approve'
		workspace_path: workspace
		run_id: run_id
		gate_id: gate_id
	})
	return swarm_action_from_report(report, run_id)
}

pub fn reject_swarm_gate_typed(workspace string, run_id string, gate_id string, reason string) SwarmActionResponse {
	report := run_swarm(SwarmOptions{
		subcommand: 'reject'
		workspace_path: workspace
		run_id: run_id
		gate_id: gate_id
		reason: reason
	})
	return swarm_action_from_report(report, run_id)
}

pub fn stop_swarm_run_typed(workspace string, run_id string) SwarmActionResponse {
	report := run_swarm(SwarmOptions{
		subcommand: 'cancel'
		workspace_path: workspace
		run_id: run_id
	})
	return swarm_action_from_report(report, run_id)
}

fn require_swarm_run(workspace string, run_id string) !(string, string, SwarmStateFile) {
	if !swarm_valid_run_id(run_id) {
		return error('invalid run_id')
	}
	ws := find_swarm_workspace(workspace)
	rd := swarm_run_dir(ws, run_id)
	st := read_swarm_state(rd) or { return error('run not found') }
	return ws, rd, st
}

fn swarm_run_info(st SwarmStateFile) SwarmRunInfo {
	return SwarmRunInfo{
		run_id: st.run_id
		recipe: st.recipe
		backend: st.backend
		run_state: st.run_state
		created_at: st.created_at
		task: st.task
	}
}

fn swarm_budget_view(st SwarmStateFile) SwarmBudgetView {
	cost_status := if st.budget.max_cost_usd > 0 || st.budget_consumed.total_cost > 0 {
		'accounted'
	} else {
		'unavailable'
	}
	return SwarmBudgetView{
		max_total_tokens: st.budget.max_total_tokens
		total_tokens: st.budget_consumed.total_tokens
		max_cost_usd: st.budget.max_cost_usd
		total_cost: st.budget_consumed.total_cost
		max_wall_seconds: st.budget.max_wall_seconds
		cost_status: cost_status
	}
}

fn collect_swarm_handoffs(rd string) []SwarmHandoffView {
	mut out := []SwarmHandoffView{}
	for st in handoff_states() {
		for rec in list_handoffs(rd, st) {
			out << SwarmHandoffView{
				id: rec.handoff_id
				htype: rec.htype
				from_role: rec.from_role
				to_role: rec.to_role
				priority: rec.priority
				artifact: rec.artifact
				commit: rec.commit
				branch: rec.branch
				blocking: rec.blocking
				state: st
				created_at: rec.created_at
			}
		}
	}
	return out
}

fn swarm_tasks_from_handoffs(handoffs []SwarmHandoffView) []SwarmTaskView {
	mut out := []SwarmTaskView{}
	for h in handoffs {
		mut blocked := ''
		if h.blocking && h.state !in ['completed', 'failed'] {
			blocked = 'blocking handoff from ${h.from_role}'
		}
		dep := if h.artifact.len > 0 {
			h.artifact
		} else {
			h.commit
		}
		out << SwarmTaskView{
			id: h.id
			status: h.state
			priority: h.priority
			owner: h.to_role
			from_role: h.from_role
			dependencies: dep
			blocked_reason: blocked
			created_at: h.created_at
		}
	}
	return out
}

fn collect_swarm_artifacts(rd string) []SwarmArtifactView {
	art_dir := os.join_path(rd, 'artifacts')
	if !os.is_dir(art_dir) {
		return []SwarmArtifactView{}
	}
	mut names := os.ls(art_dir) or { return []SwarmArtifactView{} }
	names.sort()
	mut out := []SwarmArtifactView{}
	for e in names {
		p := os.join_path(art_dir, e)
		if os.is_file(p) {
			out << SwarmArtifactView{
				name: e
				path: 'artifacts/${e}'
				size: int(os.file_size(p))
			}
		}
	}
	return out
}

fn swarm_trace_tail(rd string) []string {
	text := os.read_file(os.join_path(rd, 'trace.jsonl')) or { return []string{} }
	lines := text.split_into_lines().filter(it.len > 0)
	if lines.len <= 5 {
		return lines
	}
	return lines[lines.len - 5..].clone()
}

fn swarm_action_from_report(report SwarmReport, run_id string) SwarmActionResponse {
	return SwarmActionResponse{
		ok: report.ok
		message: report.message
		run_id: run_id
		status: report.data['run_state'] or { '' }
	}
}
