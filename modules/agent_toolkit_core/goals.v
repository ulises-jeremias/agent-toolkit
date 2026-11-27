module agent_toolkit_core

import os
import yaml
import time
import x.json2

// Goals v1 and v2 are portable, offline planning documents. They describe
// requested work and effects; they do not start workers or perform effects.
pub struct GoalDocument {
pub:
	schema_version          int
	id                      string
	title                   string
	authorized_repositories []GoalRepository
	acceptance_criteria     []GoalAcceptance
	deadline                string
	budget                  GoalBudget
	delivery_mode           string
	policy_ceiling          []string @[omitempty]
	tasks                   []GoalTask
}

pub struct GoalRepository {
pub:
	owner string
	name  string
	path  string
}

pub struct GoalAcceptance {
pub:
	id           string
	description  string
	verification string
}

pub struct GoalBudget {
pub:
	max_attempts   int
	wall_seconds   int
	provider_turns int
}

pub struct GoalTask {
pub:
	id          string
	title       string
	repository  string
	base_sha    string
	paths       []string
	depends_on  []string
	recipe      string
	runner      string
	verifier    string
	permissions []string @[omitempty]
}

struct GoalReceipt {
pub:
	task_id           string
	attempt           int
	repository        string
	base_sha          string
	candidate_sha     string
	mode              string
	environment       string
	verifier_identity string
	verifier_version  string
	result            string
	digests           []string
}

const goal_recipes = ['research', 'bug', 'feature', 'migration', 'release']

// These are portable effect names, not runtime grants. Each executor must
// intersect a task's request with the Goal ceiling and its own enforced policy.
const goal_permission_effects = [
	'repository.read',
	'repository.write',
	'process.execute',
	'network.access',
	'git.commit',
	'git.push',
	'github.read',
	'github.issue.create',
	'github.issue.update',
	'github.pr.create',
	'github.pr.update',
	'github.comment.create',
	'github.label.set',
	'github.assign',
	'github.close',
	'github.merge',
	'release.publish',
]

pub fn goal_recipe_names() []string {
	return goal_recipes.clone()
}

pub fn goal_permission_effect_names() []string {
	return goal_permission_effects.clone()
}

pub fn load_goal(path string) !GoalDocument {
	if !os.is_file(path) || os.file_size(path) > 1024 * 1024 {
		return error('goal file missing or exceeds 1 MiB')
	}
	text := os.read_file(path) or { return error('cannot read goal file') }
	doc := yaml.decode[GoalDocument](text) or { return error('invalid goal YAML: ${err}') }
	validate_goal(doc)!
	return doc
}

pub fn validate_goal(doc GoalDocument) ! {
	if doc.schema_version !in [1, 2] {
		return error('schema_version must be 1 or 2')
	}
	if !goal_identifier_valid(doc.id) || !goal_title_valid(doc.title) {
		return error('goal id and title are required')
	}
	if doc.acceptance_criteria.len == 0 {
		return error('at least one acceptance criterion is required')
	}
	if doc.authorized_repositories.len == 0 {
		return error('at least one authorized repository is required')
	}
	if doc.tasks.len == 0 {
		return error('at least one task is required')
	}
	_ := time.parse_rfc3339(doc.deadline) or { return error('deadline must be RFC3339') }
	if doc.budget.max_attempts <= 0 || doc.budget.wall_seconds <= 0 || doc.budget.provider_turns <= 0 {
		return error('all budget limits must be positive')
	}
	if doc.delivery_mode !in ['report', 'draft'] {
		return error('unknown delivery_mode: ${doc.delivery_mode}')
	}
	validate_goal_permissions(doc)!
	mut repos := map[string]bool{}
	for repo in doc.authorized_repositories {
		key := '${repo.owner.to_lower()}/${repo.name.to_lower()}'
		if !goal_identifier_valid(repo.owner) || !goal_identifier_valid(repo.name) || repo.path.trim_space().len == 0 || repo.path.contains('\x00') {
			return error('repository owner, name, and path are required')
		}
		if repos[key] {
			return error('duplicate authorized repository: ${key}')
		}
		repos[key] = true
	}
	mut criteria := map[string]bool{}
	for c in doc.acceptance_criteria {
		if !goal_identifier_valid(c.id) || c.description.trim_space().len == 0 || c.verification.trim_space().len == 0 {
			return error('acceptance criteria require id, description, and verification')
		}
		if criteria[c.id] {
			return error('duplicate acceptance criterion: ${c.id}')
		}
		criteria[c.id] = true
	}
	mut ids := map[string]bool{}
	for task in doc.tasks {
		if !goal_identifier_valid(task.id) || !goal_title_valid(task.title) {
			return error('tasks require a valid id and title')
		}
		if ids[task.id] {
			return error('duplicate task id: ${task.id}')
		}
		ids[task.id] = true
		if !repos[task.repository.to_lower()] {
			return error('task ${task.id} uses unauthorized repository: ${task.repository}')
		}
		if !goal_sha_is_valid(task.base_sha) || task.paths.len == 0 || task.runner.trim_space().len == 0 || task.verifier.trim_space().len == 0 {
			return error('task ${task.id} requires base_sha, paths, runner, and verifier')
		}
		for path in task.paths {
			if path.trim_space().len == 0 || path.starts_with('/') || path.starts_with('\\') || path.contains('\\') || path.contains(':') || path.contains('\x00') {
				return error('task ${task.id} has invalid repository path: ${path}')
			}
			for segment in path.split('/') {
				if segment.trim_space().len == 0 || segment in ['.', '..'] || segment.to_lower() == '.git' {
					return error('task ${task.id} has invalid repository path: ${path}')
				}
			}
		}
		if task.recipe !in goal_recipes {
			return error('task ${task.id} uses unknown recipe: ${task.recipe}')
		}
	}
	for task in doc.tasks {
		mut seen_dependencies := map[string]bool{}
		for dep in task.depends_on {
			if !ids[dep] {
				return error('task ${task.id} depends on unknown task: ${dep}')
			}
			if seen_dependencies[dep] {
				return error('task ${task.id} repeats dependency: ${dep}')
			}
			seen_dependencies[dep] = true
		}
	}
	goal_plan(doc)!
}

fn validate_goal_permissions(doc GoalDocument) ! {
	if doc.schema_version == 1 {
		if doc.policy_ceiling.len > 0 || doc.tasks.any(it.permissions.len > 0) {
			return error('permission declarations require Goal schema_version 2')
		}
		return
	}
	validate_goal_permission_list(doc.policy_ceiling, 'policy_ceiling')!
	if 'repository.read' !in doc.policy_ceiling {
		return error('Goal v2 policy_ceiling must include repository.read')
	}
	for task in doc.tasks {
		validate_goal_permission_list(task.permissions, 'task ${task.id} permissions')!
		if 'repository.read' !in task.permissions {
			return error('Goal v2 task ${task.id} permissions must include repository.read')
		}
		for effect in task.permissions {
			if effect !in doc.policy_ceiling {
				return error('Goal task ${task.id} requests effect outside policy_ceiling: ${effect}')
			}
		}
	}
}

fn validate_goal_permission_list(effects []string, label string) ! {
	mut seen := map[string]bool{}
	for effect in effects {
		if effect !in goal_permission_effects {
			return error('${label} contains unknown effect: ${effect}')
		}
		if seen[effect] {
			return error('${label} repeats effect: ${effect}')
		}
		seen[effect] = true
	}
}

// goal_manifest_json returns the full canonical Goal JSON object used for
// Veasel admission. It validates first and preserves repository/task paths.
pub fn goal_manifest_json(doc GoalDocument) !string {
	validate_goal(doc)!
	return json2.encode(doc, escape_unicode: true)
}

// goal_plan returns a deterministic topological ordering and rejects cycles.
pub fn goal_plan(doc GoalDocument) ![]string {
	mut done := map[string]bool{}
	mut order := []string{}
	for order.len < doc.tasks.len {
		mut progressed := false
		for task in doc.tasks {
			if done[task.id] {
				continue
			}
			mut ready := true
			for dep in task.depends_on {
				if !done[dep] {
					ready = false
					break
				}
			}
			if ready {
				done[task.id] = true
				order << task.id
				progressed = true
			}
		}
		if !progressed {
			return error('task dependency cycle detected')
		}
	}
	return order
}

pub fn validate_goal_receipt(text string, doc GoalDocument) ! {
	r := yaml.decode[GoalReceipt](text) or { return error('invalid receipt YAML') }
	mut found := false
	for t in doc.tasks {
		if t.id == r.task_id && t.repository == r.repository && t.base_sha == r.base_sha {
			found = true
		}
	}
	if !found {
		return error('receipt task, repository, or base SHA does not match goal')
	}
	if r.attempt < 1 || !goal_sha_is_valid(r.candidate_sha) || !goal_sha_is_valid(r.base_sha) || r.verifier_identity.trim_space().len == 0 || r.verifier_version.trim_space().len == 0 || r.environment.trim_space().len == 0 || r.digests.len == 0 {
		return error('receipt is missing attempt, candidate SHA, verifier identity/version, environment, or evidence digests')
	}
	if r.mode !in ['fixture', 'hermetic', 'real'] {
		return error('receipt mode must be fixture, hermetic, or real')
	}
	if r.result !in ['pass', 'fail', 'inconclusive'] {
		return error('receipt result must be pass, fail, or inconclusive')
	}
	for digest in r.digests {
		if !digest.starts_with('sha256:') || digest.len != 71 {
			return error('receipt evidence digests must use sha256:<64 lowercase hex>')
		}
		for ch in digest[7..] {
			if (ch < `0` || ch > `9`) && (ch < `a` || ch > `f`) {
				return error('receipt evidence digest is not lowercase SHA-256 hex')
			}
		}
	}
}

fn goal_sha_is_valid(value string) bool {
	if value.len !in [40, 64] {
		return false
	}
	for ch in value {
		if (ch < `0` || ch > `9`) && (ch < `a` || ch > `f`) {
			return false
		}
	}
	return true
}

fn goal_identifier_valid(value string) bool {
	if value.len == 0 || value.len > 100 || value in ['.', '..'] {
		return false
	}
	for ch in value {
		if !((ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || (ch >= `0` && ch <= `9`) || ch in [
			`_`,
			`-`,
			`.`,
		]) {
			return false
		}
	}
	return true
}

fn goal_title_valid(value string) bool {
	if value.len == 0 || value.len > 200 {
		return false
	}
	for ch in value {
		if ch < 32 || ch == 127 {
			return false
		}
	}
	return true
}
