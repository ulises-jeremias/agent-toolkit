module desktop_engine

import os
import crypto.sha256

// S7E truth gates for the remaining Engine surfaces: updates, memory,
// swarms, jobs and Doctor. Each value is real evidence or explicitly
// unknown/unavailable — never a plausible fabrication.

fn engine_truth_engine(tmp string) &Engine {
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return eng
}

// The update service has no real feed reader: no offer is invented, apply is
// unavailable (a state-only version change is not an update), and verify
// performs a real SHA-256 over the actual content.
fn test_update_service_is_honest_without_a_feed() {
	tmp := os.join_path(os.temp_dir(), 'update-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := engine_truth_engine(tmp)
	defer { eng.stop() or {} }

	if _ := eng.check_for_update('1.0.0', 'stable') {
		assert false, 'no real feed exists — an offer must not be invented'
	}
	assert eng.apply_update('9.9.9') == false, 'apply is unavailable until a real updater exists'
	snap := eng.repo.snapshot()
	for k, _ in snap.data {
		assert !k.contains('update:applied') && !k.contains('receipt:update'),
			'apply must not record fabricated update state: ${k}'
	}
	assert eng.update_history().len == 0, 'no recorded updates means empty history'

	// real digest verification: hash of the actual content
	assert eng.update_verify('real content', sha256_of('real content')) == true
	assert eng.update_verify('real content', sha256_of('other content')) == false
	assert eng.update_verify('', 'deadbeef') == false

	// manifest verification is a real JSON structural parse
	mut svc := new_update_service_engine(eng.repo, eng.bus)
	assert svc.manifest_verify('{"version":"1.0","sha256":"abc","provenance":"p"}') == true
	assert svc.manifest_verify('not json') == false
	assert svc.manifest_verify('{"version":"1.0"}') == false, 'missing fields must fail'
	assert svc.manifest_verify('the version and sha256 and provenance words in plain text') == false,
		'substring presence is not validation'
}

fn sha256_of(s string) string {
	return sha256.hexhash(s)
}

// Memory entries come only from the real workspace knowledge directory —
// no demo palace nodes and no toolkit-root (or cwd) leakage.
fn test_memory_palace_is_workspace_truth() {
	tmp := os.join_path(os.temp_dir(), 'memory-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := engine_truth_engine(tmp)
	defer { eng.stop() or {} }

	// no workspace → empty palace, never 8 demo nodes
	assert eng.memory_palace_entries().len == 0, 'no workspace means no memory entries'

	// a real workspace with real knowledge yields real entries
	ws := os.join_path(tmp, 'ws')
	os.mkdir_all(os.join_path(ws, 'knowledge', 'learnings')) or { panic(err.msg()) }
	os.write_file(os.join_path(ws, 'knowledge', 'learnings', 'real.md'), '# Real Learning\ncontent\n') or { panic(err.msg()) }
	eng.switch_workspace(ws) or { panic(err.msg()) }
	entries := eng.memory_palace_entries()
	assert entries.len == 1, 'real knowledge yields real entries: got ${entries.len}'
	assert entries[0].title == 'Real Learning'
	assert entries[0].kind == 'learning'
}

// A swarm launch records the request honestly: 'requested' (no backend is
// contacted), no invented budget, and no synthesized log lines.
fn test_swarm_launch_is_requested_not_running() {
	tmp := os.join_path(os.temp_dir(), 'swarm-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := engine_truth_engine(tmp)
	defer { eng.stop() or {} }

	run_id := eng.swarm_launch(SwarmLaunchArgs{
		recipe: swarm_recipe_from_string('pair')
		backend: swarm_backend_from_string('herdr')
		task: 'verify swarm truth'
	}) or { panic(err.msg()) }
	snap := eng.repo.snapshot()
	assert snap.data['swarm/runs/${run_id}/status'] == 'requested',
		'no backend is contacted at launch — requested, not running: ${snap.data['swarm/runs/${run_id}/status']}'
	assert 'swarm/runs/${run_id}/budget_total' !in snap.data, 'budget is unknown until a real runner reports it'
	assert eng.swarm_logs(run_id).len == 0, 'no logs means no logs'
}

// A job's exit code is unknown until a real completion records it; Doctor
// reports computed digests instead of unearned verification claims.
fn test_jobs_and_doctor_report_real_values() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'jobs-doctor-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := engine_truth_engine(tmp)
	defer { eng.stop() or {} }

	// exit code unknown (-1 sentinel) until completion
	id := eng.spawn_job('echo', ['hello']) or { panic(err.msg()) }
	rec := eng.jobs_catalog().filter(it.id == id)[0]
	assert rec.exit_code == -1, 'exit code is unknown until completion: ${rec.exit_code}'
	eng.job_complete(id, 0) or { panic(err.msg()) }
	rec2 := eng.jobs_catalog().filter(it.id == id)[0]
	assert rec2.exit_code == 0
	assert rec2.status == .done

	// doctor: no fabricated swarm apiVersion check; real computed lock digest;
	// honest placeholder warnings for the DI plane
	checks := eng.doctor()
	ids := checks.map(it.id)
	assert 'swarm:apiVersion' !in ids, 'the fabricated apiVersion health claim is gone'
	for c in checks {
		assert !c.message.contains('sha verified via'), 'verification claims must be earned: ${c.id}'
		assert !c.message.contains('shell_exec=0'), 'unmeasured claims must not be asserted: ${c.id}'
	}
	sha_check := checks.filter(it.id == 'provenance:sha')
	assert sha_check.len == 1
	digest := sha_check[0].message.all_after('sha256:')
	assert digest.len == 64, 'lock digest is the real SHA-256 of the actual bytes: ${digest}'
	for c in digest_runes(digest) {
		assert c, 'digest must be hex'
	}
}

fn digest_runes(s string) []bool {
	mut out := []bool{}
	for c in s {
		out << (c >= `0` && c <= `9`) || (c >= `a` && c <= `f`)
	}
	return out
}
