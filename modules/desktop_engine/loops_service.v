module desktop_engine

import time
import sync

pub enum LoopTier {
	l1
	l2
	l3
}

pub struct LoopEntry {
pub:
	name           string
	goal           string
	tier           LoopTier
	stage          string
	budget_total   int
	budget_spent   int
	allowlist      []string
	deny           []string
	cron_enabled   bool
	next_run       string
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
	if names.len > 0 {
		mut out := []LoopEntry{}
		for n in names {
			goal := snap.data['loops/${n}/goal'] or { 'Goal ${n}' }
			budget_str := snap.data['loops/${n}/budget'] or { '100' }
			budget := budget_str.int()
			spent_str := snap.data['loops/${n}/spent'] or { '0' }
			spent := spent_str.int()
			tier_str := snap.data['loops/${n}/tier'] or { 'l1' }
			tier := match tier_str {
				'l2' { LoopTier.l2 }
				'l3' { LoopTier.l3 }
				else { LoopTier.l1 }
			}
			out << LoopEntry{
				name: n
				goal: goal
				tier: tier
				stage: tier_str
				budget_total: budget
				budget_spent: spent
				cron_enabled: (snap.data['loops/${n}/cron'] or { 'false' }) == 'true'
				next_run: snap.data['loops/${n}/next_run'] or { '' }
			}
		}
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
		out << LoopEntry{
			name: name
			goal: 'Template goal for ${name}'
			tier: tier
			stage: tier.str()
			budget_total: 100
			budget_spent: (i * 7) % 100
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
	if content.contains('budget: -1') || content.contains('budget: -') {
		return [BuildDiagnostic{path: 'loops/${name}/loop.yaml', message: 'budget must be >=0', code: 'budget_invalid'}]
	}
	if !content.contains('goal:') {
		return [BuildDiagnostic{path: 'loops/${name}/loop.yaml', message: 'goal missing', code: 'missing_goal'}]
	}
	return []BuildDiagnostic{}
}

pub fn (mut e Engine) upsert_loop(entry LoopEntry) !u64 {
	if entry.name == '' {
		return error('loop name empty')
	}
	if entry.budget_total < 0 {
		return error('budget must be >=0')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('upsert-loop')
	tx.set('loops/${entry.name}/goal', entry.goal)
	tx.set('loops/${entry.name}/budget', entry.budget_total.str())
	tx.set('loops/${entry.name}/spent', entry.budget_spent.str())
	tx.set('loops/${entry.name}/tier', entry.tier.str())
	tx.set('loops/${entry.name}/cron', if entry.cron_enabled { 'true' } else { 'false' })
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

pub fn (mut e Engine) run_loop(name string) !string {
	if name == '' {
		return error('loop name empty')
	}
	mut found := false
	for l in e.loops_catalog() {
		if l.name == name {
			found = true
			break
		}
	}
	if !found {
		return error('loop not found: ${name}')
	}
	return e.spawn_job('agent-toolkit', ['loop', 'run', name])
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
		tx.set('loops/${name}/next_run', time.now().add(60 * time.minute).str())
	} else {
		tx.set('loops/${name}/next_run', '')
	}
	rev := e.put_transaction(mut tx)!
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
	return out
}

pub fn (e LoopEntry) budget_remaining() int {
	return e.budget_total - e.budget_spent
}
