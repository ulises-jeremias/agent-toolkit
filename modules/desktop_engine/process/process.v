module process

import sync
import time
import os
import context
import json2
import desktop_engine.eventbus

pub enum RestartPolicy {
	no
	on_failure
	always
}

@[params]
pub struct SpawnOpts {
pub:
	restart      RestartPolicy = .no
	max_restarts u8 = 3
	backoff_ms   int = 100
	env          []string
	work_dir     string
	capture_logs bool = true
}

pub struct ProcessHandle {
pub:
	id  string
	pid int
mut:
	proc        &os.Process = unsafe { nil }
	stdout_chan chan string
	stderr_chan chan string
	exit_code   ?int
	mu          sync.Mutex
	cancelled   bool
	restarts    u8
	opts        SpawnOpts
	bus         &eventbus.ToolkitEventBus = unsafe { nil }
}

pub fn (mut h ProcessHandle) cancel() {
	h.mu.lock()
	if h.cancelled {
		h.mu.unlock()
		return
	}
	h.cancelled = true
	proc := h.proc
	h.mu.unlock()
	if proc == unsafe { nil } {
		return
	}
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
	p.wait()
	p.close()
	if h.bus != unsafe { nil } {
		h.bus.publish(eventbus.ToolkitEvent{
			kind: .process_exited
			revision: 0
			path: h.id
			payload: json2.encode({
				'id':           h.id
				'code':         (if h.exit_code != none { h.exit_code or { -1 } } else { p.code }).str()
				'will_restart': 'false'
			},
				escape_unicode: true
			)
		})
	}
	h.mu.lock()
	h.exit_code = p.code
	h.mu.unlock()
}

pub fn (mut h ProcessHandle) is_alive() bool {
	h.mu.lock()
	proc := h.proc
	h.mu.unlock()
	if proc == unsafe { nil } {
		return false
	}
	mut p := unsafe { proc }
	return p.is_alive()
}

pub fn (mut h ProcessHandle) wait() int {
	h.mu.lock()
	proc := h.proc
	h.mu.unlock()
	if proc == unsafe { nil } {
		return -1
	}
	mut p := unsafe { proc }
	p.wait()
	code := p.code
	h.mu.lock()
	h.exit_code = code
	h.mu.unlock()
	return code
}

pub fn (h ProcessHandle) stdout_chan_() chan string {
	return h.stdout_chan
}

pub struct ProcessSupervisor {
mut:
	mu           sync.RwMutex
	procs        map[string]&ProcessHandle
	bus          &eventbus.ToolkitEventBus = unsafe { nil }
	dropped_logs u64
}

pub fn new_process_supervisor(bus &eventbus.ToolkitEventBus) &ProcessSupervisor {
	return &ProcessSupervisor{
		bus: bus
	}
}

pub fn (mut s ProcessSupervisor) spawn(cmd string, args []string, opts SpawnOpts) !&ProcessHandle {
	if cmd == '' {
		return error('spawn: cmd empty')
	}
	mut backoff := opts.backoff_ms
	if backoff < 100 {
		backoff = 100
	}
	if backoff > 5000 {
		backoff = 5000
	}
	mut id := '${cmd}_${time.now().unix_nano()}_${args.join('_')}'
	id = id.replace(' ', '_').replace('/', '_')
	mut proc := os.new_process(cmd)
	proc.set_args(args)
	if opts.work_dir.len > 0 {
		proc.set_work_folder(opts.work_dir)
	}
	if opts.env.len > 0 {
		mut env_map := map[string]string{}
		for e in opts.env {
			parts := e.split_nth('=', 2)
			if parts.len == 2 {
				env_map[parts[0]] = parts[1]
			}
		}
		proc.set_environment(env_map)
	}
	proc.set_redirect_stdio()
	mut out_ch := chan string{ cap: 1024 }
	mut err_ch := chan string{ cap: 1024 }
	mut handle := &ProcessHandle{
		id: id
		proc: proc
		stdout_chan: out_ch
		stderr_chan: err_ch
		opts: SpawnOpts{
			restart: opts.restart
			max_restarts: opts.max_restarts
			backoff_ms: backoff
			env: opts.env.clone()
			work_dir: opts.work_dir
			capture_logs: opts.capture_logs
		}
		bus: s.bus
	}
	s.mu.lock()
	s.procs[id] = handle
	s.mu.unlock()

	// resilience: exponential backoff retry loop (supports up to max_restarts, not single)
	spawn fn [mut handle, mut s, cmd, args] () {
		mut p := handle.proc
		for {
			p.wait()
			code := p.code
			if handle.opts.capture_logs {
				out := p.stdout_slurp()
				if out.len > 0 {
					lines := out.split_into_lines()
					for line in lines {
						if line.len == 0 {
							continue
						}
						if handle.stdout_chan.len < 1024 {
							handle.stdout_chan <- line
						} else {
							s.mu.lock()
							s.dropped_logs++
							s.mu.unlock()
							_ = <-handle.stdout_chan
							handle.stdout_chan <- line
						}
						if s.bus != unsafe { nil } {
							s.bus.publish(eventbus.ToolkitEvent{
								kind: .process_log
								revision: 0
								path: handle.id
								payload: json2.encode({
									'id':     handle.id
									'stream': 'stdout'
									'line':   line
								},
									escape_unicode: true
								)
							})
						}
					}
				}
				err_out := p.stderr_slurp()
				if err_out.len > 0 {
					lines2 := err_out.split_into_lines()
					for line2 in lines2 {
						if line2.len == 0 {
							continue
						}
						if handle.stderr_chan.len < 1024 {
							handle.stderr_chan <- line2
						} else {
							s.mu.lock()
							s.dropped_logs++
							s.mu.unlock()
							_ = <-handle.stderr_chan
							handle.stderr_chan <- line2
						}
						if s.bus != unsafe { nil } {
							s.bus.publish(eventbus.ToolkitEvent{
								kind: .process_log
								revision: 0
								path: handle.id
								payload: json2.encode({
									'id':     handle.id
									'stream': 'stderr'
									'line':   line2
								},
									escape_unicode: true
								)
							})
						}
					}
				}
			}
			handle.mu.lock()
			handle.exit_code = code
			restart_policy := handle.opts.restart
			max_r := handle.opts.max_restarts
			restarts := handle.restarts
			cancelled := handle.cancelled
			handle.mu.unlock()
			mut will_restart := false
			if !cancelled {
				if restart_policy == .always {
					will_restart = restarts < max_r
				} else if restart_policy == .on_failure && code != 0 {
					will_restart = restarts < max_r
				}
			}
			if s.bus != unsafe { nil } {
				s.bus.publish(eventbus.ToolkitEvent{
					kind: .process_exited
					revision: 0
					path: handle.id
					payload: json2.encode({
						'id':           handle.id
						'code':         code.str()
						'will_restart': will_restart.str()
					},
						escape_unicode: true
					)
				})
			}
			if will_restart {
				backoff_ms := handle.opts.backoff_ms
				mut delay := backoff_ms * (1 << restarts)
				if delay > 5000 {
					delay = 5000
				}
				time.sleep(delay * time.millisecond)
				handle.mu.lock()
				handle.restarts++
				handle.mu.unlock()
				mut new_proc := os.new_process(cmd)
				new_proc.set_args(args)
				if handle.opts.work_dir.len > 0 {
					new_proc.set_work_folder(handle.opts.work_dir)
				}
				if handle.opts.env.len > 0 {
					mut env_map2 := map[string]string{}
					for e in handle.opts.env {
						parts := e.split_nth('=', 2)
						if parts.len == 2 {
							env_map2[parts[0]] = parts[1]
						}
					}
					new_proc.set_environment(env_map2)
				}
				new_proc.set_redirect_stdio()
				handle.mu.lock()
				handle.proc = new_proc
				handle.exit_code = none
				handle.mu.unlock()
				p.close()
				p = new_proc
				continue
			} else {
				p.close()
				break
			}
		}
	}()
	return handle
}

pub fn (mut s ProcessSupervisor) cancel_all(mut ctx context.Context) {
	s.mu.rlock()
	ids := s.procs.keys()
	s.mu.runlock()
	for id in ids {
		h := s.procs[id] or { continue }
		mut handle := unsafe { h }
		handle.cancel()
	}
	_ = ctx
}

pub fn (mut s ProcessSupervisor) stop() ! {
	mut bg := context.background()
	s.cancel_all(mut bg)
}

pub fn (mut s ProcessSupervisor) start(mut ctx context.Context) ! {
	_ = ctx
}

pub fn (mut s ProcessSupervisor) spawn_job(cmd string, args []string) !string {
	h := s.spawn(cmd, args, SpawnOpts{})!
	return h.id
}

pub fn (mut s ProcessSupervisor) count() int {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return s.procs.len
}

pub fn (mut s ProcessSupervisor) dropped_count() u64 {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return s.dropped_logs
}

pub fn (mut s ProcessSupervisor) get_handle(id string) ?&ProcessHandle {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return s.procs[id] or { return none }
}

pub fn (mut s ProcessSupervisor) list_ids() []string {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return s.procs.keys()
}
