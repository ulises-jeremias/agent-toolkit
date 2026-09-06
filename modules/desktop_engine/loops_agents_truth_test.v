module desktop_engine

import os

// S7D truth gates: loops never fabricate a catalog, history or spend, and
// agent catalog metadata comes only from real catalog data.

// A valid toolkit root without loops yields an empty loop catalog — never a
// fabricated template roster with fake spend, cron or exit status.
fn test_loops_catalog_never_fabricates() {
	tmp := os.join_path(os.temp_dir(), 'loops-truth-${os.getpid()}')
	os.mkdir_all(os.join_path(tmp, 'profiles')) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', tmp, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	cat := eng.loops_catalog()
	assert cat.len == 0, 'no bundled loops must yield an empty catalog: got ${cat.len}'
	assert eng.loops_history('anything').len == 0, 'no synthetic history rows'

	// a real loop with no runs has unknown exit, no cron and no next_run
	entry := LoopEntry{
		name: 'truth-loop'
		goal: 'verify loop truth'
		tier: .l1
		stage: 'l1'
		cadence: '1d'
		schedule: cadence_to_cron('1d')
		budget: LoopBudget{ max_tokens: 80000, max_runs_per_day: 2, max_wall_seconds: 900 }
		budget_total: 80000
	}
	rev := eng.upsert_loop(entry) or { panic(err.msg()) }
	assert rev >= 1
	detail := eng.loop_detail('truth-loop') or { panic('loop missing') }
	assert detail.last_exit == '', 'no runs means unknown exit, not success'
	assert detail.cron_enabled == false
	assert detail.next_run == ''
	assert detail.budget_spent == 0, 'no runs means zero spend'

	// runs record real history rows with honest status
	id1 := eng.run_loop('truth-loop') or { panic(err.msg()) }
	assert id1.len > 0
	hist := eng.loops_history('truth-loop')
	assert hist.len == 1, 'one real run row'
	assert hist[0].status == 'started', 'a recorded start is started, not done'

	// runs_today counts real runs and the budget gate enforces it
	id2 := eng.run_loop('truth-loop') or { panic(err.msg()) }
	assert id2.len > 0
	if _ := eng.run_loop('truth-loop') {
		assert false, 'third run must hit the max_runs_per_day budget gate'
	} else {
		assert err.msg().contains('budget_exhausted')
	}
	snap := eng.repo.snapshot()
	assert snap.data['loops/truth-loop/runs_today'] == '2', 'runs_today counts real runs'

	// cron toggle records intent without inventing a schedule time
	rev2 := eng.toggle_loop_cron('truth-loop', true) or { panic(err.msg()) }
	assert rev2 >= 1
	snap2 := eng.repo.snapshot()
	assert snap2.data['loops/truth-loop/cron'] == 'true'
	assert snap2.data['loops/truth-loop/next_run'] == '', 'no scheduler means no invented next_run'

	// audit counts only real statuses — started rows are not successes
	audit := eng.loops_audit('truth-loop')
	assert audit.len == 1
	assert audit[0].runs == 2
	assert audit[0].completed == 0, 'started runs must not count as completed'
	assert audit[0].success_rate == '—'
}

// Agent metadata comes only from the real catalog: roles map from the real
// kind tier, and no invented trigger strings or ownership routing are
// attached to real entries.
fn test_agent_metadata_comes_from_catalog() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'agents-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	cat := eng.agents_catalog()
	assert cat.len >= 18
	mut by_id := map[string]AgentEntry{}
	for a in cat {
		by_id[a.id] = a
	}
	// roles are real derivations from the catalog kind field
	assert by_id['assistant'].role == 'Orchestrator', 'assistant kind is orchestrator in the catalog'
	assert by_id['architect'].role == 'Holistic'
	assert by_id['agentic-security-reviewer'].role == 'Specialist'
	for a in cat {
		assert a.triggers == '', 'triggers must come from real catalog data, not invented strings: ${a.id}'
		assert a.holistic_owner == '', 'holistic owner must come from real catalog data: ${a.id}'
		assert a.tier in ['holistic', 'specialist', 'orchestrator'], 'tier comes from the catalog kind: ${a.id}=${a.tier}'
	}
}
