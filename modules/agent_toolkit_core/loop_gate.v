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
	// Other top-level mutating commands (Python gh_gate.py parity):
	// release/gist/repo/secret/variable/workflow default to `push`,
	// but list/view/status/get are read-only.
	if rest[0] in ['release', 'gist', 'repo', 'secret', 'variable', 'workflow'] {
		if rest.len >= 2 && rest[1] in ['list', 'view', 'status', 'get'] {
			return ''
		}
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
			} else if (a.starts_with('-F') || a.starts_with('-f')) && a.contains('=') {
				// attached field form (-Ffoo=, -ffoo=): implies a body
				// without consuming the next arg (Python gh_gate parity)
				has_field = true
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
		if method == 'PATCH' && gate_path_numbered(path, '/pulls/') {
			// PATCH on /pulls/<n> closes (Python gh_gate parity; issues
			// PATCH stays push — could be close or assign)
			return 'close'
		}
		if method == 'DELETE' {
			return 'delete'
		}
		return 'push'
	}
	return ''
}

// gate_path_numbered reports whether path ends with <needle><digits>
// (e.g. /pulls/12). Used for the pulls-PATCH→close rule.
fn gate_path_numbered(path string, needle string) bool {
	if pos := path.last_index(needle) {
		tail := path[pos + needle.len..]
		if tail.len == 0 {
			return false
		}
		for ch in tail {
			if ch < `0` || ch > `9` {
				return false
			}
		}
		return true
	}
	return false
}

// gate_is_digits reports whether s is a non-empty all-digit string.
fn gate_is_digits(s string) bool {
	if s.len == 0 {
		return false
	}
	for ch in s {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return true
}

// gate_target_from_argv extracts the (repo, number) a gh call targets for
// receipt binding: -R/--repo (both forms), the first all-digit positional of
// `pr`/`issue` calls, and repos/{owner}/{name} api paths with a trailing
// number. '' when untargeted (Python require_receipt parity: unbound fields
// match any target).
pub fn gate_target_from_argv(argv []string) (string, string) {
	mut repo := ''
	mut rest := []string{}
	mut i := 0
	for i < argv.len {
		a := argv[i]
		if a == '--' {
			i++
			continue
		}
		if (a == '-R' || a == '--repo') && i + 1 < argv.len {
			repo = argv[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--repo=') {
			repo = a.all_after('=')
			i++
			continue
		}
		rest << a
		i++
	}
	mut number := ''
	if rest.len >= 3 && rest[0] in ['pr', 'issue'] && gate_is_digits(rest[2]) {
		// the target is always the immediate positional (Python parity —
		// never a flag value further down argv)
		number = rest[2]
	}
	if rest.len >= 2 && rest[0] == 'api' {
		for a in rest[1..] {
			if a.starts_with('-') {
				continue
			}
			segs := a.split('/')
			for j, s in segs {
				if s == 'repos' && j + 2 < segs.len && segs[j + 1] != '' && segs[j + 2] != '' {
					repo = segs[j + 1] + '/' + segs[j + 2]
					last := segs[segs.len - 1]
					if gate_is_digits(last) {
						number = last
					}
					break
				}
			}
			if repo != '' {
				break
			}
		}
	}
	return repo, number
}

// loop_gate_allows reports whether a classified action is permitted.
// Mirrors Python gh_gate.evaluate_action: tier forbids first (L1 everything;
// L2 all writes — allow comment/label/assign only), then deny, then allowlist.
pub fn loop_gate_allows(tier string, allowlist []string, deny []string, action string) bool {
	if action.len == 0 {
		return true
	}
	t := tier.to_upper()
	if t.starts_with('L1') || t == '1' {
		return false
	}
	if (t.starts_with('L2') || t == '2') && action in ['merge', 'close', 'approve', 'push', 'commit', 'force-push', 'delete'] {
		return false
	}
	if action in deny {
		return false
	}
	if allowlist.len == 0 {
		return false
	}
	return action in allowlist
}
