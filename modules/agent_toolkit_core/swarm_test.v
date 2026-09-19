module agent_toolkit_core

import os

fn test_swarm_help() {
	r := run_swarm(SwarmOptions{
		subcommand: 'help'
	})
	assert r.ok
	assert r.message.contains('start')
	assert r.message.contains('approve')
	assert r.message.contains('ADR-008')
}

fn test_swarm_recipes() {
	r := run_swarm(SwarmOptions{
		subcommand: 'recipes'
	})
	assert r.ok
	assert r.data['recipes'].contains('pair')
	one := run_swarm(SwarmOptions{
		subcommand: 'recipes'
		run_id: 'pair'
	})
	assert one.ok
	assert one.data['roles'].contains('implementer')
}

fn test_swarm_start_status_approve_cancel() {
	old_h := os.getenv('HARNESS_DIR')
	old_ws := os.getenv('AGENT_TOOLKIT_WORKSPACE')
	os.unsetenv('HARNESS_DIR')
	os.unsetenv('AGENT_TOOLKIT_WORKSPACE')
	base := os.join_path(os.temp_dir(), 'at-swarm-${os.getpid()}')
	os.mkdir_all(os.join_path(base, '.git')) or { assert false, err.msg() }
	defer {
		if old_h.len > 0 {
			os.setenv('HARNESS_DIR', old_h, true)
		}
		if old_ws.len > 0 {
			os.setenv('AGENT_TOOLKIT_WORKSPACE', old_ws, true)
		}
		os.rmdir_all(base) or {}
	}

	dry := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		recipe: 'team'
		backend: 'headless'
		dry_run: true
		task: 'demo'
	})
	assert dry.ok, dry.message
	assert dry.data['mode'] == 'dry-run'
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))

	start := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		recipe: 'team'
		backend: 'headless'
		task: 'demo'
	})
	assert start.ok, start.message
	assert start.data['run_state'] == 'awaiting_plan_approval'
	rid := start.data['run_id']
	assert swarm_valid_run_id(rid)
	assert os.is_file(os.join_path(base, '.agent-toolkit', 'swarm', 'runs', rid, 'state.json'))

	st := run_swarm(SwarmOptions{
		subcommand: 'status'
		workspace_path: base
		run_id: rid
	})
	assert st.ok, st.message
	assert st.data['gates'].contains('plan:pending')

	ap := run_swarm(SwarmOptions{
		subcommand: 'approve'
		workspace_path: base
		run_id: rid
		gate_id: 'plan'
	})
	assert ap.ok, ap.message
	assert ap.data['run_state'] == 'running'

	rej := run_swarm(SwarmOptions{
		subcommand: 'reject'
		workspace_path: base
		run_id: rid
		gate_id: 'final'
		reason: 'not yet'
	})
	assert rej.ok, rej.message

	can := run_swarm(SwarmOptions{
		subcommand: 'cancel'
		workspace_path: base
		run_id: rid
	})
	assert can.ok, can.message
	assert can.data['run_state'] == 'cancelled'

	doc := run_swarm(SwarmOptions{
		subcommand: 'doctor'
		workspace_path: base
	})
	assert doc.ok, doc.message
	assert doc.data['git'] == 'true'
	assert doc.data['recipes'].contains('pair')
}

fn test_clamp_swarm_concurrency_bounds() {
	assert clamp_swarm_concurrency(2) == 2
	assert clamp_swarm_concurrency(1) == 1
	assert clamp_swarm_concurrency(6) == 6
	assert clamp_swarm_concurrency(0) == 1
	assert clamp_swarm_concurrency(-3) == 1
	assert clamp_swarm_concurrency(7) == 6
	assert clamp_swarm_concurrency(99) == 6
}

fn test_swarm_budget_violations_names_each_limit() {
	b := Budget{
		max_total_tokens: 100
		max_cost_usd: 4.0
		max_wall_seconds: 60
		max_concurrency: 2
	}
	// clean run violates nothing
	assert swarm_budget_violations(b, BudgetConsumed{}, 0) == []
	// boundary trips (>= parity with Python check_limits)
	assert swarm_budget_violations(b, BudgetConsumed{ total_tokens: 100 }, 0) == ['max_total_tokens']
	assert swarm_budget_violations(b, BudgetConsumed{ total_cost: 4.0 }, 0) == ['max_cost_usd']
	assert swarm_budget_violations(b, BudgetConsumed{}, 60) == ['max_wall_seconds']
	// just under the limit is clean
	assert swarm_budget_violations(b, BudgetConsumed{ total_tokens: 99 }, 0) == []
	// several limits can trip together, in stable order
	assert swarm_budget_violations(b, BudgetConsumed{
		total_tokens: 200
		total_cost: 9.5
	}, 500) == ['max_total_tokens', 'max_cost_usd', 'max_wall_seconds']
	// zero max means unset and is skipped
	unset := Budget{}
	assert swarm_budget_violations(unset, BudgetConsumed{
		total_tokens: 1000000
		total_cost: 999.0
	}, 100000) == []
}

fn test_resolve_swarm_config_keeps_valid_concurrency() {
	r := resolve_swarm_config('', 'pair', '', '', '') or {
		assert false, err.msg()
		return
	}
	assert r.execution.max_concurrency == 2
	assert r.spec.execution.max_concurrency == 2
}
