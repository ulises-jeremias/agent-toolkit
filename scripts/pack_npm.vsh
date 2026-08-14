#!/usr/bin/env -S v run
// Copy GitHub Release V binaries into npm platform packages (ADR-025 / #536).
// Usage: RELEASE_BIN_DIR=binaries RELEASE_VERSION=x.y.z v run scripts/pack_npm.vsh

import json

fn repo_root() string {
	mut d := dir(@FILE)
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

struct PlatformSpec {
	npm      string
	os       string
	cpu      string
	bin      string
	floating string
	libc     string
}

fn load_platforms(root string) []PlatformSpec {
	path := join_path(root, 'packages', 'npm', 'agent-toolkit-cli', 'platforms.json')
	raw := read_file(path) or {
		eprintln('cannot read platforms.json: ${err}')
		exit(1)
	}
	return json.decode([]PlatformSpec, raw) or {
		eprintln('decode platforms.json: ${err}')
		exit(1)
	}
}

fn version(root string) string {
	env := getenv('RELEASE_VERSION')
	if env.len > 0 {
		return env.trim_space()
	}
	return (read_file(join_path(root, 'VERSION')) or { '0.0.0' }).trim_space()
}

fn write_platform_package(root string, spec PlatformSpec, ver string, src_bin string) {
	pkg_dir := join_path(root, 'packages', 'npm', spec.npm)
	bin_dir := join_path(pkg_dir, 'bin')
	mkdir_all(bin_dir) or {}
	mut libc_line := ''
	if spec.libc.len > 0 {
		libc_line = '  "libc": ["${spec.libc}"],\n'
	}
	pkg := '{
  "name": "${spec.npm}",
  "version": "${ver}",
  "description": "Native V binary for ${spec.npm} (optionalDependency of agent-toolkit-cli)",
  "license": "MIT",
  "os": ["${spec.os}"],
  "cpu": ["${spec.cpu}"],
${libc_line}  "files": ["README.md", "bin/${spec.bin}"],
  "homepage": "https://github.com/ulises-jeremias/agent-toolkit",
  "bugs": {
    "url": "https://github.com/ulises-jeremias/agent-toolkit/issues"
  },
  "repository": {
    "type": "git",
    "url": "git+https://github.com/ulises-jeremias/agent-toolkit.git",
    "directory": "packages/npm/${spec.npm}"
  },
  "publishConfig": {"access": "public"}
}
'
	write_file(join_path(pkg_dir, 'package.json'), pkg) or {}
	dest := join_path(bin_dir, spec.bin)
	if src_bin.len > 0 && is_file(src_bin) {
		cp(src_bin, dest) or {}
		chmod(dest, 0o755) or {}
		println('packed ${spec.npm} <- ${file_name(src_bin)}')
	} else {
		println('skip binary for ${spec.npm} (missing ${spec.floating})')
	}
}

fn sync_meta_version(root string, ver string, platforms []PlatformSpec) {
	pkg_path := join_path(root, 'packages', 'npm', 'agent-toolkit-cli', 'package.json')
	raw := read_file(pkg_path) or { return }
	mut t := raw
	// bump version
	mut i := t.index('"version"') or { -1 }
	if i >= 0 {
		// naive replace first "version": "..."
		mut start := t.index_after('"', i + 9) or { -1 }
		if start >= 0 {
			mut end := t.index_after('"', start + 1) or { -1 }
			if end > start {
				t = t[..start + 1] + ver + t[end..]
			}
		}
	}
	// rewrite optionalDependencies block values
	for spec in platforms {
		key := '"${spec.npm}"'
		idx := t.index(key) or { continue }
		// find : "..." after key within optionalDependencies
		colon := t.index_after(':', idx) or { continue }
		q1 := t.index_after('"', colon) or { continue }
		q2 := t.index_after('"', q1 + 1) or { continue }
		t = t[..q1 + 1] + ver + t[q2..]
	}
	write_file(pkg_path, t) or {}
}

fn main() {
	root := repo_root()
	mut src := getenv('RELEASE_BIN_DIR')
	if src.len == 0 {
		src = 'binaries'
	}
	if !is_abs_path(src) {
		src = join_path(root, src)
	}
	ver := version(root)
	platforms := load_platforms(root)
	sync_meta_version(root, ver, platforms)
	mut packed := 0
	for spec in platforms {
		mut src_bin := join_path(src, spec.floating)
		if !is_file(src_bin) {
			alt := join_path(src, spec.floating.trim_string_right('.exe'))
			if is_file(alt) {
				src_bin = alt
			}
		}
		write_platform_package(root, spec, ver, if is_file(src_bin) { src_bin } else { '' })
		dest := join_path(root, 'packages', 'npm', spec.npm, 'bin', spec.bin)
		if is_file(dest) {
			packed++
		}
	}
	println('npm platform packages with binaries: ${packed}')
}
