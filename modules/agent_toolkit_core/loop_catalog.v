module agent_toolkit_core

import os

pub struct LoopInfo {
pub:
	name     string
	tier     string
	cadence  string
	goal     string
	runs     int
	last     string
	status   string
}

pub struct LoopListResponse {
pub:
	ok    bool
	loops []LoopInfo
}

pub struct LoopStatusResponse {
pub:
	ok     bool
	info   LoopInfo
	budget LoopBudgetView
}

pub struct LoopBudgetView {
pub:
	max_tokens       int
	max_runs_per_day int
	max_wall_seconds int
	cost_status      string
}

pub struct LoopAuditResponse {
pub:
	ok        bool
	name      string
	completed int
	failed    int
	tokens    int
	rate      string
}

pub struct LoopHistoryEntry {
pub:
	id     string
	status string
}

pub struct LoopHistoryResponse {
pub:
	ok      bool
	name    string
	last_id string
	last    string
	status  string
	runs    []LoopHistoryEntry
}

pub struct LoopCostResponse {
pub:
	ok          bool
	name        string
	cost_status string
	detail      string
}

pub fn list_loops_typed(workspace string) LoopListResponse {
	ws := find_loop_workspace(workspace)
	mut loops := []LoopInfo{}
	for d in list_loop_dirs(ws) {
		loops << loop_info_from_dir(d)
	}
	return LoopListResponse{
		ok: true
		loops: loops
	}
}

pub fn get_loop_status_typed(workspace string, name string) !LoopStatusResponse {
	d := require_loop_dir(workspace, name)!
	meta := parse_loop_meta(d)
	info := loop_info_from_dir(d)
	return LoopStatusResponse{
		ok: true
		info: info
		budget: LoopBudgetView{
			max_tokens: meta.max_tokens
			max_runs_per_day: meta.max_runs_per_day
			max_wall_seconds: meta.max_wall_seconds
			cost_status: 'unavailable'
		}
	}
}

pub fn get_loop_audit_typed(workspace string, name string) !LoopAuditResponse {
	d := require_loop_dir(workspace, name)!
	completed, failed, tokens := audit_loop_dir(d)
	total := completed + failed
	rate := if total > 0 { '${completed * 100 / total}%' } else { 'unavailable' }
	return LoopAuditResponse{
		ok: true
		name: name
		completed: completed
		failed: failed
		tokens: tokens
		rate: rate
	}
}

pub fn get_loop_history_typed(workspace string, name string) !LoopHistoryResponse {
	d := require_loop_dir(workspace, name)!
	last_run, last_status, last_id, _, _ := read_state_md(d)
	mut runs := []LoopHistoryEntry{}
	rd := os.join_path(d, 'runs')
	if os.is_dir(rd) {
		mut names := os.ls(rd) or { []string{} }
		names.sort()
		for n in names {
			p := os.join_path(rd, n)
			if os.is_dir(p) {
				status := loop_run_status(p)
				runs << LoopHistoryEntry{
					id: n
					status: status
				}
			}
		}
	}
	return LoopHistoryResponse{
		ok: true
		name: name
		last_id: last_id
		last: last_run
		status: last_status
		runs: runs
	}
}

pub fn get_loop_cost_typed(workspace string, name string) !LoopCostResponse {
	require_loop_dir(workspace, name)!
	return LoopCostResponse{
		ok: true
		name: name
		cost_status: 'unavailable'
		detail: 'loop cost accounting is not recorded; token totals live on audit when traces exist'
	}
}

fn require_loop_dir(workspace string, name string) !string {
	if name.len == 0 || !is_valid_loop_name_core(name) {
		return error('invalid loop name')
	}
	ws := find_loop_workspace(workspace)
	return resolve_loop_dir(ws, name) or { error('loop not found') }
}

fn is_valid_loop_name_core(name string) bool {
	if name.len == 0 || name.len > 64 {
		return false
	}
	if name.contains('..') || name.contains('/') || name.contains('\\') {
		return false
	}
	return true
}

fn loop_info_from_dir(d string) LoopInfo {
	meta := parse_loop_meta(d)
	_, last_status, _, _, _ := read_state_md(d)
	return LoopInfo{
		name: os.file_name(d)
		tier: meta.tier
		cadence: meta.cadence
		goal: meta.goal
		runs: count_runs(d)
		last: last_status
		status: last_status
	}
}

fn loop_run_status(run_dir string) string {
	trace := os.join_path(run_dir, 'trace.jsonl')
	if !os.is_file(trace) {
		return 'unknown'
	}
	text := os.read_file(trace) or { return 'unknown' }
	mut status := 'unknown'
	for line in text.split_into_lines() {
		if line.contains('"kind":"run_end"') {
			if line.contains('"status":"completed"') {
				status = 'completed'
			} else if line.contains('"status":"failed"') {
				status = 'failed'
			}
		}
	}
	return status
}
