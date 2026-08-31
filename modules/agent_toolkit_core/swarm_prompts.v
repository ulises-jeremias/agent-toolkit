module agent_toolkit_core

import os

const swarm_global_protocol = '# Agent Toolkit Swarm — Global Protocol\n- You are a role in a multi-agent swarm. Work only on your assigned task.\n- Do not push, do not merge to base branch, do not publish releases.\n- Transfer code only via validated Git commits on your Toolkit-owned branch.\n- The swarm is a directed graph of roles: hand work forward to successors, and send feedback/re-work back to your predecessor — roles are started and woken automatically when a handoff reaches them.\n- Use durable handoffs via `agent-toolkit swarm handoff create` and `agent-toolkit swarm task next/complete`.\n- Inside a swarm run, the ONLY way to delegate to another swarm role is `agent-toolkit swarm handoff create`. NEVER use your internal Task/subagent tools to spawn a reviewer/qa/architect — those swarm roles run in isolated worktrees and are reached ONLY via handoffs. Self-review is forbidden.\n- Stay inside your worktree when you have one. Do not write outside `.agent-toolkit/swarm/runs/<run-id>/` except your worktree.\n- Keep artifacts under 1MB, no secrets, no full transcript forwarding.\n- Record decisions in artifacts and trace events.\n'

const swarm_interactive_bootstrap = '# Interactive mode — No initial task\n> This swarm was started **without an initial prompt/task**. The user will provide the first request next in this same Herdr/Tmux session.\n\n**Instructions for the first agent (planner/implementer):**\n- **Do NOT invent work** or start tasks on your own. Do not create a plan or code yet.\n- Do only a **very brief** context analysis (max 3-4 sentences / 30 seconds):\n  - If you detect a **workspace** (exists `AGENTS.md` and/or `knowledge/` or `find_workspace_root()` is not None, e.g. `~/.ai-workspace`):\n    Run `agent-toolkit workspace context` and briefly review `AGENTS.md` + `knowledge/todos/pending.md`.\n    Also check `projects/` and `loops/` if present. Summarize in 2-3 lines what workspace it is.\n  - If no workspace, briefly review the current repo (`git status`, `cat README.md` / `pyproject.toml`).\n- Then **stay on standby** and confirm with a short message:\n  "Brief analysis done — awaiting your first request. When you provide the task, I will apply `assistant` (discovery) + `workflow-generic-project` (plan -> approval -> implement -> review -> draft PR)."\n- When the user sends the request (via chat or `agent-toolkit swarm handoff create --type artifact --from planner --to implementer --artifact artifacts/task-contract.md --run-id <run-id>`), apply the full flow: discovery per `assistant` (order README -> docs/ -> AGENTS.md -> CONTRIBUTING -> PR templates -> Makefile/package.json -> devcontainer/CI), then `workflow-generic-project` with plan approval gate before implementing, and `github-cli-workflow` for draft PR.\n'

pub struct SwarmPromptManifest {
pub:
	role               string
	persona            string
	policy             string
	recipe             string
	includes           []string
	size_chars         int
	model_profile_task string
	is_interactive     bool
}

struct SwarmRoleDef {
pub:
	persona       string
	policy        string
	model_profile string
	consumes      []string
	produces      []string
	skills        []string
	worktree      string
}

fn swarm_load_persona_text(persona string) string {
	path := 'agents/${persona}/AGENT.md'
	if embedded_is_file(path) {
		txt := embedded_read_file(path) or { '' }
		if txt.len > 0 {
			if txt.runes().len > 2000 {
				return txt.runes()[..2000].string()
			}
			return txt
		}
	}
	if tr := find_toolkit_root() {
		if tr.path != 'embedded' {
			p1 := os.join_path(tr.path, 'agents', persona, 'AGENT.md')
			if os.is_file(p1) {
				txt := os.read_file(p1) or { '' }
				if txt.len > 0 {
					if txt.runes().len > 2000 {
						return txt.runes()[..2000].string()
					}
					return txt
				}
			}
		}
	} else {
		// no root, ignore
	}
	p2 := os.join_path(os.getwd(), 'agents', persona, 'AGENT.md')
	if os.is_file(p2) {
		txt := os.read_file(p2) or { '' }
		if txt.len > 0 {
			if txt.runes().len > 2000 {
				return txt.runes()[..2000].string()
			}
			return txt
		}
	}
	return '# Persona: ${persona}\nAct as ${persona} per Toolkit guidance.'
}

fn swarm_role_def(recipe string, role string) ?SwarmRoleDef {
	// Built-in recipes mirrored from fbb2280 recipes.py BUILTIN_RECIPES
	match recipe {
		'pair' {
			match role {
				'implementer' {
					return SwarmRoleDef{
						persona:       'implementer'
						policy:        'writer'
						model_profile: 'coding'
						consumes:      ['task-contract']
						produces:      ['commit', 'implementation-report']
						skills:        ['tdd']
						worktree:      'implementer'
					}
				}
				'reviewer' {
					return SwarmRoleDef{
						persona:       'code-reviewer'
						policy:        'reviewer-writer'
						model_profile: 'review'
						consumes:      ['commit']
						produces:      ['feedback', 'reviewed-commit']
						skills:        ['code-review']
						worktree:      'reviewer'
					}
				}
				'integrator' {
					return SwarmRoleDef{
						persona:       'architect'
						policy:        'integrator'
						model_profile: 'architecture'
						consumes:      ['reviewed-commit']
						produces:      ['final-candidate', 'final-report']
						skills:        []
						worktree:      'integration'
					}
				}
				else {
					return none
				}
			}
		}
		'team' {
			match role {
				'planner' {
					return SwarmRoleDef{
						persona:       'planner'
						policy:        'read-only'
						model_profile: 'planning'
						consumes:      []
						produces:      ['task-contract', 'acceptance-criteria', 'risk-assessment']
						skills:        ['planning']
						worktree:      ''
					}
				}
				'implementer' {
					return SwarmRoleDef{
						persona:       'implementer'
						policy:        'writer'
						model_profile: 'coding'
						consumes:      ['task-contract']
						produces:      ['commit', 'implementation-report']
						skills:        ['tdd']
						worktree:      'implementer'
					}
				}
				'reviewer' {
					return SwarmRoleDef{
						persona:       'code-reviewer'
						policy:        'reviewer-writer'
						model_profile: 'review'
						consumes:      ['commit']
						produces:      ['feedback', 'reviewed-commit']
						skills:        ['code-review']
						worktree:      'reviewer'
					}
				}
				'architect' {
					return SwarmRoleDef{
						persona:       'architect'
						policy:        'integrator'
						model_profile: 'architecture'
						consumes:      ['reviewed-commit']
						produces:      ['final-candidate', 'final-report']
						skills:        ['architecture']
						worktree:      'integration'
					}
				}
				else {
					return none
				}
			}
		}
		'full' {
			match role {
				'planner' {
					return SwarmRoleDef{
						persona:       'planner'
						policy:        'read-only'
						model_profile: 'planning'
						consumes:      []
						produces:      ['task-contract']
						skills:        ['planning']
						worktree:      ''
					}
				}
				'implementer' {
					return SwarmRoleDef{
						persona:       'implementer'
						policy:        'writer'
						model_profile: 'coding'
						consumes:      ['task-contract']
						produces:      ['commit']
						skills:        []
						worktree:      'implementer'
					}
				}
				'refactorer' {
					return SwarmRoleDef{
						persona:       'refactor-cleaner'
						policy:        'writer'
						model_profile: 'review'
						consumes:      ['commit']
						produces:      ['refactored-commit']
						skills:        []
						worktree:      'reviewer'
					}
				}
				'architect' {
					return SwarmRoleDef{
						persona:       'architect'
						policy:        'integrator'
						model_profile: 'architecture'
						consumes:      ['refactored-commit']
						produces:      ['integrated-commit']
						skills:        []
						worktree:      'integration'
					}
				}
				'hardener' {
					return SwarmRoleDef{
						persona:       'security-reviewer'
						policy:        'reviewer-writer'
						model_profile: 'hardening'
						consumes:      ['integrated-commit']
						produces:      ['hardened-commit']
						skills:        []
						worktree:      'hardener'
					}
				}
				'qa' {
					return SwarmRoleDef{
						persona:       'e2e-runner'
						policy:        'reviewer-writer'
						model_profile: 'qa'
						consumes:      ['hardened-commit']
						produces:      ['qa-report', 'final-report']
						skills:        []
						worktree:      'qa'
					}
				}
				else {
					return none
				}
			}
		}
		else {
			return none
		}
	}
}

fn swarm_role_skills(recipe string, role string) []string {
	if d := swarm_role_def(recipe, role) {
		return d.skills
	}
	return []
}

fn swarm_recipe_execution_text(recipe string) string {
	return match recipe {
		'pair', 'team', 'full' { "{'max_concurrency': 2, 'lazy_start': True, 'resumable': True, 'max_role_round_trips': 2}" }
		else { '{}' }
	}
}

fn swarm_recipe_workspace_text(recipe string) string {
	return match recipe {
		'pair', 'team', 'full' { "{'strategy': 'worktree-per-writer', 'base_ref': 'HEAD', 'integration_branch': True, 'keep_on_failure': True}" }
		else { '{}' }
	}
}

fn swarm_next_roles(recipe string, role string) []string {
	// First try produces/consumes graph
	mut next := []string{}
	if cur := swarm_role_def(recipe, role) {
		for other in swarm_recipe_roles(recipe) {
			if other == role {
				continue
			}
			if od := swarm_role_def(recipe, other) {
				for p in cur.produces {
					if p in od.consumes {
						if other !in next {
							next << other
						}
						break
					}
				}
			}
		}
	}
	if next.len > 0 {
		return next
	}
	// Fallback chain for known recipes — mirrors prompts.py fallback
	match recipe {
		'pair' {
			match role {
				'implementer' { return ['reviewer'] }
				'reviewer' { return ['integrator'] }
				else { return [] }
			}
		}
		'team' {
			match role {
				'planner' { return ['implementer'] }
				'implementer' { return ['reviewer'] }
				'reviewer' { return ['architect'] }
				else { return [] }
			}
		}
		'full' {
			match role {
				'planner' { return ['implementer'] }
				'implementer' { return ['refactorer'] }
				'refactorer' { return ['architect'] }
				'architect' { return ['hardener'] }
				'hardener' { return ['qa'] }
				else { return [] }
			}
		}
		else {
			return []
		}
	}
}

// swarm_compose_role_prompt mirrors fbb2280 prompts.py:55 compose_role_prompt
// recipe is the recipe name (pair/team/full), role is the role name, task_contract is the task text (may be empty),
// handoff is optional handoff JSON/text (empty if none), included_skills is the role's skill list, run_id is the swarm run id for the handoff tail.
pub fn swarm_compose_role_prompt(recipe string, role string, task_contract string, handoff string, included_skills []string, run_id string) (string, SwarmPromptManifest) {
	def := swarm_role_def(recipe, role) or {
		SwarmRoleDef{
			persona:       role
			policy:        'read-only'
			model_profile: ''
			consumes:      []
			produces:      []
			skills:        included_skills.clone()
			worktree:      ''
		}
	}
	persona := def.persona
	policy := def.policy
	persona_text := swarm_load_persona_text(persona)
	recipe_name := recipe
	mut parts := []string{}
	parts << swarm_global_protocol
	parts << '# Recipe: ${recipe_name} — Role: ${role}\nPolicy: ${policy}\nPersona: ${persona}\n'
	parts << persona_text
	// Recipe workflow snippet — mirrors Python `Execution: {spec.execution}\nWorkspace: {spec.workspace}`
	workflow := 'Execution: ${swarm_recipe_execution_text(recipe_name)}\nWorkspace: ${swarm_recipe_workspace_text(recipe_name)}\n'
	parts << workflow
	if swarm_recipe_roles(recipe_name).len > 0 && swarm_recipe_roles(recipe_name)[0] == role {
		parts << '# Entry node\nYou are the entry node of this run graph: the task contract below is yours to start. Downstream roles are spawned and woken automatically as your handoffs reach them.'
	}
	is_interactive := task_contract.trim_space().len == 0
	if is_interactive {
		parts << swarm_interactive_bootstrap
		if ws := find_workspace_root('') {
			parts << '# Workspace context hint\nDetected workspace at `${ws}` — run `agent-toolkit workspace context` to see session state before waiting.'
		}
	} else {
		runes := task_contract.runes()
		tc := if runes.len > 3000 { runes[..3000].string() } else { task_contract }
		parts << '# Task Contract\n${tc}'
	}
	if handoff.trim_space().len > 0 {
		parts << '# Current Handoff\n${handoff}'
	}
	if included_skills.len > 0 {
		parts << '# Skills: ${included_skills.join(', ')}'
	}
	// Handoff delegation tail — explicit like swarm-forge, per role
	rid_display := if run_id.len > 0 { run_id } else { 'see task contract' }
	next_roles := swarm_next_roles(recipe_name, role)
	// predecessor: hardcoded chain first, then dynamic reverse-scan of the
	// successor graph (covers custom recipes with consumes/produces only).
	mut pred_str := swarm_role_predecessor(recipe_name, role)
	if pred_str.len == 0 {
		for other in swarm_recipe_roles(recipe_name) {
			if other == role {
				continue
			}
			if role in swarm_next_roles(recipe_name, other) {
				pred_str = other
				break
			}
		}
	}
	if pred_str.len == 0 {
		pred_str = 'none (entry node)'
	}
	if next_roles.len > 0 {
		produces := def.produces
		produces_str := if produces.len > 0 { produces.join(', ') } else { 'artifact' }
		next_str := next_roles.join(', ')
		first_next := next_roles[0]
		handoff_lines := [
			'## Handoff — delegate to next role when done',
			'Your role `${role}` produces: ${produces_str}',
			'Next role(s): ${next_str}',
			'Predecessor (for feedback/re-work): ${pred_str}',
			'When you complete your work:',
			'1. If you created/modified code, commit it on your worktree branch (`git add` + `git commit`), then:',
			'   `agent-toolkit swarm handoff create --type commit --from ${role} --to ${first_next} --commit <40-hex-sha> --branch <your-branch>`',
			'2. If you created an artifact (e.g., `artifacts/review.md`), then:',
			'   `agent-toolkit swarm handoff create --type artifact --from ${role} --to ${first_next} --artifact artifacts/<file>.md`',
			'The next role will run `agent-toolkit swarm task next --role <next> --run-id <run_id>` to pick it up. Do not wait — the handoff is durable and the daemon will notify. The next role\'s tmux window will be auto-created by the handoff.',
			'IMPORTANT: After you finish writing the artifact or committing code, immediately run the `handoff create` command above — do NOT ask the user for confirmation, do NOT wait for \'do the handoff\'.',
			'FORBIDDEN: Do not run a local code review via subagent/Task tool. Do not self-correct and re-commit as "reviewer findings" — commit once, then handoff. The swarm\'s reviewer runs in an isolated worktree and is reached ONLY via `handoff create`; you will be woken for feedback if needed.',
			'Run ID for this swarm: `${rid_display}` — if the command says \'No run found\', add `--run-id <run_id>` or ensure `AGENT_TOOLKIT_SWARM_RUN_ID` is exported (it is in your tmux env).',
			'## Feedback — loop work back when needed',
			'You are a node in a directed graph, not a pipeline: if the next iteration belongs to an earlier role (re-work, failing checks, missing context, spec drift), send it back instead of forcing it forward:',
			'   `agent-toolkit swarm handoff create --type feedback --from ${role} --to <predecessor> --blocking --run-id ${rid_display}`',
			'The predecessor is woken automatically and iterates; with `--blocking` the round-trip is bounded by the recipe (max 2 loops per role pair) so the graph always converges.',
			'Inspect the live topology anytime: `agent-toolkit swarm graph ${rid_display}`.',
		]
		parts << handoff_lines.join('\n')
	} else {
		parts << '## Completion — you are a terminal node\nWhen your integration work is done: request the final approval gate (`agent-toolkit swarm approve <run-id> final` is granted by the human) and run `agent-toolkit swarm promote <run-id>` to merge and finish the run.'
		if pred_str.len > 0 && pred_str != 'none (entry node)' {
			parts << '## Feedback — loop work back when needed\nIf the integration fails checks or the result needs re-work, send it back instead of forcing it: `agent-toolkit swarm handoff create --type feedback --from ${role} --to ${pred_str} --blocking --run-id ${rid_display}`. The predecessor is woken automatically and iterates (bounded by the recipe round-trip limit).\nInspect the live topology: `agent-toolkit swarm graph ${rid_display}`.'
		}
	}
	mut text := parts.join('\n\n')
	rs := text.runes()
	if rs.len > 12000 {
		text = rs[..12000].string() + '\n[truncated]'
	}
	mut includes := []string{}
	includes << 'global_protocol'
	includes << 'recipe_workflow'
	includes << 'persona'
	if is_interactive {
		includes << 'interactive_bootstrap'
	}
	if !is_interactive {
		includes << 'task_contract'
	}
	if handoff.trim_space().len > 0 {
		includes << 'handoff'
	}
	if included_skills.len > 0 {
		includes << 'skills'
	}
	manifest := SwarmPromptManifest{
		role:               role
		persona:            persona
		policy:             policy
		recipe:             recipe_name
		includes:           includes
		size_chars:         text.runes().len
		model_profile_task: def.model_profile
		is_interactive:     is_interactive
	}
	return text, manifest
}
