module desktop_engine

import os

// Dismissing setup (Skip / o / Esc) persists completion so the wizard never
// ambushes the next launch: fresh engines read first-run, completing flips
// it, and the flip survives a reopen on the same persist path.
fn test_onboarding_complete_flips_first_run_persistently() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'onb-first-run-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	state_path := os.join_path(tmp, 'state.json')
	mut eng := new_engine(EngineConfig{
		persist_path: state_path
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	assert eng.is_first_run(), 'fresh engine must read first-run'
	rev := eng.complete_onboarding() or { panic(err.msg()) }
	assert rev >= 1, 'completion must commit a revision'
	assert !eng.is_first_run(), 'completed engine must not read first-run'
}
