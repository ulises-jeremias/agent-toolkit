module desktop_engine

// TargetEntry mirrors install.v profiles.
pub struct TargetEntry {
pub:
	id       string
	name     string
	enabled  bool
	layer    string
	path     string
	status   string
}

// TargetDiff mirrors diff preview typed struct.
pub struct TargetDiff {
pub:
	added    []string
	removed  []string
	modified []string
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
		enabled := if enabled_str == '' { p == 'claude-code' || p == 'cli' } else { enabled_str == 'true' }
		layer := if env.tier == 'override' { 'Project' } else { 'Toolkit' }
		out << TargetEntry{
			id: p
			name: p
			enabled: enabled
			layer: layer
			path: '${base}/profiles/${p}'
			status: if enabled { 'enabled' } else { 'disabled' }
		}
	}
	return out
}

pub fn (mut e Engine) set_target_enabled(target_id string, enabled bool) !u64 {
	if target_id == '' {
		return error('target id empty')
	}
	valid := ['claude-code', 'cursor', 'opencode', 'pi', 'windsurf', 'cursor-plugins', 'cli']
	if target_id !in valid {
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
	tx.set('receipt:generated', 'true')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

pub fn (mut e Engine) is_first_run() bool {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	val := e.repo.snapshot().data['onboarding_completed'] or { '' }
	return val != 'true'
}

pub fn (mut e Engine) doctor_fix(check_id string) !u64 {
	if check_id == '' {
		return error('check_id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('doctor-fix')
	tx.set('doctor:fix:${check_id}', 'fixed')
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
