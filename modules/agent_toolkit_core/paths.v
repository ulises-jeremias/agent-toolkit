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

// embedded_data_candidates are toolkit-data dirs relative to the V binary directory.
// PyPI wheels: agent_toolkit/bin/agent-toolkit + agent_toolkit/data/{skills,loops,profiles}.
pub fn embedded_data_candidates(exe_dir string) []string {
	return [os.join_path(exe_dir, 'data'), os.join_path(exe_dir, '..', 'data')]
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

// is_harness_workspace reports AGENTS.md/knowledge — not toolkit data, but currently
// passes is_valid_toolkit_root because it has profiles/ + loops/. Used to avoid
// AI_WORKSPACE hijack for standalone installs.
fn is_harness_workspace(path string) bool {
	return os.is_file(os.join_path(path, 'AGENTS.md')) || os.is_dir(os.join_path(path, 'knowledge'))
}

fn has_toolkit_tool_data(path string) bool {
	// real toolkit data has at least one tool-specific profile or top-level skills
	if os.is_dir(os.join_path(path, 'profiles', 'claude-code')) {
		return true
	}
	if os.is_dir(os.join_path(path, 'profiles', 'cursor')) {
		return true
	}
	if os.is_dir(os.join_path(path, 'skills')) {
		return true
	}
	if os.is_dir(os.join_path(path, 'plugins')) {
		return true
	}
	return false
}

// find_toolkit_root_with is the injectable variant for tests.
pub fn find_toolkit_root_with(fs FsService) !ToolkitRoot {
	// 1. Explicit override — but do not let a harness workspace masquerade as toolkit data.
	// Fresh agentic workstations have ~/.ai-workspace/profiles/oss-contrib.yaml + loops/ which
	// falsely qualifies as is_valid_toolkit_root; for standalone UX standalone we must sanitize.
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		if is_valid_toolkit_root(val) {
			if is_harness_workspace(val) && !has_toolkit_tool_data(val) {
				continue
			}
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

	// 3a. In-memory embedded baseline (full-embed, standalone without XDG/network).
	// This is the “binario ya tiene todo” tier — populated at compile time via
	// modules/agent_toolkit_core/embedded_data.v (#766). Wins over checkout/CWD
	// but after XDG so a fresher user update can override.
	if embedded_is_valid_root() {
		return ToolkitRoot{
			path: 'embedded'
			tier: 'embedded'
		}
	}

	// 3b. FHS system sidecar for AUR/Homebrew (aur-packages installs to /usr/share).
	// Allows PKGBUILD `agent-toolkit-bin` to ship data artifact without ELF bloat.
	if is_valid_toolkit_root('/usr/share/agent-toolkit/data') {
		return ToolkitRoot{
			path: '/usr/share/agent-toolkit/data'
			tier: 'embedded'
		}
	}

	// 3c. Embedded baseline — next to executable (ADR-011).
	// Wheel layout: agent_toolkit/bin/agent-toolkit + agent_toolkit/data/.
	exe := os.executable()
	if exe.len > 0 {
		exe_dir := os.dir(exe)
		for cand in embedded_data_candidates(exe_dir) {
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

// find_workspace_root locates a harness workspace (AGENTS.md / knowledge/), not toolkit data.
// Order: CLI override, AGENT_TOOLKIT_WORKSPACE, HARNESS_DIR, walk-up from CWD (#207 / #520).
pub fn find_workspace_root(override string) ?string {
	if override.len > 0 {
		if os.is_dir(override) {
			return override
		}
		return none
	}
	for env in ['AGENT_TOOLKIT_WORKSPACE', 'HARNESS_DIR'] {
		val := os.getenv(env).trim_space()
		if val.len > 0 && os.is_dir(val) {
			return val
		}
	}
	mut cur := os.getwd()
	for {
		if os.is_file(os.join_path(cur, 'AGENTS.md')) || os.is_dir(os.join_path(cur, 'knowledge')) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	return none
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
