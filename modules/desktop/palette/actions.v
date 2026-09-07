module palette

// S4B (#1119) — contextual actions with typed arguments, validation, preview
// and truthful execution. Every action binds a real typed Engine operation;
// nothing shells out to the CLI. Actions are classified against current code
// before exposure (READY / READY_WITH_ADAPTER / UNAVAILABLE / OUT_OF_SCOPE):
// an action without a real backend seam stays out of the registry.
//
// Outcome semantics: success / failure / partial / unavailable are distinct.
// Evidence fields (revision, job id, run id, receipt path) are populated only
// when the Engine actually produced them — never manufactured.
//
// Governing contracts:
// - docs/desktop/UX_ARCHITECTURE.md §Shared action and entity model
// - docs/desktop/TRUTH_LEDGER.md (S7 gates must stay green)

import desktop_engine
import desktop.nav

// ActionKind enumerates registry-backed contextual operations.
pub enum ActionKind {
	skill_install
	skill_remove
	target_install
	target_enable
	target_disable
	mcp_enable
	mcp_disable
	mcp_probe
	doctor_repair
	loop_run
	loop_schedule_toggle
	swarm_launch
	app_theme_cycle
	app_update_check
	app_uninstall
}

// kind_label returns the human action label used in the palette.
pub fn kind_label(k ActionKind) string {
	return match k {
		.skill_install { 'Install' }
		.skill_remove { 'Remove' }
		.target_install { 'Install profile' }
		.target_enable { 'Enable' }
		.target_disable { 'Disable' }
		.mcp_enable { 'Enable from packaged template' }
		.mcp_disable { 'Disable' }
		.mcp_probe { 'Probe health' }
		.doctor_repair { 'Repair' }
		.loop_run { 'Run now' }
		.loop_schedule_toggle { 'Toggle schedule' }
		.swarm_launch { 'Launch' }
		.app_theme_cycle { 'Change appearance' }
		.app_update_check { 'Check for updates' }
		.app_uninstall { 'Uninstall integrations' }
	}
}

// ActionStatus classifies an outcome truthfully. Partial failure and
// not-confirmed are distinct from plain success/failure.
pub enum ActionStatus {
	succeeded
	failed
	partial
	unavailable
	not_confirmed
}

// ActionArgs are the typed arguments an action accepts — product concepts
// (selection, scope, dry run, confirmation), never CLI flag strings.
@[params]
pub struct ActionArgs {
pub:
	enabled bool // for enable/disable & schedule toggles
	dry_run bool // preview-only execution where the Engine supports one
	confirm bool // explicit confirmation for actions that need one
	targets []string // multi-subject selection (target install)
	task    string // swarm launch task text
	recipe  string // swarm recipe: pair | team | full
	backend string // swarm backend: auto | herdr | tmux
}

// validate checks typed argument constraints; returns a reason on failure.
// Note: single-subject actions fall back to the contextual entity, so an
// empty selection is only invalid when no subject exists at all (enforced
// by execute(), which knows the entity).
pub fn (args ActionArgs) validate(kind ActionKind) ?string {
	return match kind {
		.swarm_launch {
			if args.task.trim_space() == '' {
				'swarm task text is required'
			} else if args.task.len > 4096 {
				'swarm task too long (max 4096)'
			} else if args.recipe != '' && args.recipe !in ['pair', 'team', 'full'] {
				'unknown swarm recipe: ${args.recipe}'
			} else if args.backend != '' && args.backend !in ['auto', 'herdr', 'tmux'] {
				'unknown swarm backend: ${args.backend}'
			} else {
				none
			}
		}
		else {
			none
		}
	}
}

// ActionEvidence carries only evidence that really exists.
pub struct ActionEvidence {
pub:
	revision       u64
	job_id         string
	run_id         string
	receipt_path   string
	artifact_paths []string
}

// ActionOutcome is the truthful result envelope.
pub struct ActionOutcome {
pub:
	status   ActionStatus
	summary  string
	evidence ActionEvidence
}

// is_ok reports whether the outcome represents real success (or accepted
// partial progress — never a fabricated pass).
pub fn (o ActionOutcome) is_ok() bool {
	return o.status in [.succeeded, .partial]
}

// RegistryAction is one contextual action bound to a registry entity.
pub struct RegistryAction {
pub:
	kind        ActionKind
	entity_kind EntityKind
	entity_id   string
	label       string
	category    string
	keywords    string
	desc        string
	// semantics
	needs_preview bool // a truthful dry-run/diff exists
	needs_confirm bool // mutating/destructive: explicit confirmation required
	// availability
	available          bool
	unavailable_reason string
	panel              nav.PanelId
}

// action_id is the stable palette id for the action row.
pub fn (a RegistryAction) action_id() string {
	return 'action:${a.entity_kind}_${a.entity_id}:${a.kind}'
}

// is_valid checks required fields.
pub fn (a RegistryAction) is_valid() bool {
	return a.entity_id != '' && a.label != ''
}

// find_entry locates a registry entry by kind + canonical id (fresh state).
fn (mut r Registry) find_entry(kind EntityKind, id string) ?RegistryEntry {
	for e in r.all_entries() {
		if e.kind == kind && e.id == id {
			return e
		}
	}
	return none
}

// actions_for derives the contextual actions for one registry entity from its
// current truthful state. Unavailable actions are listed with their reason.
pub fn (mut r Registry) actions_for(kind EntityKind, entity_id string) []RegistryAction {
	entry := r.find_entry(kind, entity_id) or {
		return []RegistryAction{}
	}
	mut out := []RegistryAction{}
	match kind {
		.skill {
			installed := r.engine.skills_installed().contains(entity_id)
			out << RegistryAction{
				kind: .skill_install
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.skill_install)
				category: entry.category
				keywords: 'install ${entity_id} skill'
				desc: if installed { 'already installed' } else { 'add to installed selection' }
				needs_preview: true
				needs_confirm: false
				available: !installed
				unavailable_reason: if installed { 'skill is already installed' } else { '' }
				panel: .skills
			}
			out << RegistryAction{
				kind: .skill_remove
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.skill_remove)
				category: entry.category
				keywords: 'remove uninstall ${entity_id} skill'
				desc: 'remove from installed selection (configuration only)'
				needs_preview: true
				needs_confirm: true
				available: installed
				unavailable_reason: if installed { '' } else { 'skill is not installed' }
				panel: .skills
			}
		}
		.target {
			installable := r.engine.target_install_supported(entity_id)
			enabled := r.engine_target_enabled(entity_id)
			out << RegistryAction{
				kind: .target_install
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.target_install)
				category: entry.category
				keywords: 'install profile ${entity_id} target'
				desc: 'write bundled profile + real install receipt'
				needs_preview: true
				needs_confirm: true
				available: installable
				unavailable_reason: if installable {
					''
				} else {
					'no bundled profile installer for this target'
				}
				panel: .targets
			}
			out << RegistryAction{
				kind: .target_enable
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.target_enable)
				category: entry.category
				keywords: 'enable ${entity_id} target'
				desc: 'mark target enabled in configuration'
				needs_confirm: false
				available: !enabled
				unavailable_reason: if enabled { 'target is already enabled' } else { '' }
				panel: .targets
			}
			out << RegistryAction{
				kind: .target_disable
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.target_disable)
				category: entry.category
				keywords: 'disable ${entity_id} target'
				desc: 'mark target disabled in configuration'
				needs_confirm: false
				available: enabled
				unavailable_reason: if enabled { '' } else { 'target is not enabled' }
				panel: .targets
			}
		}
		.mcp_provider {
			enabled := r.engine_mcp_enabled(entity_id)
			out << RegistryAction{
				kind: .mcp_enable
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.mcp_enable)
				category: entry.category
				keywords: 'enable ${entity_id} mcp provider template'
				desc: 'upsert configuration from the packaged template'
				needs_preview: true
				needs_confirm: false
				available: !enabled
				unavailable_reason: if enabled { 'provider is already enabled' } else { '' }
				panel: .mcp
			}
			out << RegistryAction{
				kind: .mcp_disable
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.mcp_disable)
				category: entry.category
				keywords: 'disable ${entity_id} mcp provider'
				desc: 'remove provider configuration (re-enable restores from template)'
				needs_confirm: true
				available: enabled
				unavailable_reason: if enabled { '' } else { 'provider is not enabled' }
				panel: .mcp
			}
			out << RegistryAction{
				kind: .mcp_probe
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.mcp_probe)
				category: entry.category
				keywords: 'probe health ${entity_id} mcp'
				desc: 'validate template + report live health (read-only)'
				needs_confirm: false
				available: true
				panel: .mcp
			}
		}
		.doctor_check {
			out << RegistryAction{
				kind: .doctor_repair
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.doctor_repair)
				category: entry.category
				keywords: 'repair fix ${entity_id} doctor check'
				desc: 'preview the repair, then apply it'
				needs_preview: true
				needs_confirm: true
				available: entry.available
				unavailable_reason: entry.unavailable_reason
				panel: .doctor
			}
		}
		.loop_template {
			out << RegistryAction{
				kind: .loop_run
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.loop_run)
				category: entry.category
				keywords: 'run now ${entity_id} loop'
				desc: 'start a real supervised run (budget gates apply)'
				needs_confirm: false
				available: true
				panel: .loops
			}
			out << RegistryAction{
				kind: .loop_schedule_toggle
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.loop_schedule_toggle)
				category: entry.category
				keywords: 'schedule cron ${entity_id} loop'
				desc: 'enable or disable the cron schedule in configuration'
				needs_confirm: false
				available: true
				panel: .loops
			}
		}
		.navigation {
			if entity_id == '/swarm' {
				out << RegistryAction{
					kind: .swarm_launch
					entity_kind: kind
					entity_id: entity_id
					label: kind_label(.swarm_launch)
					category: 'Swarm'
					keywords: 'launch swarm pair team full request'
					desc: 'record a swarm launch request (task text required)'
					needs_confirm: true
					available: true
					panel: .swarm
				}
			}
		}
		.app {
			// application-level actions (S4C): one coherent app entity, no
			// legacy command rows
			out << RegistryAction{
				kind: .app_theme_cycle
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.app_theme_cycle)
				category: entry.category
				keywords: 'theme appearance cycle paper ink system light dark'
				desc: 'cycle Paper → Ink → System'
				needs_confirm: false
				available: true
				panel: .onboarding
			}
			out << RegistryAction{
				kind: .app_update_check
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.app_update_check)
				category: entry.category
				keywords: 'update upgrade check version feed'
				desc: 'self-update'
				needs_confirm: false
				available: false
				unavailable_reason: 'No update feed/updater is available yet'
				panel: .onboarding
			}
			candidates := r.engine.uninstall_candidates()
			out << RegistryAction{
				kind: .app_uninstall
				entity_kind: kind
				entity_id: entity_id
				label: kind_label(.app_uninstall)
				category: entry.category
				keywords: 'uninstall remove integrations profiles receipts'
				desc: 'remove toolkit-owned files from install receipts (dry-run first)'
				needs_preview: true
				needs_confirm: true
				available: candidates.len > 0
				unavailable_reason: if candidates.len > 0 {
					''
				} else {
					'no install receipts found — nothing to uninstall'
				}
				panel: .onboarding
			}
		}
		else {}
	}
	return out
}

// engine_target_enabled reads the target's real enabled state (configuration
// truth — never inferred from display strings).
fn (mut r Registry) engine_target_enabled(target_id string) bool {
	for t in r.engine.targets() {
		if t.id == target_id {
			return t.enabled
		}
	}
	return false
}

// engine_mcp_enabled reads the provider's real enabled state.
fn (mut r Registry) engine_mcp_enabled(provider_id string) bool {
	for p in r.engine.mcp_catalog() {
		if p.id == provider_id {
			return p.enabled
		}
	}
	return false
}

// preview returns truthful expected effects WITHOUT mutating state, using
// real Engine dry-run/diff operations. Errors are honest (no invented text).
pub fn (mut r Registry) preview(action ActionKind, entity_id string) ![]string {
	match action {
		.skill_install {
			d := r.engine.install_skill_preview(entity_id)
			return target_diff_lines(d, 'install')
		}
		.skill_remove {
			d := r.engine.install_skill_preview(entity_id)
			return target_diff_lines(d, 'remove')
		}
		.target_install {
			d := r.engine.install_preview([entity_id])
			return target_diff_lines(d, 'install profile')
		}
		.mcp_enable {
			pv := r.engine.mcp_install_preview(entity_id)
			if pv.will_write.len == 0 && pv.will_update.len == 0 {
				return error('no packaged template for ${entity_id} — nothing to write')
			}
			mut lines := []string{}
			for p in pv.will_write {
				lines << 'write: ${p}'
			}
			for p in pv.will_update {
				lines << 'update: ${p}'
			}
			if pv.receipt_path != '' {
				lines << 'receipt: ${pv.receipt_path}'
			}
			return lines
		}
		.doctor_repair {
			return r.engine.doctor_fix_preview(entity_id)!
		}
		.app_uninstall {
			// real dry-run preview: the exact files the uninstall would
			// remove, computed by the core domain operation — nothing written
			rep := r.engine.uninstall_targets([], true)
			mut lines := []string{}
			for line in rep.message.split_into_lines() {
				if line.trim_space() != '' {
					lines << line.trim_space()
				}
			}
			if lines.len == 0 {
				return error('uninstall preview unavailable — no receipts')
			}
			return lines
		}
		else {
			return error('preview unavailable for this action')
		}
	}
}

// target_diff_lines renders an Engine TargetDiff as truthful preview lines.
fn target_diff_lines(d desktop_engine.TargetDiff, verb string) []string {
	mut lines := []string{}
	if d.added.len == 0 && d.removed.len == 0 && d.modified.len == 0 {
		lines << '${verb}: no configuration changes expected'
		return lines
	}
	for a in d.added {
		lines << '${verb}: add ${a}'
	}
	for rm in d.removed {
		lines << '${verb}: remove ${rm}'
	}
	for m in d.modified {
		if verb == 'remove' {
			lines << 'remove: ${m} is installed — it will be removed from the selection'
		} else {
			lines << '${verb}: ${m} is already present — no change'
		}
	}
	return lines
}

// execute validates typed args, runs the real Engine operation, and maps the
// result to a truthful outcome. Failures surface as errors/failures — never
// as fabricated success.
pub fn (mut r Registry) execute(kind EntityKind, entity_id string, action ActionKind, args ActionArgs) !ActionOutcome {
	// typed argument validation first
	if reason := args.validate(action) {
		return ActionOutcome{
			status: .failed
			summary: reason
		}
	}
	// availability must hold at execution time (state may have moved)
	acts := r.actions_for(kind, entity_id)
	mut act := RegistryAction{}
	mut found := false
	for a in acts {
		if a.kind == action {
			act = a
			found = true
			break
		}
	}
	if !found {
		return ActionOutcome{
			status: .unavailable
			summary: 'no such action for this entity'
		}
	}
	if !act.available {
		return ActionOutcome{
			status: .unavailable
			summary: act.unavailable_reason
		}
	}
	if act.needs_confirm && !args.confirm {
		// dry_run may bypass confirmation ONLY where a real dry-run seam
		// exists (target install). Preview methods elsewhere are separate
		// read-only calls — args.dry_run must never turn a mutating action
		// into an unconfirmed mutation.
		dry_ok := action == .target_install && args.dry_run
		if !dry_ok {
			return ActionOutcome{
				status: .not_confirmed
				summary: 'confirmation required — review the preview, then confirm'
			}
		}
	}
	// multi-subject install needs at least the contextual entity as subject
	if action == .target_install && args.targets.len == 0 && entity_id == '' {
		return ActionOutcome{
			status: .failed
			summary: 'no targets selected'
		}
	}
	// ── ACTUAL EXECUTION SEAM STARTS HERE ──────────────────────────────────
	// S4D recording boundary: the journal records only what crosses this
	// line (succeeded / partial / failed). Validation failures,
	// unavailable, not-confirmed and preview paths above never record.
	// The undo's PREVIOUS state is captured here — strictly before the
	// seam mutates anything; the expected post-state is finalized from the
	// real Engine after the seam ran.
	label := '${kind_label(action)} — ${entity_id}'
	prev := r.capture_undo(action, entity_id)
	// read-only probes and dry-run executions are not state-changing
	// executions — they are previews by proxy and never enter the journal
	record := action != .mcp_probe && action != .app_theme_cycle && !args.dry_run
	out := r.execute_seam(kind, entity_id, action, args) or {
		failed := ActionOutcome{
			status: .failed
			summary: err.msg()
		}
		if record {
			r.journal_execution(action, kind, entity_id, label, failed, prev)
		}
		return failed
	}
	if record {
		r.journal_execution(action, kind, entity_id, label, out, prev)
	}
	return out
}

// execute_seam performs the Engine operation for a validated, available,
// confirmed action.
fn (mut r Registry) execute_seam(kind EntityKind, entity_id string, action ActionKind, args ActionArgs) !ActionOutcome {
	match action {
		.skill_install {
			rev := r.engine.install_skill(entity_id) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'installed ${entity_id} (configuration selection)'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.skill_remove {
			rev := r.engine.remove_skill(entity_id) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'removed ${entity_id} from installed selection'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.target_install {
			opts := desktop_engine.InstallOptionsEngine{
				targets: if args.targets.len > 0 { args.targets } else { [entity_id] }
				dry_run: args.dry_run
				force: false
				home_dir: r.install_home_dir
				receipt_dir: r.install_receipt_dir
			}
			rev := r.engine.install_with_options(opts) or {
				// partial install commits configuration but reports remaining
				// failures — a distinct, honest outcome
				if err.msg().contains('partial install') {
					return ActionOutcome{
						status: .partial
						summary: err.msg()
						evidence: ActionEvidence{
							revision: r.engine.revision()
						}
					}
				}
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			if args.dry_run {
				return ActionOutcome{
					status: .succeeded
					summary: 'dry-run complete — nothing was written'
					evidence: ActionEvidence{
						revision: 0
					}
				}
			}
			// Receipt lookup only when no test injection is active: injected
			// receipts live outside the real config authority, and state
			// bookkeeping is never surfaced as a receipt.
			if r.install_home_dir == '' && r.install_receipt_dir == '' {
				for rc in r.engine.list_install_receipts() {
					if rc.target == entity_id {
						return ActionOutcome{
							status: .succeeded
							summary: 'installed ${entity_id} profile'
							evidence: ActionEvidence{
								revision: rev
								receipt_path: rc.receipt_path
								artifact_paths: rc.artifacts
							}
						}
					}
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'installed ${entity_id} profile (receipt not listed)'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.target_enable {
			rev := r.engine.set_target_enabled(entity_id, true) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'enabled ${entity_id}'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.target_disable {
			rev := r.engine.set_target_enabled(entity_id, false) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'disabled ${entity_id}'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.mcp_enable {
			rev := r.engine.mcp_toggle(entity_id) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'enabled ${entity_id} from packaged template'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.mcp_disable {
			rev := r.engine.mcp_toggle(entity_id) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'disabled ${entity_id} — configuration removed'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.mcp_probe {
			res := r.engine.mcp_probe(entity_id) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: res.detail
				evidence: ActionEvidence{}
			}
		}
		.doctor_repair {
			rev := r.engine.doctor_fix(entity_id) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'repair applied for ${entity_id}'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.loop_run {
			job_id := r.engine.run_loop(entity_id) or {
				// real gate failures (budget exhausted, deleted, not found)
				// are honest action failures — never fake success
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'run started for ${entity_id}'
				evidence: ActionEvidence{
					job_id: job_id
				}
			}
		}
		.loop_schedule_toggle {
			// one-click schedule toggle: read the real cron state and flip it
			// (configuration truth), like the other Engine toggles
			mut target_enabled := true
			for l in r.engine.loops_catalog() {
				if l.name == entity_id {
					target_enabled = !l.cron_enabled
					break
				}
			}
			rev := r.engine.toggle_loop_cron(entity_id, target_enabled) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			return ActionOutcome{
				status: .succeeded
				summary: 'schedule ${if target_enabled { 'enabled' } else { 'disabled' }} for ${entity_id}'
				evidence: ActionEvidence{
					revision: rev
				}
			}
		}
		.swarm_launch {
			recipe := if args.recipe == '' { 'pair' } else { args.recipe }
			backend := if args.backend == '' { 'auto' } else { args.backend }
			run_id := r.engine.swarm_launch(desktop_engine.SwarmLaunchArgs{
				recipe: desktop_engine.swarm_recipe_from_string(recipe)
				backend: desktop_engine.swarm_backend_from_string(backend)
				task: args.task
			}) or {
				return ActionOutcome{
					status: .failed
					summary: err.msg()
				}
			}
			// The engine records the launch request; workers are not proven
			// running here — the summary must say exactly that.
			return ActionOutcome{
				status: .succeeded
				summary: 'swarm ${recipe} launch requested (${backend}) — not yet running'
				evidence: ActionEvidence{
					run_id: run_id
				}
			}
		}
		.app_theme_cycle {
			// appearance is a real shell preference action; the shell executes
			// it directly — the registry exposes it but never fakes a domain
			// result for it
			return error('appearance is executed by the shell')
		}
		.app_update_check {
			// there is no updater: this stays unreachable (availability is
			// false) and never fakes a check result
			return ActionOutcome{
				status: .unavailable
				summary: 'No update feed/updater is available yet'
			}
		}
		.app_uninstall {
			rep := r.engine.uninstall_targets(args.targets, args.dry_run)
			if args.dry_run {
				return ActionOutcome{
					status: .succeeded
					summary: 'dry-run complete — nothing was deleted'
				}
			}
			summary := 'uninstalled ${rep.files_removed} owned file(s) across ${rep.tools_processed} target(s)${if rep.skipped > 0 {
				' · ${rep.skipped} skipped (user-owned/merged or absent)'
			} else {
				''
			}}'
			if rep.ok {
				return ActionOutcome{
					status: .succeeded
					summary: summary
				}
			}
			if rep.files_removed > 0 {
				// partial: some owned files were removed, some targets failed
				return ActionOutcome{
					status: .partial
					summary: '${summary} — failed: ${rep.failures.join(', ')}'
				}
			}
			return ActionOutcome{
				status: .failed
				summary: rep.message
			}
		}
	}
}
