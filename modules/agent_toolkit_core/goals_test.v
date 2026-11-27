module agent_toolkit_core

import os
import x.json2

fn sample_goal() GoalDocument {
	return GoalDocument{
		schema_version: 1
		id: 'demo'
		title: 'Demo objective'
		authorized_repositories: [
			GoalRepository{ owner: 'ulises-jeremias', name: 'agent-toolkit', path: '/work/agent-toolkit' },
		]
		acceptance_criteria: [
			GoalAcceptance{ id: 'done', description: 'validated', verification: 'independent check' },
		]
		deadline: '2026-12-01T00:00:00Z'
		budget: GoalBudget{ max_attempts: 2, wall_seconds: 3600, provider_turns: 4 }
		delivery_mode: 'draft'
		tasks: [
			GoalTask{
				id: 'one'
				title: 'First'
				repository: 'ulises-jeremias/agent-toolkit'
				base_sha: '0123456789012345678901234567890123456789'
				paths: [
					'docs',
				]
				recipe: 'research'
				runner: 'local'
				verifier: 'reviewer'
			},
			GoalTask{
				id: 'two'
				title: 'Second'
				repository: 'ulises-jeremias/agent-toolkit'
				base_sha: '0123456789012345678901234567890123456789'
				paths: [
					'schemas',
				]
				depends_on: [
					'one',
				]
				recipe: 'feature'
				runner: 'local'
				verifier: 'reviewer'
			},
		]
	}
}

fn test_goal_validates_and_plans_offline() {
	doc := sample_goal()
	validate_goal(doc) or { panic(err) }
	assert goal_plan(doc)! == ['one', 'two']
	manifest := goal_manifest_json(doc)!
	decoded := json2.decode[GoalDocument](manifest)!
	assert decoded.schema_version == 1
	assert decoded.authorized_repositories[0].path == '/work/agent-toolkit'
	assert decoded.tasks[0].paths == ['docs']
	assert decoded.tasks[1].depends_on == ['one']
}

fn test_goal_v1_keeps_legacy_manifest_without_permission_fields() {
	doc := sample_goal()
	manifest := goal_manifest_json(doc)!
	assert !manifest.contains('policy_ceiling')
	assert !manifest.contains('permissions')
	decoded := json2.decode[GoalDocument](manifest)!
	assert decoded.schema_version == 1
	assert decoded.policy_ceiling.len == 0
	assert decoded.tasks.all(it.permissions.len == 0)
}

fn test_goal_v2_permission_requests_are_bounded_by_the_policy_ceiling() {
	base := sample_goal()
	v2 := GoalDocument{
		...base
		schema_version: 2
		policy_ceiling: ['repository.read', 'repository.write', 'process.execute']
		tasks: base.tasks.map(GoalTask{
			...it
			permissions: ['repository.read', 'repository.write']
		})
	}
	validate_goal(v2) or { panic(err) }
	manifest := goal_manifest_json(v2)!
	decoded := json2.decode[GoalDocument](manifest)!
	assert decoded.schema_version == 2
	assert decoded.policy_ceiling == v2.policy_ceiling
	assert decoded.tasks.all(it.permissions == ['repository.read', 'repository.write'])

	missing_read := GoalDocument{ ...v2, policy_ceiling: ['repository.write'] }
	assert goal_error(missing_read).contains('policy_ceiling must include repository.read')
	unknown := GoalDocument{
		...v2
		policy_ceiling: [...v2.policy_ceiling, 'shell.bypass']
	}
	assert goal_error(unknown).contains('unknown effect')
	duplicate := GoalDocument{
		...v2
		policy_ceiling: [...v2.policy_ceiling, 'repository.read']
	}
	assert goal_error(duplicate).contains('repeats effect')
	outside_ceiling := GoalDocument{
		...v2
		tasks: [
			GoalTask{ ...v2.tasks[0], permissions: ['repository.read', 'github.merge'] },
			v2.tasks[1],
		]
	}
	assert goal_error(outside_ceiling).contains('outside policy_ceiling')
	v1_with_effects := GoalDocument{ ...v2, schema_version: 1 }
	assert goal_error(v1_with_effects).contains('require Goal schema_version 2')
}

fn test_goal_permission_vocabulary_is_stable_and_contains_publication_effects() {
	effects := goal_permission_effect_names()
	assert effects.len == 17
	assert effects[0] == 'repository.read'
	assert effects.contains('process.execute')
	assert effects.contains('github.merge')
	assert effects.contains('release.publish')
}

fn test_goal_recipe_registry_has_matching_definitions() {
	repo_root := os.join_path(os.dir(@FILE), '..', '..')
	assert goal_recipe_names().len == 5
	for recipe in goal_recipe_names() {
		assert os.is_file(os.join_path(repo_root, 'recipes', 'goals', '${recipe}.yaml'))
	}
}

fn test_goal_rejects_cycles_missing_acceptance_and_unauthorized_repo() {
	base := sample_goal()
	cyclic := GoalDocument{
		...base
		tasks: [
			GoalTask{ ...base.tasks[0], depends_on: ['two'] },
			base.tasks[1],
		]
	}
	assert goal_error(cyclic).contains('cycle')
	no_acceptance := GoalDocument{ ...base, acceptance_criteria: []GoalAcceptance{} }
	assert goal_error(no_acceptance).contains('acceptance')
	foreign := GoalDocument{
		...base
		tasks: [
			GoalTask{ ...base.tasks[0], repository: 'attacker/other' },
			base.tasks[1],
		]
	}
	assert goal_error(foreign).contains('unauthorized')
}

fn test_goal_rejects_unknown_recipe_and_receipt_mismatch() {
	base := sample_goal()
	unknown := GoalDocument{
		...base
		tasks: [
			GoalTask{ ...base.tasks[0], recipe: 'automerge' },
			base.tasks[1],
		]
	}
	assert goal_error(unknown).contains('unknown recipe')
	doc := sample_goal()
	bad_receipt := 'task_id: one\nattempt: 1\nrepository: other/repo\nbase_sha: 0123456789012345678901234567890123456789\ncandidate_sha: 0123456789012345678901234567890123456789\nmode: real\nenvironment: linux\nverifier_identity: independent\nverifier_version: v1\nresult: pass\ndigests:\n  - sha256:0123456789012345678901234567890123456789012345678901234567890123\n'
	assert receipt_error(bad_receipt, doc).contains('does not match'), receipt_error(bad_receipt, doc)
}

fn test_goal_receipt_distinguishes_fixture_from_real_execution() {
	doc := sample_goal()
	base := 'task_id: one\nattempt: 1\nrepository: ulises-jeremias/agent-toolkit\nbase_sha: 0123456789012345678901234567890123456789\ncandidate_sha: 0123456789012345678901234567890123456789\nmode: fixture\nenvironment: synthetic-24-worker-evaluation\nverifier_identity: fixture-validator\nverifier_version: v1\nresult: pass\ndigests:\n  - sha256:0123456789012345678901234567890123456789012345678901234567890123\n'
	validate_goal_receipt(base, doc) or { panic(err) }
	assert receipt_error(base.replace('mode: fixture', 'mode: simulated'), doc).contains('fixture, hermetic, or real')
	validate_goal_receipt(base.replace('mode: fixture', 'mode: real'), doc) or { panic(err) }
}

fn test_goal_rejects_noncanonical_scope_paths_and_accepts_repo_case_variants() {
	base := sample_goal()
	trailing_slash := GoalDocument{
		...base
		tasks: [
			GoalTask{ ...base.tasks[0], paths: ['docs/'] },
			base.tasks[1],
		]
	}
	assert goal_error(trailing_slash).contains('invalid repository path')
	whitespace_segment := GoalDocument{
		...base
		tasks: [
			GoalTask{ ...base.tasks[0], paths: ['modules/   /core'] },
			base.tasks[1],
		]
	}
	assert goal_error(whitespace_segment).contains('invalid repository path')
	case_variant := GoalDocument{
		...base
		tasks: [
			GoalTask{ ...base.tasks[0], repository: 'Ulises-Jeremias/Agent-Toolkit' },
			base.tasks[1],
		]
	}
	validate_goal(case_variant) or { panic(err) }
}

fn goal_error(doc GoalDocument) string {
	validate_goal(doc) or { return err.msg() }
	return ''
}

fn receipt_error(text string, doc GoalDocument) string {
	validate_goal_receipt(text, doc) or { return err.msg() }
	return ''
}
