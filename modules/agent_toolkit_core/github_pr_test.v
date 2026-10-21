module agent_toolkit_core

import os

fn test_draft_pr_title_truncates_long_tasks() {
	assert draft_pr_title('Fix the thing', 'run-1') == 'Fix the thing'
	assert draft_pr_title('', 'run-1') == 'Swarm run run-1'
	long := 'x'.repeat(200)
	title := draft_pr_title(long, 'run-1')
	assert title.len <= draft_pr_title_max
	assert title.ends_with('…')
}

fn test_draft_pr_body_links_issue() {
	body := draft_pr_body('run-9', 'owner/repo#42')
	assert body.contains('run-9')
	assert body.contains('Issue: owner/repo#42')
	assert !draft_pr_body('run-9', '').contains('Issue:')
}

fn test_first_url_line_extracts_pr_url() {
	assert first_url_line('noise\nhttps://github.com/o/r/pull/7\n') == 'https://github.com/o/r/pull/7'
	assert first_url_line('no url here') == ''
}

fn test_parse_swarm_pr_status_summarizes_checks() {
	sample := '{"url":"https://github.com/o/r/pull/7","state":"OPEN","isDraft":true,"mergeable":"MERGEABLE","reviewDecision":"APPROVED","changedFiles":4,"additions":120,"deletions":30,"statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"},{"conclusion":"FAILURE","status":"COMPLETED"},{"conclusion":"","status":"IN_PROGRESS"},{"state":"PENDING"}]}'
	st := parse_swarm_pr_status('run-1', sample) or {
		assert false, err.msg()
		return
	}
	assert st.ok
	assert st.is_draft
	assert st.state == 'OPEN'
	assert st.checks_pass == 1
	assert st.checks_fail == 1
	assert st.checks_pending == 2
	assert st.mergeable == 'MERGEABLE'
	assert st.review_decision == 'APPROVED'
	assert st.changed_files == 4
	assert st.additions == 120
	assert st.deletions == 30
	if _ := parse_swarm_pr_status('run-1', 'not json') {
		assert false, 'invalid JSON must error'
	}
}

fn test_pr_status_without_recorded_pr_is_honest() {
	ws := os.join_path(os.temp_dir(), 'atk-pr-status-none-${os.getpid()}')
	rd := swarm_run_dir(ws, 'run-nopr')
	os.mkdir_all(rd) or { panic(err) }
	defer {
		os.rmdir_all(ws) or {}
	}
	write_swarm_state(rd, SwarmStateFile{
		run_id: 'run-nopr'
		task: 'anything'
	}) or {
		assert false, err.msg()
		return
	}
	resp := swarm_pr_status_typed(ws, 'run-nopr')
	assert !resp.ok
	assert resp.detail.contains('No pull request recorded')
	assert swarm_pr_status_typed(ws, 'no-such-run').detail.contains('Run not found')
	ready := mark_swarm_pr_ready_typed(ws, 'run-nopr')
	assert !ready.ok
	assert ready.detail.contains('No pull request recorded')
	assert mark_swarm_pr_ready_typed(ws, 'no-such-run').detail.contains('Run not found')
}

fn test_create_draft_pr_missing_run_is_honest_error() {
	ws := os.join_path(os.temp_dir(), 'atk-draft-pr-missing-${os.getpid()}')
	os.mkdir_all(ws) or { panic(err) }
	defer {
		os.rmdir_all(ws) or {}
	}
	resp := create_swarm_draft_pr_typed(ws, 'no-such-run')
	assert !resp.ok
	assert resp.detail.contains('Run not found')
}

fn test_create_draft_pr_returns_recorded_url_without_gh() {
	ws := os.join_path(os.temp_dir(), 'atk-draft-pr-recorded-${os.getpid()}')
	rd := swarm_run_dir(ws, 'run-recorded')
	os.mkdir_all(rd) or { panic(err) }
	defer {
		os.rmdir_all(ws) or {}
	}
	write_swarm_state(rd, SwarmStateFile{
		run_id: 'run-recorded'
		task: 'anything'
		pr_url: 'https://github.com/o/r/pull/3'
	}) or {
		assert false, err.msg()
		return
	}
	resp := create_swarm_draft_pr_typed(ws, 'run-recorded')
	assert resp.ok
	assert !resp.created
	assert resp.pr_url == 'https://github.com/o/r/pull/3'
	// The URL survives a catalog read (run details surface it).
	info := swarm_run_info(read_swarm_state(rd) or {
		assert false, 'state unreadable'
		return
	})
	assert info.pr_url == 'https://github.com/o/r/pull/3'
}
