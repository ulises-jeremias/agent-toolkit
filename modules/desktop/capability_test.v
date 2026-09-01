module desktop

import os
import desktop.skills
import desktop.products
import desktop.agents
import desktop.mcp
import desktop.doctor
import desktop.targets
import desktop.onboarding
import desktop.theme
import desktop_engine

fn test_capability_viewmodels_via_engine_no_shell() {
	tmp := os.join_path(os.temp_dir(), 'desk-cap-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	mut svm := skills.new_skill_viewmodel(mut eng)
	assert svm.filtered_skills().len >= 116
	svm.set_search('core')
	assert svm.filtered_skills().len <= 227
	svm.set_domain('core')
	_ = svm.filtered_skills()
	_ = svm.build_preview()
	diags := svm.build_diagnostics()
	assert diags.len >= 0
	install_id := svm.filtered_skills()[0].id
	_ = svm.install(install_id) or { panic(err.msg()) }
	assert svm.app_state_projection().revision >= 1
	assert eng.api_call_count() > 0
	mut pvm := products.new_products_viewmodel(mut eng)
	assert pvm.all_products().len >= 2
	assert pvm.all_packs().len == 7
	_ = pvm.update_membership(pvm.all_products()[0].id, ['core/assistant']) or { panic(err.msg()) }
	_ = pvm.build_preview()
	mut avm := agents.new_agents_viewmodel(mut eng)
	assert avm.filtered_agents().len >= 18
	avm.set_tier('holistic')
	assert avm.filtered_agents().len > 0
	_ = avm.detail(avm.filtered_agents()[0].id) or { panic(err.msg()) }
	assert avm.tier_counts()['holistic'] >= 6
	mut mvm := mcp.new_mcp_viewmodel(mut eng)
	assert mvm.filtered_providers().len == 7
	assert mvm.health('github') != ''
	p1, p2 := mvm.preview('github')
	_ = p1
	_ = p2
	if _ := mvm.upsert('github', '{"token":"ghp_bad"}') {
		assert false, 'secret blocked'
	} else {
		assert true
	}
	_ = mvm.upsert('github', '{"token":"\${GITHUB_TOKEN}"}') or { panic(err.msg()) }
	mut dvm := doctor.new_doctor_viewmodel(mut eng)
	assert dvm.all_checks().len >= 3
	_ = dvm.fix(dvm.all_checks()[0].id) or { panic(err.msg()) }
	mut tvm := targets.new_targets_viewmodel(mut eng)
	assert tvm.all_targets().len >= 7
	_ = tvm.set_enabled('claude-code', false) or { panic(err.msg()) }
	diff := tvm.preview_diff(['a'], ['a', 'b'])
	assert diff.added.len == 1
	mut ovm := onboarding.new_onboarding_viewmodel(mut eng)
	_ = ovm.is_first_run()
	_ = ovm.current_step()
	_ = ovm.next()
	_ = ovm.pick_target('claude-code', true) or { panic(err.msg()) }
	assert eng.api_call_count() > 0
	th := theme.default_theme()
	assert svm.theme_tokens(th).is_dark()
	assert pvm.theme_tokens(th).is_dark()
}
