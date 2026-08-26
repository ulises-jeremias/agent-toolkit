module agent_toolkit_core

import os

// Swarm run/role state machine + approval gates (#524 REDESIGN / ADR-008).

pub struct SwarmGate {
pub mut:
	id          string
	description string
	required    bool
	approved    bool
	rejected    bool
	reason      string
}

pub fn swarm_can_transition(from_state string, to_state string) bool {
	allowed := swarm_run_transitions(from_state)
	return to_state in allowed
}

pub fn swarm_run_transitions(from_state string) []string {
	return match from_state {
		'planning' {
			['awaiting_plan_approval', 'running', 'failed', 'cancelled']
		}
		'awaiting_plan_approval' {
			['running', 'cancelled', 'failed']
		}
		'running' {
			['awaiting_human', 'paused', 'completed', 'failed', 'cancelled', 'budget_exhausted']
		}
		'awaiting_human' {
			['running', 'paused', 'completed', 'failed', 'cancelled']
		}
		'paused' {
			['running', 'cancelled', 'failed']
		}
		'completed' {
			['cleanup_pending']
		}
		'failed' {
			['cleanup_pending', 'running']
		}
		'cancelled' {
			['cleanup_pending']
		}
		'budget_exhausted' {
			['running', 'cancelled', 'cleanup_pending']
		}
		else {
			[]string{}
		}
	}
}

pub fn swarm_recipe_roles(recipe string) []string {
	return match recipe {
		'pair' {
			['implementer', 'reviewer', 'integrator']
		}
		'team' {
			['planner', 'implementer', 'reviewer', 'architect']
		}
		'full' {
			['planner', 'implementer', 'refactorer', 'architect', 'hardener', 'qa']
		}
		else {
			[]string{}
		}
	}
}

pub fn swarm_recipe_description(recipe string) string {
	return match recipe {
		'pair' {
			'Two-role implementer + reviewer/integrator workflow'
		}
		'team' {
			'Four-role planner → implementer → reviewer → architect workflow'
		}
		'full' {
			'Six-role planner → implementer → refactorer → architect → hardener → qa workflow'
		}
		else {
			''
		}
	}
}

pub fn swarm_require_plan_approval(recipe string) bool {
	return recipe in ['team', 'full']
}

pub fn swarm_role_predecessor(recipe string, role string) string {
	return match recipe {
		'pair' {
			match role {
				'reviewer' { 'implementer' }
				'integrator' { 'reviewer' }
				else { '' }
			}
		}
		'team' {
			match role {
				'implementer' { 'planner' }
				'reviewer' { 'implementer' }
				'architect' { 'reviewer' }
				else { '' }
			}
		}
		'full' {
			match role {
				'implementer' { 'planner' }
				'refactorer' { 'implementer' }
				'architect' { 'refactorer' }
				'hardener' { 'architect' }
				'qa' { 'hardener' }
				else { '' }
			}
		}
		else { '' }
	}
}

pub fn shell_quote(s string) string {
	if s.len == 0 {
		return "''"
	}
	return "'" + s.replace("'", "'\\''") + "'"
}

pub fn shell_base() string {
	sh := user_shell_fallback()
	idx := sh.last_index('/') or { return sh }
	if idx + 1 >= sh.len {
		return sh
	}
	return sh[idx + 1..]
}

fn user_shell_fallback() string {
	env := os.getenv('SHELL')
	if env.len > 0 && os.is_file(env) {
		return env
	}
	return '/usr/bin/zsh'
}

pub fn swarm_default_gates(recipe string) []SwarmGate {
	mut gates := []SwarmGate{}
	if swarm_require_plan_approval(recipe) {
		gates << SwarmGate{
			id:          'plan'
			description: 'Plan approval: review task contract before implementation.'
			required:    true
		}
	}
	gates << SwarmGate{
		id:          'final'
		description: 'Final integration approval: required before base-branch merge.'
		required:    true
	}
	return gates
}

pub fn swarm_valid_run_id(id string) bool {
	if id.len < 3 || id.len > 65 {
		return false
	}
	c0 := id[0]
	if !((c0 >= `a` && c0 <= `z`) || (c0 >= `A` && c0 <= `Z`) || (c0 >= `0` && c0 <= `9`)) {
		return false
	}
	for c in id {
		ok := (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
			|| (c >= `0` && c <= `9`) || c == `.` || c == `_` || c == `-`
		if !ok {
			return false
		}
	}
	return true
}

// Swarm recipe detail parity — mirrors Python fbb2280 recipes.py BUILTIN_RECIPES.

pub struct SwarmRoleSpec {
pub:
	persona       string
	policy        string
	worktree      string
	consumes      []string
	produces      []string
	model_profile string
}

pub struct SwarmExecutionSpec {
pub:
	max_concurrency int
	lazy_start      bool
}

pub struct SwarmBudgetSpec {
pub:
	max_total_tokens int
	max_cost_usd     f64
	max_wall_seconds int
}

pub struct SwarmSpecDetail {
pub:
	roles map[string]SwarmRoleSpec
}

pub struct SwarmRecipeSpec {
pub:
	description string
	spec        SwarmSpecDetail
	execution   SwarmExecutionSpec
	gates       []string
	budget      SwarmBudgetSpec
	ui_backend  string
}

pub const builtin_recipes = {
	'pair': SwarmRecipeSpec{
		description: 'Two-role implementer + reviewer/integrator workflow'
		spec: SwarmSpecDetail{
			roles: {
				'implementer': SwarmRoleSpec{
					persona: 'tdd-guide'
					policy: 'writer'
					worktree: 'implementer'
					consumes: ['task-contract']
					produces: ['commit', 'implementation-report']
					model_profile: 'coding'
				}
				'reviewer':    SwarmRoleSpec{
					persona: 'code-reviewer'
					policy: 'reviewer-writer'
					worktree: 'reviewer'
					consumes: ['commit']
					produces: ['feedback', 'reviewed-commit']
					model_profile: 'review'
				}
				'integrator':  SwarmRoleSpec{
					persona: 'architect'
					policy: 'integrator'
					worktree: 'integration'
					consumes: ['reviewed-commit']
					produces: ['final-candidate', 'final-report']
					model_profile: 'architecture'
				}
			}
		}
		execution: SwarmExecutionSpec{
			max_concurrency: 1
			lazy_start: true
		}
		gates: ['final']
		budget: SwarmBudgetSpec{
			max_total_tokens: 900000
			max_cost_usd: 4.0
			max_wall_seconds: 7200
		}
		ui_backend: 'herdr'
	}
	'team': SwarmRecipeSpec{
		description: 'Four-role planner → implementer → reviewer → architect workflow'
		spec: SwarmSpecDetail{
			roles: {
				'planner':     SwarmRoleSpec{
					persona: 'planner'
					policy: 'read-only'
					worktree: ''
					consumes: []
					produces: ['task-contract', 'acceptance-criteria', 'risk-assessment']
					model_profile: 'planning'
				}
				'implementer': SwarmRoleSpec{
					persona: 'tdd-guide'
					policy: 'writer'
					worktree: 'implementer'
					consumes: ['task-contract']
					produces: ['commit', 'implementation-report']
					model_profile: 'coding'
				}
				'reviewer':    SwarmRoleSpec{
					persona: 'code-reviewer'
					policy: 'reviewer-writer'
					worktree: 'reviewer'
					consumes: ['commit']
					produces: ['feedback', 'reviewed-commit']
					model_profile: 'review'
				}
				'architect':   SwarmRoleSpec{
					persona: 'architect'
					policy: 'integrator'
					worktree: 'integration'
					consumes: ['reviewed-commit']
					produces: ['final-candidate', 'final-report']
					model_profile: 'architecture'
				}
			}
		}
		execution: SwarmExecutionSpec{
			max_concurrency: 2
			lazy_start: true
		}
		gates: ['plan', 'final']
		budget: SwarmBudgetSpec{
			max_total_tokens: 900000
			max_cost_usd: 4.0
			max_wall_seconds: 7200
		}
		ui_backend: 'herdr'
	}
	'full': SwarmRecipeSpec{
		description: 'Six-role planner → implementer → refactorer → architect → hardener → qa workflow'
		spec: SwarmSpecDetail{
			roles: {
				'planner':     SwarmRoleSpec{
					persona: 'planner'
					policy: 'read-only'
					worktree: ''
					consumes: []
					produces: ['task-contract']
					model_profile: 'planning'
				}
				'implementer': SwarmRoleSpec{
					persona: 'tdd-guide'
					policy: 'writer'
					worktree: 'implementer'
					consumes: ['task-contract']
					produces: ['commit']
					model_profile: 'coding'
				}
				'refactorer':  SwarmRoleSpec{
					persona: 'refactor-cleaner'
					policy: 'writer'
					worktree: 'reviewer'
					consumes: ['commit']
					produces: ['refactored-commit']
					model_profile: 'review'
				}
				'architect':   SwarmRoleSpec{
					persona: 'architect'
					policy: 'integrator'
					worktree: 'integration'
					consumes: ['refactored-commit']
					produces: ['integrated-commit']
					model_profile: 'architecture'
				}
				'hardener':    SwarmRoleSpec{
					persona: 'security-reviewer'
					policy: 'reviewer-writer'
					worktree: 'hardener'
					consumes: ['integrated-commit']
					produces: ['hardened-commit']
					model_profile: 'hardening'
				}
				'qa':          SwarmRoleSpec{
					persona: 'e2e-runner'
					policy: 'reviewer-writer'
					worktree: 'qa'
					consumes: ['hardened-commit']
					produces: ['qa-report', 'final-report']
					model_profile: 'qa'
				}
			}
		}
		execution: SwarmExecutionSpec{
			max_concurrency: 2
			lazy_start: true
		}
		gates: ['plan', 'final']
		budget: SwarmBudgetSpec{
			max_total_tokens: 1200000
			max_cost_usd: 8.0
			max_wall_seconds: 10800
		}
		ui_backend: 'herdr'
	}
}
