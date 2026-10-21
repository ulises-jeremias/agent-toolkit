module agent_toolkit_core

import os
import time
import x.json2

// Draft PR creation for finished swarm runs (Slice 9, Pack E). A run's
// integrator branch (`agent-toolkit-swarm/<run-id>/integrator`) already
// holds the merged role work; this turns it into a reviewable draft PR
// through the user's own authenticated `gh` CLI (argv only, no shell).
// The URL is persisted on the run state so the journey issue → swarm →
// PR stays traceable, and repeat calls return the existing PR instead
// of failing or duplicating it. Every failure is an honest ok=false.

pub struct SwarmDraftPrResponse {
pub:
	ok      bool
	run_id  string
	branch  string
	pr_url  string
	created bool
	detail  string
}

const draft_pr_title_max = 80

// draft_pr_title derives a PR title from the run task.
fn draft_pr_title(task string, run_id string) string {
	trimmed := task.trim_space()
	if trimmed.len == 0 {
		return 'Swarm run ${run_id}'
	}
	if trimmed.len <= draft_pr_title_max {
		return trimmed
	}
	// '…' is 3 bytes; keep the byte length within the cap.
	return trimmed[..draft_pr_title_max - 3].trim_space() + '…'
}

// draft_pr_body links the PR back to the run and its issue, if any.
fn draft_pr_body(run_id string, issue_ref string) string {
	mut lines := [
		'Created from Agent Toolkit swarm run `${run_id}`.',
		'',
		'This draft PR carries the run integrator branch for review; it is not merged automatically.',
	]
	if issue_ref.len > 0 {
		lines << ''
		lines << 'Issue: ${issue_ref}'
	}
	return lines.join('\n')
}

// first_url_line extracts the PR URL gh prints on stdout.
fn first_url_line(text string) string {
	for line in text.split('\n') {
		trimmed := line.trim_space()
		if trimmed.starts_with('https://') || trimmed.starts_with('http://') {
			return trimmed
		}
	}
	return ''
}

// create_swarm_draft_pr_typed pushes the run's integrator branch and
// opens (or finds) its draft PR, recording the URL on the run state.
pub fn create_swarm_draft_pr_typed(ws string, run_id string) SwarmDraftPrResponse {
	branch := swarm_branch_for_role(run_id, 'integrator')
	rd := swarm_run_dir(ws, run_id)
	mut st := read_swarm_state(rd) or {
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'Run not found: ${run_id}'
		}
	}
	if st.pr_url.len > 0 {
		return SwarmDraftPrResponse{
			ok: true
			run_id: run_id
			branch: branch
			pr_url: st.pr_url
			detail: 'Draft PR already recorded for this run.'
		}
	}
	ps := new_process_service()
	verify := ps.run(
		argv: ['git', 'rev-parse', '--verify', branch]
		cwd: ws
		timeout: 5 * time.second
	) or {
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'Integrator branch not found: ${branch}'
		}
	}
	if verify.exit_code != 0 {
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'Integrator branch not found: ${branch}'
		}
	}
	if os.find_abs_path_of_executable('gh') or { '' } == '' {
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'GitHub CLI (gh) not found on PATH; install it and authenticate to create the draft PR.'
		}
	}
	// An open PR for this branch may already exist (created outside
	// Desktop or by an earlier call whose state write failed).
	existing := ps.run(
		argv: ['gh', 'pr', 'view', branch, '--json', 'url', '--jq', '.url']
		cwd: ws
		timeout: 15 * time.second
	) or { RunResult{
		exit_code: -1
	} }
	if existing.exit_code == 0 {
		url := first_url_line(existing.stdout)
		if url.len > 0 {
			record_swarm_pr_url(mut st, rd, url)
			return SwarmDraftPrResponse{
				ok: true
				run_id: run_id
				branch: branch
				pr_url: url
				detail: 'Existing draft PR recorded for this run.'
			}
		}
	}
	push := ps.run(
		argv: ['git', 'push', 'origin', 'refs/heads/${branch}:refs/heads/${branch}']
		cwd: ws
		timeout: 60 * time.second
	) or {
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'git push failed: ${err.msg()}'
		}
	}
	if push.exit_code != 0 {
		msg := push.stderr.trim_space()
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'git push failed: ${if msg.len > 0 { msg } else { 'exit ${push.exit_code}' }}'
		}
	}
	mut argv := ['gh', 'pr', 'create', '--draft', '--head', branch, '--title',
		draft_pr_title(st.task, run_id), '--body', draft_pr_body(run_id, st.issue_ref)]
	if st.base_ref.len > 0 && st.base_ref != 'HEAD' {
		argv << ['--base', st.base_ref]
	}
	created := ps.run(
		argv: argv
		cwd: ws
		timeout: 30 * time.second
	) or {
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'gh pr create failed: ${err.msg()}'
		}
	}
	if created.exit_code != 0 {
		msg := created.stderr.trim_space()
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'gh pr create failed: ${if msg.len > 0 { msg } else { 'exit ${created.exit_code}' }}'
		}
	}
	url := first_url_line(created.stdout)
	if url.len == 0 {
		return SwarmDraftPrResponse{
			ok: false
			run_id: run_id
			branch: branch
			detail: 'gh pr create did not report a PR URL.'
		}
	}
	record_swarm_pr_url(mut st, rd, url)
	return SwarmDraftPrResponse{
		ok: true
		run_id: run_id
		branch: branch
		pr_url: url
		created: true
		detail: 'Draft PR created.'
	}
}

pub struct SwarmPrStatusResponse {
pub:
	ok             bool
	run_id         string
	pr_url         string
	state          string
	is_draft       bool
	checks_pass     int
	checks_fail     int
	checks_pending  int
	mergeable       string
	review_decision string
	changed_files   int
	additions       int
	deletions       int
	detail          string
}

pub struct SwarmPrReadyResponse {
pub:
	ok     bool
	run_id string
	pr_url string
	detail string
}

pub struct GhPrCheck {
pub:
	conclusion string
	status     string
	state      string
}

pub struct GhPrView {
pub:
	url                 string
	state               string
	is_draft            bool @[json: 'isDraft']
	mergeable           string
	review_decision     string @[json: 'reviewDecision']
	changed_files       int @[json: 'changedFiles']
	additions           int
	deletions           int
	status_check_rollup []GhPrCheck @[json: 'statusCheckRollup']
}

// parse_swarm_pr_status decodes `gh pr view --json ...` output and
// summarizes the check rollup into pass/fail/pending counts.
fn parse_swarm_pr_status(run_id string, text string) !SwarmPrStatusResponse {
	view := json2.decode[GhPrView](text) or { return error('could not parse gh pr view output') }
	mut pass := 0
	mut fail := 0
	mut pending := 0
	for check in view.status_check_rollup {
		verdict := if check.conclusion.len > 0 { check.conclusion } else { check.state }
		match verdict.to_upper() {
			'SUCCESS' { pass++ }
			'FAILURE', 'ERROR', 'TIMED_OUT', 'CANCELLED', 'ACTION_REQUIRED' { fail++ }
			else { pending++ }
		}
	}
	return SwarmPrStatusResponse{
		ok: true
		run_id: run_id
		pr_url: view.url
		state: view.state
		is_draft: view.is_draft
		checks_pass: pass
		checks_fail: fail
		checks_pending: pending
		mergeable: view.mergeable
		review_decision: view.review_decision
		changed_files: view.changed_files
		additions: view.additions
		deletions: view.deletions
		detail: 'Live PR status from GitHub.'
	}
}

// swarm_pr_status_typed reports the live state of the run's recorded PR
// (Slice 10, Pack E: review outcome inside the Desktop). Honest failures:
// no PR recorded yet, no gh, or GitHub unreachable — never fake status.
pub fn swarm_pr_status_typed(ws string, run_id string) SwarmPrStatusResponse {
	fail := fn [run_id] (detail string) SwarmPrStatusResponse {
		return SwarmPrStatusResponse{
			ok: false
			run_id: run_id
			detail: detail
		}
	}
	rd := swarm_run_dir(ws, run_id)
	st := read_swarm_state(rd) or { return fail('Run not found: ${run_id}') }
	if st.pr_url.len == 0 {
		return fail('No pull request recorded for this run yet.')
	}
	if os.find_abs_path_of_executable('gh') or { '' } == '' {
		return fail('GitHub CLI (gh) not found on PATH; PR status unavailable.')
	}
	res := new_process_service().run(
		argv: ['gh', 'pr', 'view', st.pr_url, '--json',
			'url,state,isDraft,mergeable,reviewDecision,changedFiles,additions,deletions,statusCheckRollup']
		cwd: ws
		timeout: 15 * time.second
	) or { return fail('GitHub CLI (gh) is not available: ${err.msg()}') }
	if res.exit_code != 0 {
		return fail('gh pr view failed: ${res.stderr.trim_space()}')
	}
	parsed := parse_swarm_pr_status(run_id, res.stdout) or { return fail(err.msg()) }
	return SwarmPrStatusResponse{
		...parsed
		pr_url: if parsed.pr_url.len > 0 { parsed.pr_url } else { st.pr_url }
	}
}

// mark_swarm_pr_ready_typed promotes the run's draft PR to ready for
// review via `gh pr ready` (Slice 11). Explicit user action only; honest
// failures, never a silent merge or auto-approval.
pub fn mark_swarm_pr_ready_typed(ws string, run_id string) SwarmPrReadyResponse {
	fail := fn [run_id] (detail string) SwarmPrReadyResponse {
		return SwarmPrReadyResponse{
			ok: false
			run_id: run_id
			detail: detail
		}
	}
	rd := swarm_run_dir(ws, run_id)
	st := read_swarm_state(rd) or { return fail('Run not found: ${run_id}') }
	if st.pr_url.len == 0 {
		return fail('No pull request recorded for this run yet.')
	}
	if os.find_abs_path_of_executable('gh') or { '' } == '' {
		return fail('GitHub CLI (gh) not found on PATH; cannot mark the PR ready.')
	}
	res := new_process_service().run(
		argv: ['gh', 'pr', 'ready', st.pr_url]
		cwd: ws
		timeout: 30 * time.second
	) or { return fail('GitHub CLI (gh) is not available: ${err.msg()}') }
	if res.exit_code != 0 {
		msg := res.stderr.trim_space()
		return fail('gh pr ready failed: ${if msg.len > 0 { msg } else { 'exit ${res.exit_code}' }}')
	}
	append_swarm_trace(rd, 'pr_marked_ready', st.pr_url)
	return SwarmPrReadyResponse{
		ok: true
		run_id: run_id
		pr_url: st.pr_url
		detail: 'Pull request marked ready for review.'
	}
}

fn record_swarm_pr_url(mut st SwarmStateFile, rd string, url string) {
	st = SwarmStateFile{
		...st
		pr_url: url
	}
	write_swarm_state(rd, st) or { return }
	append_swarm_trace(rd, 'draft_pr_created', url)
}
