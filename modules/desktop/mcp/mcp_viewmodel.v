module mcp

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct McpViewModel {
mut:
	engine   &desktop_engine.Engine
	all      []desktop_engine.McpProvider
	filtered []desktop_engine.McpProvider
	search   string
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

// ── engine-backed: stats, toggle, provenance, receipts, preview, search ──
pub fn (vm McpViewModel) stats() desktop_engine.McpStats {
	return vm.engine.mcp_stats()
}

pub fn (mut vm McpViewModel) toggle(provider_id string) !u64 {
	rev := vm.engine.mcp_toggle(provider_id)!
	vm.refresh()
	return rev
}

pub fn (vm McpViewModel) install_preview(provider_id string) desktop_engine.McpInstallPreview {
	return vm.engine.mcp_install_preview(provider_id)
}

pub fn (vm McpViewModel) receipt(provider_id string) ?desktop_engine.McpInstallPreview {
	return vm.engine.mcp_receipt(provider_id)
}

pub fn (vm McpViewModel) provenance_json(provider_id string) string {
	return vm.engine.mcp_provenance_json(provider_id)
}

pub fn (vm McpViewModel) verify_receipts() []desktop_engine.BuildDiagnostic {
	return vm.engine.verify_mcp_receipts()
}

pub fn (mut vm McpViewModel) search(q string) {
	vm.set_search(q)
}

pub fn (vm McpViewModel) filtered_search(q string) []desktop_engine.McpProvider {
	return vm.engine.mcp_catalog_search(q)
}

pub fn (vm McpViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}

// ── Library lifecycle (slice C): setup/health/uninstall with honesty ──

// health_detailed reports recorded health: unconfigured until a probe
// succeeds; enabled-but-unprobed is configured, never healthy.
pub fn (mut vm McpViewModel) health_detailed(provider_id string) string {
	return vm.engine.mcp_health_detailed(provider_id)
}

// validate_summary renders config diagnostics without mutating; clean config
// reports clean, never healthy (health is a probe result).
pub fn (mut vm McpViewModel) validate_summary(provider_id string) string {
	diags := vm.engine.mcp_validate(provider_id)
	if diags.len == 0 {
		return 'config valid — health still unproven until Probe succeeds'
	}
	return 'config invalid: ${diags[0].path}: ${diags[0].message}'
}

// setup records provider config (the setup path). The secret guard rejects
// raw tokens; callers surface the error with its recovery hint.
pub fn (mut vm McpViewModel) setup(provider_id string, config_json string) !u64 {
	rev := vm.engine.upsert_mcp_provider(provider_id, config_json)!
	vm.refresh()
	return rev
}

// uninstall disables and unconfigures (the uninstall path). Recorded config
// is left for evidence; enable state is cleared.
pub fn (mut vm McpViewModel) uninstall(provider_id string) !u64 {
	rev := vm.engine.remove_mcp_provider(provider_id)!
	vm.refresh()
	return rev
}

// stage maps one provider to its honesty stage plus evidence: unconfigured,
// configured, healthy (probe-verified), or unknown (not in catalog).
pub fn (mut vm McpViewModel) stage(provider_id string) (string, string) {
	mut known := false
	mut enabled := false
	for p in vm.all {
		if p.id == provider_id {
			known = true
			enabled = p.enabled
			break
		}
	}
	if !known {
		return 'unknown', 'not in MCP catalog'
	}
	health := vm.engine.mcp_health_detailed(provider_id)
	if health == 'healthy' {
		return 'healthy', 'probe-verified ${health}'
	}
	if _ := vm.engine.mcp_receipt(provider_id) {
		if enabled {
			return 'configured', 'enabled · health ${health} (unprobed)'
		}
		return 'configured', 'previously enabled · currently disabled'
	}
	if enabled {
		return 'configured', 'enabled · health ${health} (no receipt yet)'
	}
	return 'unconfigured', 'in catalog, never enabled'
}
