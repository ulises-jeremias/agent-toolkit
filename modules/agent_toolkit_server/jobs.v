module agent_toolkit_server

// Phase 4 (#835): long-running job registry + process-per-run supervisor.
// Mirrors ADR-020: spawn CLI subprocess, capture output lines, persist registry.
import json
import os
import sync
import time

pub struct Job {
pub mut:
	id         string
	cmd        string
	args       []string
	status     string
	started_at string
	ended_at   string
	exit_code  int = -1
	workspace  string
}

pub struct JobRunner {
pub mut:
	mut         sync.Mutex
	jobs        map[string]Job
	max_running int = 2
	running     int
	dir         string
}

pub fn new_job_runner(dir string) &JobRunner {
	os.mkdir_all(dir) or {}
	mut jobs := map[string]Job{}
	mut running := 0
	data := os.read_file(os.join_path(dir, 'jobs.json')) or { '' }
	if data.len > 0 {
		decoded := json.decode(map[string]Job, data) or {
			eprintln('[jobs] warning: malformed jobs.json, starting empty: ${err.msg()}')
			map[string]Job{}
		}
		jobs = decoded.clone()
		// Reconcile: running/queued at crash -> failed, do not count toward running
		for id, mut job in jobs {
			if job.status in ['running', 'queued'] {
				job.status = 'failed'
				job.ended_at = time.utc().format_rfc3339()
				job.exit_code = -1
				jobs[id] = job
			}
		}
		// Count only truly running (should be 0 after reconcile, but keep logic)
		for _, job in jobs {
			if job.status == 'running' {
				running++
			}
		}
	}
	return &JobRunner{
		jobs: jobs
		max_running: 2
		running: running
		dir: dir
	}
}

fn (r &JobRunner) jobs_file() string {
	return os.join_path(r.dir, 'jobs.json')
}

fn (mut r JobRunner) persist_locked() {
	data := json.encode(r.jobs)
	tmp := r.jobs_file() + '.tmp'
	os.write_file(tmp, data) or { return }
	os.mv(tmp, r.jobs_file()) or { os.write_file(r.jobs_file(), data) or {} }
}

pub fn (mut r JobRunner) create(cmd string, args []string, workdir string) !Job {
	r.mut.lock()
	defer {
		r.mut.unlock()
	}
	if r.running >= r.max_running {
		return error('max concurrent jobs (${r.max_running}) reached')
	}
	id := 'job_' + time.utc().format_rfc3339().replace('-', '').replace(':', '').replace('.', '')
	job := Job{
		id: id
		cmd: cmd
		args: args
		status: 'queued'
		started_at: time.utc().format_rfc3339()
		workspace: workdir
	}
	r.jobs[id] = job
	mut p := os.new_process('agent-toolkit')
	p.set_args(args)
	if workdir.len > 0 {
		p.set_work_folder(workdir)
	}
	p.set_redirect_stdio()
	p.run()
	r.jobs[id].status = 'running'
	r.running++
	r.persist_locked()
	os.write_file(r.log_path(id), '[running]\n') or {}
	go r.watch(id, mut p)
	return r.jobs[id]
}

fn (mut r JobRunner) watch(id string, mut p os.Process) {
	// Stream stdout/stderr incrementally to avoid 64KB deadlock and enable live SSE/log.
	// Write incrementally to log file so GET /jobs/:id/log and SSE see progress before exit.
	mut buf := ''
	// Ensure log exists with running marker
	os.write_file(r.log_path(id), '[running]\n') or {}
	for p.is_alive() {
		out := p.stdout_read()
		err := p.stderr_read()
		if out.len > 0 {
			buf += out
			// Append incrementally (overwrite with full buf for simplicity, file is small)
			os.write_file(r.log_path(id), '[running]\n' + buf) or {}
		}
		if err.len > 0 {
			buf += err
			os.write_file(r.log_path(id), '[running]\n' + buf) or {}
		}
		// Avoid busy loop; 50ms matches SSE poll interval
		time.sleep(50 * time.millisecond)
	}
	// Final drain after process exit (wait ensures code available)
	p.wait()
	out := p.stdout_slurp()
	err := p.stderr_slurp()
	if out.len > 0 {
		buf += out
	}
	if err.len > 0 {
		if buf.len > 0 {
			buf += '\n'
		}
		buf += err
	}
	final_log := if buf.len > 0 {
		'[running]\n' + buf + '\n[exit ${p.code}]\n'
	} else {
		'[exit ${p.code}]\n'
	}
	os.write_file(r.log_path(id), final_log) or {}
	r.mut.lock()
	defer {
		r.mut.unlock()
	}
	if id in r.jobs {
		r.jobs[id].status = if p.code == 0 { 'completed' } else { 'failed' }
		r.jobs[id].exit_code = p.code
		r.jobs[id].ended_at = time.utc().format_rfc3339()
		p.close()
	}
	r.running--
	r.persist_locked()
}

// get returns a snapshot of the job with `id` if it exists.
pub fn (r &JobRunner) get(id string) ?Job {
	r.mut.lock()
	defer {
		r.mut.unlock()
	}
	if id in r.jobs {
		return r.jobs[id]
	}
	return none
}

// is_terminal reports whether a job status is final (no further events).
pub fn is_terminal(status string) bool {
	return status in ['completed', 'failed']
}

pub fn (r &JobRunner) log_path(id string) string {
	return os.join_path(r.dir, '${id}.log')
}
