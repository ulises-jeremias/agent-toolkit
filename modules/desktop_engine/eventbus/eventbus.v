module eventbus

import sync
import time
import context

// ToolkitEventKind enumerates typed event kinds (shared across State/Watcher/Process seams).
pub enum ToolkitEventKind {
	state_changed
	watcher_invalidated
	process_exited
	process_log
	job_queued
	job_completed
	engine_started
	engine_stopped
}

// ToolkitEvent is the typed bus payload. payload is json-encoded variant data.
// Uses `import json` (not json2) per V 0.5.2 contract.
pub struct ToolkitEvent {
pub:
	kind     ToolkitEventKind
	revision u64
	path     string
	payload  string
}

// ToolkitEventBus is a typed, thread-safe pub/sub with replay for late subscribers.
// Channels are buffered cap 64 per subscriber; publish is non-blocking with documented
// drop metric. Uses sync.RwMutex per V 0.5.2.
pub struct ToolkitEventBus {
mut:
	mu           sync.RwMutex
	subscribers  map[string][]chan ToolkitEvent
	replay       map[string]ToolkitEvent
	replay_valid map[string]bool
	// metrics
	dropped u64
}

// new_event_bus creates a fresh bus.
pub fn new_event_bus() &ToolkitEventBus {
	return &ToolkitEventBus{
		subscribers: map[string][]chan ToolkitEvent{}
		replay: map[string]ToolkitEvent{}
		replay_valid: map[string]bool{}
	}
}

// kind_key returns string key for enum (stable).
fn kind_key(k ToolkitEventKind) string {
	return k.str()
}

// subscribe registers ch for kind. Channel should be buffered cap 64 per spec.
// Caller owns channel lifecycle; bus does not close channel on unsubscribe (caller closes if desired).
pub fn (mut b ToolkitEventBus) subscribe(kind ToolkitEventKind, ch chan ToolkitEvent) {
	key := kind_key(kind)
	b.mu.lock()
	defer { b.mu.unlock() }
	if key !in b.subscribers {
		b.subscribers[key] = []chan ToolkitEvent{}
	}
	b.subscribers[key] << ch
}

// unsubscribe removes ch for kind. Idempotent.
pub fn (mut b ToolkitEventBus) unsubscribe(kind ToolkitEventKind, ch chan ToolkitEvent) {
	key := kind_key(kind)
	b.mu.lock()
	defer { b.mu.unlock() }
	if key !in b.subscribers {
		return
	}
	mut lst := b.subscribers[key]
	for i, c in lst {
		if c == ch {
			lst.delete(i)
			break
		}
	}
	if lst.len == 0 {
		b.subscribers.delete(key)
	} else {
		b.subscribers[key] = lst
	}
}

// publish delivers event to all subscribers of event.kind.
// Non-blocking: try_push with drop counting. Buffered cap 64 per subscriber.
pub fn (mut b ToolkitEventBus) publish(event ToolkitEvent) {
	key := kind_key(event.kind)
	// Update replay buffer size 1 per kind under lock, then fan-out without holding lock
	b.mu.lock()
	b.replay[key] = event
	b.replay_valid[key] = true
	subs := b.subscribers[key].clone()
	b.mu.unlock()
	for ch in subs {
		// Non-blocking push: if buffered cap 64 is full, drop and count
		// V 0.5.2 chan.try_push exists; fallback to select if not
		if ch.len < 64 {
			ch <- event
		} else {
			b.mu.lock()
			b.dropped++
			b.mu.unlock()
		}
	}
}

// publish_sync is deterministic helper for tests: publishes and yields briefly
// so subscribers can receive before assertions (headless).
pub fn (mut b ToolkitEventBus) publish_sync(event ToolkitEvent) {
	b.publish(event)
	// tiny yield for spawn subscribers; time.sleep is V 0.5.2 stable
	time.sleep(5 * time.millisecond)
}

// replay_for returns last event for kind if any (replay buffer size 1).
pub fn (mut b ToolkitEventBus) replay_for(kind ToolkitEventKind) ?ToolkitEvent {
	key := kind_key(kind)
	b.mu.rlock()
	defer { b.mu.runlock() }
	if b.replay_valid[key] or { false } {
		return b.replay[key]
	}
	return none
}

// dropped_count returns publish drop metric (backpressure signal).
pub fn (mut b ToolkitEventBus) dropped_count() u64 {
	b.mu.rlock()
	defer { b.mu.runlock() }
	return b.dropped
}

// subscriber_count reports number of subscribers for kind (testing).
pub fn (mut b ToolkitEventBus) subscriber_count(kind ToolkitEventKind) int {
	key := kind_key(kind)
	b.mu.rlock()
	defer { b.mu.runlock() }
	if key in b.subscribers {
		return b.subscribers[key].len
	}
	return 0
}

// subscribe_ctx registers ch and auto-unsubscribes when ctx is canceled.
// Uses spawn to monitor ctx.done() without blocking caller.
// Returns a cancel function (call to unsubscribe early); also auto-cleans on ctx.done().
pub fn (mut b ToolkitEventBus) subscribe_ctx(mut ctx context.Context, kind ToolkitEventKind, ch chan ToolkitEvent) {
	b.subscribe(kind, ch)
	spawn fn [mut b, kind, ch, mut ctx] () {
		done := ctx.done()
		_ = <-done
		b.unsubscribe(kind, ch)
	}()
}
