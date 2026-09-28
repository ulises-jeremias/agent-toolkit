module world

// Status-honesty regression gates for the world projection (WS1): the canvas
// renders only Engine-authoritative statuses; anything unproven is 'unknown'.
// A fresh/listing-only projection must never claim activity, enablement, or
// health it cannot prove.

fn honest_fixture_data() map[string]string {
	mut data := map[string]string{}
	data['repos'] = 'a,b,c'
	data['skills_count'] = '3'
	data['agents_count'] = '2'
	data['loops'] = 'loop1'
	data['jobs'] = 'job1,job2'
	data['handoffs'] = 'agent-a->agent-b,agent-b->agent-c'
	return data
}

fn test_projection_status_unknown_when_unproven() {
	proj := world_projection_from_state(honest_fixture_data(), 1)
	assert proj.nodes.len == 13, 'node count golden ${proj.nodes.len} != 13'
	for n in proj.nodes {
		assert n.status == 'unknown', 'unproven node must be unknown, got ${n.kind} ${n.id} = ${n.status}'
	}
}

fn test_projection_status_vocab_gate_rejects_invention() {
	mut data := honest_fixture_data()
	// view-layer synonyms and guesses are not Engine vocabulary
	data['jobs/job1/status'] = 'in_progress'
	data['jobs/job2/status'] = 'healthy'
	data['loops/loop1/status'] = 'idle'
	data['repos/a/status'] = 'active-ish'
	proj := world_projection_from_state(data, 2)
	for n in proj.nodes {
		assert n.status == 'unknown', 'invented status must map to unknown, got ${n.id} = ${n.status}'
	}
}

fn test_projection_status_proven_passthrough() {
	mut data := honest_fixture_data()
	data['jobs/job1/status'] = 'running'
	data['jobs/job2/status'] = 'done'
	data['swarm/handoffs/agent-a->agent-b/status'] = 'queued'
	data['swarm/handoffs/agent-b->agent-c/status'] = 'completed'
	proj := world_projection_from_state(data, 3)
	mut by_id := map[string]string{}
	for n in proj.nodes {
		by_id[n.id] = n.status
	}
	assert by_id['job:job1'] == 'running', 'proven job status passes through'
	assert by_id['job:job2'] == 'done', 'proven job status passes through'
	assert by_id['handoff:agent-a->agent-b'] == 'queued', 'proven handoff status passes through'
	assert by_id['handoff:agent-b->agent-c'] == 'completed', 'proven handoff status passes through'
	// catalog-only nodes stay unknown even when runtimes are proven
	assert by_id['repo:a'] == 'unknown'
	assert by_id['skill:0'] == 'unknown'
	assert by_id['agent:0'] == 'unknown'
	assert by_id['loop:loop1'] == 'unknown', 'loops have no Engine status key yet'
}

fn test_projection_status_normalizes_case_and_blanks() {
	assert honest_node_status({'k': 'RUNNING'}, 'k') == 'running'
	assert honest_node_status({'k': '  queued  '}, 'k') == 'queued'
	assert honest_node_status({'k': ''}, 'k') == 'unknown'
	assert honest_node_status(map[string]string{}, 'k') == 'unknown'
}

fn test_unproven_nodes_render_hollow_and_tooltip_unknown() {
	mut w := new_world_view(WorldViewConfig{ debounce_ms: 0 })
	w.projection = world_projection_from_state(honest_fixture_data(), 1)
	w.rebuild_buffer()
	culled := w.buffer.culled()
	mut hollow_arcs := 0
	mut filled_arcs := 0
	for p in culled {
		if p.kind == .arc {
			if p.filled {
				filled_arcs++
			} else {
				hollow_arcs++
			}
		}
	}
	assert hollow_arcs == 13, 'every unproven node renders hollow, got ${hollow_arcs}'
	assert filled_arcs == 0, 'no proven nodes in this fixture, got ${filled_arcs}'
	// tooltip surfaces the honest unknown instead of a fabricated state
	res := w.hit_test(w.projection.nodes[0].pos.x, w.projection.nodes[0].pos.y)
	assert res.hit, 'hit-test should hit node'
	assert res.tooltip.contains('unknown'), 'tooltip must show unknown: ${res.tooltip}'
	assert !res.tooltip.contains('running') && !res.tooltip.contains('active')
		&& !res.tooltip.contains('enabled'), 'tooltip must not fabricate: ${res.tooltip}'
}

fn test_proven_nodes_render_filled() {
	mut data := honest_fixture_data()
	data['jobs/job1/status'] = 'running'
	mut w := new_world_view(WorldViewConfig{ debounce_ms: 0 })
	w.projection = world_projection_from_state(data, 1)
	w.rebuild_buffer()
	culled := w.buffer.culled()
	mut filled_arcs := 0
	mut hollow_arcs := 0
	for p in culled {
		if p.kind == .arc {
			if p.filled {
				filled_arcs++
			} else {
				hollow_arcs++
			}
		}
	}
	assert filled_arcs == 1, 'exactly the proven node renders filled, got ${filled_arcs}'
	assert hollow_arcs == 12, 'the rest stay hollow, got ${hollow_arcs}'
}
