module desktop_engine

import os

// Workspace scaffold projection — Engine-owned filesystem truth.
//
// The scaffold checklist (knowledge/ personas/ packs/ repos/ projects/ +
// AGENTS.md) mirrors what onboarding_ensure_workspace seeds plus the AGENTS.md
// contract that marks a workspace initialized. Views consume this projection;
// they never probe the filesystem themselves.

// workspace_scaffold_entry_names is the canonical scaffold list. A trailing
// '/' entry must be a directory; a plain entry must be a file.
pub const workspace_scaffold_entry_names = ['knowledge/', 'personas/', 'packs/', 'repos/', 'projects/',
	'AGENTS.md']

// WorkspaceScaffoldEntry is one checklist row: name + real directory state.
pub struct WorkspaceScaffoldEntry {
pub:
	name    string
	present bool
}

// WorkspaceScaffold is the typed projection for one root: empty entries
// means unknown (no root), never "all missing".
pub struct WorkspaceScaffold {
pub:
	root     string
	entries  []WorkspaceScaffoldEntry
	revision u64
}

// present_flags returns per-entry presence in canonical order (view compat).
pub fn (s WorkspaceScaffold) present_flags() []bool {
	mut out := []bool{cap: s.entries.len}
	for e in s.entries {
		out << e.present
	}
	return out
}

// present_count counts entries actually present on disk.
pub fn (s WorkspaceScaffold) present_count() int {
	mut n := 0
	for e in s.entries {
		if e.present {
			n++
		}
	}
	return n
}

// probe_workspace_scaffold checks the REAL directory state of root for each
// scaffold entry. Empty root or non-directory → empty (unknown, not missing).
// Pure: no Engine needed, but owned here so the probe lives with the type.
pub fn probe_workspace_scaffold(root string) WorkspaceScaffold {
	clean := os.expand_tilde_to_home(root.trim_space())
	if clean == '' || !os.is_dir(clean) {
		return WorkspaceScaffold{
			root: root
		}
	}
	mut entries := []WorkspaceScaffoldEntry{cap: workspace_scaffold_entry_names.len}
	for name in workspace_scaffold_entry_names {
		p := os.join_path(clean, name.trim_right('/'))
		present := if name.ends_with('/') { os.is_dir(p) } else { os.is_file(p) }
		entries << WorkspaceScaffoldEntry{
			name: name
			present: present
		}
	}
	return WorkspaceScaffold{
		root: clean
		entries: entries
	}
}

// workspace_scaffold returns the typed scaffold projection for root,
// stamped with the current Engine revision (views memoize on it).
pub fn (mut e Engine) workspace_scaffold(root string) WorkspaceScaffold {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	s := probe_workspace_scaffold(root)
	return WorkspaceScaffold{
		root: s.root
		entries: s.entries.clone()
		revision: e.repo.revision_nr()
	}
}
