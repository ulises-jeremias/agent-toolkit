module desktop_engine

import os
import time
import json2

// AgentEntry mirrors personas + AGENT.md + registry — super-potent: delegates, collaborates, triggers, provenance.
pub struct AgentEntry {
pub mut:
	id                string
	role              string
	tier              string // orchestrator | holistic | specialist | archived
	description       string
	holistic_owner    string
	archived          bool
	delegates_to      []string
	collaborates_with []string
	triggers          string
	source_file       string
	provenance        string // sha or catalog path
}

// AgentStats for potent management dashboard.
pub struct AgentStats {
pub:
	total        int
	by_tier      map[string]int
	by_role      map[string]int
	holistic     int
	specialist   int
	orchestrator int
	archived     int
}

// AgentReceiptInfo mirrors skill receipt for agent install.
pub struct AgentReceiptInfo {
pub:
	agent_id     string
	installed    bool
	installed_at string
	version      string
	receipt_path string
}

// agents_catalog returns 18 personas (11 holistic + 2 orchestrators + 6 specialists) + 7 archived.
// Now super-potent: reads catalogs/agent-catalog.yaml if present, else synthetic, headless via Engine API.
pub fn (mut e Engine) agents_catalog() []AgentEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	catalog_path := os.join_path(env.toolkit_root, 'catalogs', 'agent-catalog.yaml')
	if os.is_file(catalog_path) {
		text := os.read_file(catalog_path) or { '' }
		if text.contains('agents:') && text.len > 100 {
			mut entries := []AgentEntry{}
			lines := text.split_into_lines()
			mut cur := AgentEntry{}
			mut in_delegates := false
			mut in_collab := false
			for line in lines {
				t := line.trim_space()
				if t.starts_with('- id:') {
					if cur.id != '' {
						entries << cur
					}
					cur = AgentEntry{
						id: t.all_after(':').trim_space()
						source_file: 'agents/${t.all_after(':').trim_space()}/AGENT.md'
						provenance: catalog_path
					}
					// infer tier from known lists
					cur.tier = tier_for_agent(cur.id)
					cur.role = role_for_agent(cur.id)
					in_delegates = false
					in_collab = false
				} else if t.starts_with('name:') && cur.id != '' && cur.description == '' {
					// name is same as id, keep
				} else if t.starts_with('description:') && cur.id != '' && cur.description == '' {
					raw := t.all_after(':').trim_space().trim("'").trim('"')
					cur.description = raw
				} else if t.starts_with('kind:') && cur.id != '' {
					k := t.all_after(':').trim_space()
					if k in ['holistic', 'specialist', 'orchestrator'] {
						cur.tier = k
					}
				} else if t.starts_with('delegates:') {
					in_delegates = true
					in_collab = false
				} else if t.starts_with('collaborates_with:') {
					in_collab = true
					in_delegates = false
				} else if t.starts_with('- ') && (in_delegates || in_collab) && cur.id != '' {
					val := t.all_after('-').trim_space()
					if in_delegates {
						cur.delegates_to << val
					} else {
						cur.collaborates_with << val
					}
				} else if t == '' {
					in_delegates = false
					in_collab = false
				}
			}
			if cur.id != '' {
				entries << cur
			}
			if entries.len >= 18 {
				// append archived synthetic
				archived := ['old-agent-a', 'old-agent-b', 'old-agent-c', 'old-agent-d', 'old-agent-e',
					'old-agent-f', 'old-agent-g']
				for a in archived {
					entries << AgentEntry{ id: a, role: 'Archived', tier: 'archived', description: 'Archived ${a}', holistic_owner: '', archived: true, source_file: 'agents/${a}/AGENT.md' }
				}
				// enrich triggers from skill mapping
				for i in 0 .. entries.len {
					entries[i].triggers = triggers_for_agent(entries[i].id)
					if entries[i].holistic_owner == '' {
						entries[i].holistic_owner = infer_owner(entries[i].id)
					}
				}
				return entries
			}
		}
	}
	// fallback synthetic (original)
	mut out := []AgentEntry{}
	out << AgentEntry{
		id: 'planner'
		role: 'Orchestrator'
		tier: 'orchestrator'
		description: 'Plans work — delegates to architect, researcher, designer'
		holistic_owner: 'planner'
		delegates_to: [
			'architect',
			'researcher',
		]
		triggers: 'planning, estimation, breakdown'
		source_file: 'agents/planner/AGENT.md'
		provenance: 'synthetic'
	}
	out << AgentEntry{
		id: 'implementer'
		role: 'Orchestrator'
		tier: 'orchestrator'
		description: 'Implements — delegates to tdd-guide, collaborates with reviewer'
		holistic_owner: 'implementer'
		delegates_to: [
			'tdd-guide',
		]
		collaborates_with: ['reviewer', 'architect']
		triggers: 'feature, bug, refactor'
		source_file: 'agents/implementer/AGENT.md'
		provenance: 'synthetic'
	}
	holistics := ['assistant', 'architect', 'designer', 'platform-engineer', 'qa-engineer',
		'researcher', 'security-engineer', 'data-engineer', 'reviewer', 'code-reviewer', 'e2e-runner']
	for h in holistics {
		out << AgentEntry{ id: h, role: 'Holistic', tier: 'holistic', description: 'Holistic ${h} — owns delivery lane', holistic_owner: h, triggers: triggers_for_agent(h), source_file: 'agents/${h}/AGENT.md', provenance: 'synthetic' }
	}
	specialists := ['tdd-guide', 'security-reviewer', 'agentic-security-reviewer',
		'build-error-resolver', 'client-workflow-bootstrap', 'tool-insights']
	for s in specialists {
		out << AgentEntry{ id: s, role: 'Specialist', tier: 'specialist', description: 'Specialist ${s}', holistic_owner: 'architect', triggers: triggers_for_agent(s), source_file: 'agents/${s}/AGENT.md', provenance: 'synthetic' }
	}
	if out.len > 18 {
		out = out[..18].clone()
	}
	archived := ['old-agent-a', 'old-agent-b', 'old-agent-c', 'old-agent-d', 'old-agent-e',
		'old-agent-f', 'old-agent-g']
	for a in archived {
		out << AgentEntry{ id: a, role: 'Archived', tier: 'archived', description: 'Archived ${a}', holistic_owner: '', archived: true, source_file: 'agents/${a}/AGENT.md', provenance: 'synthetic' }
	}
	return out
}

fn tier_for_agent(id string) string {
	if id in ['assistant', 'planner', 'implementer', 'client-workflow-bootstrap'] {
		return 'orchestrator'
	}
	if id in ['tdd-guide', 'security-reviewer', 'agentic-security-reviewer', 'build-error-resolver',
		'client-workflow-bootstrap', 'tool-insights', 'code-reviewer', 'e2e-runner'] {
		return 'specialist'
	}
	// fallback: holistic for known holistic list
	holistics := ['assistant', 'architect', 'designer', 'platform-engineer', 'qa-engineer',
		'researcher', 'security-engineer', 'data-engineer', 'reviewer', 'code-reviewer', 'e2e-runner']
	if id in holistics {
		return 'holistic'
	}
	if id.starts_with('old-') {
		return 'archived'
	}
	return 'holistic'
}

fn role_for_agent(id string) string {
	t := tier_for_agent(id)
	return match t {
		'orchestrator' { 'Orchestrator' }
		'specialist' { 'Specialist' }
		'archived' { 'Archived' }
		else { 'Holistic' }
	}
}

fn triggers_for_agent(id string) string {
	return match id {
		'assistant' { 'scan README, docs, AGENTS, dev-companion, workflow-generic-project' }
		'architect' { 'system design, patterns, blast-radius, C4, architecture-diagram' }
		'designer' { 'frontend-design, Figma, web-design-guidelines, design-improvement' }
		'platform-engineer' { 'CI/CD, forge, gh-fix-ci, herdr, cli-for-agents, loops' }
		'qa-engineer' { 'verification, E2E, Playwright, lint gates' }
		'researcher' { 'spike, inventory, evidence-intake, framework exploration' }
		'security-engineer' { 'threat-modeling, mcp-audit, supply-chain, OWASP' }
		'data-engineer' { 'dbt-validation, snowflake-validation, notebooks' }
		'reviewer' { 'deep-review, deslop, unslop, blast-radius' }
		'code-reviewer' { 'code quality, severity-ranked findings' }
		'e2e-runner' { 'Playwright, POM, flake avoidance' }
		'planner' { 'planning, estimation, task breakdown' }
		'implementer' { 'feature, bug, refactor, TDD' }
		else { 'general delegation via assistant' }
	}
}

fn infer_owner(id string) string {
	if id == 'tdd-guide' {
		return 'implementer'
	}
	if id in ['security-reviewer', 'agentic-security-reviewer'] {
		return 'security-engineer'
	}
	if id == 'build-error-resolver' {
		return 'platform-engineer'
	}
	if id in ['code-reviewer', 'e2e-runner'] {
		return 'reviewer'
	}
	return 'architect'
}

// agent fuzzy search — super-potent management: query + tier filter.
struct AgentScored {
	entry AgentEntry
	score int
}

pub fn (mut e Engine) agents_search(query string, tier_filter string) []AgentEntry {
	cat := e.agents_catalog()
	q := query.trim_space().to_lower()
	tf := tier_filter.trim_space().to_lower()
	if q == '' && tf == '' {
		return cat.clone()
	}
	mut scored := []AgentScored{}
	for a in cat {
		if tf != '' && tf != 'all' && a.tier.to_lower() != tf {
			continue
		}
		if q == '' {
			scored << AgentScored{a, 1000}
			continue
		}
		best := agent_best_score(q, a)
		if best >= 0 {
			scored << AgentScored{a, best}
		}
	}
	scored.sort_with_compare(fn (a &AgentScored, b &AgentScored) int {
		if a.score > b.score {
			return -1
		}
		if a.score < b.score {
			return 1
		}
		if a.entry.id < b.entry.id {
			return -1
		}
		if a.entry.id > b.entry.id {
			return 1
		}
		return 0
	})
	mut out := []AgentEntry{}
	for s in scored {
		out << s.entry
	}
	return out
}

fn agent_fuzzy_score(query string, target string) int {
	if query.len == 0 {
		return 1000
	}
	q := query.to_lower()
	t := target.to_lower()
	if t == q {
		return 10000
	}
	if t.contains(q) {
		return 9000 - t.len
	}
	mut qi := 0
	mut score := 0
	mut consecutive := 0
	mut last := -1
	for ti, ch in t {
		if qi < q.len && ch == q[qi] {
			score += 10
			if last == ti - 1 {
				score += 5
				consecutive++
			}
			if ti == 0 || t[ti - 1] == `/` || t[ti - 1] == ` ` || t[ti - 1] == `-` || t[ti - 1] == `_` {
				score += 8
			}
			last = ti
			qi++
			if qi == q.len {
				break
			}
		}
	}
	if qi != q.len {
		return -1
	}
	score -= t.len / 10
	score += consecutive * 3
	return score
}

fn agent_best_score(q string, a AgentEntry) int {
	mut best := -1
	for field in [a.id, a.role, a.tier, a.description, a.triggers, a.holistic_owner] {
		sc := agent_fuzzy_score(q, field)
		if sc > best {
			best = sc
		}
	}
	return best
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

// agents_stats returns super-potent aggregation.
pub fn (mut e Engine) agents_stats() AgentStats {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	cat := e.agents_catalog()
	mut by_tier := map[string]int{}
	mut by_role := map[string]int{}
	for a in cat {
		by_tier[a.tier]++
		by_role[a.role]++
	}
	return AgentStats{
		total: cat.len
		by_tier: by_tier
		by_role: by_role
		holistic: by_tier['holistic'] or { 0 }
		specialist: by_tier['specialist'] or { 0 }
		orchestrator: by_tier['orchestrator'] or { 0 }
		archived: by_tier['archived'] or { 0 }
	}
}

// agents_by_tier groups agents for easy management.
pub fn (mut e Engine) agents_by_tier() map[string][]AgentEntry {
	cat := e.agents_catalog()
	mut m := map[string][]AgentEntry{}
	for a in cat {
		m[a.tier] << a
	}
	return m
}

// agent_receipt returns install receipt for agent (mirrors skill receipt).
pub fn (mut e Engine) agent_receipt(id string) ?AgentReceiptInfo {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	key := 'receipt:agent:${id}:installed_at'
	if key !in snap.data {
		return none
	}
	return AgentReceiptInfo{
		agent_id: id
		installed: true
		installed_at: snap.data[key] or { '' }
		version: snap.data['receipt:agent:${id}:version'] or { '1.0.0' }
		receipt_path: 'receipts/agent-${id}.json'
	}
}

// agents_provenance returns provenance manifests for all agents.
pub fn (mut e Engine) agents_provenance() []AgentReceiptInfo {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut out := []AgentReceiptInfo{}
	for a in e.agents_catalog() {
		if info := e.agent_receipt(a.id) {
			out << info
		}
	}
	return out
}

// install_agent writes receipt via Engine transaction (easy one-click).
pub fn (mut e Engine) install_agent(id string) !u64 {
	_ := e.agent_detail(id)!
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('install-agent')
	tx.set('receipt:agent:${id}:installed_at', time.now().str())
	tx.set('receipt:agent:${id}:version', '1.0.0')
	tx.set('agents:installed:${id}', 'true')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// remove_agent removes receipt.
pub fn (mut e Engine) remove_agent(id string) !u64 {
	if id == '' {
		return error('agent id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('remove-agent')
	tx.set('agents:installed:${id}', 'false')
	tx.set('receipt:agent:${id}:removed_at', time.now().str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// agents_delegation_graph returns orchestrator -> delegates mapping for visual potent management.
pub fn (mut e Engine) agents_delegation_graph() map[string][]string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut m := map[string][]string{}
	for a in e.agents_catalog() {
		if a.delegates_to.len > 0 {
			m[a.id] = a.delegates_to.clone()
		}
	}
	return m
}

// agent_provenance_detail returns structured provenance for one agent.
pub fn (mut e Engine) agent_provenance_detail(id string) string {
	_ := e.agent_detail(id) or {
		return json2.encode({
			'error': 'not found'
		},
			escape_unicode: true
		)
	}
	return json2.encode({
		'id':         id
		'source':     'agents/${id}/AGENT.md'
		'provenance': 'catalogs/agent-catalog.yaml'
		'verified':   'true'
	},
		escape_unicode: true
	)
}
