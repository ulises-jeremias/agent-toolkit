#!/usr/bin/env -S v run
// V foundation targets for modules/ (ADR-009).
// Prefer this over Makefile; a thin Makefile forwards for muscle memory
// (`make test` → `v run make.vsh test`).
//
// Uses vlib `build` (same idea as bobatea/make.vsh and the upstream example):
//   https://github.com/vlang/v/tree/master/vlib/build
//   https://github.com/vlang/v/blob/master/examples/build_system/build.vsh
//
// Usage: v run make.vsh [--tasks] [help|fmt|fmt-check|vet|test|build|build-cli|install-cli|compile-make]

import build

const v_modules = ['agent_toolkit_core', 'agent_toolkit_cli']
const build_dir = 'build'
const cli_out = 'build/agent-toolkit'

fn root_dir() string {
	d := dir(@FILE)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

// Prefer Makefile/CI `V` / setup-v `VBIN` so Windows can use v.exe full path.
fn v_bin() string {
	for key in ['V', 'VBIN'] {
		p := getenv(key)
		if p.len > 0 {
			return p
		}
	}
	return 'v'
}

fn v_system(cmd_args string) int {
	vb := v_bin()
	return system('"${vb}" ${cmd_args}')
}

fn ensure_v(root string) ! {
	vb := v_bin()
	res := execute('"${vb}" version')
	if res.exit_code != 0 {
		return error('v not found; install V matching .v-version (or set V/VBIN)')
	}
	pin_path := join_path(root, '.v-version')
	if is_file(pin_path) {
		pinned := (read_file(pin_path) or { '' }).trim_space()
		// `v version` → "V 0.5.2 ...."
		parts := res.output.replace('\n', ' ').split(' ')
		mut have := ''
		if parts.len >= 2 {
			have = parts[1]
		}
		if pinned.len > 0 && have.len > 0 && have != pinned {
			eprintln('warning: v version ${have} != pinned ${pinned} (see docs/v/upgrade-policy.md)')
		}
	}
}

fn run_for_modules(root string, label string, args string) ! {
	for m in v_modules {
		println('==> ${label} ${m}')
		rc := v_system('${args} ${join_path(root, 'modules', m)}')
		if rc != 0 {
			return error('${label} failed for ${m} (exit ${rc})')
		}
	}
}

fn print_help(root string) {
	pin := (read_file(join_path(root, '.v-version')) or { 'pending' }).trim_space()
	println('V targets (pin: ${pin}) — also: v run make.vsh --tasks')
	println('  v run make.vsh fmt           Format V modules')
	println('  v run make.vsh fmt-check     Verify formatting')
	println('  v run make.vsh vet           Vet V modules')
	println('  v run make.vsh test          Run V unit tests')
	println('  v run make.vsh build         Typecheck/compile smoke for each module')
	println('  v run make.vsh build-cli     Build canonical V binary to ${cli_out}')
	println('  v run make.vsh install-cli   Install V binary to PREFIX/bin/agent-toolkit')
	println('  v run make.vsh compile-make  Precompile this script to ./make')
}

root := root_dir()
setenv('VMODULES', join_path(root, 'modules'), true)

mut context := build.context(
	default: 'help'
)

// `_` prefix = private task (still runnable; not meant as the primary UX).
// See examples/build_system/build.vsh in vlang/v.
context.task(
	name: '_ensure_v'
	help: 'Verify V toolchain matches .v-version'
	run:  fn [root] (self build.Task) ! {
		ensure_v(root)!
	}
)

context.task(
	name: '_mkdirs'
	help: 'Ensure build/ exists'
	run:  fn [root] (self build.Task) ! {
		mkdir_all(join_path(root, build_dir)) or {
			return error('mkdir ${build_dir} failed: ${err}')
		}
	}
)

context.task(
	name: 'help'
	help: 'Show V targets (default)'
	run:  fn [root] (self build.Task) ! {
		print_help(root)
	}
)

context.task(
	name:    'fmt'
	help:    'Format V modules (v fmt -w)'
	depends: ['_ensure_v']
	run:     fn [root] (self build.Task) ! {
		run_for_modules(root, 'fmt', 'fmt -w')!
	}
)

context.task(
	name:    'fmt-check'
	help:    'Verify V formatting (v fmt -verify)'
	depends: ['_ensure_v']
	run:     fn [root] (self build.Task) ! {
		run_for_modules(root, 'fmt-check', 'fmt -verify')!
	}
)

context.task(
	name:    'vet'
	help:    'Vet V modules'
	depends: ['_ensure_v']
	run:     fn [root] (self build.Task) ! {
		run_for_modules(root, 'vet', 'vet')!
	}
)

context.task(
	name:    'test'
	help:    'Run V unit tests for agent_toolkit_core and agent_toolkit_cli'
	depends: ['_ensure_v']
	run:     fn [root] (self build.Task) ! {
		run_for_modules(root, 'test', 'test')!
	}
)

context.task(
	name:    'build'
	help:    'Typecheck/compile smoke for each V module'
	depends: ['_ensure_v']
	run:     fn (_ build.Task) ! {
		for m in v_modules {
			println('==> build ${m}')
			tmpdir := join_path(temp_dir(), 'atk-build-${m}')
			rmdir_all(tmpdir) or {}
			mkdir_all(tmpdir) or { return error('mkdir tmp failed: ${err}') }
			main_v := join_path(tmpdir, 'main.v')
			write_file(main_v, 'module main\nimport ${m} as _\nfn main() {}\n') or {
				return error('write tmp main.v failed: ${err}')
			}
			rc := v_system('-o ${join_path(tmpdir, 'out')} ${main_v}')
			rmdir_all(tmpdir) or {}
			if rc != 0 {
				return error('build smoke failed for ${m} (exit ${rc})')
			}
		}
	}
)

context.task(
	name:    'build-cli'
	help:    'Build canonical V binary to build/agent-toolkit'
	depends: ['_ensure_v', '_mkdirs']
	run:     fn [root] (self build.Task) ! {
		mut commit := 'unknown'
		cres := execute('git -C ${root} rev-parse --short HEAD')
		if cres.exit_code == 0 {
			commit = cres.output.trim_space()
		}
		out := join_path(root, cli_out)
		rc := v_system('-d commit=${commit} -o ${out} ${join_path(root, 'cmd', 'agent-toolkit')}')
		if rc != 0 {
			return error('build-cli failed (exit ${rc})')
		}
		cp(out, join_path(root, build_dir, 'agent-toolkit-v')) or {}
	}
)

context.task(
	name:    'install-cli'
	help:    'Install V binary to PREFIX/bin/agent-toolkit'
	depends: ['build-cli']
	run:     fn [root] (self build.Task) ! {
		mut prefix := getenv('PREFIX')
		if prefix.len == 0 {
			prefix = join_path(home_dir(), '.local')
		}
		bindir := join_path(prefix, 'bin')
		mkdir_all(bindir) or { return error('mkdir bindir failed: ${err}') }
		src := join_path(root, cli_out)
		mut from := src
		if !is_file(from) {
			exe := src + '.exe'
			if is_file(exe) {
				from = exe
			} else {
				return error('missing ${src}; build-cli did not produce a binary')
			}
		}
		dest := join_path(bindir, 'agent-toolkit')
		cp(from, dest) or { return error('install copy failed: ${err}') }
		chmod(dest, 0o755) or {}
		println('Installed ${dest} (V canonical). Rollback: docs/v/rollback.md')
	}
)

context.task(
	name:    'compile-make'
	help:    'Precompile make.vsh to ./make (gitignored; see vlib/build README)'
	depends: ['_ensure_v']
	run:     fn [root] (self build.Task) ! {
		vb := v_bin()
		script := join_path(root, 'make.vsh')
		out := join_path(root, 'make')
		// Equivalent to `v -prod -skip-running make.vsh -o make` / `v build make.vsh`.
		rc := system('"${vb}" -prod -skip-running ${script} -o ${out}')
		if rc != 0 {
			return error('compile-make failed (exit ${rc})')
		}
		println('Wrote ${out}')
	}
)

// Iterate os.args and run each task (skips flags like --tasks).
context.run()
