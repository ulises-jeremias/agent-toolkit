module watcher

import sync
import time
import os
import json2
import desktop_engine.state
import desktop_engine.eventbus

@[params]
pub struct WatcherConfig {
pub:
	poll_interval_ms int = 500
	debounce_ms    int = 100
}

pub struct WatcherHandle {
mut:
	closed    bool
	mu        sync.Mutex
	stop_chan chan bool
}

pub fn (mut h WatcherHandle) close() {
	h.mu.lock()
	if h.closed {
		h.mu.unlock()
		return
	}
	h.closed = true
	ch := h.stop_chan
	h.mu.unlock()
	if ch.len == 0 {
		ch <- true
	}
}

pub fn (mut h WatcherHandle) is_closed() bool {
	h.mu.lock()
	defer { h.mu.unlock() }
	return h.closed
}

pub interface Watcher {
mut:
	watch(paths []string, on_change fn (eventbus.ToolkitEvent)) !WatcherHandle
}

pub struct NativeWatcher {
pub:
	poll_interval_ms int = 500
	debounce_ms    int = 100
}

pub fn (w NativeWatcher) available() bool {
	if os.getenv('WATCHER_FORCE_POLL') == '1' {
		return false
	}
	if os.getenv('VVATCH_FORCE_POLL') == '1' {
		return false
	}
	$if linux || macos {
		return false
	} $else {
		return false
	}
}

pub fn (mut w NativeWatcher) watch(paths []string, on_change fn (eventbus.ToolkitEvent)) !WatcherHandle {
	mut fallback := PollingWatcher{
		poll_interval_ms: w.poll_interval_ms
		debounce_ms: w.debounce_ms
	}
	return fallback.watch(paths, on_change)
}

pub struct PollingWatcher {
pub mut:
	poll_interval_ms int = 500
	debounce_ms    int = 100
	dependencies     map[string]string
}

pub fn new_polling_watcher(cfg WatcherConfig) &PollingWatcher {
	mut poll := cfg.poll_interval_ms
	if poll < 100 {
		poll = 500
	}
	if poll == 0 {
		poll = 500
	}
	mut deb := cfg.debounce_ms
	if deb < 50 {
		deb = 50
	}
	if deb > 150 {
		deb = 150
	}
	if deb == 0 {
		deb = 100
	}
	return &PollingWatcher{
		poll_interval_ms: poll
		debounce_ms: deb
		dependencies: map[string]string{}
	}
}

pub fn is_polling_forced() bool {
	return os.getenv('WATCHER_FORCE_POLL') == '1' || os.getenv('VVATCH_FORCE_POLL') == '1'
}

pub fn select_watcher(cfg WatcherConfig) Watcher {
	if is_polling_forced() {
		return new_polling_watcher(cfg)
	}
	native := NativeWatcher{
		poll_interval_ms: cfg.poll_interval_ms
		debounce_ms: cfg.debounce_ms
	}
	if native.available() {
		return native
	}
	return new_polling_watcher(cfg)
}

pub fn (w PollingWatcher) dependency_for(path string) string {
	for prefix, dep in w.dependencies {
		if path.starts_with(prefix) {
			return dep
		}
	}
	if path.contains('skills') {
		return 'skill-catalog'
	}
	if path.contains('loops') {
		return 'loops'
	}
	if path.contains('agents') {
		return 'agents'
	}
	if path.contains('workspace') {
		return 'workspace'
	}
	if path.contains('swarm') {
		return 'swarm'
	}
	if path.contains('catalogs') {
		return 'catalogs'
	}
	return path
}

fn snapshot_paths(paths []string) map[string]i64 {
	mut snap := map[string]i64{}
	for p in paths {
		if p.len == 0 {
			continue
		}
		if os.is_dir(p) {
			snap[p] = os.file_last_mod_unix(p)
			files := os.walk_ext(p, '', hidden: false)
			for f in files {
				snap[f] = os.file_last_mod_unix(f)
				sz := os.file_size(f)
				snap[f] = snap[f] * 1000000 + (i64(sz) % 1000000)
			}
		} else if os.exists(p) {
			snap[p] = os.file_last_mod_unix(p)
			sz := os.file_size(p)
			snap[p] = snap[p] * 1000000 + (i64(sz) % 1000000)
		} else {
			snap[p] = 0
		}
	}
	return snap
}

fn snapshots_equal(a map[string]i64, b map[string]i64) bool {
	if a.len != b.len {
		return false
	}
	for k, v in a {
		if b[k] != v {
			return false
		}
	}
	return true
}

fn diff_detected(old map[string]i64, new_snap map[string]i64) string {
	for k, v in new_snap {
		if old[k] != v {
			return k
		}
	}
	for k, _ in old {
		if k !in new_snap {
			return k
		}
	}
	return ''
}

pub fn (mut w PollingWatcher) watch(paths []string, on_change fn (eventbus.ToolkitEvent)) !WatcherHandle {
	if paths.len == 0 {
		return error('watch: no paths')
	}
	if w.poll_interval_ms < 100 {
		w.poll_interval_ms = 500
	}
	if w.debounce_ms < 50 || w.debounce_ms > 150 {
		w.debounce_ms = 100
	}
	mut stop_ch := chan bool{cap: 1}
	mut handle := WatcherHandle{
		stop_chan: stop_ch
	}
	poll_ms := w.poll_interval_ms
	deb_ms := w.debounce_ms
	deps := w.dependencies.clone()
	spawn fn [paths, on_change, stop_ch, poll_ms, deb_ms, deps] () {
		mut old_snap := snapshot_paths(paths)
		mut last_emit := time.now()
		mut pending_path := ''
		mut pending_since := time.now()
		mut has_pending := false
		for {
			mut slept := 0
			for slept < poll_ms {
				chunk := if poll_ms - slept > 20 { 20 } else { poll_ms - slept }
				time.sleep(chunk * time.millisecond)
				if stop_ch.len > 0 {
					_ = <-stop_ch
					return
				}
				slept += chunk
			}
			if stop_ch.len > 0 {
				_ = <-stop_ch
				return
			}
			mut new_snap := snapshot_paths(paths)
			if snapshots_equal(old_snap, new_snap) {
				if has_pending {
					elapsed := time.since(pending_since).milliseconds()
					if elapsed >= deb_ms {
						dep := if deps.len > 0 {
							mut d := pending_path
							for prefix, dep_key in deps {
								if pending_path.starts_with(prefix) {
									d = dep_key
									break
								}
							}
							if d == pending_path && pending_path.contains('skills') {
								'skill-catalog'
							} else if d == pending_path && pending_path.contains('loops') {
								'loops'
							} else {
								d
							}
						} else {
							mut d2 := pending_path
							if pending_path.contains('skills') {
								d2 = 'skill-catalog'
							} else if pending_path.contains('loops') {
								d2 = 'loops'
							} else if pending_path.contains('agents') {
								d2 = 'agents'
							}
							d2
						}
						ev := eventbus.ToolkitEvent{
							kind: .watcher_invalidated
							revision: 0
							path: dep
							payload: json2.encode({'path': pending_path, 'dependent': dep}, escape_unicode: true)
						}
						on_change(ev)
						last_emit = time.now()
						has_pending = false
						pending_path = ''
						old_snap = new_snap.clone()
					}
				}
				continue
			}
			changed := diff_detected(old_snap, new_snap)
			if changed == '' {
				old_snap = new_snap.clone()
				continue
			}
			if !has_pending {
				has_pending = true
				pending_since = time.now()
				pending_path = changed
			} else {
				pending_path = changed
			}
			elapsed := time.since(pending_since).milliseconds()
			if elapsed >= deb_ms {
				dep := if deps.len > 0 {
					mut d := pending_path
					for prefix, dep_key in deps {
						if pending_path.starts_with(prefix) {
							d = dep_key
							break
						}
					}
					if d == pending_path && pending_path.contains('skills') {
						'skill-catalog'
					} else if d == pending_path && pending_path.contains('loops') {
						'loops'
					} else {
						d
					}
				} else {
					mut d2 := pending_path
					if pending_path.contains('skills') {
						d2 = 'skill-catalog'
					} else if pending_path.contains('loops') {
						d2 = 'loops'
					} else {
						d2
					}
					d2
				}
				ev := eventbus.ToolkitEvent{
					kind: .watcher_invalidated
					revision: 0
					path: dep
					payload: json2.encode({'path': pending_path, 'dependent': dep}, escape_unicode: true)
				}
				on_change(ev)
				last_emit = time.now()
				has_pending = false
				pending_path = ''
				old_snap = new_snap.clone()
			} else {
				remaining := deb_ms - int(elapsed)
				if remaining > 0 {
					mut rem_slept := 0
					for rem_slept < remaining {
						chunk2 := if remaining - rem_slept > 10 { 10 } else { remaining - rem_slept }
						time.sleep(chunk2 * time.millisecond)
						if stop_ch.len > 0 {
							_ = <-stop_ch
							return
						}
						rem_slept += chunk2
					}
				}
				mut new_snap2 := snapshot_paths(paths)
				if !snapshots_equal(old_snap, new_snap2) {
					final_changed := diff_detected(old_snap, new_snap2)
					if final_changed != '' {
						pending_path = final_changed
					}
					dep2 := if deps.len > 0 {
						mut d := pending_path
						for prefix, dep_key in deps {
							if pending_path.starts_with(prefix) {
								d = dep_key
								break
							}
						}
						if d == pending_path && pending_path.contains('skills') {
							'skill-catalog'
						} else if d == pending_path && pending_path.contains('loops') {
							'loops'
						} else {
							d
						}
					} else {
						mut d2 := pending_path
						if pending_path.contains('skills') {
							d2 = 'skill-catalog'
						} else if pending_path.contains('loops') {
							d2 = 'loops'
						} else {
							d2
						}
						d2
					}
					ev2 := eventbus.ToolkitEvent{
						kind: .watcher_invalidated
						revision: 0
						path: dep2
						payload: json2.encode({'path': pending_path, 'dependent': dep2}, escape_unicode: true)
					}
					on_change(ev2)
					last_emit = time.now()
				}
				has_pending = false
				pending_path = ''
				old_snap = new_snap2.clone()
			}
		}
	}()
	return handle
}

pub struct StateWatcher {
mut:
	repo          &state.StateRepository = unsafe { nil }
	bus           &eventbus.ToolkitEventBus = unsafe { nil }
	watcher       Watcher
	paths         []string
	poll_ms       int = 500
	debounce_ms int = 100
	handle        ?WatcherHandle
	mu            sync.Mutex
}

pub fn new_state_watcher(repo &state.StateRepository, bus &eventbus.ToolkitEventBus, paths []string, poll_ms int, debounce_ms int) &StateWatcher {
	mut p := poll_ms
	if p < 100 || p == 0 {
		p = 500
	}
	mut d := debounce_ms
	if d < 50 || d > 150 || d == 0 {
		d = 100
	}
	cfg := WatcherConfig{
		poll_interval_ms: p
		debounce_ms: d
	}
	w := select_watcher(cfg)
	return &StateWatcher{
		repo: repo
		bus: bus
		watcher: w
		paths: paths.clone()
		poll_ms: p
		debounce_ms: d
	}
}

pub fn (mut sw StateWatcher) start() ! {
	sw.mu.lock()
	defer { sw.mu.unlock() }
	if sw.handle != none {
		return
	}
	if sw.paths.len == 0 {
		return error('StateWatcher: no paths to watch')
	}
	if sw.repo == unsafe { nil } || sw.bus == unsafe { nil } {
		return error('StateWatcher: repo or bus is nil')
	}
	mut w := sw.watcher
	mut repo_ptr := sw.repo
	mut bus_ptr := sw.bus
	handle := w.watch(sw.paths, fn [mut repo_ptr, mut bus_ptr] (ev eventbus.ToolkitEvent) {
		changed_path := ev.path
		if os.is_file(changed_path) {
			content := os.read_file(changed_path) or { '' }
			if content.len > 0 {
				mut tx := repo_ptr.begin('watcher')
				snip := if content.len > 1024 { content[..1024] } else { content }
				tx.set('watcher_last_path', changed_path)
				tx.set('watcher_content_snippet', snip[..if snip.len > 512 { 512 } else { snip.len }])
				tx.set(changed_path, snip)
				rev := tx.commit() or { return }
				bus_ptr.publish(eventbus.ToolkitEvent{
					kind: .watcher_invalidated
					revision: rev.revision
					path: changed_path
					payload: json2.encode({'path': changed_path, 'revision': rev.revision.str()}, escape_unicode: true)
				})
				return
			}
		}
		mut tx2 := repo_ptr.begin('watcher')
		tx2.set('watcher_last_path', changed_path)
		tx2.set('watcher_timestamp', time.now().unix().str())
		rev2 := tx2.commit() or { return }
		bus_ptr.publish(eventbus.ToolkitEvent{
			kind: .watcher_invalidated
			revision: rev2.revision
			path: changed_path
			payload: json2.encode({'path': changed_path, 'revision': rev2.revision.str()}, escape_unicode: true)
		})
	})!
	sw.handle = handle
}

pub fn (mut sw StateWatcher) stop() ! {
	sw.mu.lock()
	defer { sw.mu.unlock() }
	if mut h := sw.handle {
		h.close()
		sw.handle = none
	}
}

pub fn (sw StateWatcher) is_polling() bool {
	if is_polling_forced() {
		return true
	}
	return true
}
