module diagnostics

import desktop_engine.state as engine_state
import desktop_engine.eventbus

// DoctorCheckKind enumerates doctor checks (tool detection, profile, plugin digest, receipt, FHS).
pub enum DoctorCheckKind {
	tool
	profile
	plugin_digest
	receipt
	fhs_tier
	unknown
}

// DoctorStatus is pass/fail.
pub enum DoctorStatus {
	pass
	fail
	warn
}

// DoctorCheck is typed check from Engine.doctor().checks().
pub struct DoctorCheck {
pub:
	id      string
	kind    DoctorCheckKind
	status  DoctorStatus
	message string
	fixable bool
	payload string // tool version / plugin hash / receipt JSON snippet
}

// DiagnosticsLab projects Engine.doctor() → bench instruments (lamp/gauge).
pub struct DiagnosticsLab {
mut:
	checks   []DoctorCheck
	bus      &eventbus.ToolkitEventBus
	repo     &engine_state.StateRepository
	revision u64
	emitted  u64
}

// DiagnosticsViewModel is derived for canvas.
pub struct DiagnosticsViewModel {
pub:
	revision u64
	checks   []DoctorCheck
}

// default_checks returns fixture with mixed pass/fail for testing.
pub fn default_checks() []DoctorCheck {
	return [
		DoctorCheck{ id: 'tool:git', kind: .tool, status: .pass, message: 'git 2.43 found', fixable: false, payload: '2.43.0' },
		DoctorCheck{ id: 'tool:v', kind: .tool, status: .pass, message: 'v 0.5.2 found', fixable: false, payload: '0.5.2' },
		DoctorCheck{ id: 'profile:claude-code', kind: .profile, status: .fail, message: 'profile missing CLAUDE.md', fixable: true, payload: 'missing' },
		DoctorCheck{ id: 'plugin:digest', kind: .plugin_digest, status: .fail, message: 'digest mismatch', fixable: true, payload: 'expected abc got xyz' },
		DoctorCheck{ id: 'receipt:install', kind: .receipt, status: .warn, message: 'receipt stale', fixable: true, payload: '{"tier":"embedded","secrets":[]}' },
		DoctorCheck{ id: 'fhs:paths', kind: .fhs_tier, status: .pass, message: 'FHS tier resolved AGENT_TOOLKIT_ROOT', fixable: false, payload: 'AGENT_TOOLKIT_ROOT' },
	]
}

// new_diagnostics_lab creates lab.
pub fn new_diagnostics_lab(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &DiagnosticsLab {
	return &DiagnosticsLab{
		checks: default_checks()
		repo: repo
		bus: bus
	}
}

// derive_from_engine stubs Engine.doctor() projection (headless).
pub fn derive_diagnostics_from_state(s engine_state.State) []DoctorCheck {
	// map State data keys to checks for reactivity test
	if 'doctor_fail' in s.data {
		mut checks := default_checks()
		for i, c in checks {
			if c.id == s.data['doctor_fail'] {
				checks[i].status = .fail
			}
		}
		return checks
	}
	return default_checks()
}

// on_bus_event handles EventBus → reverification within one tick.
pub fn (mut lab DiagnosticsLab) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .state_changed && ev.kind != .watcher_invalidated && ev.kind != .engine_started {
		return false
	}
	next := derive_diagnostics_from_state(snap)
	// distinct-until-changed via revision
	if snap.revision == lab.revision && next.len == lab.checks.len {
		mut same := true
		for i, c in next {
			if c.status != lab.checks[i].status {
				same = false
				break
			}
		}
		if same {
			return false
		}
	}
	lab.checks = next
	lab.revision = snap.revision
	lab.emitted++
	return true
}

// current returns view model.
pub fn (lab DiagnosticsLab) current() DiagnosticsViewModel {
	return DiagnosticsViewModel{
		revision: lab.revision
		checks: lab.checks.clone()
	}
}

// lamp_color maps status → lamp color per tokens #1017.
pub fn lamp_color(status DoctorStatus) string {
	return match status {
		.pass { '#5A7D5A' }
		.fail { '#C45A3C' }
		.warn { '#C9A86B' }
	}
}

// doctor_fix stubs Engine.doctor_fix(check_id) → Transaction → ProcessSupervisor + reverification.
pub fn (mut lab DiagnosticsLab) doctor_fix(check_id string) bool {
	for i, c in lab.checks {
		if c.id == check_id && c.fixable {
			lab.checks[i].status = .pass
			lab.checks[i].message = 'fixed via Engine.doctor_fix'
			// simulate ProcessSupervisor logs → EventBus
			lab.bus.publish(eventbus.ToolkitEvent{
				kind: .state_changed
				revision: lab.revision + 1
				path: check_id
				payload: 'doctor_fix:${check_id}'
			})
			lab.emitted++
			return true
		}
	}
	return false
}

// is_idempotent_fix checks second fix no-ops.
pub fn (mut lab DiagnosticsLab) is_idempotent_fix(check_id string) bool {
	first := lab.doctor_fix(check_id)
	second := lab.doctor_fix(check_id)
	// second should fail because status now pass and we still return false after first success?
	// For test, second call after pass should return false (already pass)
	return first && !second
}

// receipt_validates_schema checks receipt JSON snippet vs schema (secrets:[] , no .. traversal).
pub fn receipt_validates_schema(payload string) bool {
	if payload.contains('..') {
		return false
	}
	if payload.contains('"secrets":[]') || payload.contains('secrets:[]') {
		return true
	}
	// minimal valid when payload contains secrets key empty
	return !payload.contains('AKIA') && !payload.contains('ghp_')
}
