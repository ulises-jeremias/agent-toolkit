module agent_toolkit_server

// Phase 4 (#835): long-running job registry + process-per-run supervisor.
// Mirrors ADR-020: spawn CLI subprocess, capture output lines, persist registry.
import x.json2
import os
import rand
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
	// retry_of is the id of the failed/canceled job this run re-executes.
	retry_of string
}

pub struct JobRunner {
pub mut:
	mut  sync.Mutex
	jobs map[string]Job
	// procs tracks live child handles for cancel. watch() owns wait/close;
	// cancel() only signals through this entry (term → grace → kill),
	// mirroring desktop_engine/process cancel semantics.
	procs       map[string]&os.Process
	max_running int = 2
	running     int
	dir         string
	// bus receives job.* / loop.* lifecycle events (nil = not published).
	bus &EventBus = unsafe { nil }
}

pub fn new_job_runner(dir string) &JobRunner {
	os.mkdir_all(dir) or {}
	mut jobs := map[string]Job{}
	mut running := 0
	data := os.read_file(os.join_path(dir, 'jobs.json')) or { '' }
	if data.len > 0 {
		decoded := json2.decode[map[string]Job](data) or {
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
	data := json2.encode(r.jobs, escape_unicode: true)
	tmp := r.jobs_file() + '.tmp'
	os.write_file(tmp, data) or { return }
	os.mv(tmp, r.jobs_file()) or { os.write_file(r.jobs_file(), data) or {} }
}

pub fn (mut r JobRunner) create(cmd string, args []string, workdir string) !Job {
	return r.create_job(cmd, args, workdir, '')
}

// create_job spawns a job; retry_of links it to the job it re-runs.
pub fn (mut r JobRunner) create_job(cmd string, args []string, workdir string, retry_of string) !Job {
	r.mut.lock()
	defer {
		r.mut.unlock()
	}
	if r.running >= r.max_running {
		return error('max concurrent jobs (${r.max_running}) reached')
	}
	// Use timestamp + pid + random to avoid collisions under parallel creates
	id := 'job_' + time.utc().format_rfc3339().replace('-', '').replace(':', '').replace('.', '') + '_' + os.getpid().str() + '_' + (rand.int_in_range(1000, 9999) or { 1000 }).str()
	job := Job{
		id: id
		cmd: cmd
		args: args
		status: 'queued'
		started_at: time.utc().format_rfc3339()
		workspace: workdir
		retry_of: retry_of
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
	r.procs[id] = p
	r.running++
	r.persist_locked()
	os.write_file(r.log_path(id), '[running]\n') or {}
	r.emit_job('job.created', r.jobs[id])
	go r.watch(id, mut p)
	return r.jobs[id]
}

// retry_source returns the job to re-run; only failed or canceled jobs
// qualify (completed runs are not retried, active ones are still running).
pub fn (r &JobRunner) retry_source(id string) !Job {
	job := r.get(id) or { return error('job not found: ${id}') }
	if job.status !in ['failed', 'canceled'] {
		return error('job is ${job.status}: ${id}')
	}
	return job
}

// emit_job publishes a job lifecycle event, plus the matching loop.* event
// for `loop run` jobs. Callers hold r.mut; the bus lock is a leaf lock.
fn (mut r JobRunner) emit_job(kind string, job Job) {
	if r.bus == unsafe { nil } {
		return
	}
	r.bus.publish(ApiEvent{
		kind: kind
		subject: job.id
		status: job.status
		exit_code: job.exit_code
		ref: job.retry_of
	})
	loop_name := job_loop_name(job)
	if loop_name.len == 0 {
		return
	}
	if kind == 'job.created' {
		r.bus.publish(ApiEvent{
			kind: 'loop.started'
			subject: loop_name
			status: job.status
			exit_code: job.exit_code
			ref: job.id
		})
	} else if kind == 'job.updated' && is_terminal(job.status) {
		r.bus.publish(ApiEvent{
			kind: 'loop.finished'
			subject: loop_name
			status: job.status
			exit_code: job.exit_code
			ref: job.id
		})
	}
}

// job_loop_name returns the loop name of a `loop run <name>` job, else ''.
fn job_loop_name(job Job) string {
	if job.cmd != 'loop' {
		return ''
	}
	mut rest := job.args.clone()
	if rest.len > 0 && rest[0] == 'loop' {
		rest = rest[1..].clone()
	}
	if rest.len >= 2 && rest[0] == 'run' && !rest[1].starts_with('-') {
		return rest[1]
	}
	return ''
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
	mut final_log := if buf.len > 0 {
		'[running]\n' + buf + '\n[exit ${p.code}]\n'
	} else {
		'[exit ${p.code}]\n'
	}
	r.mut.lock()
	defer {
		r.mut.unlock()
	}
	// Cancel wins over a racy exit: only transcribe the process outcome
	// when the job is still active; a concurrent cancel already flipped
	// the state and decremented running. The watcher is the sole writer of
	// the final log for tracked processes (so the canceled marker is never
	// clobbered) and never recreates the log of a force-deleted job.
	// Cleanup (proc entry, close) always runs: a force-deleted job leaves
	// no registry entry but its watcher still owns the process lifecycle.
	if id in r.jobs {
		if r.jobs[id].status == 'running' || r.jobs[id].status == 'queued' {
			r.jobs[id].status = if p.code == 0 { 'completed' } else { 'failed' }
			r.jobs[id].exit_code = p.code
			r.jobs[id].ended_at = time.utc().format_rfc3339()
			r.running--
			r.emit_job('job.updated', r.jobs[id])
		} else if r.jobs[id].status == 'canceled' {
			final_log += '[canceled]\n'
		}
		os.write_file(r.log_path(id), final_log) or {}
	}
	r.procs.delete(id)
	p.close()
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

// cancel flips a queued/running job to canceled and terminates its child
// (SIGTERM, grace, SIGKILL — same escalation as desktop_engine/process).
// State first: the row is canceled under lock, so a concurrent watch exit
// transcription never overwrites it and running is decremented exactly once.
// A missing or already-reaped handle is a no-op, never an error.
pub fn (mut r JobRunner) cancel(id string) !Job {
	r.mut.lock()
	mut job := r.jobs[id] or {
		r.mut.unlock()
		return error('job not found: ${id}')
	}
	if is_terminal(job.status) {
		r.mut.unlock()
		return error('job already ${job.status}: ${id}')
	}
	proc := r.procs[id] or { unsafe { nil } }
	job.status = 'canceled'
	job.ended_at = time.utc().format_rfc3339()
	r.jobs[id] = job
	if r.running > 0 {
		r.running--
	}
	r.persist_locked()
	r.emit_job('job.updated', job)
	r.mut.unlock()
	if proc != unsafe { nil } {
		mut p := unsafe { proc }
		p.signal_term()
		mut waited := 0
		for waited < 2000 {
			if !p.is_alive() {
				break
			}
			time.sleep(50 * time.millisecond)
			waited += 50
		}
		if p.is_alive() {
			p.signal_kill()
		}
	} else {
		append_canceled_marker(r.log_path(id))
	}
	return job
}

// delete removes a job's registry entry and log file. Running/queued jobs
// need force=true (which cancels first); terminal jobs delete directly.
pub fn (mut r JobRunner) delete(id string, force bool) ! {
	r.mut.lock()
	job := r.jobs[id] or {
		r.mut.unlock()
		return error('job not found: ${id}')
	}
	active := job.status == 'running' || job.status == 'queued'
	if active && !force {
		r.mut.unlock()
		return error('job is ${job.status}: ${id}')
	}
	r.mut.unlock()
	if active {
		// The job may finish (or be deleted) between the unlock above and
		// cancel; force delete still proceeds in that case.
		r.cancel(id) or {
			msg := err.msg()
			if !msg.starts_with('job already') && !msg.starts_with('job not found') {
				return err
			}
		}
	}
	r.mut.lock()
	gone := r.jobs[id] or {
		// A concurrent delete won the race; only one caller reports success.
		r.mut.unlock()
		return error('job not found: ${id}')
	}
	r.jobs.delete(id)
	r.procs.delete(id)
	r.persist_locked()
	if r.bus != unsafe { nil } {
		r.bus.publish(ApiEvent{
			kind: 'job.deleted'
			subject: id
			status: gone.status
			exit_code: gone.exit_code
		})
	}
	r.mut.unlock()
	lp := r.log_path(id)
	if os.is_file(lp) && !os.is_link(lp) {
		os.rm(lp) or {}
	}
}

// is_valid_job_id reports whether id matches the strict job ID format.
// Valid IDs are `job_` + alphanumeric, underscore, hyphen; no path separators.
// Rejects traversal, URL-encoded traversal (%2e, %2f), and symlink escape attempts.
pub fn is_valid_job_id(id string) bool {
	if id.len < 5 || !id.starts_with('job_') {
		return false
	}
	// Reject any path separator, traversal, null byte, or URL-encoded traversal.
	// URL-encoded `%` is never valid in a job ID (alphanumeric + _ - only).
	if id.contains('/') || id.contains('\\') || id.contains('..') || id.contains('\x00') || id.contains('%') {
		return false
	}
	// Absolute path check
	if id.starts_with('/') {
		return false
	}
	for ch in id[4..] {
		if !((ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_` || ch == `-`) {
			return false
		}
	}
	return true
}

// is_valid_job_id_strict validates id after URL-decoding to catch %2e%2f etc.
// Veb may decode path params, so we also reject decoded traversal.
pub fn is_valid_job_id_strict(id string) bool {
	if !is_valid_job_id(id) {
		return false
	}
	// If id contains percent-encoding, decode and re-validate
	if id.contains('%') {
		return false
	}
	return true
}

// append_canceled_marker records cancellation in the job log without
// destroying prior output. Best-effort: logging never fails a cancel.
fn append_canceled_marker(log_path string) {
	prev := os.read_file(log_path) or { '' }
	mut body := prev
	if body.len > 0 && !body.ends_with('\n') {
		body += '\n'
	}
	os.write_file(log_path, body + '[canceled]\n') or {}
}

// is_terminal reports whether a job status is final (no further events).
pub fn is_terminal(status string) bool {
	return status in ['completed', 'failed', 'canceled', 'rejected']
}

pub fn (r &JobRunner) log_path(id string) string {
	if !is_valid_job_id(id) {
		// Return a safe path that will not escape; caller should have validated and returned 400.
		// We still return a path under dir but with sanitized id to avoid traversal.
		safe := id.replace('/', '_').replace('\\', '_').replace('..', '_').replace('%', '_')
		return os.join_path(r.dir, '${safe}.log')
	}
	return os.join_path(r.dir, '${id}.log')
}

// is_log_path_safe reports whether the log file for id is safely inside runner dir
// and not a symlink escaping outside. Use before reading.
pub fn (r &JobRunner) is_log_path_safe(id string) bool {
	if !is_valid_job_id(id) {
		return false
	}
	lp := r.log_path(id)
	// Check for symlink escape: if log file exists and is a symlink pointing outside runner dir, reject.
	if os.is_link(lp) {
		real_lp := os.real_path(lp)
		real_dir := os.real_path(r.dir)
		if real_lp.len == 0 || real_dir.len == 0 {
			return false
		}
		if !(real_lp == real_dir || real_lp.starts_with(real_dir + '/')) {
			return false
		}
	}
	// Also ensure canonical parent of lp is inside dir (defense even without symlink)
	// For non-existent files, check string prefix
	if !lp.starts_with(r.dir + '/') && lp != r.dir {
		// Join should have ensured this, but double-check after sanitization
		return false
	}
	// Reject if real_path of parent escapes (e.g. dir is symlink)
	if os.exists(r.dir) {
		real_dir := os.real_path(r.dir)
		if real_dir.len > 0 {
			// lp's directory should be inside real_dir
			lp_dir := os.dir(lp)
			real_lp_dir := os.real_path(lp_dir)
			if real_lp_dir.len > 0 && !(real_lp_dir == real_dir || real_lp_dir.starts_with(real_dir + '/')) {
				return false
			}
		}
	}
	return true
}

// is_valid_workspace_path reports whether workspace path is safe: exists, is dir,
// no traversal, no URL-encoding, no symlink escape outside allowed roots.
pub fn is_valid_workspace_path(path string) bool {
	if path.len == 0 {
		return false
	}
	if path.contains('..') || path.contains('%') || path.contains('\x00') {
		return false
	}
	if !os.is_dir(path) {
		return false
	}
	// Symlink check: real path must be dir and not escape via link outside its own parent
	// For workspace, we require real_path to exist and be a dir; if symlink points to /etc, real_path is /etc
	// We don't have allowed-roots list here (server will add), but at least ensure no null/traversal.
	// Basic canonical check: real_path should succeed
	real := os.real_path(path)
	if real.len == 0 {
		return false
	}
	// Reject if is_link and real != path but we still allow symlinked workspaces inside allowed roots —
	// the caller (server.veb.v) will do allowed-roots check. Here just ensure not empty.
	return true
}
