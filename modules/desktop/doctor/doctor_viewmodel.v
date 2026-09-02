module doctor

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct DoctorViewModel {
mut:
	engine   &desktop_engine.Engine
	checks   []desktop_engine.DoctorCheck
	revision u64
}

pub fn new_doctor_viewmodel(mut engine &desktop_engine.Engine) DoctorViewModel {
	return DoctorViewModel{
		engine: engine
		checks: engine.doctor()
		revision: engine.revision()
	}
}

pub fn (mut vm DoctorViewModel) refresh() {
	vm.checks = vm.engine.doctor()
	vm.revision = vm.engine.revision()
}

pub fn (vm DoctorViewModel) all_checks() []desktop_engine.DoctorCheck {
	return vm.checks.clone()
}

pub fn (mut vm DoctorViewModel) fix(check_id string) !u64 {
	rev := vm.engine.doctor_fix(check_id)!
	vm.refresh()
	return rev
}

pub fn (vm DoctorViewModel) is_healthy() bool {
	for c in vm.checks {
		if c.status != 'pass' {
			return false
		}
	}
	return true
}

pub fn (mut vm DoctorViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

// ── super-potent: categories, fix_all, verify, receipts, provenance ──
pub fn (vm DoctorViewModel) by_category(cat string) []desktop_engine.DoctorCheck {
	mut out := []desktop_engine.DoctorCheck{}
	for c in vm.checks {
		if c.category == cat { out << c }
	}
	return out
}

pub fn (vm DoctorViewModel) categories() []string {
	mut set := map[string]bool{}
	for c in vm.checks {
		set[c.category] = true
	}
	mut out := []string{}
	for k, _ in set {
		out << k
	}
	out.sort()
	return out
}

pub fn (mut vm DoctorViewModel) fix_all() !u64 {
	rev := vm.engine.doctor_fix_all()!
	vm.refresh()
	return rev
}

pub fn (vm DoctorViewModel) verify_receipts() []desktop_engine.BuildDiagnostic {
	return vm.engine.verify_receipts()
}

pub fn (vm DoctorViewModel) verify_provenance() []desktop_engine.BuildDiagnostic {
	return vm.engine.verify_provenance_full()
}

pub fn (vm DoctorViewModel) receipts() []desktop_engine.ReceiptEntry {
	return vm.engine.receipts_catalog()
}

pub fn (vm DoctorViewModel) provenance() []desktop_engine.ProvenanceEntry {
	return vm.engine.provenance_catalog()
}

pub fn (vm DoctorViewModel) stats() map[string]int {
	mut m := map[string]int{}
	for c in vm.checks {
		m[c.status]++
		m[c.category]++
	}
	return m
}

pub fn (vm DoctorViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
