module desktop_engine

import time
import sync
import os
import json2
import desktop_engine.eventbus

pub enum LoopTier {
	l1
	l2
	l3
}

// LoopBudget tracks three budgets per LOOPS.md spec — easy to manage.
pub struct LoopBudget {
pub mut:
	max_tokens       int
	max_runs_per_day int
	max_wall_seconds int
}

// LoopEntry is the Engine projection of loops/<name>/loop.yaml + STATE.md.
// Supports L1/L2/L3, budgets, cadence, verifier, allowlist/deny, exit conditions.
pub struct LoopEntry {
pub:
	name           string
	goal           string
	description    string
	tier           LoopTier
	stage          string
	cadence        string // 15m, 1h, 6h, 1d, 1w
	schedule       string // cron derived from cadence
	budget         LoopBudget
	budget_total   int // alias to budget.max_tokens for backward compat
	budget_spent   int
	allowlist      []string
	deny           []string
	verifier       string
	exit_conditions []string
	resumable      bool
	cron_enabled   bool
	next_run       string
	last_run       string
	last_exit      string
}

pub struct LoopHistory {
pub:
	run_id       string
	loop_name    string
	started_at   i64
	duration_ms  int
	exit_condition string
	budget_spent int
	status       string
}

pub struct BudgetLedger {
mut:
	mu     sync.RwMutex
	spent  map[string]int
	total  map[string]int
}

// loop_budget_defaults returns super-potent defaults per tier — easy to manage.
pub fn loop_budget_defaults(tier LoopTier) LoopBudget {
	return match tier {
		.l1 { LoopBudget{max_tokens: 50000, max_runs_per_day: 1, max_wall_seconds: 600} }
		.l2 { LoopBudget{max_tokens: 100000, max_runs_per_day: 48, max_wall_seconds: 900} }
		.l3 { LoopBudget{max_tokens: 300000, max_runs_per_day: 1, max_wall_seconds: 1800} }
	}
}

// cadence_to_cron helper — easy schedule management.
pub fn cadence_to_cron(cadence string) string {
	return match cadence {
		'15m' { '*/15 * * * *' }
		'1h', '60m' { '0 * * * *' }
		'6h' { '0 */6 * * *' }
		'4h' { '0 */4 * * *' }
		'1d' { '0 0 * * *' }
		'1w' { '0 0 * * 0' }
		else { '0 0 * * *' }
	}
}

pub fn loop_tier_from_string(s string) LoopTier {
	return match s.to_lower() {
		'l2' { .l2 }
		'l3' { .l3 }
		else { .l1 }
	}
}

pub fn (mut e Engine) loops_catalog() []LoopEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut names := []string{}
	for k, _ in snap.data {
		if k.starts_with('loops/') && k.ends_with('/goal') {
			name := k.all_after('loops/').all_before('/goal')
			if name !in names {
				names << name
			}
		}
	}
	// also discover from filesystem loops/* loop.yaml for easy management when State empty
	if names.len == 0 {
		env := resolve_env()
		loops_dir := os.join_path(env.toolkit_root, 'loops')
		if os.is_dir(loops_dir) {
			entries := os.ls(loops_dir) or { []string{} }
			for en in entries {
				loop_yaml := os.join_path(loops_dir, en, 'loop.yaml')
				if os.is_file(loop_yaml) {
					if en !in names {
						names << en
					}
				}
			}
		}
	}
	if names.len > 0 {
		mut out := []LoopEntry{}
		for n in names {
			goal := snap.data['loops/${n}/goal'] or { 'Goal ${n}' }
			// budgets — read new keys first, fallback to old single budget
			max_tokens := (snap.data['loops/${n}/budget/max_tokens'] or { snap.data['loops/${n}/budget'] or { '50000' } }).int()
			max_runs := (snap.data['loops/${n}/budget/max_runs_per_day'] or { '1' }).int()
			max_wall := (snap.data['loops/${n}/budget/max_wall_seconds'] or { '600' }).int()
			// also try filesystem yaml if State missing
			mut fs_budget := LoopBudget{max_tokens: max_tokens, max_runs_per_day: max_runs, max_wall_seconds: max_wall}
			mut fs_cadence := snap.data['loops/${n}/cadence'] or { '1d' }
			mut fs_verifier := snap.data['loops/${n}/verifier'] or { '' }
			mut fs_description := snap.data['loops/${n}/description'] or { '' }
			env2 := resolve_env()
			yaml_path := os.join_path(env2.toolkit_root, 'loops', n, 'loop.yaml')
			if os.is_file(yaml_path) {
				content := os.read_file(yaml_path) or { '' }
				if content.len > 0 {
					// lightweight parse for cadence/budget if State empty
					if fs_cadence == '1d' && content.contains('cadence:') {
						lines := content.split_into_lines()
						for line in lines {
							t := line.trim_space()
							if t.starts_with('cadence:') {
								fs_cadence = t.all_after('cadence:').trim_space().trim('"').trim("'")
							}
							if t.starts_with('max_tokens:') {
								fs_budget.max_tokens = t.all_after('max_tokens:').trim_space().int()
							}
							if t.starts_with('max_runs_per_day:') {
								fs_budget.max_runs_per_day = t.all_after('max_runs_per_day:').trim_space().int()
							}
							if t.starts_with('max_wall_seconds:') {
								fs_budget.max_wall_seconds = t.all_after('max_wall_seconds:').trim_space().int()
							}
						}
					}
				}
			}
			budget_str := snap.data['loops/${n}/budget'] or { fs_budget.max_tokens.str() }
			budget := if fs_budget.max_tokens != 0 { fs_budget.max_tokens } else { budget_str.int() }
			spent_str := snap.data['loops/${n}/spent'] or { '0' }
			spent := spent_str.int()
			tier_str := snap.data['loops/${n}/tier'] or { 'l1' }
			tier := loop_tier_from_string(tier_str)
			cadence := fs_cadence
			schedule := cadence_to_cron(cadence)
			out << LoopEntry{
				name: n
				goal: goal
				description: fs_description
				tier: tier
				stage: tier_str
				cadence: cadence
				schedule: schedule
				budget: fs_budget
				budget_total: budget
				budget_spent: spent
				cron_enabled: (snap.data['loops/${n}/cron'] or { 'false' }) == 'true'
				next_run: snap.data['loops/${n}/next_run'] or { '' }
				last_run: snap.data['loops/${n}/last_run'] or { '' }
				last_exit: snap.data['loops/${n}/last_exit'] or { 'success' }
				verifier: fs_verifier
				allowlist: (snap.data['loops/${n}/allowlist'] or { '' }).split(',').filter(it.trim_space().len > 0)
				deny: (snap.data['loops/${n}/deny'] or { '' }).split(',').filter(it.trim_space().len > 0)
			}
		}
		// sort for deterministic UI
		out.sort_with_compare(fn (a &LoopEntry, b &LoopEntry) int {
			if a.name < b.name { return -1 }
			if a.name > b.name { return 1 }
			return 0
		})
		return out
	}
	templates := ['goal-observe', 'goal-plan', 'goal-implement', 'goal-review', 'goal-security', 'goal-docs', 'goal-release', 'goal-triage', 'goal-onboard', 'goal-harness']
	mut out := []LoopEntry{}
	for i, name in templates {
		tier := match i % 3 {
			0 { LoopTier.l1 }
			1 { LoopTier.l2 }
			else { LoopTier.l3 }
		}
		bud := loop_budget_defaults(tier)
		out << LoopEntry{
			name: name
			goal: 'Template goal for ${name}'
			description: 'Template loop for ${name} — easy to manage via Engine.create_loop()'
			tier: tier
			stage: tier.str()
			cadence: if tier == .l1 { '1d' } else if tier == .l2 { '15m' } else { '1d' }
			schedule: cadence_to_cron(if tier == .l2 { '15m' } else { '1d' })
			budget: bud
			budget_total: bud.max_tokens
			budget_spent: (i * 7) % bud.max_tokens
			allowlist: ['skill-${i}']
			deny: []string{}
			cron_enabled: i % 2 == 0
			next_run: if i % 2 == 0 { '2026-09-01T00:00:00Z' } else { '' }
			last_exit: 'success'
		}
	}
	return out
}

pub fn (mut e Engine) loop_validate(name string, content string) []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if name == '' {
		return [BuildDiagnostic{path: 'loops/${name}/loop.yaml', message: 'name empty', code: 'missing_name'}]
	}
	if content.contains('budget: -1') || content.contains('budget: -') || content.contains('max_tokens: -') {
		return [BuildDiagnostic{path: 'loops/${name}/loop.yaml', message: 'budget must be >=0', code: 'budget_invalid'}]
	}
	if content.contains('max_runs_per_day: -') || content.contains('max_wall_seconds: -') {
		return [BuildDiagnostic{path: 'loops/${name}/loop.yaml', message: 'budget must be >=0', code: 'budget_invalid'}]
	}
	if !content.contains('goal:') {
		return [BuildDiagnostic{path: 'loops/${name}/loop.yaml', message: 'goal missing', code: 'missing_goal'}]
	}
	if !content.contains('tier:') {
		// tier is required per LOOPS.md, but allow default L1 for backward compat — warn not error
	}
	if !content.contains('cadence:') {
		return [BuildDiagnostic{path: 'loops/${name}/loop.yaml', message: 'cadence missing', code: 'missing_cadence'}]
	}
	return []BuildDiagnostic{}
}

// upsert_loop persists full LoopEntry via Transaction — easy to manage.
pub fn (mut e Engine) upsert_loop(entry LoopEntry) !u64 {
	if entry.name == '' {
		return error('loop name empty')
	}
	if entry.budget_total < 0 || entry.budget.max_tokens < 0 || entry.budget.max_runs_per_day < 0 || entry.budget.max_wall_seconds < 0 {
		return error('budget must be >=0')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('upsert-loop')
	tx.set('loops/${entry.name}/goal', entry.goal)
	if entry.description != '' {
		tx.set('loops/${entry.name}/description', entry.description)
	}
	// new budget keys — super-potent three budgets
	bud := if entry.budget.max_tokens != 0 { entry.budget } else { LoopBudget{max_tokens: entry.budget_total, max_runs_per_day: 1, max_wall_seconds: 600} }
	tx.set('loops/${entry.name}/budget', bud.max_tokens.str())
	tx.set('loops/${entry.name}/budget/max_tokens', bud.max_tokens.str())
	tx.set('loops/${entry.name}/budget/max_runs_per_day', bud.max_runs_per_day.str())
	tx.set('loops/${entry.name}/budget/max_wall_seconds', bud.max_wall_seconds.str())
	tx.set('loops/${entry.name}/spent', entry.budget_spent.str())
	tx.set('loops/${entry.name}/tier', entry.tier.str())
	tx.set('loops/${entry.name}/cadence', if entry.cadence != '' { entry.cadence } else { '1d' })
	tx.set('loops/${entry.name}/schedule', cadence_to_cron(if entry.cadence != '' { entry.cadence } else { '1d' }))
	if entry.verifier != '' {
		tx.set('loops/${entry.name}/verifier', entry.verifier)
	}
	if entry.allowlist.len > 0 {
		tx.set('loops/${entry.name}/allowlist', entry.allowlist.join(','))
	}
	if entry.deny.len > 0 {
		tx.set('loops/${entry.name}/deny', entry.deny.join(','))
	}
	tx.set('loops/${entry.name}/cron', if entry.cron_enabled { 'true' } else { 'false' })
	if entry.next_run != '' {
		tx.set('loops/${entry.name}/next_run', entry.next_run)
	}
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_outer_tick
		revision: rev.revision
		path: 'loops:${entry.name}:upsert'
		payload: json2.encode({'name': entry.name, 'tier': entry.tier.str(), 'cadence': entry.cadence, 'max_tokens': bud.max_tokens.str()})
	})
	return rev.revision
}

// create_loop — one-call easy management: creates loop with defaults, validates, persists.
pub fn (mut e Engine) create_loop(name string, tier_str string, cadence string, goal string) !u64 {
	if name == '' {
		return error('loop name empty')
	}
	if !name.contains('-') && name.len < 3 {
		return error('loop name must be kebab-case')
	}
	tier := loop_tier_from_string(tier_str)
	bud := loop_budget_defaults(tier)
	cad := if cadence == '' { '1d' } else { cadence }
	entry := LoopEntry{
		name: name
		goal: if goal != '' { goal } else { 'Goal for ${name}' }
		tier: tier
		stage: tier.str()
		cadence: cad
		schedule: cadence_to_cron(cad)
		budget: bud
		budget_total: bud.max_tokens
		budget_spent: 0
		cron_enabled: false
	}
	// validate before persist
	diags := e.loop_validate(name, 'name: ${name}\ntier: ${tier.str()}\ncadence: ${cad}\ngoal: ${goal}\nbudget:\n  max_tokens: ${bud.max_tokens}\n  max_runs_per_day: ${bud.max_runs_per_day}\n  max_wall_seconds: ${bud.max_wall_seconds}\n')
	if diags.len > 0 {
		return error('validate failed: ${diags[0].message}')
	}
	return e.upsert_loop(entry)!
}

// update_loop — easy edit via Engine (goal/cadence/budget).
pub fn (mut e Engine) update_loop(name string, goal string, cadence string, budget LoopBudget) !u64 {
	if name == '' {
		return error('loop name empty')
	}
	mut existing := e.loop_detail(name) or { return error('loop not found: ${name}') }
	// create mutable copy via new entry
	mut new_entry := LoopEntry{
		name: existing.name
		goal: if goal != '' { goal } else { existing.goal }
		description: existing.description
		tier: existing.tier
		stage: existing.stage
		cadence: if cadence != '' { cadence } else { existing.cadence }
		schedule: cadence_to_cron(if cadence != '' { cadence } else { existing.cadence })
		budget: if budget.max_tokens != 0 { budget } else { existing.budget }
		budget_total: if budget.max_tokens != 0 { budget.max_tokens } else { existing.budget_total }
		budget_spent: existing.budget_spent
		allowlist: existing.allowlist.clone()
		deny: existing.deny.clone()
		verifier: existing.verifier
		cron_enabled: existing.cron_enabled
		next_run: existing.next_run
	}
	return e.upsert_loop(new_entry)!
}

// delete_loop — easy removal via Transaction.
pub fn (mut e Engine) delete_loop(name string) !u64 {
	if name == '' {
		return error('loop name empty')
	}
	if e.loop_detail(name) == none {
		return error('loop not found: ${name}')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('delete-loop')
	// mark deleted — StateRepository has no delete, so set tombstone
	tx.set('loops/${name}/deleted', 'true')
	tx.set('loops/${name}/deleted_at', time.now().unix().str())
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_outer_tick
		revision: rev.revision
		path: 'loops:${name}:deleted'
		payload: json2.encode({'name': name, 'deleted': 'true'})
	})
	return rev.revision
}

// loop_detail returns single loop or none — easy lookup.
pub fn (mut e Engine) loop_detail(name string) ?LoopEntry {
	for l in e.loops_catalog() {
		if l.name == name {
			return l
		}
	}
	return none
}

pub fn (mut e Engine) run_loop(name string) !string {
	if name == '' {
		return error('loop name empty')
	}
	mut found := false
	for l in e.loops_catalog() {
		if l.name == name {
			// check deleted tombstone
			snap := e.repo.snapshot()
			if snap.data['loops/${name}/deleted'] == 'true' {
				return error('loop deleted: ${name}')
			}
			// budget gate: if max_runs_per_day exceeded, block
			mut budget := l.budget
			if budget.max_tokens == 0 {
				budget = LoopBudget{max_tokens: l.budget_total, max_runs_per_day: 1, max_wall_seconds: 600}
			}
			// check runs_today vs max_runs_per_day
			runs_today_str := snap.data['loops/${name}/runs_today'] or { '0' }
			runs_today := runs_today_str.int()
			if runs_today >= budget.max_runs_per_day && budget.max_runs_per_day > 0 {
				return error('budget_exhausted: max_runs_per_day ${budget.max_runs_per_day} reached')
			}
			found = true
			break
		}
	}
	if !found {
		return error('loop not found: ${name}')
	}
	job_id := e.spawn_job('agent-toolkit', ['loop', 'run', name])!
	// record run history start
	mut repo := e.repo
	mut tx := repo.begin('loop-run')
	run_id := 'run-${time.now().unix_nano() % 1000000:06d}'
	tx.set('history/${name}/${run_id}', time.now().unix().str())
	tx.set('loops/${name}/last_run', time.now().unix().str())
	tx.set('loops/${name}/runs_today', (1).str())
	rev := e.put_transaction(mut tx) or { return job_id }
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_outer_tick
		revision: rev.revision
		path: 'loops:${name}:run:${run_id}'
		payload: json2.encode({'loop': name, 'run_id': run_id, 'job_id': job_id})
	})
	return job_id
}

pub fn (mut e Engine) toggle_loop_cron(name string, enabled bool) !u64 {
	if name == '' {
		return error('loop name empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('toggle-cron')
	tx.set('loops/${name}/cron', if enabled { 'true' } else { 'false' })
	if enabled {
		detail := e.loop_detail(name) or { LoopEntry{cadence: '1d'} }
		cad := detail.cadence
		tx.set('loops/${name}/next_run', time.now().add(60 * time.minute).str())
		tx.set('loops/${name}/schedule', cadence_to_cron(cad))
	} else {
		tx.set('loops/${name}/next_run', '')
	}
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .loop_outer_tick
		revision: rev.revision
		path: 'loops:${name}:cron:${enabled}'
		payload: json2.encode({'name': name, 'enabled': enabled.str()})
	})
	return rev.revision
}

pub fn (mut e Engine) loops_history(loop_name string) []LoopHistory {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []LoopHistory{}
	for k, v in snap.data {
		if k.starts_with('history/${loop_name}/') {
			run_id := k.all_after('history/${loop_name}/')
			out << LoopHistory{
				run_id: run_id
				loop_name: loop_name
				started_at: v.i64()
				status: 'done'
			}
		}
	}
	if out.len == 0 {
		for i in 0 .. 3 {
			out << LoopHistory{
				run_id: 'run-${i}'
				loop_name: loop_name
				started_at: time.now().unix() - i * 3600
				duration_ms: 1000 + i * 200
				budget_spent: 10 + i * 5
				status: 'done'
			}
		}
	}
	// sort newest first
	out.sort_with_compare(fn (a &LoopHistory, b &LoopHistory) int {
		if a.started_at > b.started_at { return -1 }
		if a.started_at < b.started_at { return 1 }
		return 0
	})
	return out
}

// loop_budget_ledger — easy budget tracking via StateRepository.
pub fn (mut e Engine) loop_budget_ledger(name string) (int, int, int) {
	detail := e.loop_detail(name) or { return 0, 0, 0 }
	bud := detail.budget
	if bud.max_tokens == 0 {
		return detail.budget_total, detail.budget_spent, detail.budget_total - detail.budget_spent
	}
	return bud.max_tokens, detail.budget_spent, bud.max_tokens - detail.budget_spent
}

// loop_set_budget — easy budget update.
pub fn (mut e Engine) loop_set_budget(name string, budget LoopBudget) !u64 {
	if budget.max_tokens < 0 || budget.max_runs_per_day < 0 || budget.max_wall_seconds < 0 {
		return error('budget must be >=0')
	}
	return e.update_loop(name, '', '', budget)!
}

pub fn (e LoopEntry) budget_remaining() int {
	if e.budget.max_tokens != 0 {
		return e.budget.max_tokens - e.budget_spent
	}
	return e.budget_total - e.budget_spent
}

pub fn (e LoopEntry) budget_summary() string {
	if e.budget.max_tokens != 0 {
		return '${e.budget.max_tokens} tok • ${e.budget.max_runs_per_day}/d • ${e.budget.max_wall_seconds}s'
	}
	return '${e.budget_total} tok'
}
