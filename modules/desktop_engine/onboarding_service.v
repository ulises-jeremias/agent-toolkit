module desktop_engine

import os

// OnboardingStatus aggregates super-potent onboarding state for wizard.
// Everything is possible and easy to manage: one call returns all gaps.
pub struct OnboardingStatus {
pub:
	is_first_run          bool
	workspace_exists      bool
	personas_bootstrapped bool
	installed_skills      []string
	installed_count       int
	enabled_targets       []string
	enabled_targets_count int
	products_count        int
	packs_enabled         []string
	pending_checks        []string
	pending_items         []string
	completed             bool
	harness_root          string
	revision              u64
	persona_count         int
	capability_ready      bool
	target_ready          bool
	product_ready         bool
	workspace_ready       bool
	persona_ready         bool
}

// onboarding_status returns aggregated wizard state via Engine (typed, no shell).
// harness_root may be '' — then uses toolkit_root/workspaces heuristic.
pub fn (mut e Engine) onboarding_status(harness_root string) OnboardingStatus {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	rev := snap.revision
	is_first := snap.data['onboarding_completed'] or { '' } != 'true'
	completed := !is_first
	// resolve harness root for existence checks
	env := resolve_env()
	mut root := harness_root.trim_space()
	if root == '' {
		// prefer recent_workspace from state, else toolkit_root
		root = snap.data['recent_workspace'] or { env.toolkit_root }
	}
	// workspace_exists: knowledge/ repos/ projects/ packs/
	workspace_exists := os.is_dir(os.join_path(root, 'knowledge')) || os.is_dir(os.join_path(root, 'repos'))
	personas_dir := os.join_path(root, 'personas')
	mut persona_count := 0
	mut personas_bootstrapped := false
	if os.is_dir(personas_dir) {
		ents := os.ls(personas_dir) or { []string{} }
		for en in ents {
			if en.ends_with('.md') {
				persona_count++
			}
		}
		personas_bootstrapped = persona_count >= 2
	}
	installed_raw := snap.data['installed_skills'] or { '' }
	mut installed := []string{}
	if installed_raw != '' {
		installed = installed_raw.split(',').map(it.trim_space()).filter(it != '')
	}
	// enabled targets via Engine targets()
	mut enabled := []string{}
	for t in e.targets() {
		if t.enabled {
			enabled << t.id
		}
	}
	// packs enabled
	mut packs_enabled := []string{}
	for k, v in snap.data {
		if k.starts_with('pack:') && k.ends_with(':enabled') && v == 'true' {
			pid := k.all_after('pack:').all_before(':enabled')
			packs_enabled << pid
		}
	}
	products_len := e.products_catalog().len
	packs_len := e.packs_catalog().len
	_ = packs_len
	mut pending := []string{}
	mut pending_checks := []string{}
	if is_first {
		pending << 'onboarding not completed'
		pending_checks << 'onboarding_completed'
	}
	if !workspace_exists {
		pending << 'workspace not initialized (knowledge/repos/projects/packs)'
		pending_checks << 'workspace_exists'
	}
	if !personas_bootstrapped {
		pending << 'personas not bootstrapped (personas/*.md)'
		pending_checks << 'personas'
	}
	if installed.len == 0 {
		pending << 'no capabilities selected (0 skills installed)'
		pending_checks << 'capability'
	}
	if enabled.len == 0 {
		pending << 'no targets enabled'
		pending_checks << 'targets'
	}
	capability_ready := installed.len > 0
	target_ready := enabled.len > 0
	product_ready := products_len > 0
	workspace_ready := workspace_exists
	persona_ready := personas_bootstrapped
	return OnboardingStatus{
		is_first_run: is_first
		workspace_exists: workspace_exists
		personas_bootstrapped: personas_bootstrapped
		installed_skills: installed.clone()
		installed_count: installed.len
		enabled_targets: enabled.clone()
		enabled_targets_count: enabled.len
		products_count: products_len
		packs_enabled: packs_enabled.clone()
		pending_checks: pending_checks.clone()
		pending_items: pending.clone()
		completed: completed
		harness_root: root
		revision: rev
		persona_count: persona_count
		capability_ready: capability_ready
		target_ready: target_ready
		product_ready: product_ready
		workspace_ready: workspace_ready
		persona_ready: persona_ready
	}
}

// onboarding_ensure_workspace creates harness workspace scaffold (knowledge, repos, projects, packs, personas, .agent-toolkit).
// Brokered via Engine transaction; filesystem scaffold is best-effort and revision bumps on success.
pub fn (mut e Engine) onboarding_ensure_workspace(target_dir string) !u64 {
	if target_dir.trim_space() == '' {
		return error('target dir empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	clean := os.real_path(target_dir)
	// also handle non-existing target: use target_dir as is for mkdir
	mut actual := target_dir
	if clean != target_dir && os.exists(target_dir) {
		actual = clean
	}
	// prevent escape? for onboarding we allow any path under home or temp but block root
	if actual == '/' || actual == '' {
		return error('invalid workspace path')
	}
	os.mkdir_all(actual) or { return error('mkdir failed: ${err}') }
	// scaffold harness structure mirroring agent_toolkit_core workspace_init
	subdirs := ['knowledge', 'knowledge/learnings', 'knowledge/todos', 'packs', 'personas', 'repos',
		'projects', '.agent-toolkit/swarm/runs']
	for sub in subdirs {
		os.mkdir_all(os.join_path(actual, sub)) or { return error('mkdir ${sub} failed: ${err}') }
	}
	// scaffold minimal files if missing
	files := {
		'knowledge/README.md':            '# Knowledge — harness workspace\n\nRun `agent-toolkit memory search <topic>` before asking.\n'
		'knowledge/learnings/general.md': '| Date | Learning | Context |\n|------|----------|---------|\n'
		'knowledge/todos/pending.md':     '# Pending\n\n<!-- add via memory add -->\n'
		'packs/README.md':                '# Packs — context bundles\n\nCreate packs/*.yaml and load via workspace load.\n'
		'.gitignore':                     'repos/\nprojects/\n.active-*\n.persona-history\n'
	}
	for rel, content in files {
		p := os.join_path(actual, rel)
		if !os.exists(p) {
			os.mkdir_all(os.dir(p)) or { return error('mkdir parent for ${rel} failed: ${err}') }
			os.write_file(p, content) or { return error('write ${rel} failed: ${err}') }
		}
	}
	// also ensure .gitkeep for repos/projects
	for d in ['repos', 'projects'] {
		gk := os.join_path(actual, d, '.gitkeep')
		if !os.exists(gk) {
			os.write_file(gk, '') or { return error('write ${d}/.gitkeep failed: ${err}') }
		}
	}
	mut repo := e.repo
	mut tx := repo.begin('onboarding-ensure-workspace')
	tx.set('recent_workspace', actual)
	tx.set('workspace_exists', 'true')
	tx.set('workspace_path', actual)
	tx.set('workspace_initialized', 'true')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// onboarding_ensure_personas bootstraps persona markdowns into harness_root/personas if missing.
// Uses minimal embedded persona templates (no shell, no external fetch).
pub fn (mut e Engine) onboarding_ensure_personas(harness_root string) !u64 {
	if harness_root.trim_space() == '' {
		return error('harness_root empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	clean := e.open_path_validated(harness_root, harness_root)!
	os.mkdir_all(os.join_path(clean, 'personas')) or { return error('mkdir personas failed: ${err}') }
	persona_templates := {
		'implementer.md': '---\nallow: [write_files, run_tests]\ndeny: [merge_prs]\n---\n\n# Implementer\n\nBias toward action.\n'
		'reviewer.md':    '---\nallow: [read_files, post_comments]\ndeny: [write_files]\n---\n\n# Reviewer\n\nCritique only.\n'
		'researcher.md':  '---\nallow: [read_files, search_web]\ndeny: [write_files]\n---\n\n# Researcher\n\nExplore and summarize.\n'
		'architect.md':   '---\nallow: [read_files, write_docs]\ndeny: [write_application_code]\n---\n\n# Architect\n\nSystem design.\n'
	}
	mut created := 0
	for fname, content in persona_templates {
		p := os.join_path(clean, 'personas', fname)
		if !os.exists(p) {
			os.write_file(p, content) or { continue }
			created++
		}
	}
	mut persona_count := 0
	for fname, _ in persona_templates {
		if os.is_file(os.join_path(clean, 'personas', fname)) {
			persona_count++
		}
	}
	if persona_count < 2 {
		return error('persona bootstrap incomplete: ${persona_count}/${persona_templates.len} available')
	}
	mut repo := e.repo
	mut tx := repo.begin('onboarding-ensure-personas')
	tx.set('personas_bootstrapped', 'true')
	tx.set('persona_count', persona_count.str())
	tx.set('recent_workspace', clean)
	if created > 0 {
		tx.set('personas_created', '${created}')
	}
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// onboarding_bulk_install_skills installs multiple skills in one transaction (super-potent).
pub fn (mut e Engine) onboarding_bulk_install_skills(skill_ids []string) !u64 {
	if skill_ids.len == 0 {
		return error('no skill ids')
	}
	for sid in skill_ids {
		if sid.trim_space() == '' {
			return error('skill id empty in bulk')
		}
		_ := e.skill_detail(sid) or { return error('skill not found: ${sid}') }
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	cur := repo.snapshot().data['installed_skills'] or { '' }
	mut set := cur.split(',').map(it.trim_space()).filter(it != '')
	for sid in skill_ids {
		if sid !in set {
			set << sid
		}
	}
	mut tx := repo.begin('onboarding-bulk-install')
	tx.set('installed_skills', set.join(','))
	tx.set('skills_count', set.len.str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// onboarding_bulk_remove_skills removes multiple in one TX.
pub fn (mut e Engine) onboarding_bulk_remove_skills(skill_ids []string) !u64 {
	if skill_ids.len == 0 {
		return error('no skill ids')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	cur := repo.snapshot().data['installed_skills'] or { '' }
	mut set := cur.split(',').map(it.trim_space()).filter(it != '')
	for sid in skill_ids {
		idx := set.index(sid)
		if idx >= 0 {
			set.delete(idx)
		}
	}
	mut tx := repo.begin('onboarding-bulk-remove')
	tx.set('installed_skills', set.join(','))
	tx.set('skills_count', set.len.str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// onboarding_set_targets_bulk replaces enabled set with exactly enabled_ids (super-potent).
pub fn (mut e Engine) onboarding_set_targets_bulk(enabled_ids []string) !u64 {
	if enabled_ids.len == 0 {
		return error('no targets selected — at least one required')
	}
	valid := e.targets().map(it.id)
	for tid in enabled_ids {
		if tid !in valid {
			return error('unsupported target: ${tid}')
		}
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('onboarding-set-targets-bulk')
	for vid in valid {
		tx.set('target:${vid}:enabled', if vid in enabled_ids { 'true' } else { 'false' })
	}
	tx.set('targets_enabled', enabled_ids.join(','))
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// onboarding_set_products_bulk sets active products membership in bulk (product_ids present).
pub fn (mut e Engine) onboarding_set_products_bulk(product_ids []string) !u64 {
	if product_ids.len == 0 {
		return error('no product ids')
	}
	valid := e.products_catalog().map(it.id)
	for pid in product_ids {
		if pid !in valid {
			return error('product not found: ${pid}')
		}
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('onboarding-set-products')
	tx.set('active_products', product_ids.join(','))
	tx.set('products_count', product_ids.len.str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// onboarding_complete marks onboarding done and persists recent_workspace/harness state.
pub fn (mut e Engine) onboarding_complete(harness_root string) !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('onboarding-complete')
	tx.set('onboarding_completed', 'true')
	if harness_root.trim_space() != '' {
		clean := os.real_path(harness_root)
		actual := if clean != '' { clean } else { harness_root }
		tx.set('recent_workspace', actual)
		tx.set('workspace_path', actual)
	}
	tx.set('onboarding_completed_at', '${repo.snapshot().timestamp}')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// onboarding_reset allows re-running wizard (super-potent: reset + pending).
pub fn (mut e Engine) onboarding_reset() !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('onboarding-reset')
	tx.set('onboarding_completed', 'false')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// workspace_init_with_templates is convenience wrapper for init + persona bootstrap in one rev.
pub fn (mut e Engine) workspace_init_with_templates(target_dir string, with_personas bool) !u64 {
	rev1 := e.onboarding_ensure_workspace(target_dir)!
	if with_personas {
		clean := os.real_path(target_dir)
		actual := if clean != '' { clean } else { target_dir }
		_ := e.onboarding_ensure_personas(actual) or { return rev1 }
		snap := e.repo.snapshot()
		return snap.revision
	}
	return rev1
}
