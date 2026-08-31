module activity

import desktop_engine.state as engine_state
import desktop_engine.eventbus

// ActivityEventKind enumerates ToolkitEvent types consumed by Journal.
pub enum ActivityEventKind {
	commit
	loop_tick
	job_log
	handoff
	approval
	budget
	doctor_fix
	install
	unknown
}

// kind_from_event maps ToolkitEventKind → ActivityEventKind.
pub fn kind_from_event(kind eventbus.ToolkitEventKind) ActivityEventKind {
	return match kind {
		.state_changed { .commit }
		.watcher_invalidated { .loop_tick }
		.process_log { .job_log }
		.process_exited { .install }
		else { .unknown }
	}
}

// ActivityRecord is one journal row (ts | type | entity | message) virtualized.
pub struct ActivityRecord {
pub:
	ts        i64
	kind      ActivityEventKind
	entity    string
	message   string
	dot_color string
	badge     string // loop/skill/job/swarm/doctor/target
}

// badge_for_kind returns badge per domain via tokens.
pub fn badge_for_kind(k ActivityEventKind) string {
	return match k {
		.commit { 'commit' }
		.loop_tick { 'loop' }
		.job_log { 'job' }
		.handoff { 'swarm' }
		.approval { 'swarm' }
		.budget { 'budget' }
		.doctor_fix { 'doctor' }
		.install { 'target' }
		else { 'unknown' }
	}
}

// dot_color per domain via tokens #1017.
pub fn dot_color(k ActivityEventKind) string {
	return match k {
		.commit { '#16a34a' }
		.loop_tick { '#7c3aed' }
		.job_log { '#0891b2' }
		.handoff { '#dc2626' }
		.approval { '#eab308' }
		.budget { '#ea580c' }
		.doctor_fix { '#e11d48' }
		.install { '#0e7490' }
		else { '#64748b' }
	}
}

// ActivityJournal is the World View timeline/journal wall.
pub struct ActivityJournal {
mut:
	records  []ActivityRecord
	index    map[string]int // entity_id → last record idx for cross-link
	bus      &eventbus.ToolkitEventBus
	repo     &engine_state.StateRepository
	revision u64
	emitted  u64
	dropped  u64
}

// JournalViewModel is derived for wall + timeline scrubber.
pub struct JournalViewModel {
pub:
	revision u64
	records  []ActivityRecord
	dot_map  map[string]string // dot index → entity_id
	total    int
}

// new_activity_journal creates journal bound to repo/bus with replay backfill.
pub fn new_activity_journal(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &ActivityJournal {
	mut j := &ActivityJournal{
		bus: bus
		repo: repo
		index: map[string]int{}
	}
	// backfill from EventBus replay log on launch (no missed history)
	if ev := bus.replay_for(.state_changed) {
		j.append_from_event(ev, 0)
	}
	if ev := bus.replay_for(.process_log) {
		j.append_from_event(ev, 0)
	}
	return j
}

// append_from_event converts ToolkitEvent → ActivityRecord (distinct-until-changed).
pub fn (mut j ActivityJournal) append_from_event(ev eventbus.ToolkitEvent, ts i64) bool {
	kind := kind_from_event(ev.kind)
	// distinct-until-changed: duplicate revision or duplicate payload suppresses rebuild
	if j.records.len > 0 {
		last := j.records[j.records.len - 1]
		if last.entity == ev.path && last.message == ev.payload && j.revision == ev.revision {
			j.dropped++
			return false
		}
	}
	rec := ActivityRecord{
		ts: if ts == 0 { 1000 + j.records.len } else { ts }
		kind: kind
		entity: ev.path
		message: ev.payload
		dot_color: dot_color(kind)
		badge: badge_for_kind(kind)
	}
	j.records << rec
	j.index[ev.path] = j.records.len - 1
	j.revision = ev.revision
	j.emitted++
	return true
}

// on_bus_event handles ToolkitEvent → Journal append within one EventBus→frame tick.
pub fn (mut j ActivityJournal) on_bus_event(ev eventbus.ToolkitEvent) bool {
	ts := ev.revision
	return j.append_from_event(ev, i64(ts))
}

// current returns view model newest-top.
pub fn (j ActivityJournal) current() JournalViewModel {
	mut rev_records := []ActivityRecord{cap: j.records.len}
	for i := j.records.len - 1; i >= 0; i-- {
		rev_records << j.records[i]
	}
	mut dot_map := map[string]string{}
	for i, r in j.records {
		dot_map[i.str()] = r.entity
	}
	return JournalViewModel{
		revision: j.revision
		records: rev_records
		dot_map: dot_map
		total: j.records.len
	}
}

// filter_by returns debounced search/filter by type/entity/project.
pub fn (j ActivityJournal) filter_by(kind ActivityEventKind, entity string) []ActivityRecord {
	mut out := []ActivityRecord{}
	for r in j.records {
		if kind != .unknown && r.kind != kind {
			continue
		}
		if entity != '' && r.entity != entity {
			continue
		}
		out << r
	}
	return out
}

// highlight_entity checks cross-link dot→canvas entity existence.
pub fn (j ActivityJournal) highlight_entity(dot_index int) string {
	key := dot_index.str()
	if entity := j.current().dot_map[key] {
		return entity
	}
	return ''
}

// virtualized_window returns culling window for 5k events (bounded draw calls).
pub fn (j ActivityJournal) virtualized_window(viewport_h int, row_h int, scroll_offset int) ([]ActivityRecord, int) {
	total := j.records.len
	rows_in_view := viewport_h / row_h + 2
	start := scroll_offset / row_h
	if start < 0 {
		start = 0
	}
	if start > total {
		start = total
	}
	end := start + rows_in_view
	if end > total {
		end = total
	}
	mut window := []ActivityRecord{}
	for i in start .. end {
		window << j.records[i]
	}
	draw_calls := window.len * 2
	return window, draw_calls
}

// culling_draw_calls returns bounded draw calls (not total).
pub fn (j ActivityJournal) culling_draw_calls(viewport_h int) int {
	_, dc := j.virtualized_window(viewport_h, 24, 0)
	return dc
}

// distinct_until_changed check for identical State revision.
pub fn (mut j ActivityJournal) distinct_check(revision u64) bool {
	if revision == j.revision {
		return false
	}
	j.revision = revision
	return true
}
