module agent_toolkit_core

fn test_ci_has_word() {
	assert ci_has_word('Tests pass 10s', 'pass')
	assert ci_has_word('job skipping 5s', 'skipping')
	// the trap: "skipping" must NOT match "skip"
	assert !ci_has_word('job skipping 5s', 'skip')
	assert !ci_has_word('FAIL', 'fail')
	assert ci_has_word('x fail y', 'fail')
	assert !ci_has_word('', 'pass')
	assert !ci_has_word('pass', '')
	assert ci_has_word('in_progress', 'in_progress')
	assert !ci_has_word('in_progressx', 'in_progress')
}

fn test_ci_classify_checks() {
	assert ci_classify_checks('Tests\tpass\t10s\nLint\tpass\t5s') == 'pass'
	assert ci_classify_checks('Tests\tfail\t10s') == 'fail'
	assert ci_classify_checks('Tests\tFAIL\t10s') == 'fail'
	assert ci_classify_checks('Tests\tpending\t0s') == 'pending'
	assert ci_classify_checks('Build\tin_progress\t0s') == 'pending'
	assert ci_classify_checks('A\tqueued\t0s') == 'pending'
	assert ci_classify_checks('A\twaiting\t0s') == 'pending'
	// skipping is not pending and not a pass/fail signal
	assert ci_classify_checks('Matrix\tsskipping\t0s') == 'unknown'
	assert ci_classify_checks('A\tsuccess\t1s') == 'pass'
	// fail wins over pass on the same screen
	assert ci_classify_checks('A\tpass\t1s\nB\tfail\t2s') == 'fail'
	// per-line ^fail anchor (bin/ci-wait `^fail` clause)
	assert ci_classify_checks('fail fast\nTests\tpass\t1s') == 'fail'
	// `failure-probe` check name is not fail (trailing word boundary)
	assert ci_classify_checks('failure-probe\tpass\t1s') == 'pass'
	assert ci_classify_checks('') == 'unknown'
}

fn test_ci_wait_pass_and_fail() {
	pass_fetch := fn (repo string, pr string) string {
		_ = repo
		_ = pr
		return 'Tests\tpass\t10s\n'
	}
	r := run_ci_wait('o/r', '1', 60, pass_fetch)
	assert r.code == 0
	assert r.output.contains('PASS')
	fail_fetch := fn (repo string, pr string) string {
		_ = repo
		_ = pr
		return 'Tests\tfail\t10s\n'
	}
	r2 := run_ci_wait('o/r', '1', 60, fail_fetch)
	assert r2.code == 1
	assert r2.output.contains('FAIL')
}

fn test_ci_wait_pending_then_pass() {
	mut calls := 0
	seq := fn [mut calls] (repo string, pr string) string {
		_ = repo
		_ = pr
		calls++
		if calls == 1 {
			return 'Tests\tpending\t0s\n'
		}
		return 'Tests\tpass\t10s\n'
	}
	r := run_ci_wait('o/r', '1', 120, seq)
	assert r.code == 0
	assert r.output.contains('Still running')
}

fn test_ci_wait_cmd_usage() {
	r := ci_wait_cmd('', '', 0)
	assert !r.ok
	assert r.message.contains('Usage')
	assert r.data['exit_code'] == '2'
	r2 := ci_wait_cmd('o/r', '', 0)
	assert !r2.ok
	assert r2.data['exit_code'] == '2'
}

fn test_ci_wait_timeout() {
	never := fn (repo string, pr string) string {
		_ = repo
		_ = pr
		return 'Tests\tpending\t0s\n'
	}
	r := run_ci_wait('o/r', '1', 1, never)
	assert r.code == 2
	assert r.output.contains('TIMEOUT')
}
