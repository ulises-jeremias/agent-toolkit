module main

// Slice I loop history: honest single-line copy, no next-run promises.

fn test_loop_history_line_carries_status_and_time() {
	line := loop_history_line('run-abcdef1234', 'completed', 1726000000, 1500)
	assert line.contains('completed'), 'status word present: ${line}'
	assert line.contains('1500ms'), 'duration present: ${line}'
	assert line.contains('run-abcd'), 'run id shortened, not hidden: ${line}'
	assert !line.contains('next'), 'never a next-run promise: ${line}'
}

fn test_loop_history_line_zero_duration_omits() {
	line := loop_history_line('r1', 'started', 1726000000, 0)
	assert line.contains('started')
	assert !line.contains('0ms'), 'zero duration omitted: ${line}'
}
