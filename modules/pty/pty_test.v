module pty

import time

// Hermetic PTY lifecycle tests: only /bin/true and /bin/sleep (absolute
// paths, no PATH dependence), no network, no fixed ports, no temp files
// ($TMPDIR honored vacuously — nothing is written to disk). Every spawned
// session is reaped via cleanup with defer.

// waitpid mirror for the no-zombie proofs below. pty.v declares the same
// prototype for the reap path; the duplicate identical prototype is legal C.
fn C.waitpid(pid int, status &int, options int) int

// wnohang_test is WNOHANG (Linux value 1): never block in waitpid.
const wnohang_test = 1

fn poll_exit(mut s Session, tries int) bool {
	for _ in 0 .. tries {
		if !s.alive() {
			return true
		}
		time.sleep(20 * time.millisecond)
	}
	return false
}

fn test_true_exit_detected_and_reaped() {
	mut s := spawn('test', '/bin/true', [], 80, 24) or { panic(err.msg()) }
	defer {
		s.kill()
	}
	pid := s.pid
	assert pid > 0
	assert poll_exit(mut s, 100), '/bin/true exit not detected promptly'
	// no zombie left: the aliveness path reaps via waitpid(WNOHANG), so a
	// further waitpid must report ECHILD (-1) — never the pid again.
	mut st := 0
	mut gone := false
	for _ in 0 .. 50 {
		if C.waitpid(pid, &st, wnohang_test) == -1 {
			gone = true
			break
		}
		time.sleep(20 * time.millisecond)
	}
	assert gone, 'zombie left behind for pid ${pid}'
}

fn test_sleep_kill_escalation_reaps() {
	mut s := spawn('test', '/bin/sleep', ['30'], 80, 24) or { panic(err.msg()) }
	defer {
		s.kill()
	}
	assert s.alive(), '/bin/sleep should be running'
	s.kill()
	assert poll_exit(mut s, 100), 'SIGTERM-then-SIGKILL did not stop /bin/sleep'
	mut st := 0
	assert C.waitpid(s.pid, &st, wnohang_test) == -1, 'zombie left behind after kill'
}

fn test_double_kill_is_safe() {
	mut s := spawn('test', '/bin/sleep', ['30'], 80, 24) or { panic(err.msg()) }
	defer {
		s.kill()
	}
	s.kill()
	first_fd := s.fd
	s.kill() // must not crash and must not double-close
	assert first_fd == -1, 'kill must park the fd at -1'
	assert s.fd == -1
	assert !s.alive()
	// drain after close is a safe no-op, not a crash
	assert s.drain() == ''
}

fn test_drain_after_exit_and_closed_fd_ops_safe() {
	mut s := spawn('test', '/bin/true', [], 80, 24) or { panic(err.msg()) }
	defer {
		s.kill()
	}
	assert poll_exit(mut s, 100), '/bin/true exit not detected promptly'
	s.kill()
	// drain-after-exit and drain-after-close: safe, repeatable
	_ = s.drain()
	assert s.drain() == ''
	// write/resize on the closed fd: documented no-ops, never a crash
	s.write('echo hi\n')
	s.resize(80, 24)
	assert s.fd == -1
}

fn test_zero_session_is_not_alive() {
	s := Session{}
	assert !s.alive(), 'zero-value Session must never report alive'
}
