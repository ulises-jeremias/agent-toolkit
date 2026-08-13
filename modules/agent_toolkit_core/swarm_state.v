module agent_toolkit_core

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
