module doctor

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub struct DoctorViewModel {
mut:
	engine &desktop_engine.Engine
	checks []desktop_engine.DoctorCheck
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

pub fn (vm DoctorViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
