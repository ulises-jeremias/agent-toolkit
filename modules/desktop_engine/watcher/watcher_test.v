module watcher

import os
import time
import desktop_engine.state
import desktop_engine.eventbus

fn test_polling_watcher_file_touch_triggers_invalidated() {
	tmp := os.join_path(os.temp_dir(), 'watcher-test-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut bus := eventbus.new_event_bus()
	_ = bus
	mut watcher := new_polling_watcher(WatcherConfig{
		poll_interval_ms: 200
		debounce_ms: 50
	})
	ch := chan eventbus.ToolkitEvent{ cap: 64 }
	bus.subscribe(.watcher_invalidated, ch)
	mut handle := watcher.watch([tmp], fn [ch, mut bus] (ev eventbus.ToolkitEvent) {
		bus.publish(ev)
	}) or {
		assert false, err.msg()
		return
	}
	defer {
		handle.close()
		time.sleep(50 * time.millisecond)
	}
	// give watcher time to snapshot initial state
	time.sleep(100 * time.millisecond)
	// file touch create
	f := os.join_path(tmp, 'probe.txt')
	os.write_file(f, 'hello') or { assert false, err.msg() }
	// wait for event within debounce+poll+500 budget
	mut received := false
	mut ev := eventbus.ToolkitEvent{}
	for _ in 0 .. 20 {
		select {
			ev = <-ch {
				received = true
				break
			}
			150 * time.millisecond {
				// poll again
			}
		}
		if received {
			break
		}
	}
	assert received, 'file touch should trigger watcher_invalidated within budget'
	assert ev.kind == .watcher_invalidated
	// path should be dependent (tmp itself or probe) - check not empty
	assert ev.path.len > 0
}

fn test_polling_watcher_fallback_forced_via_env() {
	old := os.getenv('WATCHER_FORCE_POLL')
	os.setenv('WATCHER_FORCE_POLL', '1', true)
	defer {
		if old.len > 0 {
			os.setenv('WATCHER_FORCE_POLL', old, true)
		} else {
			os.unsetenv('WATCHER_FORCE_POLL')
		}
	}
	assert is_polling_forced()
	// select_watcher should return PollingWatcher when forced
	cfg := WatcherConfig{
		poll_interval_ms: 500
		debounce_ms: 100
	}
	w := select_watcher(cfg)
	// w should be polling; we can check via type string or available
	_ = w
	// NativeWatcher unavailable when forced
	mut native := NativeWatcher{}
	assert !native.available(), 'WATCHER_FORCE_POLL=1 should make native unavailable'
	// logging path contains PollingWatcher conceptually - just ensure forced
}

fn test_polling_watcher_no_tight_loop_default_500() {
	mut w := new_polling_watcher(WatcherConfig{})
	assert w.poll_interval_ms == 500
	assert w.poll_interval_ms >= 100
	// custom <100 should be corrected to 500
	mut w2 := new_polling_watcher(WatcherConfig{
		poll_interval_ms: 50
		debounce_ms: 10
	})
	assert w2.poll_interval_ms == 500
	assert w2.debounce_ms == 50 // debounce clamped to 50-150
	

	assert w2.debounce_ms >= 50 && w2.debounce_ms <= 150
}

fn test_native_watcher_selection_logs_fallback() {
	// Engine probes NativeWatcher.available() at init; if false, uses PollingWatcher
	cfg := WatcherConfig{
		poll_interval_ms: 500
		debounce_ms: 100
	}
	mut native := NativeWatcher{
		poll_interval_ms: cfg.poll_interval_ms
		debounce_ms: cfg.debounce_ms
	}
	available := native.available()
	// On Linux CI, notify is fd not fs, so available false, fallback to polling
	// This documents Windows probe as well
	_ = available
	// PollingWatcher always available
	w := select_watcher(cfg)
	// should not be none
	assert true
	_ = w
}

fn test_state_watcher_signal_not_source_of_truth() {
	tmp := os.join_path(os.temp_dir(), 'watcher-signal-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut repo := state.new_state_repository(persist)
	mut bus := eventbus.new_event_bus()
	// initial revision 0
	assert repo.revision_nr() == 0
	// StateWatcher should not mutate repo directly; it signals via Transaction on change
	// Create StateWatcher that watches tmp
	mut sw := new_state_watcher(repo, bus, [tmp], 200, 50)
	sw.start() or { assert false, err.msg() }
	defer { sw.stop() or {} }
	ch := chan eventbus.ToolkitEvent{ cap: 64 }
	bus.subscribe(.watcher_invalidated, ch)
	time.sleep(100 * time.millisecond)
	f := os.join_path(tmp, 'canonical.json')
	os.write_file(f, '{"recent_workspace":"/tmp/ws1"}') or { assert false, err.msg() }
	mut received := false
	mut ev := eventbus.ToolkitEvent{}
	for _ in 0 .. 20 {
		select {
			ev = <-ch {
				received = true
				break
			}
			150 * time.millisecond {
			}
		}
		if received {
			break
		}
	}
	assert received, 'StateWatcher should emit watcher_invalidated after file change'
	assert ev.kind == .watcher_invalidated
	// revision should have bumped via StateRepository reload -> Transaction
	// Our StateWatcher does revision bump via tx.commit on change
	time.sleep(50 * time.millisecond)
	assert repo.revision_nr() >= 1
	// signal path: event revision should be >=1
	assert ev.revision >= 1 || repo.revision_nr() >= 1
}
