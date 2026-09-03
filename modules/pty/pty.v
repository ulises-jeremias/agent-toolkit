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
pub fn (mut s Session) drain() string {
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

// write — send input bytes to the agent (keyboard path).
pub fn (mut s Session) write(data string) {
	if s.fd <= 0 || data.len == 0 {
		return
	}
	C.write(s.fd, data.str, data.len)
}

// resize — TIOCSWINSZ on the master fd.
pub fn (mut s Session) resize(cols int, rows int) {
	ws := Winsize{
		ws_row: u16(rows)
		ws_col: u16(cols)
	}
	// TIOCSWINSZ
	C.ioctl(s.fd, 0x5414, &ws)
}

// alive — false when the child exited (poll via kill 0).
pub fn (s Session) alive() bool {
	return C.kill(s.pid, 0) == 0
}

// kill — SIGTERM the child; caller closes fd afterwards.
pub fn (mut s Session) kill() {
	C.kill(s.pid, 15)
	C.close(s.fd)
}
