module desktop_engine

import os
import agent_toolkit_core

// S7 evidence-truth regression gates. These tests enforce the contract from
// docs/desktop/TRUTH_LEDGER.md: receipts and provenance exist only as real
// evidence, digests are real SHA-256 values, verified is earned by an actual
// verification operation, and unknown stays unknown.

struct EvidenceHarness {
	tmp      string
	prev_root string
	prev_cfg  string
}

fn evidence_harness_setup() EvidenceHarness {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	prev_cfg := os.getenv('XDG_CONFIG_HOME')
	tmp := os.join_path(os.temp_dir(), 'evidence-truth-${os.getpid()}')
	os.mkdir_all(os.join_path(tmp, 'xdg-config')) or { panic(err.msg()) }
	os.setenv('XDG_CONFIG_HOME', os.join_path(tmp, 'xdg-config'), true)
	return EvidenceHarness{
		tmp: tmp
		prev_root: prev_root
		prev_cfg: prev_cfg
	}
}

fn evidence_harness_teardown(h EvidenceHarness) {
	os.setenv('AGENT_TOOLKIT_ROOT', h.prev_root, true)
	os.setenv('XDG_CONFIG_HOME', h.prev_cfg, true)
	os.rmdir_all(h.tmp) or {}
}

// A fresh Engine with no install history must surface zero receipts and never
// invent receipt evidence for selections.
fn test_fresh_engine_has_no_receipts() {
	h := evidence_harness_setup()
	defer { evidence_harness_teardown(h) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(h.tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	rec := eng.receipts_catalog()
	assert rec.len == 0, 'fresh engine must not invent receipts: got ${rec.len}'
	stats := eng.receipts_stats()
	assert stats.total == 0 && stats.verified == 0
	assert eng.verify_receipts().len == 0
	// no receipt evidence exists for a selected skill without a real install
	if _ := eng.skill_receipt('core/assistant') {
		assert false, 'skill selection alone must not produce receipt evidence'
	}
}

// Selecting a skill records configuration only — never receipt or provenance
// state keys, never fabricated digests.
fn test_skill_selection_writes_no_receipt_evidence() {
	h := evidence_harness_setup()
	defer { evidence_harness_teardown(h) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(h.tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	rev := eng.install_skill('core/assistant') or { panic(err.msg()) }
	assert rev >= 1
	snap := eng.repo.snapshot()
	for k, _ in snap.data {
		assert !k.starts_with('receipt:'), 'selection must not write receipt keys: ${k}'
		assert !k.starts_with('provenance:'), 'selection must not write provenance keys: ${k}'
	}
	assert 'core/assistant' in eng.skills_installed()

	// job completion records runtime truth only — no receipt keys
	id := eng.spawn_job('echo', ['hello']) or { panic(err.msg()) }
	eng.job_complete(id, 0) or { panic(err.msg()) }
	snap2 := eng.repo.snapshot()
	for k, _ in snap2.data {
		assert !k.starts_with('receipt:'), 'job completion must not write receipt keys: ${k}'
		assert !k.starts_with('provenance:'), 'job completion must not write provenance keys: ${k}'
	}
}

// Real receipts written by the core installer are surfaced with actual
// verification: artifact digests are recomputed from the artifact bytes.
fn test_real_receipt_verification() {
	h := evidence_harness_setup()
	defer { evidence_harness_teardown(h) }

	// real artifact file + real digest
	art_dir := os.join_path(h.tmp, 'artifacts')
	os.mkdir_all(art_dir) or { panic(err.msg()) }
	art_path := os.join_path(art_dir, 'profile.md')
	os.write_file(art_path, '# real profile content\n') or { panic(err.msg()) }
	digest := agent_toolkit_core.receipt_artifact_digest(art_path)
	assert digest != 'missing'
	assert digest.len == 16, 'core digest is 16-hex: ${digest}'

	mut receipt := agent_toolkit_core.new_install_receipt('agent-toolkit-profiles', 'claude-code',
		'user-home', 'test-version', 'src-digest-000111')
	receipt.artifacts << agent_toolkit_core.ArtifactEntry{
		path: art_path
		digest: digest
		ownership: 'created'
	}
	saved := agent_toolkit_core.save_install_receipt(mut receipt, '') or { panic(err.msg()) }
	assert saved.contains('claude-code-agent-toolkit-profiles.json')

	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(h.tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	cat := eng.receipts_catalog()
	assert cat.len == 1, 'real receipt must surface: got ${cat.len}'
	r := cat[0]
	assert r.id == 'claude-code'
	assert r.product == 'agent-toolkit-profiles'
	assert r.version == 'test-version'
	assert r.installed_at != '', 'installed_at comes from the real receipt file'
	assert r.receipt_path == saved
	assert r.verified, 'digest recomputation must succeed while artifact matches'

	// tamper with the artifact → verification must fail honestly
	os.write_file(art_path, '# tampered\n') or { panic(err.msg()) }
	cat2 := eng.receipts_catalog()
	assert cat2.len == 1
	assert !cat2[0].verified, 'tampered artifact must report unverified, never silently pass'
	assert eng.verify_receipts().len == 1, 'unverified receipt must be reported'
}

// Provenance entries come from real bundled manifests with real digests —
// never placeholders like sha256:abc.
fn test_provenance_is_real_manifest_evidence() {
	h := evidence_harness_setup()
	defer { evidence_harness_teardown(h) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(h.tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	prov := eng.provenance_catalog()
	assert prov.len > 0, 'bundled plugins manifests must yield provenance records'
	for p in prov {
		assert p.artifact_path.starts_with('plugins/')
		assert !p.source_digest.contains('abc'), 'placeholder digests are forbidden'
		assert !p.generated_digest.contains('def'), 'placeholder digests are forbidden'
		assert p.detail != ''
	}

	// a bundled skill has real provenance evidence from the manifests
	sp := eng.skill_provenance('core/assistant') or {
		panic('core/assistant must have real provenance from plugins manifests')
	}
	assert sp.source_digest.len > 0
	assert !sp.source_digest.contains('abc')

	// agent provenance detail reports the verification field honestly
	detail := eng.agent_provenance_detail('code-reviewer')
	assert detail.contains('"verified"')
}

// The plugins-digest is a real SHA-256 over canonical catalog material.
fn test_build_preview_digest_is_real_sha256() {
	h := evidence_harness_setup()
	defer { evidence_harness_teardown(h) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(h.tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	p1 := eng.build_preview()
	p2 := eng.build_preview()
	assert p1 == p2, 'digest over canonical material must be stable'
	digest := p1.all_after('plugins-digest:').all_before(':')
	assert digest.len == 64, 'SHA-256 hex must be 64 chars: ${digest}'
	for c in digest {
		assert (c >= `0` && c <= `9`) || (c >= `a` && c <= `f`), 'digest must be hex: ${digest}'
	}
}

// MCP evidence semantics: enabling uses the packaged template, health is
// configured (not healthy) until a probe succeeds, and invalid JSON is
// refused.
fn test_mcp_enable_uses_packaged_template_and_honest_health() {
	h := evidence_harness_setup()
	defer { evidence_harness_teardown(h) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(h.tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	// invalid JSON must be refused by upsert
	if _ := eng.upsert_mcp_provider('github', 'not-json{') {
		assert false, 'invalid JSON must be rejected'
	} else {
		assert err.msg().contains('not valid JSON')
	}

	rev := eng.mcp_toggle('github') or { panic(err.msg()) }
	assert rev >= 1
	snap := eng.repo.snapshot()
	assert snap.data['mcp:github:enabled'] == 'true'
	assert snap.data['mcp:github:health'] == 'configured', 'enabled without probe is configured, not healthy'
	assert snap.data['mcp:github:config'] != '', 'toggle must record the packaged template config'
	assert !snap.data['mcp:github:config'].contains('@modelcontextprotocol/server-github'),
		'toggle must not invent an npx stanza'
	assert snap.data['provenance:mcp:github:source'] == 'mcp/templates/github/config.template.json',
		'provenance must be the real packaged template path'

	// enabled provider without a probe reports configured or warn, never healthy
	hg := eng.mcp_health_detailed('github')
	assert hg == 'configured' || hg == 'warn', 'unprobed provider must not report healthy: ${hg}'
	// verify_mcp_receipts is a real config check
	assert eng.verify_mcp_receipts().len == 0
}
