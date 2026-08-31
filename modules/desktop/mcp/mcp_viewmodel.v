module mcp

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct McpViewModel {
mut:
	engine &desktop_engine.Engine
	all    []desktop_engine.McpProvider
	filtered []desktop_engine.McpProvider
	search string
	revision u64
}

pub fn new_mcp_viewmodel(mut engine &desktop_engine.Engine) McpViewModel {
	cat := engine.mcp_catalog()
	return McpViewModel{
		engine: engine
		all: cat.clone()
		filtered: cat.clone()
		revision: engine.revision()
	}
}

pub fn (mut vm McpViewModel) refresh() {
	vm.all = vm.engine.mcp_catalog()
	vm.apply_filter()
	vm.revision = vm.engine.revision()
}

pub fn (mut vm McpViewModel) apply_filter() {
	mut out := []desktop_engine.McpProvider{}
	for p in vm.all {
		if vm.search != '' {
			q := vm.search.to_lower()
			if !p.id.to_lower().contains(q) && !p.name.to_lower().contains(q) {
				continue
			}
		}
		out << p
	}
	vm.filtered = out
}

pub fn (mut vm McpViewModel) set_search(q string) {
	vm.search = q
	vm.apply_filter()
}

pub fn (vm McpViewModel) filtered_providers() []desktop_engine.McpProvider {
	return vm.filtered.clone()
}

pub fn (mut vm McpViewModel) health(provider_id string) string {
	return vm.engine.mcp_health(provider_id)
}

pub fn (mut vm McpViewModel) preview(provider_id string) (string, string) {
	return vm.engine.mcp_preview(provider_id)
}

pub fn (mut vm McpViewModel) validate(provider_id string) []desktop_engine.BuildDiagnostic {
	return vm.engine.mcp_validate(provider_id)
}

pub fn (mut vm McpViewModel) upsert(provider_id string, config_json string) !u64 {
	rev := vm.engine.upsert_mcp_provider(provider_id, config_json)!
	vm.refresh()
	return rev
}

pub fn (mut vm McpViewModel) remove(provider_id string) !u64 {
	rev := vm.engine.remove_mcp_provider(provider_id)!
	vm.refresh()
	return rev
}

pub fn (mut vm McpViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm McpViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
