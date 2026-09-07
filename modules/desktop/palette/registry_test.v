module palette

import os
import time
import desktop_engine
import desktop.nav

// TestEngine is a test fixture owning its exact temp directory: create the
// exact path → use the fixture → stop the Engine → remove that exact path.
struct TestEngine {
mut:
	eng &desktop_engine.Engine = unsafe { nil }
	tmp string
}

// fresh_engine boots an Engine over a unique isolated temp persist path.
fn fresh_engine(label string) &TestEngine {
	tmp := os.join_path(os.temp_dir(), 'palette-registry-${label}-${os.getpid()}-${time.now().unix_nano()}')
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

fn find_entry(entries []RegistryEntry, kind EntityKind, id string) ?RegistryEntry {
	for e in entries {
		if e.kind == kind && e.id == id {
			return e
		}
	}
	return none
}

fn test_fresh_engine_yields_navigation_and_catalog_only() {
	mut fe := fresh_engine('fresh')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	entries := reg.all_entries()
	// navigation: the 13 production shell destinations, in shell order
	navs := entries.filter(it.kind == .navigation)
	assert navs.len == 13
	assert navs[0].id == '/world'
	assert navs[1].id == '/skills'
	assert navs[0].keys == '1'
	// runtime truth: a fresh engine has no jobs and no swarm runs — the
	// registry must not fabricate any
	assert entries.filter(it.kind == .job).len == 0
	assert entries.filter(it.kind == .swarm_run).len == 0
	// no fabricated filler rows: every entry maps to a real catalog record
	for e in entries {
		assert e.is_valid()
		assert e.label != ''
		assert e.category != ''
	}
	// catalog entities mirror the engine catalogs exactly
	skills := entries.filter(it.kind == .skill)
	assert skills.len == fe.eng.skills_catalog().len
	agents := entries.filter(it.kind == .agent)
	assert agents.len == fe.eng.agents_catalog().len
	products := entries.filter(it.kind == .product)
	assert products.len == fe.eng.products_catalog().len
	// canonical identity survives: skills keep their catalog id
	if skills.len > 0 {
		s := fe.eng.skills_catalog()[0]
		entry := find_entry(entries, .skill, s.id) or { panic('skill ${s.id} missing from registry') }
		assert entry.action_id() == 'skill:${s.id}'
	}
}

fn test_unavailable_entries_carry_reason() {
	mut fe := fresh_engine('unavail')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	entries := reg.all_entries()
	// targets without a bundled profile are visible but unavailable, with the
	// honest reason — never silently dropped, never fake-actionable
	targets := entries.filter(it.kind == .target)
	catalog_targets := fe.eng.targets()
	assert targets.len == catalog_targets.len
	for t in catalog_targets {
		entry := find_entry(entries, .target, t.id) or { panic('target ${t.id} missing') }
		if t.path == '' {
			assert !entry.available
			assert entry.unavailable_reason.contains('no bundled profile')
		} else {
			assert entry.available
			assert entry.unavailable_reason == ''
		}
	}
	// doctor checks are repairable only when the engine reports fixable
	for c in fe.eng.doctor() {
		entry := find_entry(entries, .doctor_check, c.id) or { panic('doctor check ${c.id} missing') }
		assert entry.available == c.fixable
		if !c.fixable {
			assert entry.unavailable_reason.contains('not auto-fixable')
		}
	}
}

fn test_workspace_scoped_entity_preserves_identity() {
	mut fe := fresh_engine('workspace')
	defer {
		fe.cleanup()
	}
	// a real (trivial) job record gives the registry a runtime row with a
	// workspace context — spawned via the engine, never fabricated
	job_id := fe.eng.spawn_job_with_opts('echo', ['registry-workspace-test'], '/tmp/atk-registry-ws') or {
		panic(err.msg())
	}
	fe.eng.job_complete(job_id, 0) or {}
	mut reg := new_registry(mut fe.eng)
	entries := reg.all_entries()
	entry := find_entry(entries, .job, job_id) or { panic('job ${job_id} missing from registry') }
	assert entry.workspace == '/tmp/atk-registry-ws'
	assert entry.action_id() == 'job:${job_id}'
	assert entry.panel == nav.PanelId.jobs
}

fn test_filter_preserves_canonical_identity() {
	mut fe := fresh_engine('filter')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	// every query hit keeps its registry identity: category/keyword matches
	// surface the same actions an empty query would
	mut hits := reg.filter('skills')
	assert hits.len > 0
	for a in hits {
		assert a.entity_id != '' || a.kind == .navigation
	}
	// entity search: match a skill by its canonical id fragment
	catalog := fe.eng.skills_catalog()
	if catalog.len > 0 {
		fragment := catalog[0].id.split('/')[0]
		hits = reg.filter(fragment)
		assert hits.len > 0
		mut found := false
		for a in hits {
			if a.kind == .skill && a.entity_id == catalog[0].id {
				found = true
			}
		}
		assert found
	}
	// no match stays empty — no fallback rows invented
	assert reg.filter('zzz_no_such_query_42').len == 0
}

fn test_registry_caches_per_revision() {
	mut fe := fresh_engine('cache')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	_ = reg.all_entries()
	first_builds := reg.builds
	assert first_builds == 1
	// same revision → no rebuild (cheap frame refresh)
	_ = reg.all_entries()
	_ = reg.all_actions()
	assert reg.builds == first_builds
	// engine mutation bumps revision → registry rebuilds
	mut repo := fe.eng.state_repo()
	mut tx := repo.begin('registry-cache-test')
	tx.set('registry_probe', '1')
	fe.eng.put_transaction(mut tx) or { panic(err.msg()) }
	_ = reg.all_entries()
	assert reg.builds == first_builds + 1
}

fn test_scored_filter_ranks_exact_match_first() {
	mut fe := fresh_engine('rank')
	defer {
		fe.cleanup()
	}
	mut reg := new_registry(mut fe.eng)
	scored := reg.scored_filter('Go to Skills')
	assert scored.len > 0
	assert scored[0].action.id == 'nav:/skills'
	assert scored[0].score > 0
}
