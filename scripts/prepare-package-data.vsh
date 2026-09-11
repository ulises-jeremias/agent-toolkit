#!/usr/bin/env -S v run
// Copy monorepo capability data into the publishable package tree for hatch builds.
// Safe to re-run. Destination contents are gitignored except .gitignore.
// Usage: ./scripts/prepare-package-data.vsh   (from repo root or any subdir)

import os

fn repo_root() string {
	mut d := os.dir(@FILE)
	// scripts/ -> repo root
	d = os.dir(d)
	if os.is_file(os.join_path(d, 'VERSION')) {
		return d
	}
	return os.getwd()
}

fn main() {
	root := repo_root()
	dest := os.join_path(root, 'packages', 'pypi', 'agent-toolkit-cli', 'src', 'agent_toolkit',
		'data')
	os.mkdir_all(dest) or {
		eprintln('prepare-package-data: cannot create ${dest}: ${err}')
		exit(1)
	}
	for name in ['skills', 'agents', 'loops', 'profiles', 'mcp', 'catalogs', 'distributions', 'packs', 'capabilities'] {
		src := os.join_path(root, name)
		target := os.join_path(dest, name)
		os.rmdir_all(target) or {}
		// The capability trees hold no symlinks (verified: no git mode
		// 120000 entries), so a recursive copy matches the old `cp -a`.
		os.cp_all(src, target, true) or {
			eprintln('prepare-package-data: cannot copy ${src} → ${target}: ${err}')
			exit(1)
		}
	}
	println('Prepared package data under ${dest}')
}
