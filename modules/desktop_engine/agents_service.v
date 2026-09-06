module desktop_engine

import os
import x.json2
import agent_toolkit_core

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

// agents_catalog returns personas from the resolved catalog. Missing data is empty;
// archived or demo personas must not be fabricated for production views.
pub fn (mut e Engine) agents_catalog() []AgentEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	catalog_path := data_path(env, 'catalogs/agent-catalog.yaml')
	if data_file_exists(env, 'catalogs/agent-catalog.yaml') {
		text := data_file_read(env, 'catalogs/agent-catalog.yaml') or { '' }
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
					// tier starts unknown; the catalog's real `kind:` overrides
					cur.tier = tier_for_agent(cur.id)
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
			if entries.len > 0 {
				// Enrich only with real derivations: the display role maps from
				// the catalog's real `kind:` tier. Triggers and holistic owner
				// come only from real catalog data — never invented routing
				// metadata attached to real entries.
				for i in 0 .. entries.len {
					entries[i].role = role_for_tier(entries[i].tier)
				}
				return entries
			}
		}
	}
	return []AgentEntry{}
}

// tier_for_agent only applies the archived naming convention; the canonical
// tier comes from the catalog's real `kind:` field. A missing kind stays
// unknown rather than guessed from hardcoded id lists.
fn tier_for_agent(id string) string {
	if id.starts_with('old-') {
		return 'archived'
	}
	return ''
}

// role_for_tier maps a real catalog tier to its display label. An unknown
// tier has no label — never a guessed one.
fn role_for_tier(tier string) string {
	return match tier {
		'orchestrator' { 'Orchestrator' }
		'specialist' { 'Specialist' }
		'archived' { 'Archived' }
		'holistic' { 'Holistic' }
		else { '' }
	}
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

// agent_receipt returns real receipt evidence for an agent: the artifact
// records of core install receipts whose deployed artifacts include the
// agent's AGENT.md. Selection state alone is never receipt evidence.
pub fn (mut e Engine) agent_receipt(id string) ?AgentReceiptInfo {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	needle := 'agents/${id}/AGENT.md'
	for r in agent_toolkit_core.list_install_receipts('') {
		for a in r.artifacts {
			if a.path.contains(needle) {
				return AgentReceiptInfo{
					agent_id: id
					installed: true
					installed_at: r.installed_at
					version: r.version
					receipt_path: os.join_path(agent_toolkit_core.default_receipt_dir(),
						agent_toolkit_core.receipt_filename(r.target, r.product))
				}
			}
		}
	}
	return none
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

// install_agent records the agent as selected in configuration state.
// Selection is configuration truth only — no receipt is written; receipt
// evidence exists only when the core installer deploys real artifacts.
pub fn (mut e Engine) install_agent(id string) !u64 {
	_ := e.agent_detail(id)!
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('install-agent')
	tx.set('agents:installed:${id}', 'true')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// remove_agent clears the selection.
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

// agent_provenance_detail returns structured provenance for one agent. The
// source fields are real catalog facts; verified reflects actual provenance
// evidence from the bundled manifests, never an unconditional claim.
pub fn (mut e Engine) agent_provenance_detail(id string) string {
	_ := e.agent_detail(id) or {
		return json2.encode({
			'error': 'not found'
		},
			escape_unicode: true
		)
	}
	mut verified := false
	mut source_digest := ''
	mut generated_digest := ''
	needle := 'agents/${id}/AGENT.md'
	for p in e.provenance_catalog() {
		if p.artifact_path.contains(needle) {
			verified = p.verified
			source_digest = p.source_digest
			generated_digest = p.generated_digest
			break
		}
	}
	return json2.encode({
		'id':              id
		'source':          'agents/${id}/AGENT.md'
		'provenance':      'catalogs/agent-catalog.yaml'
		'sourceDigest':    source_digest
		'generatedDigest': generated_digest
		'verified':        if verified { 'true' } else { 'false' }
	},
		escape_unicode: true
	)
}
