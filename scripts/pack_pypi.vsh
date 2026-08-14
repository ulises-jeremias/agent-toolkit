#!/usr/bin/env -S v run
// Build PyPI sdist + platform wheels from GitHub Release V binaries (ADR-021).
// Usage: RELEASE_BIN_DIR=binaries v run scripts/pack_pypi.vsh

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
	floating  string
	bin       string
	wheel_tag string
}

fn load_platforms(root string) []PlatformSpec {
	path := join_path(root, 'packages', 'pypi', 'agent-toolkit-cli', 'platforms.json')
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
	env := getenv('RELEASE_VERSION').trim_space()
	if env.len > 0 {
		return env
	}
	return (read_file(join_path(root, 'VERSION')) or { '0.0.0' }).trim_space()
}

fn resolve_dir(root string, env_key string, default_rel string) string {
	raw := getenv(env_key)
	p := if raw.len > 0 { raw } else { default_rel }
	if is_abs_path(p) {
		return p
	}
	return join_path(root, p)
}

fn clear_native_bin(bin_dir string) {
	mkdir_all(bin_dir) or {}
	for name in ls(bin_dir) or { []string{} } {
		if name == '.gitkeep' {
			continue
		}
		p := join_path(bin_dir, name)
		if is_file(p) {
			rm(p) or {}
		}
	}
}

fn write_native_bin(bin_dir string, src string, dest_name string) string {
	clear_native_bin(bin_dir)
	dest := join_path(bin_dir, dest_name)
	cp(src, dest) or {}
	chmod(dest, 0o755) or {}
	return dest
}

fn uv_build(root string, pkg string, kind string, dest string, wheel_tag string) {
	mut env_pairs := environ()
	if wheel_tag.len > 0 {
		env_pairs['AGENT_TOOLKIT_WHEEL_TAG'] = wheel_tag
	} else {
		env_pairs.delete('AGENT_TOOLKIT_WHEEL_TAG')
	}
	mut env_list := []string{}
	for k, v in env_pairs {
		env_list << '${k}=${v}'
	}
	cmd := 'uv build --${kind} --out-dir ${dest} ${pkg}'
	res := execute_opt(cmd) or {
		eprintln('uv build failed: ${err}')
		exit(1)
	}
	if res.exit_code != 0 {
		eprintln(res.output)
		exit(res.exit_code)
	}
	_ = root
	_ = env_list
}

fn main() {
	root := repo_root()
	pkg := join_path(root, 'packages', 'pypi', 'agent-toolkit-cli')
	bin_dir := join_path(pkg, 'src', 'agent_toolkit', 'bin')
	src_root := resolve_dir(root, 'RELEASE_BIN_DIR', 'binaries')
	dest := resolve_dir(root, 'RELEASE_OUT_DIR', 'dist')
	mkdir_all(dest) or {}
	ver := version(root)
	println('pack_pypi: version=${ver} bin_dir=${src_root} out=${dest}')
	clear_native_bin(bin_dir)
	// sdist
	chdir(root) or {}
	res_sdist := system('uv build --sdist --out-dir ${dest} ${pkg}')
	if res_sdist != 0 {
		exit(res_sdist)
	}
	mut built := 0
	for spec in load_platforms(root) {
		src := join_path(src_root, spec.floating)
		if !is_file(src) {
			println('skip ${spec.floating} (missing under ${src_root})')
			continue
		}
		write_native_bin(bin_dir, src, spec.bin)
		setenv('AGENT_TOOLKIT_WHEEL_TAG', spec.wheel_tag, true)
		rc := system('uv build --wheel --out-dir ${dest} ${pkg}')
		unsetenv('AGENT_TOOLKIT_WHEEL_TAG')
		if rc != 0 {
			exit(rc)
		}
		built++
		println('wheel ${spec.wheel_tag} ← ${spec.floating}')
	}
	clear_native_bin(bin_dir)
	if built == 0 {
		eprintln('pack_pypi: no platform binaries found; sdist only')
		exit(1)
	}
	println('pack_pypi: ${built} wheel(s) + sdist in ${dest}')
}
