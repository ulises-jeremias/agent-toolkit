module palette

import os
import time
import desktop_engine

// s4d journal/undo tests — every case from the S4D acceptance matrix.

// JrnEngine is the journal test fixture owning its exact temp directory.
struct JrnEngine {
mut:
	eng &desktop_engine.Engine = unsafe { nil }
	tmp string
}

fn new_journal_engine(label string) &JrnEngine {
	tmp := os.join_path(os.temp_dir(), 'palette-journal-${label}-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: persist
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return &JrnEngine{
		eng: eng
		tmp: tmp
	}
}

fn (mut fe JrnEngine) cleanup() {
	fe.eng.stop() or {}
	if fe.tmp != '' {
		os.rmdir_all(fe.tmp) or {}
		fe.tmp = ''
	}
}

fn journal_skill_id(mut eng &desktop_engine.Engine) string {
	catalog := eng.skills_catalog()
	if catalog.len == 0 {
		panic('no catalog skills')
	}
	return catalog[0].id
}

fn has_action(acts []RegistryAction, kind ActionKind) bool {
	return acts.any(it.kind == kind)
}

// fresh session → empty journal, no fabricated recent actions
fn test_journal_fresh_session_is_empty() {
	mut fe := new_journal_engine('fresh')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	assert reg.journal_records().len == 0
}

// TARGET: enable → recent + undo → exact restore → consumed; second undo
// reports already-undone; undo record itself has no undo.
fn test_journal_target_undo_exact() {
	mut fe := new_journal_engine('target')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	mut target_id := ''
	for t in fe.eng.targets() {
		target_id = t.id
		break
	}
	if target_id == '' {
		panic('no targets')
	}
	was_enabled := fe.eng.target_enabled(target_id)
	kind := if was_enabled { ActionKind.target_disable } else { ActionKind.target_enable }
	out := reg.execute(.target, target_id, kind, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	recs := reg.journal_records()
	assert recs.len == 1
	rec := recs[0]
	assert rec.outcome == .succeeded
	assert rec.entity_id == target_id
	assert rec.has_undo
	assert rec.undo.status == .available
	assert rec.undo.spec !is AppearanceUndo
	// the undo record must carry no fabricated evidence: revision matches
	// the real post-execution state
	// undo restores the exact previous value
	uout := reg.execute_undo(rec.execution_id) or {
		panic(err.msg())
	}
	assert uout.status == .consumed
	assert uout.summary.contains('Undid')
	assert fe.eng.target_enabled(target_id) == was_enabled
	// single use
	uout2 := reg.execute_undo(rec.execution_id) or {
		panic(err.msg())
	}
	assert uout2.status == .consumed
	assert uout2.summary.contains('already undone')
	// the undo itself is a recorded execution with no undo
	recs2 := reg.journal_records()
	assert recs2.len == 2
	assert recs2[0].label.starts_with('Undid')
	assert !recs2[0].has_undo
}

// TARGET divergence: a later unrelated change makes undo stale and it must
// not overwrite the newer state; stale stays stale.
fn test_journal_target_undo_stale() {
	mut fe := new_journal_engine('target-stale')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	mut target_id := ''
	for t in fe.eng.targets() {
		target_id = t.id
		break
	}
	was := fe.eng.target_enabled(target_id)
	kind := if was { ActionKind.target_disable } else { ActionKind.target_enable }
	out := reg.execute(.target, target_id, kind, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	// an unrelated later change flips the target back
	fe.eng.set_target_enabled(target_id, was) or { panic(err.msg()) }
	// optimistic precheck sees the divergence
	assert reg.undo_precheck(out_status_id(reg)) == .stale
	uout := reg.execute_undo(out_status_id(reg)) or {
		panic(err.msg())
	}
	assert uout.status == .stale
	assert uout.summary.contains('State changed')
	// no overwrite: the newer state survives
	assert fe.eng.target_enabled(target_id) == was
	// stale stays stale
	assert reg.undo_precheck(out_status_id(reg)) == .stale
}

// helper: first recent execution id
fn out_status_id(reg &Registry) u64 {
	recs := reg.journal_records()
	if recs.len == 0 {
		panic('no journal records')
	}
	return recs[0].execution_id
}

// SKILL: full-selection snapshot; unrelated later install makes undo stale
// and preserves the unrelated change.
fn test_journal_skill_selection_guard() {
	mut fe := new_journal_engine('skill-guard')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	s1 := journal_skill_id(mut fe.eng)
	catalog := fe.eng.skills_catalog()
	if catalog.len < 2 {
		panic('need two catalog skills')
	}
	s2 := catalog[1].id
	out := reg.execute(.skill, s1, .skill_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	assert fe.eng.skills_installed().contains(s1)
	// unrelated later change: install s2
	fe.eng.install_skill(s2) or { panic(err.msg()) }
	// undo must be stale — restoring would destroy the s2 change
	assert reg.undo_precheck(out_status_id(reg)) == .stale
	uout := reg.execute_undo(out_status_id(reg)) or {
		panic(err.msg())
	}
	assert uout.status == .stale
	// unrelated state preserved
	inst := fe.eng.skills_installed()
	assert inst.contains(s1) && inst.contains(s2)
}

// SKILL: exact restore when nothing diverged.
fn test_journal_skill_undo_exact() {
	mut fe := new_journal_engine('skill-exact')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	s1 := journal_skill_id(mut fe.eng)
	before := fe.eng.skills_installed().clone()
	out := reg.execute(.skill, s1, .skill_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert fe.eng.skills_installed() != before || before.contains(s1)
	uout := reg.execute_undo(out_status_id(reg)) or {
		panic(err.msg())
	}
	assert uout.status == .consumed
	after := fe.eng.skills_installed()
	assert after == before
}

// EXECUTION HISTORY boundary: validation failure, unavailable and
// not-confirmed never record; seam failure records failed truthfully.
fn test_journal_recording_boundary() {
	mut fe := new_journal_engine('boundary')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	s1 := journal_skill_id(mut fe.eng)
	// validation failure (empty swarm task) → no recent
	_ = reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: ' '
	}) or { panic('must not error') }
	assert reg.journal_records().len == 0
	// unavailable (remove a not-installed skill) → no recent
	_ = reg.execute(.skill, s1, .skill_remove, ActionArgs{
		confirm: true
	}) or { panic('must not error') }
	assert reg.journal_records().len == 0
	// not confirmed (install first, then unconfirmed remove) → no recent
	_ = reg.execute(.skill, s1, .skill_install, ActionArgs{}) or {
		panic(err.msg())
	}
	inst_recs := reg.journal_records()
	assert inst_recs.len == 1 && inst_recs[0].outcome == .succeeded
	_ = reg.execute(.skill, s1, .skill_remove, ActionArgs{}) or {
		panic('must not error')
	}
	assert reg.journal_records().len == 1
	// seam failure records failed truthfully (budget-gated loop run)
	entry := desktop_engine.LoopEntry{
		name: 'journal-loop'
		goal: 'boundary'
		tier: .l1
		stage: 'l1'
		cadence: '1d'
		schedule: desktop_engine.cadence_to_cron('1d')
		budget: desktop_engine.LoopBudget{
			max_tokens: 80000
			max_runs_per_day: 1
			max_wall_seconds: 900
		}
		budget_total: 80000
	}
	fe.eng.upsert_loop(entry) or { panic(err.msg()) }
	_ = reg.execute(.loop_template, 'journal-loop', .loop_run, ActionArgs{}) or {
		panic(err.msg())
	}
	_ = reg.execute(.loop_template, 'journal-loop', .loop_run, ActionArgs{}) or {
		panic(err.msg())
	}
	// second run fails at the budget gate — a real seam failure
	recs := reg.journal_records()
	assert recs[0].outcome == .failed
	assert recs[0].label.contains('Run now')
	// failed records carry no undo
	assert !recs[0].has_undo
}

// MCP disable: config survives in place; undo restores the exact captured
// state (config + enabled + health) via the typed restore seam.
fn test_journal_mcp_disable_undo() {
	mut fe := new_journal_engine('mcp')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	mut pid := ''
	for p in fe.eng.mcp_catalog() {
		pid = p.id
		break
	}
	if pid == '' {
		panic('no providers')
	}
	// start from a known enabled state
	_ = reg.execute(.mcp_provider, pid, .mcp_enable, ActionArgs{}) or {
		panic(err.msg())
	}
	before := fe.eng.mcp_state_snapshot(pid) or { panic('snapshot missing') }
	out := reg.execute(.mcp_provider, pid, .mcp_disable, ActionArgs{
		confirm: true
	}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	after_disable := fe.eng.mcp_state_snapshot(pid) or { panic('missing') }
	// disable keeps the config bytes in place
	assert after_disable.config == before.config
	assert !after_disable.enabled
	// undo restores the exact captured state
	uout := reg.execute_undo(out_status_id_for(reg, out)) or {
		panic(err.msg())
	}
	_ = uout
	restored := fe.eng.mcp_state_snapshot(pid) or { panic('missing') }
	assert restored.config == before.config
	assert restored.enabled == before.enabled
	assert restored.health == before.health
}

// helper: execution id of the most recent record
fn out_status_id_for(reg &Registry, _ ActionOutcome) u64 {
	return out_status_id(reg)
}

// MCP enable: prior config is overwritten by the template — undo must
// restore the exact prior state from the snapshot; the snapshot never
// appears in journal metadata.
fn test_journal_mcp_enable_snapshot() {
	mut fe := new_journal_engine('mcp-enable')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	mut pid := ''
	for p in fe.eng.mcp_catalog() {
		pid = p.id
		break
	}
	// a pre-existing (custom) configuration the user had before
	custom := '{"command":"custom-guarded","args":["' + '\${CUSTOM_TOKEN}' + '"]}'
	fe.eng.upsert_mcp_provider(pid, custom) or { panic(err.msg()) }
	fe.eng.mcp_toggle(pid) or { panic(err.msg()) } // disable — config preserved
	// enable overwrites the custom config with the packaged template
	out := reg.execute(.mcp_provider, pid, .mcp_enable, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	after_enable := fe.eng.mcp_state_snapshot(pid) or { panic('missing') }
	assert after_enable.config != custom
	// undo restores the exact prior (custom, disabled) state
	uout := reg.execute_undo(out_status_id_for(reg, out)) or {
		panic(err.msg())
	}
	assert uout.status == .consumed
	restored := fe.eng.mcp_state_snapshot(pid) or { panic('missing') }
	assert restored.config == custom
	assert !restored.enabled
	// no config blob ever leaks into journal metadata
	for rec in reg.journal_records() {
		assert !rec.label.contains('custom-guarded')
		assert !rec.label.contains('CUSTOM_TOKEN')
	}
}

// SECURITY: a snapshot whose config carries a raw secret (predating the
// guard) is refused on restore — undo unavailable, secret policy never
// weakened. gho_ tokens are detected even alongside placeholders.
fn test_journal_mcp_restore_refuses_raw_secret() {
	mut fe := new_journal_engine('mcp-secret')
	defer {
		fe.cleanup()
	}
	bad := '{"token":"gho_rawsecretvalue123","command":"' + '\${GUARDED_CMD}' + '"}'
	snap := desktop_engine.McpStateSnapshot{
		provider_id: 'github'
		config: bad
		enabled: true
		health: 'configured'
	}
	if _ := fe.eng.restore_mcp_state(snap) {
		assert false, 'raw gho_ token must be refused'
	} else {
		assert err.msg().contains('secret guard')
	}
}

// LOOP schedule: exact previous configuration restored; loop RUN is never
// undoable.
fn test_journal_loop_schedule_undo() {
	mut fe := new_journal_engine('loop-cron')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	entry := desktop_engine.LoopEntry{
		name: 'journal-cron-loop'
		goal: 'undo schedule'
		tier: .l1
		stage: 'l1'
		cadence: '1d'
		schedule: desktop_engine.cadence_to_cron('1d')
		budget: desktop_engine.LoopBudget{
			max_tokens: 80000
			max_runs_per_day: 1
			max_wall_seconds: 900
		}
		budget_total: 80000
	}
	fe.eng.upsert_loop(entry) or { panic(err.msg()) }
	out := reg.execute(.loop_template, 'journal-cron-loop', .loop_schedule_toggle, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	assert fe.eng.loops_catalog().filter(it.name == 'journal-cron-loop')[0].cron_enabled
	uout := reg.execute_undo(out_status_id(reg)) or {
		panic(err.msg())
	}
	assert uout.status == .consumed
	assert !fe.eng.loops_catalog().filter(it.name == 'journal-cron-loop')[0].cron_enabled
	// loop RUN has no undo
	run_out := reg.execute(.loop_template, 'journal-cron-loop', .loop_run, ActionArgs{}) or {
		panic(err.msg())
	}
	assert run_out.status == .succeeded
	run_rec := reg.journal_records()[0]
	assert !run_rec.has_undo
}

// PROBE and dry-run executions are not recorded (read-only / preview-like).
fn test_journal_probe_and_dry_run_not_recorded() {
	mut fe := new_journal_engine('probe')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	mut pid := ''
	for p in fe.eng.mcp_catalog() {
		pid = p.id
		break
	}
	_ = reg.execute(.mcp_provider, pid, .mcp_probe, ActionArgs{}) or {
		panic(err.msg())
	}
	assert reg.journal_records().len == 0
	// target install dry-run crosses the seam but writes nothing — it is a
	// preview, not an execution
	mut tid := ''
	for t in fe.eng.targets() {
		if fe.eng.target_install_supported(t.id) {
			tid = t.id
			break
		}
	}
	if tid != '' {
		_ = reg.execute(.target, tid, .target_install, ActionArgs{
			dry_run: true
			confirm: true
		}) or { panic(err.msg()) }
		assert reg.journal_records().len == 0
	}
}

// SESSION bound: the journal stays capped.
fn test_journal_bounded() {
	mut fe := new_journal_engine('bounded')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(fe.eng)
	s1 := journal_skill_id(mut fe.eng)
	for i in 0 .. 40 {
		kind := if i % 2 == 0 { ActionKind.skill_install } else { ActionKind.skill_remove }
		_ = reg.execute(.skill, s1, kind, ActionArgs{
			confirm: true
		}) or { panic(err.msg()) }
	}
	assert reg.journal_records().len == recents_limit
	// newest first with stable ids
	recs := reg.journal_records()
	assert recs[0].execution_id > recs[recs.len - 1].execution_id
}
