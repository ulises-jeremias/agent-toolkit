#!/usr/bin/env -S v run
// V foundation targets for modules/ (ADR-009).
// Prefer this over Makefile; a thin Makefile forwards for muscle memory
// (`make test` → `v run make.vsh test`).
//
// Style: vlib `build` task runner (same pattern as bobatea/make.vsh).
// Usage: v run make.vsh [--tasks] [help|fmt|fmt-check|vet|test|build|build-cli|install-cli|compile-make]

import build

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

fn ensure_v(root string) {
	vb := v_bin()
	res := execute('"${vb}" version')
	if res.exit_code != 0 {
		eprintln('v not found; install V matching .v-version (or set V/VBIN)')
		exit(1)
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

fn run_for_modules(root string, label string, args string) {
	modules := ['agent_toolkit_core', 'agent_toolkit_cli']
	for m in modules {
		println('==> ${label} ${m}')
		rc := v_system('${args} ${join_path(root, 'modules', m)}')
		if rc != 0 {
			exit(rc)
		}
	}
}

fn build_cli(root string) {
	ensure_v(root)
	mkdir_all(join_path(root, 'build')) or {}
	mut commit := 'unknown'
	cres := execute('git -C ${root} rev-parse --short HEAD')
	if cres.exit_code == 0 {
		commit = cres.output.trim_space()
	}
	rc := v_system('-d commit=${commit} -o ${join_path(root, 'build', 'agent-toolkit')} ${join_path(root, 'cmd', 'agent-toolkit')}')
	if rc != 0 {
		exit(rc)
	}
	cp(join_path(root, 'build', 'agent-toolkit'), join_path(root, 'build', 'agent-toolkit-v')) or {}
}

fn install_cli(root string) {
	build_cli(root)
	mut prefix := getenv('PREFIX')
	if prefix.len == 0 {
		prefix = join_path(home_dir(), '.local')
	}
	bindir := join_path(prefix, 'bin')
	mkdir_all(bindir) or {}
	dest := join_path(bindir, 'agent-toolkit')
	cp(join_path(root, 'build', 'agent-toolkit'), dest) or {}
	chmod(dest, 0o755) or {}
	println('Installed ${dest} (V canonical). Rollback: docs/v/rollback.md')
}

fn build_modules(root string) {
	ensure_v(root)
	modules := ['agent_toolkit_core', 'agent_toolkit_cli']
	for m in modules {
		println('==> build ${m}')
		tmpdir := join_path(temp_dir(), 'atk-build-${m}')
		rmdir_all(tmpdir) or {}
		mkdir_all(tmpdir) or {}
		main_v := join_path(tmpdir, 'main.v')
		write_file(main_v, 'module main\nimport ${m} as _\nfn main() {}\n') or {}
		rc := v_system('-o ${join_path(tmpdir, 'out')} ${main_v}')
		rmdir_all(tmpdir) or {}
		if rc != 0 {
			exit(rc)
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
	println('  v run make.vsh build-cli     Build canonical V binary to build/agent-toolkit')
	println('  v run make.vsh install-cli   Install V binary to PREFIX/bin/agent-toolkit')
	println('  v run make.vsh compile-make  Precompile this script to ./make')
}

root := root_dir()
setenv('VMODULES', join_path(root, 'modules'), true)

mut context := build.context(
	default: 'help'
)

context.task(
	name: 'help'
	help: 'Show V targets (default)'
	run:  fn [root] (self build.Task) ! {
		print_help(root)
	}
)

context.task(
	name: 'fmt'
	help: 'Format V modules (v fmt -w)'
	run:  fn [root] (self build.Task) ! {
		ensure_v(root)
		run_for_modules(root, 'fmt', 'fmt -w')
	}
)

context.task(
	name: 'fmt-check'
	help: 'Verify V formatting (v fmt -verify)'
	run:  fn [root] (self build.Task) ! {
		ensure_v(root)
		run_for_modules(root, 'fmt-check', 'fmt -verify')
	}
)

context.task(
	name: 'vet'
	help: 'Vet V modules'
	run:  fn [root] (self build.Task) ! {
		ensure_v(root)
		run_for_modules(root, 'vet', 'vet')
	}
)

context.task(
	name: 'test'
	help: 'Run V unit tests for agent_toolkit_core and agent_toolkit_cli'
	run:  fn [root] (self build.Task) ! {
		ensure_v(root)
		run_for_modules(root, 'test', 'test')
	}
)

context.task(
	name: 'build'
	help: 'Typecheck/compile smoke for each V module'
	run:  fn [root] (self build.Task) ! {
		build_modules(root)
	}
)

context.task(
	name: 'build-cli'
	help: 'Build canonical V binary to build/agent-toolkit'
	run:  fn [root] (self build.Task) ! {
		build_cli(root)
	}
)

context.task(
	name: 'install-cli'
	help: 'Build and install V binary to PREFIX/bin/agent-toolkit'
	run:  fn [root] (self build.Task) ! {
		install_cli(root)
	}
)

context.task(
	name: 'compile-make'
	help: 'Precompile make.vsh to ./make (add /make to .gitignore)'
	run:  fn [root] (self build.Task) ! {
		ensure_v(root)
		vb := v_bin()
		script := join_path(root, 'make.vsh')
		out := join_path(root, 'make')
		rc := system('"${vb}" -prod -skip-running ${script} -o ${out}')
		if rc != 0 {
			exit(rc)
		}
		println('Wrote ${out}')
	}
)

context.run()
