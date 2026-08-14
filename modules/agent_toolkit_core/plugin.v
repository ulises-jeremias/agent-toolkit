module agent_toolkit_core

import os

// PluginOptions configures `plugin sync|check` (#519).
pub struct PluginOptions {
pub:
	subcommand   string // sync | check
	toolkit_root string
}

// PluginReport summarizes surface sync/check for plugin products (core/agents/forge).
pub struct PluginReport {
pub mut:
	ok      bool
	message string
	drift   int
}

// run_plugin syncs or checks canonical agents/skills into plugin bundles.
// Distinct from `build --check` (compiler drift): this is plugin surface copy/compare (core/agents/forge).
pub fn run_plugin(opts PluginOptions) PluginReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return PluginReport{
			ok:      true
			message: plugin_help_text()
		}
	}
	root := if opts.toolkit_root.len > 0 { opts.toolkit_root } else { lookup_checkout_root() }
	if root.len == 0 {
		return PluginReport{
			ok:      false
			message: 'Cannot locate toolkit directory'
		}
	}
	if sub !in ['sync', 'check'] {
		return PluginReport{
			ok:      false
			message: 'Unknown subcommand: ${sub}\n  Valid subcommands: sync, check'
		}
	}
	return run_plugin_surfaces(root, sub == 'check')
}

pub fn plugin_result(report PluginReport) CommandResult {
	return CommandResult{
		command: 'plugin'
		ok:      report.ok
		message: report.message
		data:    {
			'drift': '${report.drift}'
			'mode':  if report.message.contains('checking') { 'check' } else { 'sync' }
		}
	}
}

pub fn plugin_help_text() string {
	return 'plugin — Plugin bundle management for agent-toolkit.

Usage: agent-toolkit plugin <subcommand> [--json]

Subcommands:
    sync     Sync canonical agents/skills into plugin bundles
    check    Verify plugin bundles are in sync (exit 1 if drift)

Options:
    --json   Structured CommandResult JSON

This is plugin surface copy/compare (core/agents/forge). Compiler emit drift is `build --check`.
'
}

fn run_plugin_surfaces(root string, check bool) PluginReport {
	plugins_dir := os.join_path(root, 'plugins')
	surfaces := build_plugin_surfaces(root)
	mode := if check { 'checking' } else { 'syncing' }
	icon := if check { '🔍' } else { '🔄' }
	mut lines := []string{}
	lines << ''
	lines << '${icon} plugin bundles (${mode})...'
	lines << ''
	mut drift := 0
	mut names := surfaces.keys()
	names.sort()
	for plugin_name in names {
		pairs := surfaces[plugin_name]
		plugin_dir := os.join_path(plugins_dir, plugin_name)
		if !os.is_dir(plugin_dir) {
			lines << '  ⚠  Plugin dir missing: ${plugin_name}'
			continue
		}
		lines << '── ${plugin_name} ──'
		for pair in pairs {
			src := os.join_path(root, pair[0])
			dst := os.join_path(plugin_dir, pair[1])
			ok, msg := sync_or_check_surface(src, dst, root, check)
			if msg.len > 0 {
				lines << msg
			}
			if !ok {
				drift++
			}
		}
		if check {
			prov := os.join_path(plugin_dir, '.provenance.json')
			if os.is_file(prov) {
				for msg in verify_generated_digests(plugins_dir, prov) {
					lines << '  ✗  ${msg}'
					drift++
				}
			}
		}
		lines << ''
	}
	if drift > 0 {
		lines << '  ✗  Plugin surfaces are out of sync'
		if check {
			lines << '     Run: agent-toolkit plugin sync'
		}
	} else {
		lines << '  ✓  All plugin surfaces are in sync!'
	}
	return PluginReport{
		ok:      drift == 0
		message: lines.join('\n')
		drift:   drift
	}
}

fn build_plugin_surfaces(root string) map[string][][]string {
	mut surfaces := map[string][][]string{}
	surfaces['agent-toolkit-core'] = [
		['agents/code-reviewer', 'agents/code-reviewer'],
		['skills/core/assistant', 'skills/assistant'],
		['skills/core/dev-companion', 'skills/dev-companion'],
		['skills/core/output-handshake', 'skills/output-handshake'],
		['skills/core/pr-fallback', 'skills/pr-fallback'],
		['skills/core/workspace-knowledge-sync', 'skills/workspace-knowledge-sync'],
		['skills/core/onboarding', 'skills/onboarding'],
	]
	mut agents := [][]string{}
	agents_dir := os.join_path(root, 'agents')
	if os.is_dir(agents_dir) {
		entries := os.ls(agents_dir) or { []string{} }
		mut names := entries.clone()
		names.sort()
		for d in names {
			if os.is_dir(os.join_path(agents_dir, d)) {
				agents << ['agents/${d}', 'agents/${d}']
			}
		}
	}
	surfaces['agent-toolkit-agents'] = agents
	mut forge := [][]string{}
	forge_dir := os.join_path(root, 'skills', 'forge')
	if os.is_dir(forge_dir) {
		entries := os.ls(forge_dir) or { []string{} }
		mut names := entries.clone()
		names.sort()
		for d in names {
			if os.is_dir(os.join_path(forge_dir, d)) {
				forge << ['skills/forge/${d}', 'skills/${d}']
			}
		}
	}
	surfaces['agent-toolkit-forge'] = forge
	return surfaces
}

fn sync_or_check_surface(src string, dst string, root string, check bool) (bool, string) {
	if !os.exists(src) {
		return true, ''
	}
	if dirs_in_sync(src, dst) {
		return true, ''
	}
	src_rel := relative_to(src, root) or { src }
	dst_rel := relative_to(dst, root) or { dst }
	if check {
		return false, '  ✗  DRIFT: ${src_rel} → ${dst_rel}'
	}
	copy_tree(src, dst) or {
		return false, '  ✗  Failed to sync ${src} → ${dst}: ${err}'
	}
	return true, '  ✓  synced: ${src_rel} → ${dst_rel}'
}

fn dirs_in_sync(src string, dst string) bool {
	if !os.exists(dst) {
		return false
	}
	src_files := plugin_list_rel_files(src)
	dst_files := plugin_list_rel_files(dst)
	if src_files.len != dst_files.len {
		return false
	}
	mut dset := map[string]bool{}
	for f in dst_files {
		dset[f] = true
	}
	for f in src_files {
		if f !in dset {
			return false
		}
		if file_digest(os.join_path(src, f)) != file_digest(os.join_path(dst, f)) {
			return false
		}
	}
	for f in dst_files {
		if f !in src_files {
			return false
		}
	}
	return true
}

fn plugin_list_rel_files(root string) []string {
	mut out := []string{}
	collect_rel_files(root, root, mut out)
	// include provenance files for surface dirs (collect_rel_files skips them)
	out.sort()
	return out
}

fn copy_tree(src string, dst string) ! {
	if os.exists(dst) {
		os.rmdir_all(dst) or { return error('rmtree failed: ${err}') }
	}
	files := plugin_list_rel_files(src)
	fs := new_fs()
	for rel in files {
		from := os.join_path(src, rel)
		to := os.join_path(dst, rel)
		data := os.read_file(from) or { return error('read ${from}: ${err}') }
		fs.write_atomic(to, data)!
	}
}
