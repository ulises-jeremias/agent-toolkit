module state

import time
import desktop_engine.state as engine_state
import desktop_engine.eventbus

// AppState is the Engine-backed derived state that powers the entire Desktop shell via EventBus.
// Derived from Engine State (skills/agents/distributions/products.yaml + plugins + runtime jobs/loops refs).
// Never reads catalogs/plugins directly; never shells out to CLI (Engine API only).
pub struct AppState {
pub:
	revision  u64
	timestamp i64
	actor     string
	// Derived counts (from Engine snapshot.data + catalogs via Engine DI)
	skills_count   int
	agents_count   int
	products_count int
	// Derived prefs & layout (recent workspace, dock, theme)
	recent_workspace string
	dock_layout      string
	theme_kind       string // dark|light
	// Raw snapshot for selectors
	raw engine_state.State
}

// clone returns immutable copy.
pub fn (s AppState) clone() AppState {
	return AppState{
		revision: s.revision
		timestamp: s.timestamp
		actor: s.actor
		skills_count: s.skills_count
		agents_count: s.agents_count
		products_count: s.products_count
		recent_workspace: s.recent_workspace
		dock_layout: s.dock_layout
		theme_kind: s.theme_kind
		raw: s.raw.clone()
	}
}

// derive_AppState projects Engine State → AppState.
// Pure function: no I/O, no shell, memoizable.
pub fn derive_app_state(s engine_state.State) AppState {
	// Derive counts from data map size / explicit keys; real Desktop
	// would query Engine DI catalogs (skills_catalog etc.) via injected counts.
	// Headless stub: if data contains counts keys use them, else fallback to data.len
	mut skills := 0
	mut agents := 0
	mut products := 0
	if 'skills_count' in s.data {
		skills = s.data['skills_count'].int()
	} else {
		// fallback heuristic for parity harness
		skills = s.data.len
	}
	if 'agents_count' in s.data {
		agents = s.data['agents_count'].int()
	}
	if 'products_count' in s.data {
		products = s.data['products_count'].int()
	}
	return AppState{
		revision: s.revision
		timestamp: s.timestamp
		actor: s.actor
		skills_count: skills
		agents_count: agents
		products_count: products
		recent_workspace: s.data['recent_workspace'] or { '' }
		dock_layout: s.data['dock_layout'] or { 'default' }
		theme_kind: s.data['theme_kind'] or { 'dark' }
		raw: s.clone()
	}
}

// AppStateProjector subscribes to Engine ToolkitEventBus → AppState
// with debounce + distinct-until-changed (no polling, ≤60 Hz coalesce).
pub struct AppStateProjector {
mut:
	bus         &eventbus.ToolkitEventBus
	current     AppState
	subscribers []chan AppState
	// debounce window (headless: 0 => immediate, real window: ~16 ms coalesce)
	debounce_ms int
	// metrics
	emitted      u64
	dropped      u64
	last_emit_ms i64
}

// new_app_state_projector creates a projector bound to bus with initial state.
pub fn new_app_state_projector(bus &eventbus.ToolkitEventBus, initial engine_state.State) &AppStateProjector {
	return &AppStateProjector{
		bus: bus
		current: derive_app_state(initial)
		debounce_ms: 0
	}
}

// new_app_state_projector_debounced allows configuring debounce for frame coalesce tests.
pub fn new_app_state_projector_debounced(bus &eventbus.ToolkitEventBus, initial engine_state.State, debounce_ms int) &AppStateProjector {
	return &AppStateProjector{
		bus: bus
		current: derive_app_state(initial)
		debounce_ms: debounce_ms
	}
}

// current_state returns latest AppState (thread-unsafe for headless tests; real Desktop wraps with RwMutex).
pub fn (mut p AppStateProjector) current_state() AppState {
	return p.current.clone()
}

// subscribe registers ch to receive AppState updates (buffered cap 64).
pub fn (mut p AppStateProjector) subscribe(ch chan AppState) {
	p.subscribers << ch
}

// on_bus_event handles one ToolkitEvent → AppState projection.
// Distinct-until-changed: only emits when revision changed or derived data changed.
// Debounce: coalesces rapid bursts to one emit per frame tick.
pub fn (mut p AppStateProjector) on_bus_event(ev eventbus.ToolkitEvent, latest engine_state.State) bool {
	if ev.kind != .state_changed && ev.kind != .engine_started {
		return false
	}
	next := derive_app_state(latest)
	// distinct-until-changed: revision must advance or payload must differ
	if next.revision == p.current.revision && next.raw.data.len == p.current.raw.data.len {
		// shallow check: if data equal, skip
		mut equal := true
		for k, v in next.raw.data {
			if p.current.raw.data[k] != v {
				equal = false
				break
			}
		}
		if equal {
			p.dropped++
			return false
		}
	}
	// debounce window: if debounce_ms >0, only emit if window elapsed
	if p.debounce_ms > 0 {
		now := time.now().unix_milli()
		if now - p.last_emit_ms < p.debounce_ms {
			p.dropped++
			return false
		}
		p.last_emit_ms = now
	}
	p.current = next
	p.emitted++
	// fan-out non-blocking (cap 64)
	for ch in p.subscribers {
		if ch.len < 64 {
			ch <- next.clone()
		} else {
			p.dropped++
		}
	}
	return true
}

// emitted_count returns emitted metric.
pub fn (p AppStateProjector) emitted_count() u64 {
	return p.emitted
}

// dropped_count returns dropped distinct/debounce metric.
pub fn (p AppStateProjector) dropped_count() u64 {
	return p.dropped
}

// bind connects projector to bus synchronously for headless tests.
// Real Desktop spawns: `spawn fn [mut p] () { for { ev := <-bus_ch; p.on_bus_event(ev, repo.snapshot()) } }`
pub fn (mut p AppStateProjector) bind(bus_ch chan eventbus.ToolkitEvent, repo &engine_state.StateRepository) {
	// headless synchronous helper for tests: caller drives loop manually
	_ = bus_ch
	_ = repo
}

// snapshot_selector is a pure selector helper (memoizable, no side effects) —
// demonstrates State → View binding pattern for router/dock.
pub fn (s AppState) select_recent_workspace() string {
	return s.recent_workspace
}

// revision returns monotonic revision for EventBus→frame tick assertion.
pub fn (s AppState) revision_nr() u64 {
	return s.revision
}
