module spike_xasync

import context
import time as _

fn test_baseline_spawn_no_leak() {
	mut bg := context.background()
	ok := baseline_spawn_wg(mut bg)
	assert ok
}

fn test_xasync_group_no_zombie() {
	mut bg := context.background()
	xasync_group_demo(mut bg) or { assert false, err.msg() }
}

fn test_xasync_timeout_bounded() {
	mut bg := context.background()
	ok := xasync_timeout_demo(bg)
	assert ok
}

fn test_decision_matrix_published() {
	m := decision_matrix()
	assert m.len == 3
	mut patterns := []string{}
	for r in m {
		patterns << r.pattern
	}
	assert patterns[1].contains('x.async')
	// recommendation must mention where valuable
	assert m[1].recommendation.contains('adopt') || m[1].recommendation.contains('Group')
	// rxv stays EVALUATE
	assert m[2].pattern.contains('rxv')
	assert m[2].recommendation.contains('EVALUATE')
}
