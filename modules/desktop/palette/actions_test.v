module palette

import os
import desktop_engine

// s4b_engine builds an Engine over an isolated temp persist path.
fn s4b_engine(label string) &desktop_engine.Engine {
	tmp := os.join_path(os.temp_dir(), 'palette-actions-${label}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: persist
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return eng
}

fn first_skill_id(mut eng &desktop_engine.Engine) string {
	catalog := eng.skills_catalog()
	if catalog.len == 0 {
		panic('no catalog skills — test env misconfigured')
	}
	return catalog[0].id
}

// find_action locates an action by kind in a derived action list.
fn find_action(acts []RegistryAction, kind ActionKind) ?RegistryAction {
	for a in acts {
		if a.kind == kind {
			return a
		}
	}
	return none
}

// 1. unavailable actions carry a truthful reason.
fn test_unavailable_action_has_reason() {
	mut eng := s4b_engine('unavail')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	skill_id := first_skill_id(mut eng)

	// remove on a not-installed skill is unavailable with a reason
	acts := reg.actions_for(.skill, skill_id)
	rm := find_action(acts, .skill_remove) or { panic('skill_remove action missing') }
	assert !rm.available
	assert rm.unavailable_reason.contains('not installed')

	// disable on a not-enabled target is unavailable with a reason
	mut target_id := ''
	for t in eng.targets() {
		target_id = t.id
		break
	}
	if target_id != '' && !eng.target_enabled(target_id) {
		dacts := reg.actions_for(.target, target_id)
		dis := find_action(dacts, .target_disable) or { panic('target_disable action missing') }
		assert !dis.available
		assert dis.unavailable_reason.contains('not enabled')
	}

	// doctor repair on a non-fixable check is unavailable with a reason
	for c in eng.doctor() {
		if !c.fixable {
			cacts := reg.actions_for(.doctor_check, c.id)
			assert cacts.len == 1
			assert !cacts[0].available
			assert cacts[0].unavailable_reason.contains('not auto-fixable')
			break
		}
	}
}

// 2. typed args are validated before any Engine call.
fn test_typed_args_are_validated() {
	mut eng := s4b_engine('args')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	// empty swarm task → failed validation, nothing recorded
	before := eng.revision()
	out := reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: '   '
	}) or { panic(err.msg()) }
	assert out.status == .failed
	assert out.summary.contains('task text is required')
	assert eng.revision() == before
	// bad recipe → failed validation
	out2 := reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: 'x'
		recipe: 'army'
	}) or { panic(err.msg()) }
	assert out2.status == .failed
	assert out2.summary.contains('unknown swarm recipe')
	// empty target selection → failed validation
	out3 := reg.execute(.target, 'claude-code', .target_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out3.status == .failed
	assert out3.summary.contains('no targets selected')
}

// 3. preview calculates real effects without mutating state.
fn test_preview_does_not_mutate_state() {
	mut eng := s4b_engine('preview')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	skill_id := first_skill_id(mut eng)
	before_rev := eng.revision()
	before_installed := eng.skills_installed().clone()

	lines := reg.preview(.skill_install, skill_id) or { panic(err.msg()) }
	assert lines.len > 0
	assert lines[0].contains('add')
	assert lines[0].contains(skill_id)
	// nothing mutated: revision and installed selection unchanged
	assert eng.revision() == before_rev
	assert eng.skills_installed() == before_installed

	// doctor preview: real dry-run lines, no mutation
	mut check_id := ''
	for c in eng.doctor() {
		if c.fixable {
			check_id = c.id
			break
		}
	}
	if check_id != '' {
		prev := reg.preview(.doctor_repair, check_id) or { panic(err.msg()) }
		assert prev.len > 0
		assert eng.revision() == before_rev
	}
}

// 4. real execution mutates the expected authoritative state.
fn test_skill_execution_mutates_config_truth() {
	mut eng := s4b_engine('exec-skill')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	skill_id := first_skill_id(mut eng)
	out := reg.execute(.skill, skill_id, .skill_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	assert out.evidence.revision > 0
	assert eng.skills_installed().contains(skill_id)
	// install of an installed skill is unavailable (not a fake no-op success)
	out2 := reg.execute(.skill, skill_id, .skill_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out2.status == .unavailable
	// remove needs confirmation; without it the state must be untouched
	nc := reg.execute(.skill, skill_id, .skill_remove, ActionArgs{}) or {
		panic(err.msg())
	}
	assert nc.status == .not_confirmed
	assert eng.skills_installed().contains(skill_id)
	// confirmed remove really removes
	rm := reg.execute(.skill, skill_id, .skill_remove, ActionArgs{
		confirm: true
	}) or { panic(err.msg()) }
	assert rm.status == .succeeded
	assert !eng.skills_installed().contains(skill_id)
}

// 5. target enable/disable uses actual configuration state.
fn test_target_enable_disable_uses_config_truth() {
	mut eng := s4b_engine('exec-target')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	mut target_id := ''
	for t in eng.targets() {
		target_id = t.id
		break
	}
	if target_id == '' {
		panic('no targets in catalog — test env misconfigured')
	}
	was_enabled := eng.target_enabled(target_id)
	if was_enabled {
		out := reg.execute(.target, target_id, .target_disable, ActionArgs{}) or {
			panic(err.msg())
		}
		assert out.status == .succeeded
		assert !eng.target_enabled(target_id)
	} else {
		out := reg.execute(.target, target_id, .target_enable, ActionArgs{}) or {
			panic(err.msg())
		}
		assert out.status == .succeeded
		assert eng.target_enabled(target_id)
	}
	// the flipped direction now reports unavailability correctly
	acts := reg.actions_for(.target, target_id)
	for a in acts {
		if a.kind == .target_enable {
			assert a.available == !eng.target_enabled(target_id)
		}
		if a.kind == .target_disable {
			assert a.available == eng.target_enabled(target_id)
		}
	}
}

// 6. MCP actions use the real provider configuration.
fn test_mcp_actions_use_real_provider_config() {
	mut eng := s4b_engine('exec-mcp')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	mut provider_id := ''
	for p in eng.mcp_catalog() {
		provider_id = p.id
		break
	}
	if provider_id == '' {
		panic('no mcp providers in catalog — test env misconfigured')
	}
	was_enabled := reg.engine_mcp_enabled(provider_id)
	if was_enabled {
		// disable requires confirmation
		nc := reg.execute(.mcp_provider, provider_id, .mcp_disable, ActionArgs{}) or {
			panic(err.msg())
		}
		assert nc.status == .not_confirmed
		out := reg.execute(.mcp_provider, provider_id, .mcp_disable, ActionArgs{
			confirm: true
		}) or { panic(err.msg()) }
		assert out.status == .succeeded
		assert !reg.engine_mcp_enabled(provider_id)
	} else {
		// preview shows real write targets, mutates nothing
		before := eng.revision()
		pv := reg.preview(.mcp_enable, provider_id) or {
			// providers without a packaged template honestly have no preview
			assert err.msg().contains('no packaged template')
			return
		}
		assert pv.len > 0
		assert eng.revision() == before
		out := reg.execute(.mcp_provider, provider_id, .mcp_enable, ActionArgs{}) or {
			panic(err.msg())
		}
		assert out.status == .succeeded
		assert reg.engine_mcp_enabled(provider_id)
	}
}

// 7. doctor preview → repair is truthful end to end.
fn test_doctor_preview_repair_truthful() {
	mut eng := s4b_engine('exec-doctor')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	mut check_id := ''
	for c in eng.doctor() {
		if c.fixable {
			check_id = c.id
			break
		}
	}
	if check_id == '' {
		println('no fixable doctor checks — skipping execution leg')
		return
	}
	prev := reg.preview(.doctor_repair, check_id) or {
		panic(err.msg())
	}
	assert prev.len > 0
	out := reg.execute(.doctor_check, check_id, .doctor_repair, ActionArgs{
		confirm: true
	}) or { panic(err.msg()) }
	assert out.status == .succeeded
	assert out.evidence.revision > 0
	// re-execution after a real fix is either an idempotent success (audit
	// stamp) or an honest unavailability if the check no longer reports
	// fixable — never a fabricated second repair
	out2 := reg.execute(.doctor_check, check_id, .doctor_repair, ActionArgs{
		confirm: true
	}) or { panic(err.msg()) }
	assert out2.status in [.succeeded, .unavailable]
	if out2.status == .succeeded {
		assert out2.evidence.revision > 0
	}
}

// 8. loop run actually invokes the Engine operation (real history + budget).
fn test_loop_run_invokes_engine() {
	mut eng := s4b_engine('exec-loop')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	entry := desktop_engine.LoopEntry{
		name: 's4b-loop'
		goal: 's4b action test'
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
	eng.upsert_loop(entry) or { panic(err.msg()) }
	out := reg.execute(.loop_template, 's4b-loop', .loop_run, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	assert out.evidence.job_id.len > 0
	hist := eng.loops_history('s4b-loop')
	assert hist.len == 1
	assert hist[0].status == 'started'
	// budget gate → real failure, no false success
	out2 := reg.execute(.loop_template, 's4b-loop', .loop_run, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out2.status == .failed
	assert out2.summary.contains('budget_exhausted')
}

// 9. swarm launch preserves requested-vs-running semantics.
fn test_swarm_launch_preserves_requested_semantics() {
	mut eng := s4b_engine('exec-swarm')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	// unconfirmed launch must not record anything
	before := eng.revision()
	nc := reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: 's4b requested-vs-running check'
		recipe: 'pair'
		backend: 'auto'
	}) or { panic(err.msg()) }
	assert nc.status == .not_confirmed
	assert eng.revision() == before
	out := reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: 's4b requested-vs-running check'
		recipe: 'pair'
		backend: 'auto'
		confirm: true
	}) or { panic(err.msg()) }
	assert out.status == .succeeded
	assert out.evidence.run_id.starts_with('swarm-')
	assert out.summary.contains('requested')
	assert !out.summary.to_lower().contains('running workers')
	// the recorded run is 'requested', never 'running'
	mut status := ''
	for s in eng.swarm_list() {
		if s.id == out.evidence.run_id {
			status = s.status.str()
		}
	}
	assert status == 'requested'
}

// 10. fresh engine exposes no fabricated runtime actions.
fn test_fresh_engine_no_fabricated_runtime_actions() {
	mut eng := s4b_engine('fresh')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	entries := reg.all_entries()
	assert entries.filter(it.kind == .job).len == 0
	assert entries.filter(it.kind == .swarm_run).len == 0
}

// 11. unknown entity → no actions, honest empty (not fabricated defaults).
fn test_unknown_entity_has_no_actions() {
	mut eng := s4b_engine('unknown')
	defer {
		eng.stop() or {}
	}
	mut reg := new_registry(mut eng)
	assert reg.actions_for(.skill, 'does/not-exist').len == 0
	out := reg.execute(.skill, 'does/not-exist', .skill_install, ActionArgs{}) or {
		panic('must not error')
	}
	assert out.status == .unavailable
}
