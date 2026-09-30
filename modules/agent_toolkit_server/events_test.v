module agent_toolkit_server

import agent_toolkit_core
import os
import time
import x.json2

fn test_event_bus_assigns_monotonic_seq_and_timestamp() {
	mut bus := new_event_bus()
	a := bus.publish(ApiEvent{ kind: 'job.created', subject: 'job_a' })
	b := bus.publish(ApiEvent{ kind: 'job.updated', subject: 'job_a' })
	assert a.seq == 1
	assert b.seq == 2
	assert a.at.len > 0
	assert bus.last_seq() == 2
	all, missed := bus.since(0)
	assert !missed
	assert all.map(it.seq) == [1, 2]
	tail, tail_missed := bus.since(1)
	assert !tail_missed
	assert tail.map(it.kind) == ['job.updated']
	none_left, _ := bus.since(2)
	assert none_left.len == 0
}

fn test_event_bus_reports_missed_cursor_past_ring_and_from_older_process() {
	mut bus := new_event_bus()
	bus.capacity = 3
	for i in 0 .. 5 {
		bus.publish(ApiEvent{ kind: 'job.created', subject: 'job_${i}' })
	}
	kept, missed := bus.since(0)
	assert missed
	assert kept.map(it.seq) == [3, 4, 5]
	fresh, fresh_missed := bus.since(2)
	assert !fresh_missed
	assert fresh.map(it.seq) == [3, 4, 5]
	future, future_missed := bus.since(99)
	assert future_missed
	assert future.len == 3
}

fn test_event_bus_subscriber_cap() {
	mut bus := new_event_bus()
	for _ in 0 .. max_event_subscribers {
		assert bus.acquire()
	}
	assert !bus.acquire()
	bus.release()
	assert bus.acquire()
}

fn test_event_filter_and_cursor_parsing() {
	assert event_matches('job.created', [])
	assert event_matches('job.created', ['job.'])
	assert event_matches('loop.finished', ['job.', 'loop.finished'])
	assert !event_matches('loop.started', ['job.', 'loop.finished'])
	assert !event_matches('jobx.created', ['job.'])
	assert parse_event_cursor('', '11')!.seq == 0
	assert parse_event_cursor(' 42 ', '11')! == EventCursor{
		seq: 42
	}
	assert parse_event_cursor('11-7', '11')! == EventCursor{
		seq: 7
	}
	assert parse_event_cursor('99-7', '100')! == EventCursor{
		seq: 7
		foreign: true
	}
	for bad in ['-1', '1e3', 'abc', '1234567890', 'x-1', '12-', '12-a'] {
		if _ := parse_event_cursor(bad, '12') {
			assert false, 'accepted ${bad}'
		}
	}
}

fn test_sse_id_round_trips_and_other_boot_is_foreign() {
	mut bus := new_event_bus()
	ev := bus.publish(ApiEvent{ kind: 'job.created' })
	assert ev.boot == bus.boot
	id := event_sse_id(ev)
	assert parse_event_cursor(id, bus.boot)! == EventCursor{
		seq: ev.seq
	}
	restarted := EventBus{
		boot: '${bus.boot}0'
	}
	assert parse_event_cursor(id, restarted.boot)!.foreign
}

fn test_api_event_types_match_schema_enum() {
	schemas := os.join_path(os.dir(@FILE), '..', '..', 'docs', 'compatibility', 'api-schemas.yaml')
	text := os.read_file(schemas) or { panic(err) }
	line := text.split_into_lines().filter(it.trim_space().starts_with('- type:string='))
	assert line.len == 1
	assert line[0].all_after('=').split('|') == api_event_types
}

fn test_swarm_sub_mutates() {
	assert swarm_sub_mutates('start', agent_toolkit_core.SwarmOptions{})
	assert !swarm_sub_mutates('start', agent_toolkit_core.SwarmOptions{ dry_run: true })
	assert !swarm_sub_mutates('status', agent_toolkit_core.SwarmOptions{})
	assert swarm_sub_mutates('handoff', agent_toolkit_core.SwarmOptions{ handoff_sub: 'create' })
	assert !swarm_sub_mutates('handoff', agent_toolkit_core.SwarmOptions{})
	assert swarm_sub_mutates('task', agent_toolkit_core.SwarmOptions{ handoff_sub: 'complete' })
	assert !swarm_sub_mutates('task', agent_toolkit_core.SwarmOptions{ handoff_sub: 'help' })
}

fn test_api_event_json_uses_type_key() {
	ev := ApiEvent{
		seq: 7
		kind: 'job.updated'
		subject: 'job_x'
		status: 'failed'
		exit_code: 1
	}
	text := json2.encode(ev)
	assert text.contains('"type":"job.updated"')
	assert !text.contains('"kind"')
	back := json2.decode[ApiEvent](text)!
	assert back.kind == 'job.updated'
}

fn test_job_loop_name() {
	assert job_loop_name(Job{ cmd: 'loop', args: ['loop', 'run', 'triage', '--workspace', '/w'] }) == 'triage'
	assert job_loop_name(Job{ cmd: 'loop', args: ['run', 'triage'] }) == 'triage'
	assert job_loop_name(Job{ cmd: 'loop', args: ['loop', 'status'] }) == ''
	assert job_loop_name(Job{ cmd: 'loop', args: ['loop', 'run', '--dry-run'] }) == ''
	assert job_loop_name(Job{ cmd: 'version', args: ['run', 'x'] }) == ''
}

fn test_cancel_and_delete_publish_job_events() {
	dir := os.join_path(os.temp_dir(), 'test_evjobs_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	mut runner := new_job_runner(dir)
	mut bus := new_event_bus()
	runner.bus = bus
	runner.jobs['job_ev_x1'] = Job{
		id: 'job_ev_x1'
		cmd: 'loop'
		args: ['loop', 'run', 'triage']
		status: 'running'
	}
	runner.running = 1
	runner.cancel('job_ev_x1') or { panic(err.msg()) }
	runner.delete('job_ev_x1', false) or { panic(err.msg()) }
	events, _ := bus.since(0)
	assert events.map(it.kind) == ['job.updated', 'loop.finished', 'job.deleted']
	assert events[0].subject == 'job_ev_x1'
	assert events[0].status == 'canceled'
	assert events[1].subject == 'triage'
	assert events[1].ref == 'job_ev_x1'
	assert events[2].status == 'canceled'
}

fn test_retry_source_only_failed_or_canceled() {
	dir := os.join_path(os.temp_dir(), 'test_retrysrc_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	mut runner := new_job_runner(dir)
	for st in ['failed', 'canceled', 'completed', 'running', 'rejected'] {
		runner.jobs['job_rs_${st}'] = Job{
			id: 'job_rs_${st}'
			cmd: 'version'
			status: st
		}
	}
	assert runner.retry_source('job_rs_failed')!.id == 'job_rs_failed'
	assert runner.retry_source('job_rs_canceled')!.id == 'job_rs_canceled'
	for st in ['completed', 'running', 'rejected'] {
		runner.retry_source('job_rs_${st}') or {
			assert err.msg().starts_with('job is ${st}')
			continue
		}
		assert false, 'retry allowed for ${st}'
	}
	runner.retry_source('job_rs_missing') or {
		assert err.msg().starts_with('job not found')
		return
	}
	assert false, 'expected not-found error'
}

// Live proof (unix): a failing fake `agent-toolkit` run publishes
// job.created then job.updated(failed), and its retry is a new job linked
// by retry_of that publishes its own lifecycle.
fn test_live_job_events_and_retry() {
	$if windows {
		return
	}
	dir := os.join_path(os.temp_dir(), 'test_evlive_' + os.getpid().str())
	os.mkdir_all(dir) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	fake := os.join_path(dir, 'agent-toolkit')
	os.write_file(fake, '#!/bin/sh\necho boom\nexit 3\n') or { panic(err.msg()) }
	os.chmod(fake, 0o755) or { panic(err.msg()) }
	old_path := os.getenv('PATH')
	os.setenv('PATH', dir + ':' + old_path, true)
	defer {
		os.setenv('PATH', old_path, true)
	}
	mut runner := new_job_runner(os.join_path(dir, 'runs'))
	mut bus := new_event_bus()
	runner.bus = bus
	first := runner.create('version', ['version'], '') or { panic(err.msg()) }
	wait_terminal(runner, first.id)
	src := runner.retry_source(first.id) or { panic(err.msg()) }
	assert src.status == 'failed'
	second := runner.create_job(src.cmd, src.args, src.workspace, src.id) or { panic(err.msg()) }
	assert second.id != first.id
	assert second.retry_of == first.id
	wait_terminal(runner, second.id)
	events, _ := bus.since(0)
	assert events.map('${it.kind}:${it.subject}') == ['job.created:${first.id}',
		'job.updated:${first.id}', 'job.created:${second.id}', 'job.updated:${second.id}']
	assert events[1].status == 'failed'
	assert events[1].exit_code == 3
	assert events[2].ref == first.id
	assert runner.get(first.id)!.status == 'failed'
}

fn wait_terminal(runner &JobRunner, id string) {
	deadline := time.now().add(15 * time.second)
	for {
		job := runner.get(id) or { panic('job vanished: ${id}') }
		if is_terminal(job.status) {
			return
		}
		assert time.now().unix_milli() <= deadline.unix_milli(), 'job never finished: ${id}'
		time.sleep(50 * time.millisecond)
	}
}
