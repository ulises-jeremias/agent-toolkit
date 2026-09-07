module palette

import os
import time
import desktop_engine

// TestEngine is a test fixture owning its exact temp directory: create the
// exact path → use the fixture → stop the Engine → remove that exact path.
// No fixture ever touches another fixture's directory.
struct TestEngine {
mut:
	eng &desktop_engine.Engine = unsafe { nil }
	tmp string
}

// new_s4b_engine boots an Engine over a unique isolated temp persist path.
fn new_s4b_engine(label string) &TestEngine {
	tmp := os.join_path(os.temp_dir(), 'palette-actions-${label}-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: persist
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return &TestEngine{
		eng: eng
		tmp: tmp
	}
}

// cleanup stops the Engine and removes this fixture's exact temp path.
fn (mut fe TestEngine) cleanup() {
	fe.eng.stop() or {}
	if fe.tmp != '' {
		os.rmdir_all(fe.tmp) or {}
		fe.tmp = ''
	}
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
	mut fe := new_s4b_engine('unavail')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	skill_id := first_skill_id(mut fe.eng)

	// remove on a not-installed skill is unavailable with a reason
	acts := reg.actions_for(.skill, skill_id)
	rm := find_action(acts, .skill_remove) or { panic('skill_remove action missing') }
	assert !rm.available
	assert rm.unavailable_reason.contains('not installed')

	// disable on a not-enabled target is unavailable with a reason
	mut target_id := ''
	for t in fe.eng.targets() {
		target_id = t.id
		break
	}
	if target_id != '' && !fe.eng.target_enabled(target_id) {
		dacts := reg.actions_for(.target, target_id)
		dis := find_action(dacts, .target_disable) or { panic('target_disable action missing') }
		assert !dis.available
		assert dis.unavailable_reason.contains('not enabled')
	}

	// doctor repair on a non-fixable check is unavailable with a reason
	for c in fe.eng.doctor() {
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
	mut fe := new_s4b_engine('args')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	// empty swarm task → failed validation, nothing recorded
	before := fe.eng.revision()
	out := reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: '   '
	}) or { panic(err.msg()) }
	assert out.status == .failed
	assert out.summary.contains('task text is required')
	assert fe.eng.revision() == before
	// bad recipe → failed validation
	out2 := reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: 'x'
		recipe: 'army'
	}) or { panic(err.msg()) }
	assert out2.status == .failed
	assert out2.summary.contains('unknown swarm recipe')
	// single-subject target install defaults to the contextual entity: an
	// empty selection with no entity is the only invalid case
	out3 := reg.execute(.target, '', .target_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out3.status == .unavailable
	// no default subject is invented when the entity is unknown
}

// dry_run must never bypass confirmation for actions without a real
// dry-run seam (skill_remove and doctor repair mutate for real).
fn test_dry_run_does_not_bypass_confirmation() {
	mut fe := new_s4b_engine('dryrun')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	skill_id := first_skill_id(mut fe.eng)
	// install the skill so remove is available
	_ = reg.execute(.skill, skill_id, .skill_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert fe.eng.skills_installed().contains(skill_id)
	before := fe.eng.revision()
	out := reg.execute(.skill, skill_id, .skill_remove, ActionArgs{
		dry_run: true
	}) or { panic(err.msg()) }
	assert out.status == .not_confirmed
	assert fe.eng.skills_installed().contains(skill_id)
	assert fe.eng.revision() == before
}

// 3. preview calculates real effects without mutating state.
fn test_preview_does_not_mutate_state() {
	mut fe := new_s4b_engine('preview')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	skill_id := first_skill_id(mut fe.eng)
	before_rev := fe.eng.revision()
	before_installed := fe.eng.skills_installed().clone()

	lines := reg.preview(.skill_install, skill_id) or { panic(err.msg()) }
	assert lines.len > 0
	assert lines[0].contains('add')
	assert lines[0].contains(skill_id)
	// nothing mutated: revision and installed selection unchanged
	assert fe.eng.revision() == before_rev
	assert fe.eng.skills_installed() == before_installed

	// doctor preview: real dry-run lines, no mutation
	mut check_id := ''
	for c in fe.eng.doctor() {
		if c.fixable {
			check_id = c.id
			break
		}
	}
	if check_id != '' {
		prev := reg.preview(.doctor_repair, check_id) or { panic(err.msg()) }
		assert prev.len > 0
		assert fe.eng.revision() == before_rev
	}
}

// 4. real execution mutates the expected authoritative state.
fn test_skill_execution_mutates_config_truth() {
	mut fe := new_s4b_engine('exec-skill')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	skill_id := first_skill_id(mut fe.eng)
	out := reg.execute(.skill, skill_id, .skill_install, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	assert out.evidence.revision > 0
	assert fe.eng.skills_installed().contains(skill_id)
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
	assert fe.eng.skills_installed().contains(skill_id)
	// confirmed remove really removes
	rm := reg.execute(.skill, skill_id, .skill_remove, ActionArgs{
		confirm: true
	}) or { panic(err.msg()) }
	assert rm.status == .succeeded
	assert !fe.eng.skills_installed().contains(skill_id)
}

// 5. target enable/disable uses actual configuration state.
fn test_target_enable_disable_uses_config_truth() {
	mut fe := new_s4b_engine('exec-target')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	mut target_id := ''
	for t in fe.eng.targets() {
		target_id = t.id
		break
	}
	if target_id == '' {
		panic('no targets in catalog — test env misconfigured')
	}
	was_enabled := fe.eng.target_enabled(target_id)
	if was_enabled {
		out := reg.execute(.target, target_id, .target_disable, ActionArgs{}) or {
			panic(err.msg())
		}
		assert out.status == .succeeded
		assert !fe.eng.target_enabled(target_id)
	} else {
		out := reg.execute(.target, target_id, .target_enable, ActionArgs{}) or {
			panic(err.msg())
		}
		assert out.status == .succeeded
		assert fe.eng.target_enabled(target_id)
	}
	// the flipped direction now reports unavailability correctly
	acts := reg.actions_for(.target, target_id)
	for a in acts {
		if a.kind == .target_enable {
			assert a.available == !fe.eng.target_enabled(target_id)
		}
		if a.kind == .target_disable {
			assert a.available == fe.eng.target_enabled(target_id)
		}
	}
}

// 6. MCP actions use the real provider configuration.
fn test_mcp_actions_use_real_provider_config() {
	mut fe := new_s4b_engine('exec-mcp')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	mut provider_id := ''
	for p in fe.eng.mcp_catalog() {
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
		before := fe.eng.revision()
		pv := reg.preview(.mcp_enable, provider_id) or {
			// providers without a packaged template honestly have no preview
			assert err.msg().contains('no packaged template')
			return
		}
		assert pv.len > 0
		assert fe.eng.revision() == before
		out := reg.execute(.mcp_provider, provider_id, .mcp_enable, ActionArgs{}) or {
			panic(err.msg())
		}
		assert out.status == .succeeded
		assert reg.engine_mcp_enabled(provider_id)
	}
}

// 7. doctor preview → repair is truthful end to end.
fn test_doctor_preview_repair_truthful() {
	mut fe := new_s4b_engine('exec-doctor')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	mut check_id := ''
	for c in fe.eng.doctor() {
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
	mut fe := new_s4b_engine('exec-loop')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
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
	fe.eng.upsert_loop(entry) or { panic(err.msg()) }
	out := reg.execute(.loop_template, 's4b-loop', .loop_run, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .succeeded
	assert out.evidence.job_id.len > 0
	hist := fe.eng.loops_history('s4b-loop')
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
	mut fe := new_s4b_engine('exec-swarm')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	// unconfirmed launch must not record anything
	before := fe.eng.revision()
	nc := reg.execute(.navigation, '/swarm', .swarm_launch, ActionArgs{
		task: 's4b requested-vs-running check'
		recipe: 'pair'
		backend: 'auto'
	}) or { panic(err.msg()) }
	assert nc.status == .not_confirmed
	assert fe.eng.revision() == before
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
	for s in fe.eng.swarm_list() {
		if s.id == out.evidence.run_id {
			status = s.status.str()
		}
	}
	assert status == 'requested'
}

// 10. fresh engine exposes no fabricated runtime actions.
fn test_fresh_engine_no_fabricated_runtime_actions() {
	mut fe := new_s4b_engine('fresh')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	entries := reg.all_entries()
	assert entries.filter(it.kind == .job).len == 0
	assert entries.filter(it.kind == .swarm_run).len == 0
}

// 12. application-level actions are honest (S4C).
fn test_app_actions_honest() {
	mut fe := new_s4b_engine('app')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	// update: honestly unavailable — no fake check result, no mutation
	out := reg.execute(.app, 'agent-toolkit', .app_update_check, ActionArgs{}) or {
		panic(err.msg())
	}
	assert out.status == .unavailable
	assert out.summary.contains('No update feed/updater')
	// theme: the shell executes appearance changes; the module never fakes a
	// domain result for it
	if _ := reg.execute(.app, 'agent-toolkit', .app_theme_cycle, ActionArgs{}) {
		assert false, 'theme cycle must not execute as a fake domain action'
	} else {
		assert err.msg().contains('shell')
	}
	// uninstall: preview is a real dry-run (nothing deleted); execution is
	// only ever attempted with confirm — and tests never run a real uninstall
	acts := reg.actions_for(.app, 'agent-toolkit')
	un := find_action(acts, .app_uninstall) or { panic('app_uninstall missing') }
	assert un.needs_preview && un.needs_confirm
	if un.available {
		before := reg.engine.uninstall_candidates().len
		pv := reg.preview(.app_uninstall, 'agent-toolkit') or { panic(err.msg()) }
		assert pv.len > 0
		// dry-run execution (explicitly confirmed) reports success without
		// deleting anything
		dr := reg.execute(.app, 'agent-toolkit', .app_uninstall, ActionArgs{
			confirm: true
			dry_run: true
		}) or { panic(err.msg()) }
		assert dr.status == .succeeded
		assert dr.summary.contains('nothing was deleted')
		assert reg.engine.uninstall_candidates().len == before
	}
}

// 11. unknown entity → no actions, honest empty (not fabricated defaults).
fn test_unknown_entity_has_no_actions() {
	mut fe := new_s4b_engine('unknown')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	assert reg.actions_for(.skill, 'does/not-exist').len == 0
	out := reg.execute(.skill, 'does/not-exist', .skill_install, ActionArgs{}) or {
		panic('must not error')
	}
	assert out.status == .unavailable
}
