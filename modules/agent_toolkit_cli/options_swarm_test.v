module agent_toolkit_cli

fn test_parse_swarm_handoff_act_and_max_hops_space_form() {
	opts := parse_swarm_options(['handoff', 'create', '--type', 'decision_request', '--from', 'implementer',
		'--to', 'reviewer', '--act', 'propose', '--max-hops', '3']) or { panic(err.msg()) }
	assert opts.subcommand == 'handoff'
	assert opts.act == 'propose'
	assert opts.max_hops == 3
}

fn test_parse_swarm_handoff_act_and_max_hops_equals_form() {
	opts := parse_swarm_options(['handoff', 'create', '--type=decision_request', '--from=implementer',
		'--to=reviewer', '--act=review', '--max-hops=2']) or { panic(err.msg()) }
	assert opts.act == 'review'
	assert opts.max_hops == 2
}

fn test_parse_swarm_handoff_defaults_without_act() {
	opts := parse_swarm_options(['handoff', 'create', '--type', 'decision_request', '--from', 'implementer',
		'--to', 'all']) or { panic(err.msg()) }
	assert opts.act == ''
	assert opts.max_hops == 0
	assert opts.to_role == 'all'
}
