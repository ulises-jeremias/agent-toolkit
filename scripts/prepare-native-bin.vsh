#!/usr/bin/env -S v run
// Copy a native V binary into the PyPI package tree for platform wheels (ADR-021 / #535).
// Usage: ./scripts/prepare-native-bin.vsh   (from repo root or any subdir)
//   AGENT_TOOLKIT_NATIVE_BIN overrides build-artifact discovery.

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
		'bin')
	os.mkdir_all(dest) or {
		eprintln('prepare-native-bin: cannot create ${dest}: ${err}')
		exit(1)
	}
	mut src := os.getenv('AGENT_TOOLKIT_NATIVE_BIN')
	if src == '' {
		for cand in [os.join_path(root, 'build', 'agent-toolkit'), os.join_path(root, 'build', 'agent-toolkit-v'), os.join_path(root,
			'build', 'agent-toolkit.exe')] {
			if os.is_file(cand) {
				src = cand
				break
			}
		}
	}
	if src == '' || !os.is_file(src) {
		eprintln('prepare-native-bin: no binary (set AGENT_TOOLKIT_NATIVE_BIN or ./make.vsh build-cli)')
		exit(1)
	}
	mut out := os.join_path(dest, 'agent-toolkit')
	if src.ends_with('.exe') {
		out = os.join_path(dest, 'agent-toolkit.exe')
	}
	os.cp(src, out) or {
		eprintln('prepare-native-bin: cannot copy ${src} → ${out}: ${err}')
		exit(1)
	}
	os.chmod(out, 0o755) or {}
	println('Copied ${src} → ${out}')
}
