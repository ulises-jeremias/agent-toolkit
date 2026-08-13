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
		run_id:     'pair'
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
		subcommand:     'start'
		workspace_path: base
		recipe:         'team'
		backend:        'headless'
		dry_run:        true
		task:           'demo'
	})
	assert dry.ok, dry.message
	assert dry.data['mode'] == 'dry-run'
	assert !os.is_dir(os.join_path(base, '.agent-toolkit', 'swarm', 'runs'))

	start := run_swarm(SwarmOptions{
		subcommand:     'start'
		workspace_path: base
		recipe:         'team'
		backend:        'headless'
		task:           'demo'
	})
	assert start.ok, start.message
	assert start.data['run_state'] == 'awaiting_plan_approval'
	rid := start.data['run_id']
	assert swarm_valid_run_id(rid)
	assert os.is_file(os.join_path(base, '.agent-toolkit', 'swarm', 'runs', rid, 'state.json'))

	st := run_swarm(SwarmOptions{
		subcommand:     'status'
		workspace_path: base
		run_id:         rid
	})
	assert st.ok, st.message
	assert st.data['gates'].contains('plan:pending')

	ap := run_swarm(SwarmOptions{
		subcommand:     'approve'
		workspace_path: base
		run_id:         rid
		gate_id:        'plan'
	})
	assert ap.ok, ap.message
	assert ap.data['run_state'] == 'running'

	rej := run_swarm(SwarmOptions{
		subcommand:     'reject'
		workspace_path: base
		run_id:         rid
		gate_id:        'final'
		reason:         'not yet'
	})
	assert rej.ok, rej.message

	can := run_swarm(SwarmOptions{
		subcommand:     'cancel'
		workspace_path: base
		run_id:         rid
	})
	assert can.ok, can.message
	assert can.data['run_state'] == 'cancelled'

	doc := run_swarm(SwarmOptions{
		subcommand:     'doctor'
		workspace_path: base
	})
	assert doc.ok, doc.message
	assert doc.data['git'] == 'true'
	assert doc.data['recipes'].contains('pair')
}
