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
	engine       &desktop_engine.Engine
	step         OnboardingStep
	targets      []desktop_engine.TargetEntry
	harness_root string
	revision     u64
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

// ── Super-potent onboarding: capability/target/product/workspace/persona in one wizard ──
// All via Engine typed APIs (no shell, every mutation is a Transaction → EventBus → AppState).
pub fn (mut vm OnboardingViewModel) set_harness_root(path string) {
	vm.harness_root = path
}

pub fn (vm OnboardingViewModel) harness_root_path() string {
	return vm.harness_root
}

pub fn (mut vm OnboardingViewModel) status() desktop_engine.OnboardingStatus {
	return vm.engine.onboarding_status(vm.harness_root)
}

pub fn (mut vm OnboardingViewModel) ensure_workspace(target string) !u64 {
	rev := vm.engine.onboarding_ensure_workspace(target)!
	vm.revision = rev
	vm.harness_root = target
	return rev
}

pub fn (mut vm OnboardingViewModel) init_workspace_with_templates(target string, with_personas bool) !u64 {
	rev := vm.engine.workspace_init_with_templates(target, with_personas)!
	vm.revision = rev
	vm.harness_root = target
	return rev
}

pub fn (mut vm OnboardingViewModel) ensure_personas() !u64 {
	root := if vm.harness_root != '' {
		vm.harness_root
	} else {
		vm.engine.onboarding_status('').harness_root
	}
	rev := vm.engine.onboarding_ensure_personas(root)!
	vm.revision = rev
	return rev
}

pub fn (mut vm OnboardingViewModel) bootstrap_personas() !u64 {
	return vm.ensure_personas()
}

pub fn (mut vm OnboardingViewModel) bulk_install_skills(ids []string) !u64 {
	rev := vm.engine.onboarding_bulk_install_skills(ids)!
	vm.revision = rev
	return rev
}

pub fn (mut vm OnboardingViewModel) bulk_remove_skills(ids []string) !u64 {
	rev := vm.engine.onboarding_bulk_remove_skills(ids)!
	vm.revision = rev
	return rev
}

pub fn (mut vm OnboardingViewModel) install_skills_bulk(ids []string) !u64 {
	return vm.bulk_install_skills(ids)
}

pub fn (mut vm OnboardingViewModel) set_targets_bulk(ids []string) !u64 {
	rev := vm.engine.onboarding_set_targets_bulk(ids)!
	vm.targets = vm.engine.targets()
	vm.revision = rev
	return rev
}

pub fn (mut vm OnboardingViewModel) set_products_bulk(ids []string) !u64 {
	rev := vm.engine.onboarding_set_products_bulk(ids)!
	vm.revision = rev
	return rev
}

pub fn (mut vm OnboardingViewModel) complete_with_harness() !u64 {
	rev := vm.engine.onboarding_complete(vm.harness_root)!
	vm.revision = rev
	vm.step = .done
	return rev
}

pub fn (mut vm OnboardingViewModel) reset_onboarding() !u64 {
	rev := vm.engine.onboarding_reset()!
	vm.revision = rev
	vm.step = .detect
	return rev
}

pub fn (vm OnboardingViewModel) pending_items() []string {
	return vm.engine.onboarding_status(vm.harness_root).pending_items
}

pub fn (vm OnboardingViewModel) is_workspace_ready() bool {
	return vm.engine.onboarding_status(vm.harness_root).workspace_ready
}

pub fn (vm OnboardingViewModel) is_capability_ready() bool {
	return vm.engine.onboarding_status(vm.harness_root).capability_ready
}

pub fn (vm OnboardingViewModel) is_persona_ready() bool {
	return vm.engine.onboarding_status(vm.harness_root).persona_ready
}

pub fn (mut vm OnboardingViewModel) next_super() OnboardingStep {
	st := vm.engine.onboarding_status(vm.harness_root)
	// super-potent: auto-skip completed gaps
	if !st.workspace_ready {
		vm.step = .detect
		return vm.step
	}
	if !st.capability_ready {
		vm.step = .pick_targets
		return vm.step
	}
	if !st.persona_ready {
		vm.step = .seed
		return vm.step
	}
	return vm.next()
}

pub fn (mut vm OnboardingViewModel) refresh() {
	vm.targets = vm.engine.targets()
	vm.revision = vm.engine.revision()
}

pub fn (mut vm OnboardingViewModel) on_bus_event(revision u64) bool {
	if revision == vm.revision {
		return false
	}
	vm.refresh()
	return true
}

pub fn (mut vm OnboardingViewModel) app_state_projection() app_state.AppState {
	snap := vm.engine.snapshot()
	return app_state.derive_app_state(snap)
}

pub fn (vm OnboardingViewModel) theme_tokens(t theme.Theme) theme.Theme {
	return t
}
