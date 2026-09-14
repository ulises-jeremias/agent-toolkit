module desktop

import desktop.state as app_state
import desktop_engine

// Library install lifecycle facade (slice C, #1230).
//
// Honesty states for everything the Library surface installs:
//   available  — present in the Engine catalog, nothing recorded
//   configured — a selection/enabled flag exists in Engine configuration state
//   verified   — real receipt evidence recomputed from the Engine, never the flag
//   unavailable — not in the catalog at all
//
// install_agent records a selection flag only (no receipt is written); an
// agent receipt exists only when a core install deploys the agent's AGENT.md.
// The view must never claim configured as installed/verified. Provider/model
// properties are intentionally absent: AgentEntry carries no provider/model
// fields, so there is nothing truthful to inspect or edit (see #1230).
// skills_sync/skills_validate do not exist in the Engine; they are recorded
// as named dependencies and are not invented here.

// LibraryInstallState is the single vocabulary for Library install honesty.
pub enum LibraryInstallState {
	unavailable
	available
	configured
	verified
}

// library_install_state_label renders a state for cards and facts. 'installed'
// is never emitted: only verified (receipt-backed) or configured (flag-only)
// are truthful claims.
pub fn library_install_state_label(s LibraryInstallState) string {
	return match s {
		.unavailable { 'unavailable' }
		.available { 'available' }
		.configured { 'configured' }
		.verified { 'verified' }
	}
}

// LibraryAgentLifecycle is the full honest picture of one configured agent.
pub struct LibraryAgentLifecycle {
pub:
	id            string
	state         LibraryInstallState
	display       string // state label for cards and facts
	validate_ok   bool
	validate_err  string
	receipt_path  string
	receipt_info  string // installed_at · version, '' when unverified
	evidence      string // one-line provenance for messages
}

// library_agent_lifecycle validates first, then reads configuration state,
// then recomputes receipt evidence. Selection alone never yields verified.
pub fn (mut d Desktop) library_agent_lifecycle(id string) LibraryAgentLifecycle {
	ag := d.engine.agent_detail(id) or {
		return LibraryAgentLifecycle{
			id: id
			state: .unavailable
			display: library_install_state_label(.unavailable)
			validate_err: err.msg()
			evidence: 'not in agent catalog: ${err.msg()}'
		}
	}
	snap := d.engine.snapshot()
	configured := (snap.data['agents:installed:${id}'] or { 'false' }) == 'true'
	if r := d.engine.agent_receipt(id) {
		return LibraryAgentLifecycle{
			id: id
			state: .verified
			display: library_install_state_label(.verified)
			validate_ok: true
			receipt_path: r.receipt_path
			receipt_info: '${r.installed_at} · v${r.version}'
			evidence: 'receipt ${r.receipt_path}'
		}
	}
	if configured {
		return LibraryAgentLifecycle{
			id: id
			state: .configured
			display: library_install_state_label(.configured)
			validate_ok: true
			evidence: 'selected in configuration (agents:installed:${id}), no receipt yet — deploy targets to verify'
		}
	}
	return LibraryAgentLifecycle{
		id: id
		state: .available
		display: library_install_state_label(.available)
		validate_ok: true
		evidence: 'in catalog ${ag.source_file}, not selected'
	}
}

// library_agent_preview describes what install would change without mutating.
// Empty when the agent is unavailable (nothing truthful to preview).
pub fn (mut d Desktop) library_agent_preview(id string) string {
	lc := d.library_agent_lifecycle(id)
	if lc.state == .unavailable {
		return 'cannot preview: ${lc.validate_err}'
	}
	if lc.state == .verified {
		return 'already verified — ${lc.receipt_info} (${lc.receipt_path})'
	}
	if lc.state == .configured {
		return 'already selected — no receipt yet; deploy targets that ship agents/${id}/AGENT.md, then Verify'
	}
	ag := d.engine.agent_detail(id) or { return 'cannot preview: ${err.msg()}' }
	mut bits := ['will set agents:installed:${id}=true (selection only, no receipt)']
	if ag.delegates_to.len > 0 {
		bits << 'declares delegates: ${ag.delegates_to.join(', ')}'
	}
	if ag.holistic_owner != '' {
		bits << 'holistic owner ${ag.holistic_owner}'
	}
	return bits.join(' · ')
}

// engine_agents_provenance returns receipt evidence for all agents in one
// Engine call — card state without per-agent receipt IO.
pub fn (mut d Desktop) engine_agents_provenance() []desktop_engine.AgentReceiptInfo {
	return d.engine.agents_provenance()
}

// engine_agents_configured lists agent ids with a live selection flag — one
// snapshot read for per-frame card state (no per-agent receipt IO).
pub fn (mut d Desktop) engine_agents_configured() []string {
	snap := d.engine.snapshot()
	mut out := []string{}
	for k, v in snap.data {
		if k.starts_with('agents:installed:') && v == 'true' {
			out << k.all_after('agents:installed:')
		}
	}
	return out
}

// engine_validate_agent proves catalog membership before any mutation.
pub fn (mut d Desktop) engine_validate_agent(id string) !bool {
	return d.engine.validate_agent(id)!
}

// engine_agent_detail exposes catalog facts for preview text.
pub fn (mut d Desktop) engine_agent_detail(id string) !desktop_engine.AgentEntry {
	return d.engine.agent_detail(id)!
}

// engine_remove_agent clears the selection flag (recovery path for a
// configured-but-unwanted agent). Receipts are recomputed, never deleted.
pub fn (mut d Desktop) engine_remove_agent(id string) !u64 {
	rev := d.engine.remove_agent(id)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

// engine_install_skill_preview is the dry-run diff for one skill (no mutation).
pub fn (mut d Desktop) engine_install_skill_preview(id string) desktop_engine.TargetDiff {
	return d.engine.install_skill_preview(id)
}

// engine_verify_skill_receipts recomputes all skill receipt evidence.
pub fn (mut d Desktop) engine_verify_skill_receipts() []desktop_engine.BuildDiagnostic {
	return d.engine.verify_skill_receipts()
}

// library_skill_stage maps one skill to its honesty state plus evidence.
pub fn (mut d Desktop) library_skill_stage(id string) (LibraryInstallState, string) {
	_ := d.engine.skill_detail(id) or {
		return LibraryInstallState.unavailable, 'not in skills catalog: ${err.msg()}'
	}
	if r := d.engine.skill_receipt(id) {
		return LibraryInstallState.verified, 'receipt ${r.receipt_path} · ${r.installed_at}'
	}
	if id in d.engine.skills_installed() {
		return LibraryInstallState.configured, 'selected, no receipt yet — deploy targets to verify'
	}
	return LibraryInstallState.available, 'in catalog, not selected'
}

// engine_mcp_health_detailed reports recorded health: unconfigured until a
// probe succeeds; enabled-but-unprobed is configured, never healthy.
pub fn (mut d Desktop) engine_mcp_health_detailed(provider_id string) string {
	return d.engine.mcp_health_detailed(provider_id)
}

// engine_mcp_validate returns config diagnostics without mutating.
pub fn (mut d Desktop) engine_mcp_validate(provider_id string) []desktop_engine.BuildDiagnostic {
	return d.engine.mcp_validate(provider_id)
}

// engine_upsert_mcp_provider records provider config (setup path). The secret
// guard rejects raw tokens; health stays configured until a probe succeeds.
pub fn (mut d Desktop) engine_upsert_mcp_provider(provider_id string, config_json string) !u64 {
	rev := d.engine.upsert_mcp_provider(provider_id, config_json)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

// engine_remove_mcp_provider disables and unconfigures (uninstall path).
// Recorded config is left for evidence; enable state is cleared.
pub fn (mut d Desktop) engine_remove_mcp_provider(provider_id string) !u64 {
	rev := d.engine.remove_mcp_provider(provider_id)!
	snap := d.engine.snapshot()
	d.app_state = app_state.derive_app_state(snap)
	return rev
}

// engine_verify_mcp_receipts recomputes MCP receipt evidence (enabled
// providers must have recorded config).
pub fn (mut d Desktop) engine_verify_mcp_receipts() []desktop_engine.BuildDiagnostic {
	return d.engine.verify_mcp_receipts()
}

// library_mcp_stage maps one provider to its honesty stage plus evidence.
// Stages: unconfigured (nothing recorded) → configured (enabled/config
// recorded, health not proven) → healthy (probe-verified via health record).
// Health is a probe result, never a default for being enabled.
pub fn (mut d Desktop) library_mcp_stage(provider_id string) (string, string) {
	mut known := false
	mut enabled := false
	for p in d.engine.mcp_catalog() {
		if p.id == provider_id {
			known = true
			enabled = p.enabled
			break
		}
	}
	if !known {
		return 'unknown', 'not in MCP catalog'
	}
	health := d.engine.mcp_health_detailed(provider_id)
	if health == 'healthy' {
		return 'healthy', 'probe-verified ${health}'
	}
	if r := d.engine.mcp_receipt(provider_id) {
		if enabled {
			return 'configured', 'enabled · receipt ${r.receipt_path} · health ${health} (unprobed)'
		}
		return 'configured', 'receipt ${r.receipt_path} · currently disabled'
	}
	if enabled {
		return 'configured', 'enabled · health ${health} (no receipt yet)'
	}
	return 'unconfigured', 'in catalog, never enabled'
}

// engine_product_receipt reports real install receipt evidence for a product.
pub fn (mut d Desktop) engine_product_receipt(product_id string) string {
	return d.engine.product_receipt(product_id)
}


