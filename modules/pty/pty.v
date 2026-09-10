// pty — real PTY sessions for the desktop terminal (Linux).
//
// Spawns agent CLIs (claude, opencode, cursor-agent, muse, pi, …) attached to
// a pseudo-terminal so the GUI can run them interactively. The reader is
// NON-BLOCKING and drained per frame by the caller — no threads, no races.
// See modules/pty/README in the issue for the agent detection matrix.
module pty

import os

// #flag -lutil (test)
#include <pty.h>

#include <unistd.h>

#include <stdlib.h>

#include <fcntl.h>

#include <signal.h>

#include <sys/ioctl.h>

#include <sys/wait.h>

pub struct Winsize {
pub:
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

pub struct Session {
pub mut:
	pid   int
	fd    int
	agent string
	cmd   string
}

fn C.forkpty(amaster &int, name voidptr, termp voidptr, winp voidptr) int

fn C.execvp(&char, &&char) int

fn C._exit(int)

fn C.write(fd int, buf voidptr, count usize) isize

fn C.read(fd int, buf voidptr, count usize) isize

fn C.close(fd int) int

fn C.kill(pid int, sig int) int

fn C.waitpid(pid int, status &int, options int) int

fn C.usleep(usec u32) int

const sig_term = 15
const sig_kill = 9
// wnohang is WNOHANG: waitpid in the reap path never blocks.
const wnohang = 1
// kill_grace_polls × kill_grace_us bounds the SIGTERM grace period before
// SIGKILL escalation (10 × 20ms = 200ms).
const kill_grace_polls = 10
const kill_grace_us = u32(20000)

// child_exited — non-blocking reap check via waitpid(WNOHANG). Returns true
// once the child is gone: reaped by this very call (zombie → reaped, never
// reported alive) or already reaped earlier (ECHILD). Returns false while it
// is still running. Never blocks. A pid <= 0 (zero-value Session) counts as
// gone so kill(0, ·) process-group semantics are never reached.
fn child_exited(pid int) bool {
	if pid <= 0 {
		return true
	}
	mut status := 0
	res := C.waitpid(pid, &status, wnohang)
	if res == pid {
		return true
	}
	if res == 0 {
		return false
	}
	// res < 0: ECHILD (already reaped) or a transient error. Confirm with
	// kill 0 so a transient failure on a live child is not misread as dead
	// (a zombie still owns its pid entry, so kill 0 succeeds on zombies).
	return C.kill(pid, 0) != 0
}

fn C.ioctl(fd i32, request u64, args ...voidptr) i32

fn C.fcntl(fd i32, cmd i32, arg ...voidptr) i32

fn C.isatty(int) int

// AgentBin — one supported agent CLI for the session manager.
pub struct AgentBin {
pub:
	agent  string // target id (claude-code, cursor, opencode, …)
	binary string // CLI binary to exec
	argv   string // optional default subcommand ('' = none)
}

// agent_bins — the detection table: every interactive agent CLI the toolkit
// supports. Copilot/Windsurf are IDE-first (no interactive CLI) and are
// intentionally absent — the GUI surfaces them as info cards instead.
pub const agent_bins = [
	AgentBin{'claude-code', 'claude', ''},
	AgentBin{'opencode', 'opencode', ''},
	AgentBin{'cursor', 'cursor-agent', ''},
	AgentBin{'muse-code', 'muse', ''},
	AgentBin{'pi', 'pi', ''},
	AgentBin{'codex', 'codex', ''},
	AgentBin{'gemini', 'gemini', ''},
]

// find_in_path — pure-V `command -v`: check every PATH dir for the binary.
pub fn find_in_path(binary string) bool {
	if binary == '' {
		return false
	}
	path := os.getenv('PATH')
	if path == '' {
		return false
	}
	for dir in path.split(':') {
		if dir == '' {
			continue
		}
		if os.exists(os.join_path(dir, binary)) {
			return true
		}
	}
	return false
}

// Detected — one row of the session dialog.
pub struct Detected {
pub:
	agent AgentBin
	found bool
}

// detect — returns the found/missing state of the whole table.
pub fn detect() []Detected {
	mut out := []Detected{}
	for ab in pty.agent_bins {
		out << Detected{
			agent: ab
			found: find_in_path(ab.binary)
		}
	}
	return out
}

// spawn — forkpty + execvp. argv is built as a pointer array (no shell).
// The fd is set non-blocking; drain() per frame reads pending output.
pub fn spawn(agent string, binary string, args []string, cols int, rows int) !Session {
	ws := Winsize{
		ws_row: u16(rows)
		ws_col: u16(cols)
	}
	mut mfd := 0
	pid := C.forkpty(&mfd, voidptr(0), voidptr(0), &ws)
	if pid < 0 {
		return error('forkpty failed')
	}
	if pid == 0 {
		// child — build argv (NULL-terminated) and exec, no shell
		mut argv := []voidptr{cap: args.len + 2}
		argv << voidptr(binary.str)
		for a in args {
			argv << voidptr(a.str)
		}
		argv << voidptr(0)
		C.execvp(&char(binary.str), &&char(argv.data))
		C._exit(127)
	}
	// parent — non-blocking master fd
	// F_SETFL=4, O_NONBLOCK=0o4000
	C.fcntl(mfd, 4, 0o4000)
	return Session{
		pid: pid
		fd: mfd
		agent: agent
		cmd: binary
	}
}

// drain — reads all currently pending output (non-blocking), returns it as
// a string for GhosttyTerminal.feed(). Empty string = nothing pending.
// Reaps an exited child first (never blocks) and is a safe no-op once the
// fd is closed (fd parked at -1 by kill).
pub fn (mut s Session) drain() string {
	if s.fd < 0 {
		return ''
	}
	child_exited(s.pid)
	mut out := []u8{}
	mut buf := [8192]u8{}
	for {
		n := C.read(s.fd, &buf[0], 8192)
		if n <= 0 {
			break
		}
		out << buf[..n]
		if out.len > 262144 {
			// 256 KB per frame is plenty for a TUI burst
			break
		}
	}
	if out.len == 0 {
		return ''
	}
	return out.bytestr()
}

// write — send input bytes to the agent (keyboard path). Documented no-op
// on a closed (or never-opened) fd and on empty input — never crashes.
pub fn (mut s Session) write(data string) {
	if s.fd <= 0 || data.len == 0 {
		return
	}
	C.write(s.fd, data.str, data.len)
}

// resize — TIOCSWINSZ on the master fd. Documented no-op once the fd is
// closed (fd parked at -1 by kill) — never crashes.
pub fn (mut s Session) resize(cols int, rows int) {
	if s.fd < 0 {
		return
	}
	ws := Winsize{
		ws_row: u16(rows)
		ws_col: u16(cols)
	}
	// TIOCSWINSZ
	C.ioctl(s.fd, 0x5414, &ws)
}

// alive — false once the child exited. waitpid(WNOHANG)-based: unlike the
// old kill(pid, 0) probe this reaps zombies instead of reporting them
// alive. Never blocks. A zero-value Session (pid <= 0) is never alive.
pub fn (s Session) alive() bool {
	return !child_exited(s.pid)
}

// close_fd closes the master fd exactly once and parks it at -1, so a
// second kill can neither double-close nor close a recycled fd.
fn (mut s Session) close_fd() {
	if s.fd >= 0 {
		C.close(s.fd)
		s.fd = -1
	}
}

// kill — SIGTERM the child, escalate to SIGKILL after a short grace
// (kill_grace_polls × kill_grace_us), reap without blocking, then close the
// master fd exactly once (fd parked at -1, close semantics kept). Safe to
// call twice and safe on an already-closed or zero-value session: signals
// are only sent to a child that waitpid still reports running, so an
// already-reaped (possibly recycled) pid is never signalled.
pub fn (mut s Session) kill() {
	if s.pid > 0 && !child_exited(s.pid) {
		C.kill(s.pid, sig_term)
		for _ in 0 .. kill_grace_polls {
			C.usleep(kill_grace_us)
			if child_exited(s.pid) {
				break
			}
		}
		if !child_exited(s.pid) {
			C.kill(s.pid, sig_kill)
		}
		// final non-blocking reap attempt; a slow-dying child is reaped
		// by the next alive()/drain() poll instead
		child_exited(s.pid)
	}
	s.close_fd()
}
