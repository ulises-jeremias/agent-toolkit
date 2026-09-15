module main

import os

// Release UAT: run-bound terminal cwd must survive hostile paths. Proof is
// a real POSIX shell roundtrip, not a string-shape assertion.

fn sh_roundtrip(quoted string) string {
	r := os.execute('printf %s ' + quoted)
	assert r.exit_code == 0, 'quoted path must parse: ${quoted}'
	return r.output
}

fn test_term_shell_quote_plain_path() {
	assert term_shell_quote('/runs/abc/worktree') == "'/runs/abc/worktree'"
	assert sh_roundtrip(term_shell_quote('/runs/abc/worktree')) == '/runs/abc/worktree'
}

fn test_term_shell_quote_hostile_path_roundtrips() {
	path := '/weird \$HOME`s "quoted`x'
	assert sh_roundtrip(term_shell_quote(path)) == path, 'quote/dollar/backtick survive: ${term_shell_quote(path)}'
}

fn test_term_shell_quote_single_quote_escapes() {
	path := "/o'clock"
	assert sh_roundtrip(term_shell_quote(path)) == path, 'embedded quote survives: ${term_shell_quote(path)}'
}
