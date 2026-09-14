module agents

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct AgentsViewModel {
mut:
	engine   &desktop_engine.Engine
	all      []desktop_engine.AgentEntry
	filtered []desktop_engine.AgentEntry
	search   string
	tier     string
	revision u64
}

pub fn new_agents_viewmodel(mut engine &desktop_engine.Engine) AgentsViewModel {
	cat := engine.agents_catalog()
	return AgentsViewModel{
		engine: engine
		all: cat.clone()
		filtered: cat.clone()
		revision: engine.revision()
	}
}

pub fn (mut vm AgentsViewModel) refresh() {
	vm.all = vm.engine.agents_catalog()
	vm.apply_filter()
	vm.revision = vm.engine.revision()
}

pub fn (mut vm AgentsViewModel) apply_filter() {
	mut out := []desktop_engine.AgentEntry{}
	for a in vm.all {
		if vm.tier != '' && a.tier != vm.tier {
			continue
		}
		if vm.search != '' {
			q := vm.search.to_lower()
			if !a.id.to_lower().contains(q) && !a.role.to_lower().contains(q) {
				continue
			}
		}
		out << a
	}
	vm.filtered = out
}

pub fn (mut vm AgentsViewModel) set_search(q string) {
	vm.search = q
	vm.apply_filter()
}

pub fn (mut vm AgentsViewModel) set_tier(t string) {
	vm.tier = t
	vm.apply_filter()
}

pub fn (vm AgentsViewModel) filtered_agents() []desktop_engine.AgentEntry {
	return vm.filtered.clone()
}

pub fn (mut vm AgentsViewModel) detail(id string) !desktop_engine.AgentEntry {
	return vm.engine.agent_detail(id)
}

pub fn (mut vm AgentsViewModel) holistic_owner(agent_id string) string {
	ag := vm.engine.agent_detail(agent_id) or { return '' }
	return ag.holistic_owner
}

pub fn (mut vm AgentsViewModel) tier_counts() map[string]int {
	return vm.engine.agents_tier_counts()
}

pub fn (mut vm AgentsViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

// ── engine-backed: search, stats, provenance, receipts, delegation ──
pub fn (mut vm AgentsViewModel) search(query string, tier string) []desktop_engine.AgentEntry {
	return vm.engine.agents_search(query, tier)
}

pub fn (vm AgentsViewModel) stats() desktop_engine.AgentStats {
	return vm.engine.agents_stats()
}

pub fn (vm AgentsViewModel) by_tier() map[string][]desktop_engine.AgentEntry {
	return vm.engine.agents_by_tier()
}

pub fn (vm AgentsViewModel) receipt(id string) ?desktop_engine.AgentReceiptInfo {
	return vm.engine.agent_receipt(id)
}

pub fn (mut vm AgentsViewModel) install(id string) !u64 {
	rev := vm.engine.install_agent(id)!
	vm.refresh()
	return rev
}

pub fn (mut vm AgentsViewModel) remove_agent(id string) !u64 {
	rev := vm.engine.remove_agent(id)!
	vm.refresh()
	return rev
}

pub fn (vm AgentsViewModel) provenance_detail(id string) string {
	return vm.engine.agent_provenance_detail(id)
}

pub fn (vm AgentsViewModel) delegation_graph() map[string][]string {
	return vm.engine.agents_delegation_graph()
}

pub fn (vm AgentsViewModel) verify() []desktop_engine.BuildDiagnostic {
	return vm.engine.verify_skill_receipts()
}

pub fn (vm AgentsViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

// ── Library install lifecycle (slice C): validate → preview → apply → verify ──
// install_agent records a selection flag only — no receipt is written — so
// lifecycle_state never reports more than configured without receipt
// evidence recomputed from the Engine.

// lifecycle_state maps one agent to its honesty state: unavailable when the id
// is not in the catalog, verified only with receipt evidence, configured when
// the selection flag is set, available otherwise.
pub fn (mut vm AgentsViewModel) lifecycle_state(id string) string {
	_ := vm.engine.agent_detail(id) or { return 'unavailable' }
	if _ := vm.engine.agent_receipt(id) {
		return 'verified'
	}
	snap := vm.engine.snapshot()
	if (snap.data['agents:installed:${id}'] or { 'false' }) == 'true' {
		return 'configured'
	}
	return 'available'
}

// configured_ids lists agent ids with a live selection flag (one snapshot read).
pub fn (mut vm AgentsViewModel) configured_ids() []string {
	snap := vm.engine.snapshot()
	mut out := []string{}
	for k, v in snap.data {
		if k.starts_with('agents:installed:') && v == 'true' {
			out << k.all_after('agents:installed:')
		}
	}
	return out
}

// preview_install describes what install would change without mutating.
// Returns an error for unknown ids so the view can explain + offer recovery.
pub fn (mut vm AgentsViewModel) preview_install(id string) !string {
	ag := vm.engine.agent_detail(id)!
	if _ := vm.engine.agent_receipt(id) {
		return 'already verified — receipt evidence exists, nothing to apply'
	}
	snap := vm.engine.snapshot()
	if (snap.data['agents:installed:${id}'] or { 'false' }) == 'true' {
		return 'already selected — no receipt yet; deploy targets, then verify'
	}
	mut bits := ['will set agents:installed:${id}=true (selection only, no receipt)']
	if ag.delegates_to.len > 0 {
		bits << 'declares delegates: ${ag.delegates_to.join(', ')}'
	}
	return bits.join(' · ')
}

// verify_install recomputes receipt evidence after apply. ok is true only
// with a real receipt; the message always carries the evidence or the next
// step, never a bare claim.
pub fn (mut vm AgentsViewModel) verify_install(id string) (bool, string) {
	_ := vm.engine.agent_detail(id) or { return false, 'unavailable: ${err.msg()}' }
	if r := vm.engine.agent_receipt(id) {
		return true, 'verified — ${r.receipt_path}'
	}
	snap := vm.engine.snapshot()
	if (snap.data['agents:installed:${id}'] or { 'false' }) == 'true' {
		return false, 'configured but unverified — deploy targets that ship agents/${id}/AGENT.md, then verify again'
	}
	return false, 'available — not selected, nothing to verify'
}
