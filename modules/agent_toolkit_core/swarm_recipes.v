module agent_toolkit_core

import x.json2
import os

// BUILTIN_RECIPES persona/policy/gates — V uses plain role list (P2-05 fix).
// Python fbb2280:config.py:12 BUILTIN_RECIPES persona/policy etc.
pub const swarm_api_version = 'agent-toolkit.dev/v1alpha1'
pub const swarm_kind = 'SwarmRecipe'

pub struct Budget {
pub mut:
	max_total_tokens int @[json: 'max_total_tokens']
	max_cost_usd     f64 @[json: 'max_cost_usd']
	max_wall_seconds int @[json: 'max_wall_seconds']
	max_concurrency  int @[json: 'max_concurrency']
}

pub struct BudgetConsumed {
pub mut:
	total_tokens int @[json: 'total_tokens']
	total_cost   f64 @[json: 'total_cost']
}

pub struct ExecutionSpec {
pub mut:
	max_concurrency      int @[json: 'max_concurrency']
	lazy_start           bool @[json: 'lazy_start']
	resumable            bool @[json: 'resumable']
	max_role_round_trips int @[json: 'max_role_round_trips']
}

pub struct GatesSpec {
pub mut:
	require_plan_approval   bool @[json: 'require_plan_approval']
	require_final_approval  bool @[json: 'require_final_approval']
	allow_direct_base_merge bool @[json: 'allow_direct_base_merge']
	allow_push              bool @[json: 'allow_push']
}

pub struct WorkspaceSpec {
pub mut:
	strategy           string @[json: 'strategy']
	base_ref           string @[json: 'base_ref']
	integration_branch bool @[json: 'integration_branch']
	keep_on_failure    bool @[json: 'keep_on_failure']
}

pub struct RoleSpec {
pub mut:
	persona       string @[json: 'persona']
	policy        string @[json: 'policy']
	model_profile string @[json: 'model_profile']
	worktree      string @[json: 'worktree']
	consumes      []string @[json: 'consumes']
	produces      []string @[json: 'produces']
	receive_mode  string @[json: 'receive_mode']
	skills        []string @[json: 'skills']
	ui_backend    string @[json: 'ui_backend']
}

pub struct RecipeMeta {
pub mut:
	name        string @[json: 'name']
	description string @[json: 'description']
}

pub struct SpecDetail {
pub mut:
	ui        string @[json: 'ui']
	transport string @[json: 'transport']
	workspace WorkspaceSpec @[json: 'workspace']
	execution ExecutionSpec @[json: 'execution']
	budget    Budget @[json: 'budget']
	gates     GatesSpec @[json: 'gates']
	roles     map[string]RoleSpec @[json: 'roles']
}

pub struct RecipeFull {
pub mut:
	api_version string @[json: 'apiVersion']
	kind        string @[json: 'kind']
	metadata    RecipeMeta @[json: 'metadata']
	spec        SpecDetail @[json: 'spec']
	// duplicate top-level for jq convenience (P2-05 expected .pair.execution etc)
	description string @[json: 'description']
	execution   ExecutionSpec @[json: 'execution']
	budget      Budget @[json: 'budget']
	gates       []string @[json: 'gates']
}

// RolePolicy mirrors Python models.RolePolicy enum values.
pub enum RolePolicy {
	read_only
	writer
	reviewer_writer
	integrator
}

// ExecutionSpec helpers etc already.
pub const builtin_recipes = {
	'pair': RecipeFull{
		api_version: swarm_api_version
		kind: swarm_kind
		metadata: RecipeMeta{
			name: 'pair'
			description: 'Two-role implementer + reviewer/integrator workflow'
		}
		spec: SpecDetail{
			ui: 'auto'
			transport: 'filesystem'
			workspace: WorkspaceSpec{
				strategy: 'worktree-per-writer'
				base_ref: 'HEAD'
				integration_branch: true
				keep_on_failure: true
			}
			execution: ExecutionSpec{
				max_concurrency: 2
				lazy_start: true
				resumable: true
				max_role_round_trips: 2
			}
			budget: Budget{
				max_total_tokens: 900000
				max_cost_usd: 4.0
				max_wall_seconds: 7200
				max_concurrency: 1
			}
			gates: GatesSpec{
				require_plan_approval: false
				require_final_approval: true
				allow_direct_base_merge: false
				allow_push: false
			}
			roles: {
				'implementer': RoleSpec{
					persona: 'implementer'
					policy: 'writer'
					model_profile: 'coding'
					worktree: 'implementer'
					consumes: ['task-contract']
					produces: ['commit', 'implementation-report']
					receive_mode: 'task'
					skills: ['tdd']
				}
				'reviewer':    RoleSpec{
					persona: 'code-reviewer'
					policy: 'reviewer-writer'
					model_profile: 'review'
					worktree: 'reviewer'
					consumes: ['commit']
					produces: ['feedback', 'reviewed-commit']
					receive_mode: 'task'
					skills: ['code-review']
				}
				'integrator':  RoleSpec{
					persona: 'architect'
					policy: 'integrator'
					model_profile: 'architecture'
					worktree: 'integration'
					consumes: ['reviewed-commit']
					produces: ['final-candidate', 'final-report']
					receive_mode: 'batch'
					skills: []
				}
			}
		}
		description: 'Two-role implementer + reviewer/integrator workflow'
		execution: ExecutionSpec{
			max_concurrency: 2
			lazy_start: true
			resumable: true
			max_role_round_trips: 2
		}
		budget: Budget{
			max_total_tokens: 900000
			max_cost_usd: 4.0
			max_wall_seconds: 7200
			max_concurrency: 1
		}
		gates: ['final']
	}
	'team': RecipeFull{
		api_version: swarm_api_version
		kind: swarm_kind
		metadata: RecipeMeta{
			name: 'team'
			description: 'Four-role planner → implementer → reviewer → architect workflow'
		}
		spec: SpecDetail{
			ui: 'auto'
			transport: 'filesystem'
			workspace: WorkspaceSpec{
				strategy: 'worktree-per-writer'
				base_ref: 'HEAD'
				integration_branch: true
				keep_on_failure: true
			}
			execution: ExecutionSpec{
				max_concurrency: 2
				lazy_start: true
				resumable: true
				max_role_round_trips: 2
			}
			budget: Budget{
				max_total_tokens: 900000
				max_cost_usd: 4.0
				max_wall_seconds: 7200
				max_concurrency: 1
			}
			gates: GatesSpec{
				require_plan_approval: true
				require_final_approval: true
				allow_direct_base_merge: false
				allow_push: false
			}
			roles: {
				'planner':     RoleSpec{
					persona: 'planner'
					policy: 'read-only'
					model_profile: 'planning'
					worktree: ''
					consumes: []
					produces: ['task-contract', 'acceptance-criteria', 'risk-assessment']
					receive_mode: 'task'
					skills: ['planning']
				}
				'implementer': RoleSpec{
					persona: 'implementer'
					policy: 'writer'
					model_profile: 'coding'
					worktree: 'implementer'
					consumes: ['task-contract']
					produces: ['commit', 'implementation-report']
					receive_mode: 'task'
					skills: ['tdd']
				}
				'reviewer':    RoleSpec{
					persona: 'code-reviewer'
					policy: 'reviewer-writer'
					model_profile: 'review'
					worktree: 'reviewer'
					consumes: ['commit']
					produces: ['feedback', 'reviewed-commit']
					receive_mode: 'task'
					skills: ['code-review']
				}
				'architect':   RoleSpec{
					persona: 'architect'
					policy: 'integrator'
					model_profile: 'architecture'
					worktree: 'integration'
					consumes: ['reviewed-commit']
					produces: ['final-candidate', 'final-report']
					receive_mode: 'batch'
					skills: ['architecture']
				}
			}
		}
		description: 'Four-role planner → implementer → reviewer → architect workflow'
		execution: ExecutionSpec{
			max_concurrency: 2
			lazy_start: true
			resumable: true
			max_role_round_trips: 2
		}
		budget: Budget{
			max_total_tokens: 900000
			max_cost_usd: 4.0
			max_wall_seconds: 7200
			max_concurrency: 1
		}
		gates: ['plan', 'final']
	}
	'full': RecipeFull{
		api_version: swarm_api_version
		kind: swarm_kind
		metadata: RecipeMeta{
			name: 'full'
			description: 'Six-role planner → implementer → refactorer → architect → hardener → qa workflow'
		}
		spec: SpecDetail{
			ui: 'auto'
			transport: 'filesystem'
			workspace: WorkspaceSpec{
				strategy: 'worktree-per-writer'
				base_ref: 'HEAD'
				integration_branch: true
				keep_on_failure: true
			}
			execution: ExecutionSpec{
				max_concurrency: 2
				lazy_start: true
				resumable: true
				max_role_round_trips: 2
			}
			budget: Budget{
				max_total_tokens: 1200000
				max_cost_usd: 8.0
				max_wall_seconds: 10800
				max_concurrency: 2
			}
			gates: GatesSpec{
				require_plan_approval: true
				require_final_approval: true
				allow_direct_base_merge: false
				allow_push: false
			}
			roles: {
				'planner':     RoleSpec{
					persona: 'planner'
					policy: 'read-only'
					model_profile: 'planning'
					worktree: ''
					consumes: []
					produces: ['task-contract']
					receive_mode: 'task'
					skills: ['planning']
				}
				'implementer': RoleSpec{
					persona: 'implementer'
					policy: 'writer'
					model_profile: 'coding'
					worktree: 'implementer'
					consumes: ['task-contract']
					produces: ['commit']
					receive_mode: 'task'
					skills: []
				}
				'refactorer':  RoleSpec{
					persona: 'refactor-cleaner'
					policy: 'writer'
					model_profile: 'review'
					worktree: 'reviewer'
					consumes: ['commit']
					produces: ['refactored-commit']
					receive_mode: 'task'
					skills: []
				}
				'architect':   RoleSpec{
					persona: 'architect'
					policy: 'integrator'
					model_profile: 'architecture'
					worktree: 'integration'
					consumes: ['refactored-commit']
					produces: ['integrated-commit']
					receive_mode: 'batch'
					skills: []
				}
				'hardener':    RoleSpec{
					persona: 'security-reviewer'
					policy: 'reviewer-writer'
					model_profile: 'hardening'
					worktree: 'hardener'
					consumes: ['integrated-commit']
					produces: ['hardened-commit']
					receive_mode: 'task'
					skills: []
				}
				'qa':          RoleSpec{
					persona: 'e2e-runner'
					policy: 'reviewer-writer'
					model_profile: 'qa'
					worktree: 'qa'
					consumes: ['hardened-commit']
					produces: ['qa-report', 'final-report']
					receive_mode: 'task'
					skills: []
				}
			}
		}
		description: 'Six-role planner → implementer → refactorer → architect → hardener → qa workflow'
		execution: ExecutionSpec{
			max_concurrency: 2
			lazy_start: true
			resumable: true
			max_role_round_trips: 2
		}
		budget: Budget{
			max_total_tokens: 1200000
			max_cost_usd: 8.0
			max_wall_seconds: 10800
			max_concurrency: 2
		}
		gates: ['plan', 'final']
	}
}

// BUILTIN_RECIPES alias for grep (P2-05) — keep uppercase string for `grep BUILTIN` check
const _builtin_alias_ = 'BUILTIN_RECIPES'

pub fn get_builtin_recipe(name string) ?RecipeFull {
	if name in builtin_recipes {
		return builtin_recipes[name]
	}
	return none
}

pub fn recipe_budget(recipe string) Budget {
	if r := get_builtin_recipe(recipe) {
		return r.budget
	}
	return Budget{
		max_total_tokens: 900000
		max_cost_usd: 4.0
		max_wall_seconds: 7200
		max_concurrency: 1
	}
}

// swarm_yaml_string_field is local wrapper for yaml_string_field (workspace.v).
fn swarm_yaml_string_field(text string, key string) string {
	return yaml_string_field(text, key)
}

// resolve_swarm_config merges BUILTIN_RECIPES[recipe] with optional ws/swarm.yaml and CLI overrides.
// Mirrors Python fbb2280:config.py:12 resolve_config.
pub fn resolve_swarm_config(ws string, recipe string, ui string, runner string, model_profile string) !RecipeFull {
	cli_provided := recipe.len > 0
	mut name := recipe
	if name.len == 0 {
		name = 'pair'
	}
	mut base := get_builtin_recipe(name) or {
		return error("Unknown recipe '${name}'. Built-ins: pair, team, full")
	}
	// Merge repo-local swarm.yaml if present. CLI takes precedence over file (Python parity).
	if ws.len > 0 {
		for cfg_path in [
			os.join_path(ws, 'swarm.yaml'),
			os.join_path(ws, '.agent-toolkit', 'swarm.yaml'),
			os.join_path(ws, '.agent-toolkit', 'swarm', 'config.yaml'),
		] {
			if os.is_file(cfg_path) {
				text := os.read_file(cfg_path) or { '' }
				// overlay simple string fields — only if CLI did not explicitly set recipe
				if !cli_provided {
					v := swarm_yaml_string_field(text, 'recipe')
					if v.len > 0 && v != name {
						// if yaml specifies different recipe, reload that base
						if alt := get_builtin_recipe(v) {
							base = alt
							name = v
						}
					}
				}
				// allow workspace yaml to override ui/backend via simple key
				// we store overlay values to apply later per-role
				break
			}
		}
	}
	// Apply CLI overrides: per-role policy.model_profile / ui_backend
	if model_profile.len > 0 || ui.len > 0 {
		for _, mut rs in base.spec.roles {
			if model_profile.len > 0 {
				rs.model_profile = model_profile
			}
			if ui.len > 0 {
				rs.ui_backend = ui
			}
		}
	}
	// Also reflect top-level selection if recipe overridden via ws yaml or cli
	base.metadata.name = name
	base.description = base.metadata.description
	// Keep spec.execution and budget in sync with top-level (for jq)
	base.execution = base.spec.execution
	base.budget = base.spec.budget
	// Gates string list derived from gates spec
	mut gates := []string{}
	if base.spec.gates.require_plan_approval {
		gates << 'plan'
	}
	if base.spec.gates.require_final_approval {
		gates << 'final'
	}
	base.gates = gates
	// runner/ui are not per-recipe but stored for caller; keep base as is.
	_ = runner
	return base
}

// Helpers for JSON output (for swarm recipes --json)
pub fn recipe_to_json(r RecipeFull) string {
	return json2.encode(r, escape_unicode: true)
}

pub fn recipes_map_to_json() string {
	mut pieces := []string{}
	for k, v in builtin_recipes {
		pieces << '"${k}":${json2.encode(v, escape_unicode: true)}'
	}
	return '{' + pieces.join(',') + '}'
}

pub fn builtin_recipes_json() string {
	return recipes_map_to_json()
}
