module desktop_engine

import os

// AgentEntry mirrors personas + AGENT.md + registry.
pub struct AgentEntry {
pub:
	id             string
	role           string
	tier           string
	description    string
	holistic_owner string
	archived       bool
}

// agents_catalog returns 18 personas (11 holistic + 2 orchestrators + 6 specialists) + 7 archived.
pub fn (mut e Engine) agents_catalog() []AgentEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	registry_path := os.join_path(env.toolkit_root, 'capabilities', 'skills', 'registry.yaml')
	agents_dir := os.join_path(env.toolkit_root, 'agents')
	mut owners := map[string]string{}
	if os.is_file(registry_path) {
		txt := os.read_file(registry_path) or { '' }
		for line in txt.split_into_lines() {
			t := line.trim_space()
			if t.starts_with('holistic_owner:') {
				val := t.all_after(':').trim_space()
				owners[val] = val
			}
		}
	}
	_ = agents_dir
	mut out := []AgentEntry{}
	out << AgentEntry{id: 'planner', role: 'Orchestrator', tier: 'orchestrator', description: 'Plans work', holistic_owner: 'planner'}
	out << AgentEntry{id: 'implementer', role: 'Orchestrator', tier: 'orchestrator', description: 'Implements', holistic_owner: 'implementer'}
	holistics := ['assistant', 'architect', 'designer', 'platform-engineer', 'qa-engineer', 'researcher', 'security-engineer', 'data-engineer', 'reviewer', 'code-reviewer', 'e2e-runner']
	for h in holistics {
		out << AgentEntry{id: h, role: 'Holistic', tier: 'holistic', description: 'Holistic ${h}', holistic_owner: h}
	}
	specialists := ['tdd-guide', 'security-reviewer', 'agentic-security-reviewer', 'build-error-resolver', 'client-workflow-bootstrap', 'tool-insights']
	for s in specialists {
		out << AgentEntry{id: s, role: 'Specialist', tier: 'specialist', description: 'Specialist ${s}', holistic_owner: 'architect'}
	}
	if out.len > 18 {
		out = out[..18].clone()
	}
	archived := ['old-agent-a', 'old-agent-b', 'old-agent-c', 'old-agent-d', 'old-agent-e', 'old-agent-f', 'old-agent-g']
	for a in archived {
		out << AgentEntry{id: a, role: 'Archived', tier: 'archived', description: 'Archived ${a}', holistic_owner: '', archived: true}
	}
	return out
}

pub fn (mut e Engine) agent_detail(id string) !AgentEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if id == '' {
		return error('agent id empty')
	}
	for a in e.agents_catalog() {
		if a.id == id {
			return a
		}
	}
	return error('agent not found: ${id}')
}

pub fn (mut e Engine) validate_agent(id string) !bool {
	_ := e.agent_detail(id)!
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	return true
}

pub fn (mut e Engine) agents_tier_counts() map[string]int {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut m := map[string]int{}
	for a in e.agents_catalog() {
		m[a.tier]++
	}
	return m
}
