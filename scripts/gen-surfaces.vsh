#!/usr/bin/env -S v run
// Sync canonical agents/ and skills/ into plugin bundle surfaces.
// Run with --check to fail on drift (used in CI).
// Deprecated: prefer `agent-toolkit build --check` (ADR-003).
// Usage: v run scripts/gen-surfaces.vsh [--check]

fn repo_root() string {
	mut d := dir(@FILE)
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

fn rel_to(root string, path string) string {
	prefix := '${root}/'
	if path.starts_with(prefix) {
		return path[prefix.len..]
	}
	return path
}

fn dirs_in_sync(src string, dst string) bool {
	if !is_dir(dst) {
		return false
	}
	src_files := walk_ext(src, '')
	dst_files := walk_ext(dst, '')
	mut src_rels := map[string]string{}
	mut dst_rels := map[string]string{}
	for f in src_files {
		if is_dir(f) {
			continue
		}
		r := rel_to(src, f)
		src_rels[r] = f
	}
	for f in dst_files {
		if is_dir(f) {
			continue
		}
		r := rel_to(dst, f)
		dst_rels[r] = f
	}
	if src_rels.len != dst_rels.len {
		return false
	}
	for r, sf in src_rels {
		df := dst_rels[r] or { return false }
		sa := read_bytes(sf) or { return false }
		db := read_bytes(df) or { return false }
		if sa != db {
			return false
		}
	}
	return true
}

fn sync_surface(root string, src string, dst string, check bool) bool {
	if !exists(src) {
		return true
	}
	if dirs_in_sync(src, dst) {
		return true
	}
	if check {
		println('  DRIFT: ${rel_to(root, src)} → ${rel_to(root, dst)}')
		return false
	}
	if exists(dst) {
		rmdir_all(dst) or {}
	}
	cp_all(src, dst, true) or {
		eprintln('copy failed: ${err}')
		return false
	}
	println('  synced: ${rel_to(root, src)} → ${rel_to(root, dst)}')
	return true
}

fn collect_surface_pairs(root string) map[string][][]string {
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
	mut agents_pairs := [][]string{}
	agents_dir := join_path(root, 'agents')
	for name in (ls(agents_dir) or { []string{} }).sorted() {
		p := join_path(agents_dir, name)
		if is_dir(p) {
			agents_pairs << ['agents/${name}', 'agents/${name}']
		}
	}
	surfaces['agent-toolkit-agents'] = agents_pairs
	mut forge_pairs := [][]string{}
	forge_dir := join_path(root, 'skills', 'forge')
	for name in (ls(forge_dir) or { []string{} }).sorted() {
		p := join_path(forge_dir, name)
		if is_dir(p) {
			forge_pairs << ['skills/forge/${name}', 'skills/${name}']
		}
	}
	surfaces['agent-toolkit-forge'] = forge_pairs
	return surfaces
}

fn main() {
	root := repo_root()
	check := '--check' in args
	mode := if check { 'checking' } else { 'syncing' }
	icon := if check { '🔍' } else { '🔄' }
	println('\n${icon} gen-surfaces (${mode} plugin bundles)...\n')
	plugins_dir := join_path(root, 'plugins')
	surfaces := collect_surface_pairs(root)
	mut drift := false
	for plugin_name in surfaces.keys().sorted() {
		plugin_dir := join_path(plugins_dir, plugin_name)
		if !is_dir(plugin_dir) {
			println('  ⚠ Plugin dir missing: ${plugin_name}')
			continue
		}
		println('── ${plugin_name} ──')
		for pair in surfaces[plugin_name] {
			src := join_path(root, pair[0])
			dst := join_path(plugin_dir, pair[1])
			ok := sync_surface(root, src, dst, check)
			if !ok {
				drift = true
			}
		}
	}
	println('')
	if drift {
		println('❌ Plugin surfaces are out of sync — run: v run scripts/gen-surfaces.vsh')
		exit(1)
	}
	println('✅ All plugin surfaces are in sync!')
}
