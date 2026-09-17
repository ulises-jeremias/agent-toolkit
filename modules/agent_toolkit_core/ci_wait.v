module agent_toolkit_core

import os
import time

// `agent-toolkit ci-wait <owner/repo> <pr> [timeout=300]` — exact port of
// workspace bin/ci-wait: exact-word matching (so "skipping" never matches
// "skip"), exponential backoff 15s doubling capped at 60s.
// Exits: 0=pass, 1=fail (or usage error), 2=timeout.

pub struct CiWaitResult {
pub:
	code   int
	output string
}

// CiWaitOptions configures the top-level `ci-wait` command.
pub struct CiWaitOptions {
pub:
	repo         string // owner/repo
	pr           string // PR number
	timeout_secs int    // timeout budget in seconds (<=0 selects the default)
}

fn ci_is_word_char(c u8) bool {
	return c.is_alnum() || c == `_`
}

// ci_has_word reports whole-word presence (grep -w semantics over
// [A-Za-z0-9_]), case-sensitive.
pub fn ci_has_word(text string, word string) bool {
	if word == '' {
		return false
	}
	b := text.bytes()
	w := word.bytes()
	mut i := 0
	for i + w.len <= b.len {
		mut hit := true
		for j := 0; j < w.len; j++ {
			if b[i + j] != w[j] {
				hit = false
				break
			}
		}
		if hit {
			before_ok := i == 0 || !ci_is_word_char(b[i - 1])
			after_ok := i + w.len >= b.len || !ci_is_word_char(b[i + w.len])
			if before_ok && after_ok {
				return true
			}
		}
		i++
	}
	return false
}

// ci_line_starts_with_word mirrors grep -w ^word (bin/ci-wait `^fail` clause:
// line-anchored with a trailing word boundary, so `failure-probe` is not fail).
fn ci_line_starts_with_word(line string, word string) bool {
	if !line.starts_with(word) {
		return false
	}
	b := line.bytes()
	if word.len >= b.len {
		return true
	}
	return !ci_is_word_char(b[word.len])
}

// ci_classify_checks maps `gh pr checks` text to fail|pending|pass|unknown,
// mirroring the script's check order exactly.
pub fn ci_classify_checks(status string) string {
	for line in status.split_into_lines() {
		if ci_has_word(line, 'fail') || ci_line_starts_with_word(line, 'fail') || line.contains('FAIL') || line.contains(' fail ') {
			return 'fail'
		}
	}
	if ci_has_word(status, 'pending') || ci_has_word(status, 'in_progress') || ci_has_word(status, 'queued') || ci_has_word(status, 'waiting') {
		return 'pending'
	}
	for line in status.split_into_lines() {
		if ci_has_word(line, 'pass') || ci_has_word(line, 'success') || ci_has_word(line, 'SUCCESS') {
			return 'pass'
		}
	}
	return 'unknown'
}

// ci_fetch_checks is the production checks source (live gh).
// NOTE: `gh pr checks` exits non-zero (1 on failing checks, 8 while
// pending) WITH the checks table on stdout, so the output is used
// regardless of exit code. Empty output means no data (auth error,
// unknown PR) and the caller keeps waiting.
fn ci_fetch_checks(repo string, pr string) string {
	res := os.execute('gh pr checks ${pr} --repo ${repo} 2>/dev/null')
	return res.output
}

// run_ci_wait polls until pass/fail/timeout. fetch injects the checks source
// (production: live gh; tests: scripted transcripts).
pub fn run_ci_wait(repo string, pr string, timeout_seconds int, fetch fn (string, string) string) CiWaitResult {
	timeout := if timeout_seconds > 0 { timeout_seconds } else { 300 }
	deadline := time.now().add_seconds(timeout)
	mut sleep_s := 15
	mut progress := '[ci-wait] Watching ${repo}#${pr} (timeout=${timeout}s)'
	for time.now() < deadline {
		status := fetch(repo, pr)
		if status.trim_space() == '' {
			progress += '\n[ci-wait] No checks yet, waiting...'
			time.sleep(sleep_s * time.second)
			sleep_s = if sleep_s < 60 { sleep_s * 2 } else { 60 }
			continue
		}
		state := ci_classify_checks(status)
		if state == 'fail' {
			return CiWaitResult{
				code:   1
				output: progress + '\nFAIL\n' + status
			}
		}
		if state == 'pending' {
			remaining := deadline.unix() - time.now().unix()
			progress += '\n[ci-wait] Still running... ${remaining}s remaining'
			time.sleep(sleep_s * time.second)
			sleep_s = if sleep_s < 60 { sleep_s * 2 } else { 60 }
			continue
		}
		if state == 'pass' {
			return CiWaitResult{
				code:   0
				output: progress + '\nPASS'
			}
		}
		progress += '\n[ci-wait] Unknown state, continuing...'
		time.sleep(sleep_s * time.second)
		sleep_s = if sleep_s < 60 { sleep_s * 2 } else { 60 }
	}
	return CiWaitResult{
		code:   2
		output: progress + '\nTIMEOUT'
	}
}

// ci_wait_cmd is the top-level `ci-wait` entry point: live gh fetch with the
// workspace parity budget (default 1800 s). The numeric outcome travels in
// data['exit_code'] so dispatch can preserve bin/ci-wait codes (0/1/2).
pub fn ci_wait_cmd(repo string, pr string, timeout_secs int) LoopReport {
	if repo == '' || pr == '' {
		return LoopReport{
			ok:      false
			message: 'Usage: agent-toolkit ci-wait <repo> <pr> [--timeout SECS]'
			data:    {
				'subcommand': 'ci-wait'
				'exit_code':  '2'
			}
		}
	}
	budget := if timeout_secs > 0 { timeout_secs } else { 1800 }
	r := run_ci_wait(repo, pr, budget, ci_fetch_checks)
	return LoopReport{
		ok:      r.code == 0
		message: r.output
		data:    {
			'subcommand': 'ci-wait'
			'repo':       repo
			'pr':         pr
			'exit_code':  r.code.str()
		}
	}
}

// ci_wait_help_text renders `ci-wait --help`.
pub fn ci_wait_help_text() string {
	return 'ci-wait — Wait for PR checks (bin/ci-wait parity).

Usage:
    agent-toolkit ci-wait <repo> <pr> [--timeout SECS]
    agent-toolkit ci-wait --repo R --pr N [--timeout SECS]

Exit codes: 0 pass, 1 fail, 2 timeout (or usage error).
Matching is exact-word (grep -w semantics): "skipping" never matches "skip".
Poll backoff starts at 15s and doubles, capped at 60s. Default timeout 1800s.
'
}

// ci_wait_result maps a ci-wait LoopReport onto the CLI CommandResult.
pub fn ci_wait_result(report LoopReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = ''
	}
	return CommandResult{
		command: 'ci-wait'
		ok:      report.ok
		message: report.message
		data:    data
	}
}
