module agent_toolkit_server

import sync
import time

// ApiEvent is one entry of the global event stream (GET /api/v1/events).
// Schema: docs/compatibility/api-schemas.yaml#ApiEvent.
pub struct ApiEvent {
pub mut:
	seq       int
	boot      string
	kind      string @[json: 'type']
	at        string
	subject   string
	status    string
	exit_code int
	ref       string
	message   string
}

pub const api_event_types = ['backend.ready', 'backend.resync', 'job.created', 'job.updated',
	'job.deleted', 'loop.started', 'loop.finished', 'swarm.changed', 'memory.changed',
	'install.started', 'install.finished']

const event_bus_capacity = 512
const max_event_subscribers = 16

// EventBus is an in-memory, sequence-numbered ring of recent events.
// Subscribers poll by cursor instead of holding channels, so a slow or dead
// SSE client can never block publishers; a cursor older than the ring, or
// from another server process (different boot), gets a backend.resync and
// should refetch state.
@[heap]
pub struct EventBus {
pub:
	boot string
mut:
	mu          sync.Mutex
	events      []ApiEvent
	next_seq    int = 1
	capacity    int = event_bus_capacity
	subscribers int
}

pub fn new_event_bus() &EventBus {
	return &EventBus{
		boot: time.utc().unix_milli().str()
	}
}

// publish stamps seq/at on e, retains it, and returns the stored event.
pub fn (mut b EventBus) publish(e ApiEvent) ApiEvent {
	b.mu.lock()
	defer {
		b.mu.unlock()
	}
	mut ev := e
	ev.seq = b.next_seq
	ev.boot = b.boot
	ev.at = time.utc().format_rfc3339()
	b.next_seq++
	b.events << ev
	if b.events.len > b.capacity {
		b.events.delete_many(0, b.events.len - b.capacity)
	}
	return ev
}

// since returns retained events with seq > cursor. missed is true when the
// cursor predates the ring (or comes from an earlier server process), in
// which case every retained event is returned.
pub fn (mut b EventBus) since(cursor int) ([]ApiEvent, bool) {
	b.mu.lock()
	defer {
		b.mu.unlock()
	}
	last := b.next_seq - 1
	if cursor > last {
		return b.events.clone(), true
	}
	if b.events.len == 0 {
		return []ApiEvent{}, false
	}
	oldest := b.events[0].seq
	if cursor < oldest - 1 {
		return b.events.clone(), true
	}
	return b.events.filter(it.seq > cursor), false
}

pub fn (mut b EventBus) last_seq() int {
	b.mu.lock()
	defer {
		b.mu.unlock()
	}
	return b.next_seq - 1
}

// acquire reserves a subscriber slot; release must follow when the stream ends.
pub fn (mut b EventBus) acquire() bool {
	b.mu.lock()
	defer {
		b.mu.unlock()
	}
	if b.subscribers >= max_event_subscribers {
		return false
	}
	b.subscribers++
	return true
}

pub fn (mut b EventBus) release() {
	b.mu.lock()
	defer {
		b.mu.unlock()
	}
	if b.subscribers > 0 {
		b.subscribers--
	}
}

// event_matches reports whether kind passes a comma-separated filter of
// exact types or `prefix.` families (empty filter = everything).
pub fn event_matches(kind string, filter []string) bool {
	if filter.len == 0 {
		return true
	}
	for f in filter {
		if f == kind || (f.ends_with('.') && kind.starts_with(f)) {
			return true
		}
	}
	return false
}

// EventCursor is a parsed resume position. foreign is true when the cursor
// was issued by another server process, so nothing after it is known.
pub struct EventCursor {
pub:
	seq     int
	foreign bool
}

// parse_event_cursor parses a Last-Event-ID (`<boot>-<seq>`, as sent in SSE
// ids) or a bare `<seq>` from ?since (assumed to be this process). Empty = 0.
pub fn parse_event_cursor(raw string, boot string) !EventCursor {
	s := raw.trim_space()
	if s.len == 0 {
		return EventCursor{}
	}
	if s.contains('-') {
		epoch := s.all_before('-')
		seq := parse_event_seq(s.all_after('-'))!
		if !is_digits(epoch) {
			return error('invalid event cursor')
		}
		return EventCursor{
			seq: seq
			foreign: epoch != boot
		}
	}
	return EventCursor{
		seq: parse_event_seq(s)!
	}
}

fn parse_event_seq(s string) !int {
	if s.len == 0 || s.len > 9 || !is_digits(s) {
		return error('invalid event cursor')
	}
	return s.int()
}

fn is_digits(s string) bool {
	if s.len == 0 {
		return false
	}
	for ch in s {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return true
}

// event_sse_id is the SSE `id:` for ev, round-tripped by parse_event_cursor.
pub fn event_sse_id(ev ApiEvent) string {
	return '${ev.boot}-${ev.seq}'
}
