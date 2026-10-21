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
