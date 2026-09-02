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

// ── super-potent: search, stats, provenance, receipts, delegation ──
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
