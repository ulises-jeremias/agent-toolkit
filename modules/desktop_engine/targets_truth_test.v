module desktop_engine

import os

// S7B target/install truth gates: the supported roster comes from the
// canonical registry, nothing is enabled by default, detection is real, and
// install evidence is real deployed files plus a real receipt.

fn targets_truth_setup() (string, string) {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	prev_cfg := os.getenv('XDG_CONFIG_HOME')
	tmp := os.join_path(os.temp_dir(), 'targets-truth-${os.getpid()}')
	os.mkdir_all(os.join_path(tmp, 'xdg-config')) or { panic(err.msg()) }
	os.setenv('XDG_CONFIG_HOME', os.join_path(tmp, 'xdg-config'), true)
	return tmp, prev_root
}

fn targets_truth_teardown(tmp string, prev_root string, prev_cfg string) {
	os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true)
	os.setenv('XDG_CONFIG_HOME', prev_cfg, true)
	os.rmdir_all(tmp) or {}
}

// The roster comes from capabilities/targets/registry.yaml with real display
// names; a fresh configuration enables nothing by default.
fn test_targets_come_from_canonical_registry() {
	tmp, prev_root := targets_truth_setup()
	prev_cfg := os.getenv('XDG_CONFIG_HOME')
	defer { targets_truth_teardown(tmp, prev_root, prev_cfg) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	reg := eng.targets_registry()
	assert reg.len == 11, 'registry must list 11 targets: got ${reg.len}'
	mut by_id := map[string]TargetRegistryEntry{}
	for r in reg {
		by_id[r.id] = r
	}
	assert by_id['claude-code'].display_name == 'Claude Code'
	assert by_id['cursor'].tier == 'A'
	assert by_id['windsurf'].maturity == 'limited'

	tgts := eng.targets()
	assert tgts.len == 11
	for t in tgts {
		assert !t.enabled, 'fresh config must not enable ${t.id} by default'
		assert t.status == 'detected' || t.status == 'available', 'fresh status must be detected/available: ${t.id}=${t.status}'
		assert t.receipt == '', 'no receipt evidence without a real install: ${t.id}'
	}
	// targets with bundled profiles carry the real bundled path
	mut with_profiles := 0
	for t in tgts {
		if t.path != '' {
			assert t.path.starts_with('profiles/'), 'bundled profile path: ${t.path}'
			with_profiles++
		}
	}
	assert with_profiles >= 5, 'bundled profile targets must be present: ${with_profiles}'
}

// set_target_enabled only accepts registry targets and writes explicit
// configuration only — no receipt keys.
fn test_set_target_enabled_is_explicit_config() {
	tmp, prev_root := targets_truth_setup()
	prev_cfg := os.getenv('XDG_CONFIG_HOME')
	defer { targets_truth_teardown(tmp, prev_root, prev_cfg) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	if _ := eng.set_target_enabled('not-a-target', true) {
		assert false, 'unknown target must be rejected'
	} else {
		assert err.msg().contains('unsupported target')
	}
	rev := eng.set_target_enabled('cursor', true) or { panic(err.msg()) }
	assert rev >= 1
	assert eng.targets().filter(it.id == 'cursor')[0].enabled == true
	snap := eng.repo.snapshot()
	for k, _ in snap.data {
		assert !k.starts_with('receipt:target:'), 'enabling must not write receipt keys: ${k}'
	}
}

// install deploys real profile files through the core installer and records
// a real receipt; dry-run writes nothing; unsupported installs fail honestly.
fn test_real_install_and_honest_dry_run() {
	tmp, prev_root := targets_truth_setup()
	prev_cfg := os.getenv('XDG_CONFIG_HOME')
	defer { targets_truth_teardown(tmp, prev_root, prev_cfg) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	// compiler target without a bundled profile installer is refused
	if _ := eng.install_with_options(InstallOptionsEngine{ targets: ['codex'] }) {
		assert false, 'codex has no bundled profile installer and must be refused'
	} else {
		assert err.msg().contains('no bundled profile installer')
	}

	// dry-run computes the real preview and writes nothing
	dry_home := os.join_path(tmp, 'dry-home')
	os.mkdir_all(dry_home) or { panic(err.msg()) }
	rev0 := eng.install_with_options(InstallOptionsEngine{
		targets: ['claude-code']
		dry_run: true
		home_dir: dry_home
	}) or { panic(err.msg()) }
	assert rev0 == 0
	assert !os.exists(os.join_path(dry_home, '.claude')), 'dry-run must not deploy files'

	// real install deploys files and records a real receipt
	home := os.join_path(tmp, 'home')
	os.mkdir_all(home) or { panic(err.msg()) }
	rev := eng.install_with_options(InstallOptionsEngine{
		targets: ['claude-code']
		home_dir: home
	}) or { panic(err.msg()) }
	assert rev >= 1
	assert os.exists(os.join_path(home, '.claude')), 'real install deploys profile files'
	recs := eng.list_install_receipts()
	assert recs.len == 1, 'exactly the real receipt surfaces: got ${recs.len}'
	assert recs[0].target == 'claude-code'
	assert recs[0].installed_at != '', 'installed_at is real receipt evidence'
	assert recs[0].artifacts.len > 0, 'real receipt records real artifacts'
	assert eng.verify_install_receipts().len == 0, 'fresh install has no drift'
	assert eng.install_receipt_json('claude-code').contains('installedAt')

	// target row now carries real receipt evidence and config truth
	row := eng.targets().filter(it.id == 'claude-code')[0]
	assert row.enabled, 'install records configuration truth'
	assert row.receipt != '', 'target row carries the real receipt path'
}
