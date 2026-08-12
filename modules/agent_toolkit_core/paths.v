module agent_toolkit_core

import os

// ToolkitRoot is a resolved toolkit data/repo root with the tier that won.
pub struct ToolkitRoot {
pub:
	path string
	tier string // override | xdg_data | xdg_cache | embedded | checkout | cwd
}

// is_offline reports AGENT_TOOLKIT_OFFLINE truthy (1|true|yes).
pub fn is_offline() bool {
	v := os.getenv('AGENT_TOOLKIT_OFFLINE').trim_space().to_lower()
	return v in ['1', 'true', 'yes']
}

// is_valid_toolkit_root reports whether path looks like toolkit data or a checkout.
pub fn is_valid_toolkit_root(path string) bool {
	if path.len == 0 || !os.is_dir(path) {
		return false
	}
	if os.is_dir(os.join_path(path, 'skills')) {
		return true
	}
	if os.is_dir(os.join_path(path, 'loops')) {
		return true
	}
	if os.is_dir(os.join_path(path, 'profiles')) {
		return true
	}
	return false
}

// is_repo_checkout reports skills/ + loops/ (development tree).
pub fn is_repo_checkout(path string) bool {
	return os.is_dir(os.join_path(path, 'skills')) && os.is_dir(os.join_path(path, 'loops'))
}

// find_toolkit_root resolves the toolkit root per ADR-015 (no network; #557 owns downloads).
pub fn find_toolkit_root() !ToolkitRoot {
	return find_toolkit_root_with(new_fs())
}

// find_toolkit_root_with is the injectable variant for tests.
pub fn find_toolkit_root_with(fs FsService) !ToolkitRoot {
	// 1. Explicit override
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		if is_valid_toolkit_root(val) {
			return ToolkitRoot{
				path: val
				tier: 'override'
			}
		}
	}

	// 2. Installed shared / external data (XDG data home) — never download here
	xdg_data := fs.toolkit_data_dir()
	if is_valid_toolkit_root(xdg_data) {
		return ToolkitRoot{
			path: xdg_data
			tier: 'xdg_data'
		}
	}
	// Read-only cache probe (populated by sync elsewhere; no network)
	xdg_cache := fs.toolkit_cache_dir()
	if is_valid_toolkit_root(xdg_cache) {
		return ToolkitRoot{
			path: xdg_cache
			tier: 'xdg_cache'
		}
	}

	// 3. Embedded baseline — next to executable (ADR-011); absent until packaging ships it
	exe := os.executable()
	if exe.len > 0 {
		exe_dir := os.dir(exe)
		for cand in [os.join_path(exe_dir, 'data'), os.join_path(exe_dir, '..', 'data')] {
			if is_valid_toolkit_root(cand) {
				return ToolkitRoot{
					path: cand
					tier: 'embedded'
				}
			}
		}
	}

	// 4. Development repository checkout — walk-up from CWD
	cwd := os.getwd()
	mut cur := cwd
	for {
		if is_repo_checkout(cur) {
			return ToolkitRoot{
				path: cur
				tier: 'checkout'
			}
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}

	// 5. CWD fallback
	if is_valid_toolkit_root(cwd) {
		return ToolkitRoot{
			path: cwd
			tier: 'cwd'
		}
	}

	hint := if is_offline() {
		'Offline mode: bundled/cache data missing. Set AGENT_TOOLKIT_ROOT or populate XDG data.'
	} else {
		'Set AGENT_TOOLKIT_ROOT to your agent-toolkit checkout (download sync is owned by #557).'
	}
	return error('Cannot locate agent-toolkit data directory. ${hint}')
}

// find_repo_root prefers a root that contains distributions/ (compiler/inventory).
pub fn find_repo_root() !string {
	root := find_toolkit_root()!
	if os.is_dir(os.join_path(root.path, 'distributions')) {
		return root.path
	}
	parent := os.dir(root.path)
	if os.is_dir(os.join_path(parent, 'distributions')) {
		return parent
	}
	return root.path
}
