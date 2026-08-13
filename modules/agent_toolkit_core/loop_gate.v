module agent_toolkit_core

// classify_gh_argv maps `gh` argv to a mutating action or '' if read-only.
// Unknown mutating forms fail closed as `push` (Python gh_gate.py parity).
pub fn classify_gh_argv(argv []string) string {
	mut args := []string{}
	for a in argv {
		if a != '--' {
			args << a
		}
	}
	if args.len == 0 {
		return ''
	}
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['-R', '--repo'] && i + 1 < args.len {
			i += 2
			continue
		}
		if a.starts_with('--repo=') {
			i++
			continue
		}
		break
	}
	if i >= args.len {
		return ''
	}
	rest := args[i..].clone()
	if rest[0] == 'pr' && rest.len >= 2 {
		return classify_pr(rest)
	}
	if rest[0] == 'issue' && rest.len >= 2 {
		return classify_issue(rest)
	}
	if rest[0] == 'api' {
		return classify_api(rest)
	}
	if rest[0] in ['auth', 'api', 'status', 'browse'] {
		return ''
	}
	// git-like writes
	if rest[0] in ['repo', 'release'] {
		return 'push'
	}
	return ''
}

fn classify_pr(rest []string) string {
	sub := rest[1]
	return match sub {
		'merge' {
			'merge'
		}
		'close' {
			'close'
		}
		'comment' {
			'comment'
		}
		'create' {
			'push'
		}
		'review' {
			if '--approve' in rest {
				'approve'
			} else {
				'comment'
			}
		}
		'edit' {
			if '--add-label' in rest || '--remove-label' in rest {
				'label'
			} else if '--add-assignee' in rest || '--remove-assignee' in rest {
				'assign'
			} else {
				'push'
			}
		}
		'list', 'view', 'status', 'diff', 'checks' {
			''
		}
		'delete' {
			'delete'
		}
		'ready', 'reopen', 'lock', 'unlock' {
			'push'
		}
		else {
			'push'
		}
	}
}

fn classify_issue(rest []string) string {
	sub := rest[1]
	return match sub {
		'comment' {
			'comment'
		}
		'close' {
			'close'
		}
		'create' {
			if '--label' in rest || '-l' in rest {
				'label'
			} else {
				'push'
			}
		}
		'edit' {
			if '--add-label' in rest || '--remove-label' in rest {
				'label'
			} else if '--add-assignee' in rest || '--remove-assignee' in rest {
				'assign'
			} else if issue_edit_is_close(rest) {
				'close'
			} else {
				'push'
			}
		}
		'list', 'view', 'status' {
			''
		}
		else {
			'push'
		}
	}
}

fn issue_edit_is_close(rest []string) bool {
	for i, a in rest {
		if a == '--state' && i + 1 < rest.len && rest[i + 1] == 'closed' {
			return true
		}
		if a.starts_with('--state=') && a.all_after('=') == 'closed' {
			return true
		}
	}
	return false
}

fn classify_api(rest []string) string {
	mut method := 'GET'
	mut method_explicit := false
	mut path := ''
	mut has_field := false
	mut skip_next := false
	for a in rest[1..].clone() {
		if skip_next {
			skip_next = false
			continue
		}
		if a in ['-X', '--method'] {
			skip_next = true
			continue
		}
		if a.starts_with('--method=') {
			method = a.all_after('=').to_upper()
			method_explicit = true
			continue
		}
		if a.starts_with('-') {
			if a in ['-F', '-f', '--field', '--raw-field'] {
				has_field = true
				skip_next = true
			} else if a in ['-H', '--header', '--input', '-i'] {
				skip_next = true
			}
			continue
		}
		if path.len == 0 {
			path = a
		}
	}
	for i, a in rest {
		if a in ['-X', '--method'] && i + 1 < rest.len {
			method = rest[i + 1].to_upper()
			method_explicit = true
		}
	}
	if has_field && !method_explicit {
		method = 'POST'
	}
	if method in ['POST', 'PUT', 'PATCH', 'DELETE'] {
		if path.contains('/merge') {
			return 'merge'
		}
		if path.contains('/comments') {
			return 'comment'
		}
		if path.contains('assignees') {
			return 'assign'
		}
		if path.contains('/labels') {
			return 'label'
		}
		if method == 'DELETE' {
			return 'delete'
		}
		return 'push'
	}
	return ''
}

// loop_gate_allows reports whether a classified action is permitted.
pub fn loop_gate_allows(tier string, allowlist []string, deny []string, action string) bool {
	if action.len == 0 {
		return true
	}
	if action in deny {
		return false
	}
	t := tier.to_upper()
	if t == 'L1' {
		return false
	}
	if action in ['merge', 'close'] && t != 'L3' {
		return false
	}
	if allowlist.len == 0 {
		return false
	}
	return action in allowlist
}
