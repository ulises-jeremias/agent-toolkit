module desktop_engine

// #1128 — bounded, explainable known-workspace discovery.
//
// Sources (deterministic, no filesystem crawls, no sibling-repo heuristics):
//   1. the ACTIVE workspace (persisted workspace_path/recent_workspace)
//   2. the PREVIOUS workspace (workspace/previous_path — one-level switch trail)
//   3. the designed fresh-user default (~/.ai-workspace)
//   4. recent projects (workspace/recent_projects) that exist as directories
//
// Every entry records WHY it was discovered and its truthful state:
// known ≠ valid ≠ active ≠ initialized. A missing directory stays listed
// with exists=false — the user decides (switch away / remove is a separate
// concern), never silently dropped.

import os

// KnownWorkspace is one discovered candidate with truthful state.
pub struct KnownWorkspace {
pub:
	path         string
	why          string // 'active' | 'previous' | 'default' | 'recent project'
	exists       bool
	initialized  bool // knowledge/repos scaffold present (workspace_is_initialized)
	is_active    bool
	has_projects bool // contains a git repository marker (project ≠ workspace)
}

// known_workspaces returns the bounded discovery list (deduped by canonical
// path, active first). Never crawls the home directory; never lists
// unrelated private directories.
pub fn (mut e Engine) known_workspaces() []KnownWorkspace {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	home := os.home_dir()
	default_ws := os.join_path(home, '.ai-workspace')

	active := snap.data['workspace_path'] or {
		snap.data['recent_workspace'] or { '' }
	}
	previous := snap.data['workspace/previous_path'] or { '' }

	mut paths := []string{}
	mut whys := []string{}
	if active != '' {
		paths << active
		whys << 'active'
	}
	if previous != '' && previous !in paths {
		paths << previous
		whys << 'previous'
	}
	if default_ws !in paths {
		paths << default_ws
		whys << 'default'
	}
	for p in e.recent_projects() {
		if p !in paths {
			paths << p
			whys << 'recent project'
		}
	}

	mut out := []KnownWorkspace{}
	mut seen := map[string]bool{}
	for i, raw in paths {
		clean := os.real_path(os.expand_tilde_to_home(raw.trim_space()))
		// dedupe on CANONICAL paths: '~/ws' and '/home/u/ws' are one workspace
		if clean == '' || seen[clean] {
			continue
		}
		if clean == os.path_separator || clean == os.home_dir() {
			// the home directory itself is never a workspace (#1127 rule)
			continue
		}
		seen[clean] = true
		exists := os.is_dir(clean)
		initialized := exists && workspace_is_initialized(clean)
		has_projects := exists && os.is_dir(os.join_path(clean, 'repos'))
			&& (os.ls(os.join_path(clean, 'repos')) or { []string{} })
				.filter(it != '.gitkeep').len > 0
		out << KnownWorkspace{
			path:         clean
			why:          whys[i]
			exists:       exists
			initialized:  initialized
			// active state comes from the PERSISTED preference — it survives
			// the directory being deleted (truthful: active but missing)
			is_active:    clean == os.real_path(active)
			has_projects: has_projects
		}
	}
	// active first, then stable order by path
	out.sort_with_compare(fn (a &KnownWorkspace, b &KnownWorkspace) int {
		if a.is_active != b.is_active {
			return if a.is_active { -1 } else { 1 }
		}
		if a.path < b.path {
			return -1
		}
		if a.path > b.path {
			return 1
		}
		return 0
	})
	return out
}

