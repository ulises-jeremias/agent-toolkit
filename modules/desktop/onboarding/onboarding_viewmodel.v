module onboarding

import desktop_engine
import desktop.theme
import desktop.state as app_state

pub enum OnboardingStep {
	detect
	pick_targets
	install
	seed
	tour
	done
}

pub struct OnboardingViewModel {
mut:
	engine &desktop_engine.Engine
	step   OnboardingStep
	targets []desktop_engine.TargetEntry
	revision u64
}

pub fn new_onboarding_viewmodel(mut engine &desktop_engine.Engine) OnboardingViewModel {
	initial := if engine.is_first_run() { OnboardingStep.detect } else { OnboardingStep.done }
	return OnboardingViewModel{
		engine: engine
		step: initial
		targets: engine.targets()
		revision: engine.revision()
	}
}

pub fn (vm OnboardingViewModel) current_step() OnboardingStep {
	return vm.step
}

pub fn (mut vm OnboardingViewModel) is_first_run() bool {
	return vm.engine.is_first_run()
}

pub fn (mut vm OnboardingViewModel) next() OnboardingStep {
	vm.step = match vm.step {
		.detect { .pick_targets }
		.pick_targets { .install }
		.install { .seed }
		.seed { .tour }
		.tour { .done }
		.done { .done }
	}
	return vm.step
}

pub fn (mut vm OnboardingViewModel) pick_target(target_id string, enabled bool) !u64 {
	rev := vm.engine.set_target_enabled(target_id, enabled)!
	vm.targets = vm.engine.targets()
	return rev
}

pub fn (mut vm OnboardingViewModel) install_selected(selected []string) !u64 {
	rev := vm.engine.install(selected)!
	vm.revision = rev
	return rev
}

pub fn (mut vm OnboardingViewModel) complete() !u64 {
	mut repo := vm.engine.state_repo()
	mut tx := repo.begin('onboarding-complete')
	tx.set('onboarding_completed', 'true')
	rev := vm.engine.put_transaction(mut tx)!
	vm.revision = rev.revision
	vm.step = .done
	return rev.revision
}

pub fn (mut vm OnboardingViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm OnboardingViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
