module desktop_engine

import os
import time
import x.json2
import agent_toolkit_core

// TargetEntry is the Engine projection of a supported target from the
// canonical registry (capabilities/targets/registry.yaml). enabled is
// explicit configuration truth (never a default); detected is a real system
// detection; receipt is real install evidence.
pub struct TargetEntry {
pub:
	id         string
	name       string
	enabled    bool
	layer      string // registry capability tier
	path       string // bundled profiles/<id>/ when shipped, else ''
	status     string // enabled | detected | available
	receipt    string // real receipt path when one exists, else ''
	provenance string // bundled profiles source when shipped, else ''
	detected   bool
}

// TargetDiff mirrors diff preview typed struct.
pub struct TargetDiff {
pub:
	added    []string
	removed  []string
	modified []string
}

// InstallOptions mirrors core InstallOptions for Engine-owned install flow
// (headless, no shell). home_dir/receipt_dir exist for test injection; the
// defaults target the real user home and config authority.
pub struct InstallOptionsEngine {
pub:
	targets     []string
	dry_run     bool
	force       bool
	receipt_dir string
	home_dir    string // '' → real user home
}

// InstallReceiptInfo mirrors core InstallReceipt for desktop management.
pub struct InstallReceiptInfo {
pub:
	target          string
	product         string
	version         string
	installed_at    string
	source_digest   string
	artifacts       []string
	receipt_path    string
	provenance_path string
}

// TargetRegistryEntry is one parsed row of the canonical target registry.
pub struct TargetRegistryEntry {
pub mut:
	id           string
	display_name string
	tier         string
	maturity     string
}

// targets_registry parses the canonical target registry
// (capabilities/targets/registry.yaml) through the tier-aware data reader.
// This is the single source for supported targets — the Engine maintains no
// private roster.
pub fn (mut e Engine) targets_registry() []TargetRegistryEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	mut out := []TargetRegistryEntry{}
	txt := data_file_read(env, 'capabilities/targets/registry.yaml') or { return out }
	mut cur := TargetRegistryEntry{}
	mut in_targets := false
	for line in txt.split_into_lines() {
		t := line.trim_space()
		if t == 'targets:' {
			in_targets = true
			continue
		}
		if !in_targets {
			continue
		}
		if t.starts_with('- id:') {
			if cur.id != '' {
				out << cur
			}
			cur = TargetRegistryEntry{ id: t.all_after('- id:').trim_space() }
			continue
		}
		if cur.id == '' {
			continue
		}
		if t.starts_with('display_name:') {
			cur.display_name = t.all_after('display_name:').trim_space()
		} else if t.starts_with('tier:') {
			cur.tier = t.all_after('tier:').trim_space()
		} else if t.starts_with('maturity:') {
			cur.maturity = t.all_after('maturity:').trim_space()
		}
	}
	if cur.id != '' {
		out << cur
	}
	return out
}

// target_detected performs a real system detection using the same signals as
// the core installer: the tool's config directory under the user home or the
// tool executable on PATH. No detection is fabricated — unknown targets are
// simply not detected.
pub fn target_detected(id string) bool {
	home := os.home_dir()
	mut on_path := ''
	match id {
		'claude-code' {
			on_path = os.find_abs_path_of_executable('claude') or { '' }
			return os.exists(os.join_path(home, '.claude')) || on_path != ''
		}
		'cursor' {
			on_path = os.find_abs_path_of_executable('cursor') or { '' }
			return os.exists(os.join_path(home, '.cursor')) || on_path != ''
		}
		'opencode' {
			on_path = os.find_abs_path_of_executable('opencode') or { '' }
			return os.exists(os.join_path(home, '.config', 'opencode')) || on_path != ''
		}
		'gemini-cli' {
			on_path = os.find_abs_path_of_executable('gemini') or { '' }
			return os.exists(os.join_path(home, '.gemini')) || on_path != ''
		}
		'copilot-cli' {
			on_path = os.find_abs_path_of_executable('copilot') or { '' }
			return os.exists(os.join_path(home, '.config', 'github-copilot')) || on_path != ''
		}
		'pi' {
			on_path = os.find_abs_path_of_executable('pi') or { '' }
			return on_path != ''
		}
		'windsurf' {
			on_path = os.find_abs_path_of_executable('windsurf') or { '' }
			return os.exists(os.join_path(home, '.codeium')) || on_path != ''
		}
		'codex' {
			on_path = os.find_abs_path_of_executable('codex') or { '' }
			return os.exists(os.join_path(home, '.codex')) || on_path != ''
		}
		'muse-code' {
			on_path = os.find_abs_path_of_executable('muse') or { '' }
			return os.exists(os.join_path(home, '.config', 'muse')) || on_path != ''
		}
		else {
			// copilot-repository is per-project; agent-plugins is a portable
			// format — neither has a user-level runtime to detect.
			return false
		}
	}
}

// targets returns the supported-target catalog derived from the canonical
// registry. enabled comes only from explicit configuration state; a fresh
// environment enables nothing by default.
pub fn (mut e Engine) targets() []TargetEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	snap := e.repo.snapshot()
	mut out := []TargetEntry{}
	for r in e.targets_registry() {
		enabled := snap.data['target:${r.id}:enabled'] == 'true'
		detected := target_detected(r.id)
		// canonical bundled profile dir (profiles/copilot serves copilot-cli)
		profiles_rel := 'profiles/${install_tool_name(r.id)}'
		path := if data_dir_exists(env, profiles_rel) { profiles_rel } else { '' }
		mut receipt := ''
		if rr := agent_toolkit_core.load_install_receipt(install_tool_name(r.id), agent_toolkit_core.profiles_product, '') {
			receipt = os.join_path(agent_toolkit_core.default_receipt_dir(), agent_toolkit_core.receipt_filename(rr.target, rr.product))
		}
		status := if enabled { 'enabled' } else if detected { 'detected' } else { 'available' }
		out << TargetEntry{
			id: r.id
			name: if r.display_name != '' { r.display_name } else { r.id }
			enabled: enabled
			layer: if r.tier != '' { 'tier ${r.tier}' } else { 'registry' }
			path: path
			status: status
			receipt: receipt
			provenance: path
			detected: detected
		}
	}
	return out
}

pub fn (mut e Engine) set_target_enabled(target_id string, enabled bool) !u64 {
	if target_id == '' {
		return error('target id empty')
	}
	supported := e.targets_registry().map(it.id)
	if target_id !in supported {
		return error('unsupported target: ${target_id}')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('set-target')
	tx.set('target:${target_id}:enabled', if enabled { 'true' } else { 'false' })
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// toggle_target is one-click enable/disable — easy management.
pub fn (mut e Engine) toggle_target(target_id string) !u64 {
	for t in e.targets() {
		if t.id == target_id {
			return e.set_target_enabled(target_id, !t.enabled)!
		}
	}
	return error('target not found: ${target_id}')
}

pub fn (mut e Engine) diff(before []string, after []string) TargetDiff {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut added := []string{}
	mut removed := []string{}
	for a in after {
		if a !in before {
			added << a
		}
	}
	for b in before {
		if b !in after {
			removed << b
		}
	}
	return TargetDiff{
		added: added
		removed: removed
		modified: []string{}
	}
}

// install_preview returns dry-run diff without writing — super-potent preview.
pub fn (mut e Engine) install_preview(targets []string) TargetDiff {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut before := []string{}
	for t in e.targets() {
		if t.enabled { before << t.id }
	}
	mut after := before.clone()
	for tgt in targets {
		if tgt !in after { after << tgt }
	}
	return e.diff(before, after)
}

// install_dry_run returns the canonical core installer's real dry-run
// preview for these targets. Nothing is written and no receipt is claimed.
pub fn (mut e Engine) install_dry_run(targets []string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	report := agent_toolkit_core.run_install(agent_toolkit_core.InstallOptions{
		tools: targets
		dry_run: true
		home_dir: os.home_dir()
	})
	return report.message
}

// install performs a REAL profile installation through the canonical core
// installer: profile files are deployed to the selected tools' config
// locations and real receipts are written under the user config authority.
// Configuration state records what actually installed; partial failures are
// reported accurately. No install state is fabricated.
pub fn (mut e Engine) install(targets []string) !u64 {
	return e.install_with_options(InstallOptionsEngine{
		targets: targets
	})
}

// install_tool_name maps a registry target id to the core installer tool
// name where they differ. The bundled profile directory name is canonical
// (profiles/copilot serves the copilot-cli registry entry).
fn install_tool_name(id string) string {
	return match id {
		'copilot-cli' { 'copilot' }
		else { id }
	}
}

// install_with_options is the full Engine install flow: canonical core
// run_install with dry-run/force/receipt-dir/home injection, then a
// configuration transaction for the targets that actually installed.
pub fn (mut e Engine) install_with_options(opts InstallOptionsEngine) !u64 {
	if opts.targets.len == 0 {
		return error('no targets selected')
	}
	supported := e.targets_registry().map(it.id)
	mut installable := []string{}
	for t in e.targets() {
		if t.path != '' && install_tool_name(t.id) in agent_toolkit_core.install_valid_tools {
			installable << t.id
		}
	}
	for t in opts.targets {
		if t !in supported {
			return error('unsupported target: ${t}')
		}
		if t !in installable {
			return error('no bundled profile installer for ${t} — compiler targets are built via the CLI')
		}
	}
	home := if opts.home_dir != '' { opts.home_dir } else { os.home_dir() }
	report := agent_toolkit_core.run_install(agent_toolkit_core.InstallOptions{
		tools: opts.targets.map(install_tool_name(it))
		dry_run: opts.dry_run
		force: opts.force
		receipt_dir: opts.receipt_dir
		home_dir: home
	})
	if opts.dry_run {
		// a real preview was computed and nothing was written
		return 0
	}
	installed := opts.targets.filter(install_tool_name(it) !in report.failures)
	if installed.len == 0 {
		return error('install failed: ${report.failures.join(', ')}')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('install')
	tx.set('install:targets', installed.join(','))
	for t in installed {
		tx.set('target:${t}:enabled', 'true')
	}
	rev := e.put_transaction(mut tx)!
	if report.failures.len > 0 {
		// partial success: configuration recorded, remaining failures reported
		return error('partial install: failed ${report.failures.join(', ')}')
	}
	return rev.revision
}

// list_install_receipts returns real install receipts from the user config
// authority. State bookkeeping is never surfaced as a receipt.
pub fn (mut e Engine) list_install_receipts() []InstallReceiptInfo {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut out := []InstallReceiptInfo{}
	for r in agent_toolkit_core.list_install_receipts('') {
		out << InstallReceiptInfo{
			target: r.target
			product: r.product
			version: r.version
			installed_at: r.installed_at
			source_digest: r.source_digest
			artifacts: r.artifacts.map(it.path)
			receipt_path: os.join_path(agent_toolkit_core.default_receipt_dir(), agent_toolkit_core.receipt_filename(r.target, r.product))
			provenance_path: ''
		}
	}
	return out
}

// verify_install_receipts checks real receipts for artifact drift (Doctor
// parity). A receipt whose artifact is missing from disk is reported.
pub fn (mut e Engine) verify_install_receipts() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	for r in e.list_install_receipts() {
		for a in r.artifacts {
			if agent_toolkit_core.receipt_artifact_digest(a) == 'missing' {
				diags << BuildDiagnostic{
					path: a
					message: 'receipt artifact missing for ${r.target}'
					code: 'artifact_missing'
				}
			}
		}
	}
	return diags
}

// install_receipt_json returns the real recorded receipt for a target, or an
// honest not-found payload. No receipt is synthesized.
pub fn (mut e Engine) install_receipt_json(target_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if r := agent_toolkit_core.load_install_receipt(target_id, agent_toolkit_core.profiles_product, '') {
		return json2.encode({
			'schemaVersion': '1'
			'product':       r.product
			'target':        r.target
			'scope':         r.scope
			'version':       r.version
			'installedAt':   r.installed_at
			'sourceDigest':  r.source_digest
			'provenance':    ''
		},
			escape_unicode: true
		)
	}
	return json2.encode({
		'error': 'no install receipt recorded for ${target_id}'
	},
		escape_unicode: true
	)
}

pub fn (mut e Engine) is_first_run() bool {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	val := e.repo.snapshot().data['onboarding_completed'] or { '' }
	return val != 'true'
}

// complete_onboarding marks first run complete via transaction.
pub fn (mut e Engine) complete_onboarding() !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('onboarding')
	tx.set('onboarding_completed', 'true')
	tx.set('onboarding_at', time.now().str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

pub fn (mut e Engine) doctor_fix(check_id string) !u64 {
	if check_id == '' {
		return error('check_id empty')
	}
	// Real repairs first — the fixed row must flip to pass on re-check (#1108).
	// Anything without an automated repair falls through to the audit stamp
	// (idempotent success; the dry-run preview says exactly that).
	if check_id.starts_with('profile:') {
		tid := check_id.all_after('profile:')
		for t in e.targets() {
			if t.id == tid {
				if t.enabled {
					break
				}
				return e.doctor_fix_enable_target(tid)!
			}
		}
	}
	if check_id.starts_with('mcp:') && check_id != 'mcp:docker' {
		mid := check_id.all_after('mcp:')
		for p in e.mcp_catalog() {
			// toggle on an enabled provider would REMOVE it — only the
			// disabled→upsert direction is a repair; enabled errors fall
			// through to the audit stamp (preview says so honestly).
			if p.id == mid && !p.enabled {
				rev := e.mcp_toggle(mid)!
				e.doctor_fix_stamp(check_id)!
				return rev
			}
		}
	}
	return e.doctor_fix_stamp(check_id)!
}

// doctor_fix_enable_target enables a disabled profile target in configuration
// and records the audit stamp in the same transaction.
fn (mut e Engine) doctor_fix_enable_target(target_id string) !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('doctor-fix')
	tx.set('target:${target_id}:enabled', 'true')
	tx.set('doctor:fix:profile:${target_id}', 'fixed')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// doctor_fix_stamp records the audit trail for checks without an automated
// repair (or already passing) — idempotent success, never an error. It never
// fabricates receipt evidence: a missing receipt stays missing.
fn (mut e Engine) doctor_fix_stamp(check_id string) !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('doctor-fix')
	tx.set('doctor:fix:${check_id}', 'fixed')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// doctor_fix_preview describes the state mutations a fix would perform
// WITHOUT writing anything — the GUI dry-run card renders these lines (#1108).
pub fn (mut e Engine) doctor_fix_preview(check_id string) ![]string {
	if check_id == '' {
		return error('check_id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut known := false
	for c in e.doctor() {
		if c.id == check_id {
			known = true
			if c.status == 'pass' {
				return ['note: check already passes — fix records an audit stamp only',
					'set doctor:fix:${check_id} = fixed']
			}
			break
		}
	}
	if !known {
		return error('unknown doctor check: ${check_id}')
	}
	if check_id.starts_with('profile:') {
		tid := check_id.all_after('profile:')
		return ['set target:${tid}:enabled = true',
			'set doctor:fix:profile:${tid} = fixed']
	}
	if check_id.starts_with('mcp:') && check_id != 'mcp:docker' {
		mid := check_id.all_after('mcp:')
		for p in e.mcp_catalog() {
			if p.id == mid {
				if p.enabled {
					return ['set doctor:fix:mcp:${mid} = fixed (audit trail)',
						'note: provider reports ${p.health} — toggle would REMOVE it, so no config change is made']
				}
				return ['enable ${mid} from its packaged template config',
					'set doctor:fix:mcp:${mid} = fixed']
			}
		}
	}
	return ['set doctor:fix:${check_id} = fixed (audit trail)',
		'note: no automated repair — ${doctor_manual_hint(check_id)}']
}

// doctor_manual_hint points at the manual step for checks without a repair.
fn doctor_manual_hint(check_id string) string {
	if check_id == 'toolkit_root' {
		return 'set AGENT_TOOLKIT_ROOT to the checkout'
	}
	if check_id.starts_with('loops:') {
		return 'edit the loop budget (cron editor lands in #1102)'
	}
	if check_id == 'audit:skills' {
		return 'run ./scripts/generate-catalogs.vsh, then re-check'
	}
	if check_id == 'mcp:docker' {
		return 'install docker: https://docs.docker.com/get-docker/'
	}
	if check_id.starts_with('receipt:') {
		return 'run install for this target to record a real receipt'
	}
	return 'see the check message, then re-check'
}

// doctor_fix_category fixes every fixable non-passing check in one category
// (facet-chip action, #1108). Returns the last revision, or 0 when nothing
// was fixable.
pub fn (mut e Engine) doctor_fix_category(cat string) !u64 {
	if cat == '' {
		return error('category empty')
	}
	mut rev := u64(0)
	mut fixed := 0
	for c in e.doctor() {
		if c.category == cat && c.fixable && c.status != 'pass' {
			rev = e.doctor_fix(c.id)!
			fixed++
		}
	}
	if fixed == 0 {
		return 0
	}
	return rev
}

// doctor_fix_all performs the real per-check repairs via doctor_fix —
// repairs where a repair exists, audit stamps otherwise. It never blanket-
// stamps checks as fixed without performing the repair.
pub fn (mut e Engine) doctor_fix_all() !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	checks := e.doctor()
	mut rev := u64(0)
	mut fixed := 0
	for c in checks {
		if c.fixable && (c.status == 'warn' || c.status == 'fail') {
			rev = e.doctor_fix(c.id)!
			fixed++
		}
	}
	if fixed == 0 {
		return 0
	}
	return rev
}

pub fn (mut e Engine) resolve_paths() []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	return [env.toolkit_root, env.tier]
}

// resolve_paths_detailed returns structured path info from the real
// authorities: bundled data root, user config receipt dir and the resolved
// toolkit version.
pub fn (mut e Engine) resolve_paths_detailed() string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	return json2.encode({
		'toolkit_root': env.toolkit_root
		'tier':         env.tier
		'receipt_dir':  agent_toolkit_core.default_receipt_dir()
		'provenance':   'plugins/*/.provenance.json'
		'version':      agent_toolkit_core.resolve_toolkit_version()
	},
		escape_unicode: true
	)
}
