module agent_toolkit_core

fn test_classify_gh_readonly() {
	assert classify_gh_argv(['pr', 'view', '1']) == ''
	assert classify_gh_argv(['pr', 'list']) == ''
	assert classify_gh_argv(['issue', 'view', '2']) == ''
	assert classify_gh_argv(['api', 'repos/o/r']) == ''
	// release/gist/repo/secret/variable/workflow read-only subs
	assert classify_gh_argv(['release', 'list', '--repo', 'o/r']) == ''
	assert classify_gh_argv(['release', 'view', 'v1']) == ''
	assert classify_gh_argv(['repo', 'view', 'o/r']) == ''
	assert classify_gh_argv(['secret', 'list']) == ''
	assert classify_gh_argv(['variable', 'get', 'NAME']) == ''
	assert classify_gh_argv(['workflow', 'view', 'ci']) == ''
	assert classify_gh_argv(['gist', 'view', 'abc']) == ''
}

fn test_classify_gh_mutating() {
	assert classify_gh_argv(['pr', 'merge', '1']) == 'merge'
	assert classify_gh_argv(['pr', 'close', '1']) == 'close'
	assert classify_gh_argv(['pr', 'comment', '1']) == 'comment'
	assert classify_gh_argv(['pr', 'create']) == 'push'
	assert classify_gh_argv(['pr', 'review', '1', '--approve']) == 'approve'
	assert classify_gh_argv(['pr', 'unknown-sub']) == 'push'
	assert classify_gh_argv(['issue', 'close', '9']) == 'close'
	assert classify_gh_argv(['issue', 'edit', '9', '--state', 'closed']) == 'close'
	assert classify_gh_argv(['api', '-X', 'POST', '/repos/o/r/pulls/1/merge']) == 'merge'
	assert classify_gh_argv(['release', 'create', 'v1']) == 'push'
	assert classify_gh_argv(['release', 'delete', 'v1']) == 'push'
	assert classify_gh_argv(['release']) == 'push'
	assert classify_gh_argv(['repo', 'create', 'x']) == 'push'
	assert classify_gh_argv(['secret', 'set', 'NAME']) == 'push'
	assert classify_gh_argv(['workflow', 'run', 'ci']) == 'push'
}

fn test_classify_api_attached_field_and_pulls_patch() {
	// attached -F form implies POST (fail-closed): a field-bearing api call
	// is never read-only
	assert classify_gh_argv(['api', '-Ftitle=x', 'repos/o/r/pulls']) == 'push'
	assert classify_gh_argv(['api', '-fbody=y', 'repos/o/r/issues/3']) == 'push'
	// PATCH on a numbered pulls path closes (Python gh_gate parity)
	assert classify_gh_argv(['api', 'repos/o/r/pulls/5', '-X', 'PATCH']) == 'close'
	assert classify_gh_argv(['api', '--method=PATCH', 'repos/o/r/pulls/12']) == 'close'
	// PATCH on issues stays push (could be close or assign)
	assert classify_gh_argv(['api', '-X', 'PATCH', 'repos/o/r/issues/3']) == 'push'
}

fn test_loop_gate_l2_forbids_writes() {
	// Python tier_forbids parity: L2 allows comment/label/assign only
	assert loop_gate_allows('L2', ['push'], [], 'push') == false
	assert loop_gate_allows('L2', ['approve'], [], 'approve') == false
	assert loop_gate_allows('L2', ['delete'], [], 'delete') == false
	assert loop_gate_allows('l2', ['push'], [], 'push') == false
	assert loop_gate_allows('L2', ['label'], [], 'label') == true
	assert loop_gate_allows('L2', ['assign'], [], 'assign') == true
}

fn test_loop_gate_tier() {
	assert loop_gate_allows('L1', ['comment'], [], '') == true
	assert loop_gate_allows('L1', ['comment'], [], 'comment') == false
	assert loop_gate_allows('L2', ['comment'], [], 'comment') == true
	assert loop_gate_allows('L2', ['comment'], [], 'merge') == false
	assert loop_gate_allows('L3', ['merge'], [], 'merge') == true
	assert loop_gate_allows('L2', ['comment'], ['comment'], 'comment') == false
	assert loop_gate_allows('L2', [], [], 'comment') == false
}
