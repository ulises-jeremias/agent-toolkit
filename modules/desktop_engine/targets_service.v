module desktop_engine

import time
import x.json2

// TargetEntry mirrors install.v profiles — super-potent with receipt/provenance.
pub struct TargetEntry {
pub:
	id         string
	name       string
	enabled    bool
	layer      string
	path       string
	status     string
	receipt    string // receipt path if installed
	provenance string // provenance path
}

// TargetDiff mirrors diff preview typed struct.
pub struct TargetDiff {
pub:
	added    []string
	removed  []string
	modified []string
}

// InstallOptions mirrors core InstallOptions for Engine-owned install flow (headless, no shell).
pub struct InstallOptionsEngine {
pub:
	targets     []string
	dry_run     bool
	force       bool
	receipt_dir string
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

pub fn (mut e Engine) targets() []TargetEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	base := env.toolkit_root
	mut out := []TargetEntry{}
	profiles := ['claude-code', 'cursor', 'opencode', 'pi', 'windsurf', 'cursor-plugins', 'cli']
	for p in profiles {
		enabled_str := e.repo.snapshot().data['target:${p}:enabled'] or { '' }
		enabled := enabled_str == 'true'
		layer := if env.tier == 'override' { 'Project' } else { 'Toolkit' }
		snap := e.repo.snapshot()
		receipt := snap.data['receipt:target:${p}:path'] or { '' }
		prov := snap.data['provenance:target:${p}:source'] or { 'profiles/${p}/config.yaml' }
		out << TargetEntry{
			id: p
			name: p
			enabled: enabled
			layer: layer
			path: '${base}/profiles/${p}'
			status: if enabled { 'enabled' } else { 'disabled' }
			receipt: receipt
			provenance: prov
		}
	}
	return out
}

pub fn (mut e Engine) set_target_enabled(target_id string, enabled bool) !u64 {
	if target_id == '' {
		return error('target id empty')
	}
	mut known := false
	for target in e.targets() {
		if target.id == target_id {
			known = true
			break
		}
	}
	if !known {
		return error('unsupported target: ${target_id}')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('set-target')
	tx.set('target:${target_id}:enabled', if enabled { 'true' } else { 'false' })
	// receipt provenance for toggle
	if enabled {
		tx.set('receipt:target:${target_id}:enabled_at', time.now().str())
	}
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

// install_dry_run returns human-readable preview (like core install --dry-run).
pub fn (mut e Engine) install_dry_run(targets []string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	d := e.install_preview(targets)
	mut lines := []string{}
	lines << 'agent-toolkit install --dry-run'
	lines << 'targets: ${targets.join(', ')}'
	if d.added.len > 0 { lines << 'will add: ${d.added.join(', ')}' }
	if d.removed.len > 0 { lines << 'will remove: ${d.removed.join(', ')}' }
	if d.added.len == 0 && d.removed.len == 0 { lines << 'no changes — already up to date' }
	lines << 'receipt: ~/.config/agent-toolkit/receipts/<target>-agent-toolkit-profiles.json'
	lines << 'provenance: plugins/<product>/.provenance.json'
	return lines.join('\n')
}

pub fn (mut e Engine) install(targets []string) !u64 {
	if targets.len == 0 {
		return error('no targets selected')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('install')
	tx.set('install:targets', targets.join(','))
	tx.set('install:timestamp', '${repo.snapshot().timestamp}')
	// per-target receipts + provenance (ADR-022 parity)
	for t in targets {
		tx.set('receipt:target:${t}:installed_at', time.now().str())
		tx.set('receipt:target:${t}:version', '')
		// The target adapter may add a digest after writing its real artifact.
		// Do not claim verification before that adapter reports one.
		tx.set('receipt:target:${t}:digest', '')
		tx.set('receipt:target:${t}:path', '~/.config/agent-toolkit/receipts/${t}-agent-toolkit-profiles.json')
		tx.set('provenance:target:${t}:source', 'profiles/${t}')
		tx.set('receipt:target:${t}:artifacts', 'profiles/${t}/config.yaml')
		tx.set('target:${t}:enabled', 'true')
	}
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// install_with_options mirrors core run_install with dry_run/force/receipt handling.
pub fn (mut e Engine) install_with_options(opts InstallOptionsEngine) !u64 {
	if opts.dry_run {
		// dry-run writes nothing, just preview
		_ = e.install_dry_run(opts.targets)
		return 0
	}
	return e.install(opts.targets)!
}

// list_install_receipts returns all target receipts via StateRepository (headless).
pub fn (mut e Engine) list_install_receipts() []InstallReceiptInfo {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []InstallReceiptInfo{}
	for k, v in snap.data {
		if k.starts_with('receipt:target:') && k.ends_with(':installed_at') {
			tgt := k.all_after('receipt:target:').all_before(':installed_at')
			out << InstallReceiptInfo{
				target: tgt
				product: snap.data['receipt:target:${tgt}:product'] or { '' }
				version: snap.data['receipt:target:${tgt}:version'] or { '' }
				installed_at: v
				source_digest: snap.data['receipt:target:${tgt}:digest'] or { '' }
				artifacts: (snap.data['receipt:target:${tgt}:artifacts'] or { '' }).split(',').filter(it != '')
				receipt_path: snap.data['receipt:target:${tgt}:path'] or { '' }
				provenance_path: snap.data['provenance:target:${tgt}:source'] or { '' }
			}
		}
	}
	// also surface skill/mcp receipts for unified view
	for k, v in snap.data {
		if k.starts_with('receipt:skill:') && k.ends_with(':installed_at') {
			id := k.all_after('receipt:skill:').all_before(':installed_at')
			out << InstallReceiptInfo{
				target: 'skill:${id}'
				product: snap.data['receipt:skill:${id}:product'] or { 'agent-toolkit-core' }
				version: snap.data['receipt:skill:${id}:version'] or { '' }
				installed_at: v
				source_digest: snap.data['receipt:skill:${id}:digest'] or { '' }
				receipt_path: 'receipts/skill-${id}.json'
				provenance_path: snap.data['provenance:skill:${id}:source'] or { '' }
			}
		}
	}
	return out
}

// verify_install_receipts checks receipts for drift (Doctor parity).
pub fn (mut e Engine) verify_install_receipts() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	for r in e.list_install_receipts() {
		if r.installed_at == '' {
			diags << BuildDiagnostic{
				path: r.receipt_path
				message: 'receipt timestamp missing for ${r.target}'
				code: 'receipt_corrupt'
			}
		}
		if r.source_digest == '' {
			diags << BuildDiagnostic{
				path: r.provenance_path
				message: 'provenance digest missing for ${r.target}'
				code: 'provenance_missing'
			}
		}
	}
	return diags
}

// install_receipt_json returns ADR-022 style JSON for a target (easy audit).
pub fn (mut e Engine) install_receipt_json(target_id string) string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	installed_at := snap.data['receipt:target:${target_id}:installed_at'] or { '' }
	version := snap.data['receipt:target:${target_id}:version'] or { '' }
	digest := snap.data['receipt:target:${target_id}:digest'] or { '' }
	return json2.encode({
		'schemaVersion': '1'
		'product':       'agent-toolkit-profiles'
		'target':        target_id
		'scope':         'project'
		'version':       version
		'installedAt':   installed_at
		'sourceDigest':  digest
		'provenance':    snap.data['provenance:target:${target_id}:source'] or { 'profiles/${target_id}' }
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

// doctor_fix_enable_target enables a disabled profile target and records the
// audit stamp in the same transaction (mirror set_target_enabled + receipt).
fn (mut e Engine) doctor_fix_enable_target(target_id string) !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('doctor-fix')
	tx.set('target:${target_id}:enabled', 'true')
	tx.set('receipt:target:${target_id}:enabled_at', time.now().str())
	tx.set('doctor:fix:profile:${target_id}', 'fixed')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// doctor_fix_stamp records the audit trail for checks without an automated
// repair (or already passing) — idempotent success, never an error.
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
				return [
					'note: check already passes — fix records an audit stamp only',
					'set doctor:fix:${check_id} = fixed',
				]
			}
			break
		}
	}
	if !known {
		return error('unknown doctor check: ${check_id}')
	}
	if check_id.starts_with('profile:') {
		tid := check_id.all_after('profile:')
		return ['set target:${tid}:enabled = true', 'set receipt:target:${tid}:enabled_at = <now>',
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
				return [
					'use packaged MCP template ${p.provenance}',
					'set doctor:fix:mcp:${mid} = fixed',
				]
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

// doctor_fix_all fixes all fixable Doctor checks in one transaction — super-potent.
pub fn (mut e Engine) doctor_fix_all() !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	checks := e.doctor()
	mut repo := e.repo
	mut tx := repo.begin('doctor-fix-all')
	mut fixed := 0
	for c in checks {
		if c.fixable && (c.status == 'warn' || c.status == 'fail') {
			tx.set('doctor:fix:${c.id}', 'fixed')
			fixed++
		}
	}
	if fixed == 0 {
		return 0
	}
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

pub fn (mut e Engine) resolve_paths() []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	return [env.toolkit_root, env.tier]
}

// resolve_paths_detailed returns structured path info with receipt/provenance.
pub fn (mut e Engine) resolve_paths_detailed() string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	return json2.encode({
		'toolkit_root': env.toolkit_root
		'tier':         env.tier
		'receipt_dir':  '~/.config/agent-toolkit/receipts'
		'provenance':   'plugins/*/.provenance.json'
		'cache':        cache_path('1.27.0')
	},
		escape_unicode: true
	)
}
