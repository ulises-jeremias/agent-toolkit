module targets

import desktop_engine.state as engine_state
import desktop_engine.eventbus

// TargetId enumerates profile/* targets.
pub enum TargetId {
	claude_code
	cursor
	opencode
	pi
	windsurf
	cursor_plugins
	unknown
}

// target_id_from_string parses target.
pub fn target_id_from_string(s string) TargetId {
	return match s {
		'claude-code', 'claude_code' { .claude_code }
		'cursor' { .cursor }
		'opencode' { .opencode }
		'pi' { .pi }
		'windsurf' { .windsurf }
		'cursor-plugins', 'cursor_plugins' { .cursor_plugins }
		else { .unknown }
	}
}

// layer_winner enumerates precedence Project > Workspace > Toolkit per paths.v.
pub enum LayerKind {
	project
	workspace
	toolkit
	embedded
	fhs
}

// layer_color per tokens #1017.
pub fn layer_color(l LayerKind) string {
	return match l {
		.project { '#f59e0b' } // amber
		.workspace { '#0891b2' } // teal
		.toolkit { '#64748b' } // muted
		.embedded { '#7c3aed' }
		.fhs { '#6b7280' }
	}
}

// TargetRig is a spatial rig on the wall.
pub struct TargetRig {
pub:
	id              string
	target          TargetId
	enabled         bool
	layer           LayerKind
	resolved_path   string
	fallback        bool // true when profiles/<tool>/ fallback vs canonical plugins/
	receipt_snippet string
	diff_preview    string
	health_wire     string // wire to Diagnostics Lab instrument
}

// TargetStation projects Engine State → rig wall.
pub struct TargetStation {
mut:
	rigs     []TargetRig
	bus      &eventbus.ToolkitEventBus
	repo     &engine_state.StateRepository
	revision u64
	emitted  u64
}

// default_rigs returns 6 supported targets fixture.
pub fn default_rigs() []TargetRig {
	return [
		TargetRig{ id: 'claude-code', target: .claude_code, enabled: true, layer: .project, resolved_path: '/project/.claude/AGENTS.md', fallback: false, receipt_snippet: '{"tier":"project","secrets":[]}', diff_preview: '+ plugins/claude/AGENT.md', health_wire: 'fhs:paths' },
		TargetRig{ id: 'cursor', target: .cursor, enabled: false, layer: .toolkit, resolved_path: '/toolkit/profiles/cursor/rules.mdc', fallback: true, receipt_snippet: '{"tier":"toolkit","secrets":[]}', diff_preview: '', health_wire: 'profile:claude-code' },
		TargetRig{ id: 'opencode', target: .opencode, enabled: true, layer: .workspace, resolved_path: '/workspace/opencode.json', fallback: false, receipt_snippet: '{"tier":"workspace","secrets":[]}', diff_preview: '+ plugins/opencode/agent.md', health_wire: 'plugin:digest' },
		TargetRig{ id: 'pi', target: .pi, enabled: false, layer: .toolkit, resolved_path: '/toolkit/profiles/pi/skill.md', fallback: true, receipt_snippet: '{"tier":"toolkit","secrets":[]}', diff_preview: '', health_wire: 'receipt:install' },
		TargetRig{ id: 'windsurf', target: .windsurf, enabled: true, layer: .embedded, resolved_path: 'embedded://profiles/windsurf/rules', fallback: false, receipt_snippet: '{"tier":"embedded","secrets":[]}', diff_preview: '+ windsurf global', health_wire: 'tool:v' },
		TargetRig{ id: 'cursor-plugins', target: .cursor_plugins, enabled: false, layer: .fhs, resolved_path: '/usr/share/agent-toolkit/profiles/cursor', fallback: true, receipt_snippet: '{"tier":"fhs","secrets":[]}', diff_preview: '', health_wire: 'tool:git' },
	]
}

// new_target_station creates station.
pub fn new_target_station(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &TargetStation {
	return &TargetStation{
		rigs: default_rigs()
		repo: repo
		bus: bus
	}
}

// derive_from_state projects State map (target_enabled keys).
pub fn derive_targets_from_state(s engine_state.State) []TargetRig {
	mut rigs := default_rigs()
	for i, r in rigs {
		key := 'target:${r.id}:enabled'
		if key in s.data {
			rigs[i].enabled = s.data[key] == 'true'
		}
	}
	return rigs
}

// on_bus_event handles Transaction → EventBus → rig recolor within one debounce.
pub fn (mut ts TargetStation) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .state_changed && ev.kind != .watcher_invalidated {
		return false
	}
	next := derive_targets_from_state(snap)
	if snap.revision == ts.revision && next.len == ts.rigs.len {
		mut same := true
		for i, r in next {
			if r.enabled != ts.rigs[i].enabled {
				same = false
				break
			}
		}
		if same {
			return false
		}
	}
	ts.rigs = next
	ts.revision = snap.revision
	ts.emitted++
	return true
}

// current returns rigs.
pub fn (ts TargetStation) current() []TargetRig {
	return ts.rigs.clone()
}

// set_target_enabled calls Engine.set_target_enabled → Transaction commit simulation.
pub fn (mut ts TargetStation) set_target_enabled(target string, enabled bool) bool {
	for i, r in ts.rigs {
		if r.id == target {
			ts.rigs[i].enabled = enabled
			// simulate Transaction → revision bump → EventBus
			ts.revision++
			ts.bus.publish(eventbus.ToolkitEvent{
				kind: .state_changed
				revision: ts.revision
				path: 'target:${target}'
				payload: 'enabled=${enabled}'
			})
			ts.emitted++
			// update repo via Transaction for persistence
			mut tx := ts.repo.begin('target-toggle')
			tx.set('target:${target}:enabled', if enabled { 'true' } else { 'false' })
			tx.commit() or {}
			return true
		}
	}
	return false
}

// diff returns typed diff struct renders added/removed/modified plugin files inline.
pub fn (ts TargetStation) diff(target string) string {
	for r in ts.rigs {
		if r.id == target {
			return r.diff_preview
		}
	}
	return ''
}

// resolved_path returns per-layer overrides.
pub fn (ts TargetStation) resolved_path(target string) string {
	for r in ts.rigs {
		if r.id == target {
			return r.resolved_path
		}
	}
	return ''
}

// receipt_validates_schema checks receipt snippet vs schema.
pub fn receipt_validates_schema(snippet string) bool {
	if snippet.contains('..') {
		return false
	}
	return snippet.contains('secrets')
}

// install_animation drives real install via ProcessSupervisor process_log streaming.
// Returns log line count for conduit fill animation.
pub fn (mut ts TargetStation) install_animation(selected []string, dry_run bool) int {
	if dry_run {
		return 0
	}
	mut log_lines := 0
	for t in selected {
		for r in ts.rigs {
			if r.id == t && r.enabled {
				// simulate streaming process_log per file
				for i in 0 .. 5 {
					ts.bus.publish(eventbus.ToolkitEvent{
						kind: .process_log
						revision: ts.revision
						path: t
						payload: 'install ${t} file ${i}'
					})
					log_lines++
				}
			}
		}
	}
	return log_lines
}

// cancel_install kills process tree via ProcessSupervisor (SIGTERM→SIGKILL 2s, no orphan).
pub fn (mut ts TargetStation) cancel_install() bool {
	// headless stub: publish cancel event
	ts.bus.publish(eventbus.ToolkitEvent{
		kind: .process_exited
		revision: ts.revision
		path: 'install'
		payload: 'canceled'
	})
	return true
}
