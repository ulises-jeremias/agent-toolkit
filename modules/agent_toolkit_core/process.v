module agent_toolkit_core

import os
import time

// RunOptions configures a no-shell process spawn.
pub struct RunOptions {
pub:
	argv      []string // argv[0] = executable name or path; rest = args
	cwd       string
	env       map[string]string // if empty, inherit parent env
	timeout   time.Duration // 0 = no timeout
	// term_grace is how long a timed-out process gets after SIGTERM
	// before the process-group kill escalates. 0 = default (1s).
	term_grace time.Duration
}

const default_term_grace = 1 * time.second

// RunResult is the captured outcome of a process run.
pub struct RunResult {
pub:
	exit_code int
	stdout    string
	stderr    string
	timed_out bool
}

// ProcessService runs external programs without a shell (no injection).
pub struct ProcessService {}

// new_process_service returns a ProcessService.
pub fn new_process_service() ProcessService {
	return ProcessService{}
}

// run executes argv[0] with argv[1..] as arguments. Never uses a shell.
pub fn (p ProcessService) run(opts RunOptions) !RunResult {
	if opts.argv.len == 0 {
		return error('process argv must not be empty')
	}
	exe_name := opts.argv[0]
	exe := if os.is_file(exe_name) {
		exe_name
	} else {
		os.find_abs_path_of_executable(exe_name) or {
			return error('executable not found: ${exe_name}')
		}
	}
	mut proc := os.new_process(exe)
	if opts.argv.len > 1 {
		proc.set_args(opts.argv[1..])
	}
	if opts.cwd.len > 0 {
		proc.set_work_folder(opts.cwd)
	}
	if opts.env.len > 0 {
		proc.set_environment(opts.env)
	}
	proc.set_redirect_stdio()
	proc.run()
	if opts.timeout > 0 {
		deadline := time.now().add(opts.timeout)
		for proc.is_alive() {
			if time.now() > deadline {
				terminate_with_grace(mut proc, opts.term_grace)
				out := proc.stdout_slurp()
				err := proc.stderr_slurp()
				proc.close()
				return RunResult{
					exit_code: -1
					stdout: out
					stderr: err
					timed_out: true
				}
			}
			time.sleep(10 * time.millisecond)
		}
	}
	proc.wait()
	code := proc.code
	out := proc.stdout_slurp()
	err := proc.stderr_slurp()
	proc.close()
	return RunResult{
		exit_code: code
		stdout: out
		stderr: err
		timed_out: false
	}
}

// terminate_with_grace stops a timed-out process politely first:
// SIGTERM, wait out the grace window, then escalate to a process-group
// kill (reaches grandchildren when the child leads its own group) and
// finally SIGKILL. The old path went straight to SIGKILL, which gave
// provider CLIs no chance to flush state or stop their own children.
fn terminate_with_grace(mut proc os.Process, grace time.Duration) {
	window := if grace > 0 { grace } else { default_term_grace }
	proc.signal_term()
	mut deadline := time.now().add(window)
	for proc.is_alive() && time.now() < deadline {
		time.sleep(10 * time.millisecond)
	}
	if !proc.is_alive() {
		return
	}
	proc.signal_pgkill()
	deadline = time.now().add(250 * time.millisecond)
	for proc.is_alive() && time.now() < deadline {
		time.sleep(10 * time.millisecond)
	}
	if proc.is_alive() {
		proc.signal_kill()
	}
}

// to_domain_error maps a process failure / timeout into ADR-010 classes.
pub fn (r RunResult) to_domain_error(context string) DomainError {
	if r.timed_out {
		return err_external('process.timeout', '${context}: process timed out')
	}
	if r.exit_code != 0 {
		return err_external('process.exit', '${context}: exit ${r.exit_code}: ${r.stderr.trim_space()}')
	}
	return DomainError{
		class: .ok
		code: 'ok'
		message: ''
	}
}
