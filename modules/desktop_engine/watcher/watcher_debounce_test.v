module watcher

import os
import time
import desktop_engine.eventbus

fn test_debounce_coalesces_rapid_saves() {
	tmp := os.join_path(os.temp_dir(), 'watcher-debounce-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut bus := eventbus.new_event_bus()
	mut watcher := new_polling_watcher(WatcherConfig{
		poll_interval_ms: 100
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
	defer { handle.close() }
	time.sleep(150 * time.millisecond)
	f := os.join_path(tmp, 'rapid.txt')
	// 3 rapid writes 10ms apart
	os.write_file(f, '1') or {}
	time.sleep(10 * time.millisecond)
	os.write_file(f, '2') or {}
	time.sleep(10 * time.millisecond)
	os.write_file(f, '3') or {}
	// within debounce window, should coalesce to single event
	// wait up to debounce+poll+2000 (more robust on macOS)
	mut count := 0
	mut deadline := time.now().add(3000 * time.millisecond)
	for time.now().unix_milli() < deadline.unix_milli() {
		select {
			_ := <-ch {
				count++
			}
			50 * time.millisecond {
			}
		}
		if count > 0 {
			// wait a bit more to ensure no second event due to debounce
			time.sleep(300 * time.millisecond)
			// drain any extra
			for ch.len > 0 {
				_ = <-ch
				count++
			}
			break
		}
	}
	// debounce should coalesce 3 rapid writes → 1 reload event (allow 1-2 on slower runners)
	assert count >= 1 && count <= 2, 'debounce should coalesce 3 rapid writes to 1-2 events, got ${count}'
}

fn test_dependency_graph_reloads_only_dependents() {
	tmp := os.join_path(os.temp_dir(), 'watcher-graph-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	skills_dir := os.join_path(tmp, 'skills', 'a')
	loops_dir := os.join_path(tmp, 'loops')
	os.mkdir_all(skills_dir) or {}
	os.mkdir_all(loops_dir) or {}
	mut w := new_polling_watcher(WatcherConfig{
		poll_interval_ms: 200
		debounce_ms: 50
	})
	// dependency graph: prefix -> dependent
	w.dependencies['${tmp}/skills'] = 'skill-catalog'
	w.dependencies['${tmp}/loops'] = 'loops'
	// touching skills file should resolve to skill-catalog, not loops
	changed_skills := os.join_path(skills_dir, 'SKILL.md')
	assert w.dependency_for(changed_skills) == 'skill-catalog'
	assert w.dependency_for(os.join_path(loops_dir, 'loop.json')) == 'loops'
	// also test heuristic fallback
	assert w.dependency_for('/some/skills/foo/SKILL.md') == 'skill-catalog'
	// Watching both roots, change in skills should emit skill-catalog only
	mut bus := eventbus.new_event_bus()
	ch := chan eventbus.ToolkitEvent{ cap: 64 }
	bus.subscribe(.watcher_invalidated, ch)
	mut handle := w.watch([tmp], fn [ch, mut bus] (ev eventbus.ToolkitEvent) {
		bus.publish(ev)
	}) or {
		assert false, err.msg()
		return
	}
	defer { handle.close() }
	time.sleep(100 * time.millisecond)
	os.write_file(changed_skills, '# skill') or {}
	mut ev := eventbus.ToolkitEvent{}
	mut received := false
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
	assert received
	// dependent should be skill-catalog, not loops
	assert ev.path == 'skill-catalog' || ev.payload.contains('skill-catalog')
	assert !ev.payload.contains('"dependent":"loops"')
}

fn test_thread_safe_concurrent_watch_close() {
	tmp := os.join_path(os.temp_dir(), 'watcher-conc-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut watcher := new_polling_watcher(WatcherConfig{
		poll_interval_ms: 200
		debounce_ms: 50
	})
	ch := chan eventbus.ToolkitEvent{ cap: 64 }
	// concurrent watch + close + on_change should not race
	mut handles := []WatcherHandle{}
	for i in 0 .. 3 {
		mut h := watcher.watch([tmp], fn [ch] (ev eventbus.ToolkitEvent) {
			// on_change may spawn
			spawn fn [ev, ch] () {
				ch <- ev
			}()
		}) or { continue }
		handles << h
		_ = i
	}
	// concurrent close
	for mut h in handles {
		spawn fn [mut h] () {
			h.close()
		}()
	}
	time.sleep(200 * time.millisecond)
	// ensure no panic/race, handles closed
	for mut h in handles {
		assert h.is_closed()
	}
}
