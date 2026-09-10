module main

import desktop
import desktop.nav
import desktop.palette
import desktop_engine
import os
import time

// Reachability gate: the canonical set of critical user
// workflows must be reachable through the typed registry's semantics —
// not through CLI command parity. This test is the coverage authority;
// scripts/gui-coverage.py is only a human-readable report.

struct ReachFixture {
mut:
	app &GuiApp = unsafe { nil }
	d   &desktop.Desktop = unsafe { nil }
	scratch_dir string
}

fn reach_app(label string) &ReachFixture {
	scratch_dir := os.join_path(os.temp_dir(), 'atk-reach-${label}-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(scratch_dir) or { panic(err.msg()) }
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: desktop.DesktopConfig{
			headless: true
		}
		persist_path: os.join_path(scratch_dir, 'state.json')
	})
	d.boot() or { panic(err.msg()) }
	mut app := &GuiApp{
		desktop: d
		selected_panel: 0
		hover_panel: -1
		selected_desk: -1
		hover_desk: -1
	}
	app.palette_reg = d.palette_registry()
	app.palette_open = true
	return &ReachFixture{
		app: app
		d: d
		scratch_dir: scratch_dir
	}
}

fn (mut f ReachFixture) cleanup() {
	f.d.shutdown() or {}
	os.rmdir_all(f.scratch_dir) or {}
	f.scratch_dir = ''
}

fn has_action(acts []palette.RegistryAction, kind palette.ActionKind) bool {
	return acts.any(it.kind == kind)
}

// workflow: discover + inspect + install skill where supported
fn test_workflow_skill_discovery_install() {
	mut f := reach_app('skill')
	defer {
		f.cleanup()
	}
	entries := f.app.palette_reg.all_entries()
	skills := entries.filter(it.kind == palette.EntityKind.skill)
	assert skills.len > 0, 'skills must be discoverable'
	first := skills[0]
	assert first.panel == nav.PanelId.skills
	assert first.action_id().starts_with('skill:')
	// inspect + install: deep-link panel + real install action
	acts := f.app.palette_reg.actions_for(palette.EntityKind.skill, first.id)
	assert acts.len > 0
	install := acts.filter(it.kind == palette.ActionKind.skill_install)
	assert install.len == 1
	// a not-installed catalog skill must be installable where supported
	assert install[0].available
	assert install[0].entity_id == first.id
}

// workflow: discover + inspect agent
fn test_workflow_agent_discovery() {
	mut f := reach_app('agent')
	defer {
		f.cleanup()
	}
	entries := f.app.palette_reg.all_entries()
	agents := entries.filter(it.kind == palette.EntityKind.agent)
	assert agents.len > 0, 'agents must be discoverable'
	assert agents[0].panel == nav.PanelId.agents
	assert agents[0].action_id().starts_with('agent:')
}

// workflow: discover target; install where supported; enable/disable
fn test_workflow_target_discovery_install_toggle() {
	mut f := reach_app('target')
	defer {
		f.cleanup()
	}
	entries := f.app.palette_reg.all_entries()
	targets := entries.filter(it.kind == palette.EntityKind.target)
	assert targets.len > 0, 'targets must be discoverable'
	first_id := targets[0].id
	acts := f.app.palette_reg.actions_for(palette.EntityKind.target, first_id)
	// both directions exist; availability is mutually exclusive config truth
	enable := acts.filter(it.kind == palette.ActionKind.target_enable)
	disable := acts.filter(it.kind == palette.ActionKind.target_disable)
	assert enable.len == 1 && disable.len == 1
	assert enable[0].available != disable[0].available
	// install action exists; its availability matches engine execution truth
	inst := acts.filter(it.kind == palette.ActionKind.target_install)
	assert inst.len == 1
	assert inst[0].available == f.d.engine_target_install_supported(first_id)
	if !inst[0].available {
		assert inst[0].unavailable_reason.contains('no bundled profile')
	}
}

// workflow: discover MCP provider; enable/disable; probe
fn test_workflow_mcp_discovery_toggle_probe() {
	mut f := reach_app('mcp')
	defer {
		f.cleanup()
	}
	entries := f.app.palette_reg.all_entries()
	providers := entries.filter(it.kind == palette.EntityKind.mcp_provider)
	assert providers.len > 0, 'MCP providers must be discoverable'
	first_id := providers[0].id
	acts := f.app.palette_reg.actions_for(palette.EntityKind.mcp_provider, first_id)
	assert has_action(acts, palette.ActionKind.mcp_enable)
	assert has_action(acts, palette.ActionKind.mcp_disable)
	probe := acts.filter(it.kind == palette.ActionKind.mcp_probe)
	assert probe.len == 1 && probe[0].available
}

// workflow: Doctor preview + repair
fn test_workflow_doctor_preview_repair() {
	mut f := reach_app('doctor')
	defer {
		f.cleanup()
	}
	entries := f.app.palette_reg.all_entries()
	checks := entries.filter(it.kind == palette.EntityKind.doctor_check)
	assert checks.len > 0, 'doctor checks must be discoverable'
	mut found_repair := false
	for c in checks {
		acts := f.app.palette_reg.actions_for(palette.EntityKind.doctor_check, c.id)
		repairs := acts.filter(it.kind == palette.ActionKind.doctor_repair)
		if repairs.len == 1 {
			found_repair = true
			assert repairs[0].needs_preview, 'repair must offer a real preview'
			assert repairs[0].needs_confirm, 'repair is mutating and must confirm'
			if !c.available {
				assert !repairs[0].available
				assert repairs[0].unavailable_reason.contains('not auto-fixable')
			}
		}
	}
	assert found_repair, 'at least one check must expose the repair action'
}

// workflow: run a loop
fn test_workflow_loop_run() {
	mut f := reach_app('loop')
	defer {
		f.cleanup()
	}
	entry := desktop_engine.LoopEntry{
		name: 's4c-reach-loop'
		goal: 'reachability gate'
		tier: .l1
		stage: 'l1'
		cadence: '1d'
		schedule: desktop_engine.cadence_to_cron('1d')
		budget: desktop_engine.LoopBudget{
			max_tokens: 80000
			max_runs_per_day: 1
			max_wall_seconds: 900
		}
		budget_total: 80000
	}
	f.d.loops_catalog() // warm engine
	rev := f.d.engine_upsert_loop(entry) or { panic(err.msg()) }
	assert rev > 0
	acts := f.app.palette_reg.actions_for(palette.EntityKind.loop_template, 's4c-reach-loop')
	assert has_action(acts, palette.ActionKind.loop_run)
	assert has_action(acts, palette.ActionKind.loop_schedule_toggle)
}

// workflow: swarm launch/request
fn test_workflow_swarm_launch() {
	mut f := reach_app('swarm')
	defer {
		f.cleanup()
	}
	acts := f.app.palette_reg.actions_for(palette.EntityKind.navigation, '/swarm')
	launch := acts.filter(it.kind == palette.ActionKind.swarm_launch)
	assert launch.len == 1
	assert launch[0].available
}

// application-level actions: theme, honest update unavailability, uninstall
fn test_workflow_app_level_actions() {
	mut f := reach_app('app')
	defer {
		f.cleanup()
	}
	entries := f.app.palette_reg.all_entries()
	app := entries.filter(it.kind == palette.EntityKind.app)
	assert app.len == 1
	assert app[0].id == 'agent-toolkit'
	acts := f.app.palette_reg.actions_for(palette.EntityKind.app, 'agent-toolkit')
	// theme: real shell action, no confirmation, no evidence machinery
	theme := acts.filter(it.kind == palette.ActionKind.app_theme_cycle)
	assert theme.len == 1 && theme[0].available && !theme[0].needs_confirm
	// update: honestly unavailable with a reason — never a fake check
	upd := acts.filter(it.kind == palette.ActionKind.app_update_check)
	assert upd.len == 1
	assert !upd[0].available
	assert upd[0].unavailable_reason.contains('No update feed/updater')
	// uninstall: destructive — real dry-run preview + explicit confirmation
	un := acts.filter(it.kind == palette.ActionKind.app_uninstall)
	assert un.len == 1
	assert un[0].needs_preview && un[0].needs_confirm
	if un[0].available {
		lines := f.app.palette_reg.preview(palette.ActionKind.app_uninstall, 'agent-toolkit') or {
			panic(err.msg())
		}
		assert lines.len > 0
	}
}
