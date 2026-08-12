module agent_toolkit_core

import os

// embedded_version is the compile-time fallback; keep in sync with root VERSION
// and packages/.../__init__.py via scripts/bump-version.py.
pub const embedded_version = '1.10.0'

// resolve_toolkit_version returns the toolkit version string.
// Prefers a VERSION file under env roots / CWD checkout, else embedded_version.
pub fn resolve_toolkit_version() string {
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		if v := read_version_file(os.join_path(val, 'VERSION')) {
			return v
		}
	}
	cwd := os.getwd()
	mut cur := cwd
	for {
		ver_path := os.join_path(cur, 'VERSION')
		if v := read_version_file(ver_path) {
			if os.is_dir(os.join_path(cur, 'skills'))
				|| os.is_dir(os.join_path(cur, 'loops'))
				|| os.is_dir(os.join_path(cur, 'profiles')) {
				return v
			}
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	return embedded_version
}

fn read_version_file(path string) ?string {
	if !os.is_file(path) {
		return none
	}
	text := os.read_file(path) or { return none }
	v := text.trim_space()
	if v.len == 0 {
		return none
	}
	return v
}
