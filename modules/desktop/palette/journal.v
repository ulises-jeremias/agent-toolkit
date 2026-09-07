module palette

// S4D (#1119) — truthful Recent Actions + evidence-backed Undo.
//
// The registry owns ONE canonical execution journal. A record is appended
// only after an action's real execution seam has actually run — never for
// validation failures, unavailable/unconfirmed outcomes, previews,
// navigation or inspection. Two execution planes are legitimate:
//
//   Engine/core actions  → Registry.execute() → real seam → record result
//   Shell-native actions → shell typed handler → real shell setter →
//                          registry.record_execution()
//
// Undo exists only where the exact previous authoritative state is known and
// an exact typed restore seam exists. Every undo performs an optimistic
// exact-state check first: current state must equal the state recorded right
// after the action; any divergence makes the undo stale (state changed — it
// must never overwrite newer changes). Undo is single-use: available →
// consumed on success, available → stale on divergence, stale stays stale.
// No redo.
//
// Governing contracts: docs/desktop/TRUTH_LEDGER.md, docs/desktop/DESIGN.md.

import desktop_engine
import time

// UndoKind identifies the typed undo variant.
pub enum UndoKind {
	target_enabled
	skill_selection
	mcp_state
	loop_schedule
	appearance
}

// UndoStatus is the lifecycle of one undo capability: available → consumed
// (successful restoration) or available → stale (state diverged). Stale is
// terminal — no automatic re-enable. No redo.
pub enum UndoStatus {
	available
	consumed
	stale
	unsupported
}

// TargetEnabledUndo restores the exact prior enabled boolean.
pub struct TargetEnabledUndo {
pub mut:
	entity_id        string
	previous_enabled bool
	expected_enabled bool
}

// SkillsSelectionUndo restores the exact prior installed-skill selection.
pub struct SkillsSelectionUndo {
pub mut:
	previous_selection []string
	expected_selection []string
}

// McpStateUndo restores the exact prior provider state via the narrow
// Engine restore seam. The snapshot is opaque: session-local only, never
// displayed, logged, serialized or put in RecentAction metadata.
pub struct McpStateUndo {
pub mut:
	entity_id string
	snapshot  desktop_engine.McpStateSnapshot
	expected  desktop_engine.McpStateSnapshot
}

// LoopScheduleUndo restores the exact prior cron configuration.
pub struct LoopScheduleUndo {
pub mut:
	entity_id     string
	previous_cron bool
	expected_cron bool
}

// AppearanceUndo restores the exact prior appearance via the real shell
// setter (apply_appearance + save_ui_state). The appearance is stored as
// its canonical name ('paper'|'ink'|'system') — the shell parses it.
pub struct AppearanceUndo {
pub mut:
	previous_appearance string
	expected_appearance string
}

// UndoSpec is the typed reversal description. Domain variants — never CLI
// fragments, never a generic map.
pub type UndoSpec = TargetEnabledUndo
	| SkillsSelectionUndo
	| McpStateUndo
	| LoopScheduleUndo
	| AppearanceUndo

// UndoEntry pairs a spec with its lifecycle status.
pub struct UndoEntry {
pub:
	kind        UndoKind
	action_kind ActionKind
	entity_kind EntityKind
	entity_id   string
	label       string
	spec        UndoSpec
mut:
	status UndoStatus = .available
}

// RecentAction is one truthful execution record. Outcomes are only
// succeeded / partial / failed — an execution seam actually ran.
pub struct RecentAction {
pub:
	execution_id u64
	timestamp    i64 // unix seconds, from the actual execution
	action_kind  ActionKind
	entity_kind  EntityKind
	entity_id    string
	label        string // safe display label
	workspace    string // workspace context when applicable
	outcome      ActionStatus
	evidence     ActionEvidence // only refs the action really produced
	has_undo     bool
pub mut:
	undo UndoEntry
}

// is_undoable reports whether the record currently offers undo (rendering
// additionally runs undo_precheck for the live optimistic check).
pub fn (ra RecentAction) is_undoable() bool {
	return ra.has_undo && ra.undo.status == .available
}

// UndoOutcome reports the result of an undo attempt truthfully.
pub struct UndoOutcome {
pub:
	status  UndoStatus
	summary string
}

// recents_limit bounds the session-local journal. Bounded by design: a long
// Desktop session never accumulates an unbounded execution log.
pub const recents_limit = 25

// record_execution appends a truthful execution record to the journal.
// The caller must provide registry-real action/entity identity, and only
// after the actual execution seam ran. Shell-native actions (appearance)
// use this path; the journal itself never invents activity.
pub fn (mut r Registry) record_execution(action_kind ActionKind, entity_kind EntityKind, entity_id string, label string, outcome ActionStatus, evidence ActionEvidence, undo ?UndoEntry) u64 {
	if outcome !in [.succeeded, .partial, .failed] {
		return 0
	}
	r.undo_seq++
	exec_id := r.undo_seq
	u := undo or { UndoEntry{} }
	has := undo != none
	rec := RecentAction{
		execution_id: exec_id
		timestamp: time.now().unix()
		action_kind: action_kind
		entity_kind: entity_kind
		entity_id: entity_id
		label: label
		outcome: outcome
		evidence: evidence
		has_undo: has
		undo: u
	}
	r.journal.prepend(rec)
	for r.journal.len > recents_limit {
		r.journal.delete(r.journal.len - 1)
	}
	return exec_id
}

// journal_records returns the session journal (newest first).
pub fn (r Registry) journal_records() []RecentAction {
	return r.journal.clone()
}

// find_recent locates a record by execution id.
pub fn (r Registry) find_recent(execution_id u64) ?RecentAction {
	for rec in r.journal {
		if rec.execution_id == execution_id {
			return rec
		}
	}
	return none
}

fn (r Registry) recent_index(execution_id u64) ?int {
	for idx, rec in r.journal {
		if rec.execution_id == execution_id {
			return idx
		}
	}
	return none
}

// ── state readers (the exact authoritative values) ─────────────────────────

fn (mut r Registry) engine_loop_cron(name string) bool {
	for l in r.engine.loops_catalog() {
		if l.name == name {
			return l.cron_enabled
		}
	}
	return false
}

// ── capture: previous state before a mutating seam runs ────────────────────

// capture_undo reads the exact previous authoritative state for an action
// that is about to execute its seam. Returns none when the action is not
// reversible (irreversible / read-only) — such actions never get undo.
fn (mut r Registry) capture_undo(action_kind ActionKind, entity_id string) ?UndoEntry {
	match action_kind {
		.target_enable {
			previous := r.engine_target_enabled(entity_id)
			return UndoEntry{
				kind: .target_enabled
				action_kind: action_kind
				entity_kind: .target
				entity_id: entity_id
				label: 'Enable target ${entity_id}'
				spec: TargetEnabledUndo{
					entity_id: entity_id
					previous_enabled: previous
					expected_enabled: true
				}
			}
		}
		.target_disable {
			previous := r.engine_target_enabled(entity_id)
			return UndoEntry{
				kind: .target_enabled
				action_kind: action_kind
				entity_kind: .target
				entity_id: entity_id
				label: 'Disable target ${entity_id}'
				spec: TargetEnabledUndo{
					entity_id: entity_id
					previous_enabled: previous
					expected_enabled: false
				}
			}
		}
		.skill_install, .skill_remove {
			label := if action_kind == .skill_install {
				'Install skill ${entity_id}'
			} else {
				'Remove skill ${entity_id}'
			}
			return UndoEntry{
				kind: .skill_selection
				action_kind: action_kind
				entity_kind: .skill
				entity_id: entity_id
				label: label
				spec: SkillsSelectionUndo{
					previous_selection: r.engine.skills_installed()
					expected_selection: []string{}
				}
			}
		}
		.mcp_enable, .mcp_disable {
			snap := r.engine.mcp_state_snapshot(entity_id) or {
				// nothing to restore — undo unavailable for this execution
				return none
			}
			label := if action_kind == .mcp_enable {
				'Enable MCP ${entity_id}'
			} else {
				'Disable MCP ${entity_id}'
			}
			return UndoEntry{
				kind: .mcp_state
				action_kind: action_kind
				entity_kind: .mcp_provider
				entity_id: entity_id
				label: label
				spec: McpStateUndo{
					entity_id: entity_id
					snapshot: snap
					expected: desktop_engine.McpStateSnapshot{}
				}
			}
		}
		.loop_schedule_toggle {
			previous := r.engine_loop_cron(entity_id)
			return UndoEntry{
				kind: .loop_schedule
				action_kind: action_kind
				entity_kind: .loop_template
				entity_id: entity_id
				label: 'Toggle schedule ${entity_id}'
				spec: LoopScheduleUndo{
					entity_id: entity_id
					previous_cron: previous
					expected_cron: !previous
				}
			}
		}
		else {
			return none
		}
	}
}

// finish_undo_expected fills the expected post-state of an undo entry from
// the ACTUAL state the Engine reports after the action ran — the optimistic
// guard later compares exact truth, never assumptions.
fn finish_undo_expected(ue UndoEntry, mut r Registry) UndoEntry {
	mut spec := ue.spec
	match mut spec {
		TargetEnabledUndo {
			spec.expected_enabled = r.engine_target_enabled(ue.entity_id)
		}
		SkillsSelectionUndo {
			spec.expected_selection = r.engine.skills_installed()
		}
		McpStateUndo {
			spec.expected = r.engine.mcp_state_snapshot(ue.entity_id) or {
				desktop_engine.McpStateSnapshot{}
			}
		}
		LoopScheduleUndo {
			spec.expected_cron = r.engine_loop_cron(ue.entity_id)
		}
		else {}
	}
	return UndoEntry{
		kind: ue.kind
		action_kind: ue.action_kind
		entity_kind: ue.entity_kind
		entity_id: ue.entity_id
		label: ue.label
		spec: spec
	}
}

// ── undo execution ─────────────────────────────────────────────────────────

// undo_precheck reports whether an undo would currently be allowed — the
// optimistic exact-state check, run before any user commits to it. Used by
// rendering so a stale undo is visible as unavailable without executing.
pub fn (mut r Registry) undo_precheck(execution_id u64) UndoStatus {
	rec := r.find_recent(execution_id) or {
		return .unsupported
	}
	if !rec.has_undo {
		return .unsupported
	}
	if rec.undo.status != .available {
		return rec.undo.status
	}
	if !r.undo_state_matches(rec.undo) {
		return .stale
	}
	return .available
}

// undo_state_matches performs the optimistic exact-state verification: the
// affected authoritative state must equal the state recorded right after the
// action ran. Never the global revision alone — unrelated changes may
// legitimately bump it.
fn (mut r Registry) undo_state_matches(ue UndoEntry) bool {
	match ue.spec {
		TargetEnabledUndo {
			return r.engine_target_enabled(ue.entity_id) == ue.spec.expected_enabled
		}
		SkillsSelectionUndo {
			return r.engine.skills_installed() == ue.spec.expected_selection
		}
		McpStateUndo {
			cur := r.engine.mcp_state_snapshot(ue.entity_id) or {
				desktop_engine.McpStateSnapshot{}
			}
			return cur.config == ue.spec.expected.config && cur.enabled == ue.spec.expected.enabled
				&& cur.health == ue.spec.expected.health
				&& cur.provenance == ue.spec.expected.provenance
		}
		LoopScheduleUndo {
			return r.engine_loop_cron(ue.entity_id) == ue.spec.expected_cron
		}
		AppearanceUndo {
			// the shell verifies appearance equality at execution time
			return true
		}
	}
}

// execute_undo restores the exact previous state for an executed action.
// Single-use, guarded by the optimistic exact-state check; the undo itself
// is recorded as a real execution ('Undid …') with no undo of its own.
// Appearance undo is executed by the shell (real setter) — the registry
// refuses to fake it.
pub fn (mut r Registry) execute_undo(execution_id u64) !UndoOutcome {
	idx := r.recent_index(execution_id) or {
		return error('no such execution record')
	}
	if !r.journal[idx].has_undo {
		return error('this action has no undo')
	}
	if r.journal[idx].undo.status != .available {
		return UndoOutcome{
			status: r.journal[idx].undo.status
			summary: match r.journal[idx].undo.status {
				.consumed { 'already undone' }
				.stale { 'State changed since this action; cannot safely undo.' }
				else { 'undo unsupported' }
			}
		}
	}
	ue := r.journal[idx].undo
	// optimistic exact-state verification — never clobber newer changes
	if !r.undo_state_matches(ue) {
		mut rec := r.journal[idx]
		rec.undo.status = .stale
		r.journal[idx] = rec
		return UndoOutcome{
			status: .stale
			summary: 'State changed since this action; cannot safely undo.'
		}
	}
	// typed restore seams
	mut ok := true
	match ue.spec {
		TargetEnabledUndo {
			r.engine.set_target_enabled(ue.entity_id, ue.spec.previous_enabled) or {
				ok = false
			}
		}
		SkillsSelectionUndo {
			r.engine.restore_skill_selection(ue.spec.previous_selection) or {
				ok = false
			}
		}
		McpStateUndo {
			r.engine.restore_mcp_state(ue.spec.snapshot) or {
				ok = false
			}
		}
		LoopScheduleUndo {
			r.engine.toggle_loop_cron(ue.entity_id, ue.spec.previous_cron) or {
				ok = false
			}
		}
		AppearanceUndo {
			return error('appearance undo is executed by the shell')
		}
	}
	if !ok {
		// the restore failed to execute; the capability stays available so
		// the user can retry after resolving the underlying problem
		return UndoOutcome{
			status: .available
			summary: 'undo failed — the restore operation could not run'
		}
	}
	// post-verify: the state must now equal the previous state
	if !r.undo_restored(ue) {
		mut rec := r.journal[idx]
		rec.undo.status = .stale
		r.journal[idx] = rec
		return UndoOutcome{
			status: .stale
			summary: 'restore did not produce the previous state — verify manually'
		}
	}
	mut rec := r.journal[idx]
	rec.undo.status = .consumed
	r.journal[idx] = rec
	// the undo itself is a real execution event — recorded, no undo of its own
	r.record_execution(ue.action_kind, ue.entity_kind, ue.entity_id, 'Undid ${ue.label}', .succeeded, ActionEvidence{
		revision: r.engine.revision()
	}, none)
	return UndoOutcome{
		status: .consumed
		summary: 'Undid ${ue.label}'
	}
}

// undo_restored verifies the affected state now equals the previous state.
fn (mut r Registry) undo_restored(ue UndoEntry) bool {
	match ue.spec {
		TargetEnabledUndo {
			return r.engine_target_enabled(ue.entity_id) == ue.spec.previous_enabled
		}
		SkillsSelectionUndo {
			return r.engine.skills_installed() == ue.spec.previous_selection
		}
		McpStateUndo {
			cur := r.engine.mcp_state_snapshot(ue.entity_id) or {
				desktop_engine.McpStateSnapshot{}
			}
			return cur.config == ue.spec.snapshot.config && cur.enabled == ue.spec.snapshot.enabled
				&& cur.health == ue.spec.snapshot.health
		}
		LoopScheduleUndo {
			return r.engine_loop_cron(ue.entity_id) == ue.spec.previous_cron
		}
		AppearanceUndo {
			return false
		}
	}
}

// mark_undo_consumed finalizes a shell-executed undo (e.g. appearance): the
// shell restored the exact previous value through the real setter, then the
// registry records the undo as a real execution with no undo of its own.
pub fn (mut r Registry) mark_undo_consumed(execution_id u64, revision u64) UndoOutcome {
	idx := r.recent_index(execution_id) or {
		return UndoOutcome{
			status: .unsupported
			summary: 'no such execution record'
		}
	}
	if !r.journal[idx].has_undo {
		return UndoOutcome{
			status: .unsupported
			summary: 'this action has no undo'
		}
	}
	if r.journal[idx].undo.status != .available {
		return UndoOutcome{
			status: r.journal[idx].undo.status
			summary: match r.journal[idx].undo.status {
				.consumed { 'already undone' }
				.stale { 'State changed since this action; cannot safely undo.' }
				else { 'undo unsupported' }
			}
		}
	}
	mut rec := r.journal[idx]
	rec.undo.status = .consumed
	r.journal[idx] = rec
	ue := r.journal[idx].undo
	r.record_execution(ue.action_kind, ue.entity_kind, ue.entity_id, 'Undid ${ue.label}', .succeeded, ActionEvidence{
		revision: revision
	}, none)
	return UndoOutcome{
		status: .consumed
		summary: 'Undid ${ue.label}'
	}
}

// hook into execution: called by Registry.execute after the seam ran. The
// execution boundary is explicit — this runs only when execute_seam was
// invoked. Reversible mutating actions capture their previous state and
// finalize the expected post-state from the real Engine.
fn (mut r Registry) journal_execution(action_kind ActionKind, entity_kind EntityKind, entity_id string, label string, outcome ActionOutcome, prev ?UndoEntry) {
	mut undo_entry := UndoEntry{}
	mut has_undo := false
	// only genuinely mutated executions with a captured previous state get
	// undo; failed runs record truthfully without an undo capability
	if outcome.status in [.succeeded, .partial] && prev != none {
		undo_entry = finish_undo_expected(prev, mut r)
		has_undo = true
	}
	r.record_execution(action_kind, entity_kind, entity_id, label, outcome.status, outcome.evidence, if has_undo {
		undo_entry
	} else {
		none
	})
}
