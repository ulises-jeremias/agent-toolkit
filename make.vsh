#!/usr/bin/env -S v run
// V foundation targets for modules/ (ADR-009).
// Usage: ./make.vsh [--tasks] [help|fmt|fmt-check|vet|test|build|build-cli|install-cli|compile-make]
// Optional: ./make.vsh compile-make && ./make <target>
//
// vlib build (context.run) only runs non-hyphen args as tasks; flags like
// `--prefix=/usr/local` are skipped by the runner and parsed here manually.
// See: https://github.com/vlang/v/tree/master/vlib/build
// Style: bobatea/make.vsh + examples/build_system/build.vsh

import build

const mods = ['agent_toolkit_core', 'agent_toolkit_cli']

fn root() string {
	d := dir(@FILE)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

// Prefer CI `V` / setup-v `VBIN` so Windows can use v.exe full path.
fn vbin() string {
	for k in ['V', 'VBIN'] {
		p := getenv(k)
		if p.len > 0 {
			return p
		}
	}
	return 'v'
}

fn vcmd(args string) int {
	return system('"${vbin()}" ${args}')
}

// flag_value reads `--name=value` or `--name value` from os.args.
// vlib/build skips hyphen args when selecting tasks, so this is the idiomatic
// way to pass runtime knobs (build has no task-param API; examples use consts).
fn flag_value(name string) string {
	long := '--${name}'
	eq := '${long}='
	for i, a in args {
		if a.starts_with(eq) {
			return a.all_after('=')
		}
		if a == long && i + 1 < args.len && !args[i + 1].starts_with('-') {
			return args[i + 1]
		}
	}
	return ''
}

fn install_prefix() string {
	p := flag_value('prefix')
	if p.len > 0 {
		return p
	}
	env := getenv('PREFIX')
	if env.len > 0 {
		return env
	}
	return join_path(home_dir(), '.local')
}

fn ensure_v(r string) {
	res := execute('"${vbin()}" version')
	if res.exit_code != 0 {
		eprintln('v not found; install V matching .v-version (or set V/VBIN)')
		exit(1)
	}
	pin_path := join_path(r, '.v-version')
	if !is_file(pin_path) {
		return
	}
	pinned := (read_file(pin_path) or { '' }).trim_space()
	parts := res.output.replace('\n', ' ').split(' ')
	have := if parts.len >= 2 { parts[1] } else { '' }
	if pinned.len > 0 && have.len > 0 && have != pinned {
		eprintln('warning: v version ${have} != pinned ${pinned} (see docs/v/upgrade-policy.md)')
	}
}

fn each_mod(r string, label string, args string) {
	for m in mods {
		println('==> ${label} ${m}')
		rc := vcmd('${args} ${join_path(r, 'modules', m)}')
		if rc != 0 {
			exit(rc)
		}
	}
}

r := root()
setenv('VMODULES', join_path(r, 'modules'), true)
ensure_v(r)

mut context := build.context(
	default: 'help'
)

context.task(
	name: 'help'
	help: 'Show targets (default); also: --tasks'
	run:  fn [r] (_ build.Task) ! {
		pin := (read_file(join_path(r, '.v-version')) or { 'pending' }).trim_space()
		println('V targets (pin: ${pin}) — ./make.vsh --tasks')
		println('  fmt | fmt-check | vet | test | build | build-cli | install-cli | compile-make')
		println('  install-cli flags: --prefix=/path  (or PREFIX env; default ~/.local)')
	}
)

context.task(name: 'fmt', help: 'Format modules', run: fn [r] (_ build.Task) ! {
	each_mod(r, 'fmt', 'fmt -w')
})

context.task(name: 'fmt-check', help: 'Verify formatting', run: fn [r] (_ build.Task) ! {
	each_mod(r, 'fmt-check', 'fmt -verify')
})

context.task(name: 'vet', help: 'Vet modules', run: fn [r] (_ build.Task) ! {
	each_mod(r, 'vet', 'vet')
})

context.task(name: 'test', help: 'Run unit tests', run: fn [r] (_ build.Task) ! {
	each_mod(r, 'test', 'test')
})

context.task(name: 'build', help: 'Compile-smoke each module', run: fn (_ build.Task) ! {
	for m in mods {
		println('==> build ${m}')
		tmpdir := join_path(temp_dir(), 'atk-build-${m}')
		rmdir_all(tmpdir) or {}
		mkdir_all(tmpdir) or {}
		main_v := join_path(tmpdir, 'main.v')
		write_file(main_v, 'module main\nimport ${m} as _\nfn main() {}\n') or {}
		rc := vcmd('-o ${join_path(tmpdir, 'out')} ${main_v}')
		rmdir_all(tmpdir) or {}
		if rc != 0 {
			exit(rc)
		}
	}
})

context.task(name: 'build-cli', help: 'Build build/agent-toolkit', run: fn [r] (_ build.Task) ! {
	mkdir_all(join_path(r, 'build')) or {}
	mut commit := 'unknown'
	cres := execute('git -C ${r} rev-parse --short HEAD')
	if cres.exit_code == 0 {
		commit = cres.output.trim_space()
	}
	out := join_path(r, 'build', 'agent-toolkit')
	rc := vcmd('-d commit=${commit} -o ${out} ${join_path(r, 'cmd', 'agent-toolkit')}')
	if rc != 0 {
		exit(rc)
	}
	cp(out, join_path(r, 'build', 'agent-toolkit-v')) or {}
})

context.task(
	name:    'install-cli'
	help:    'Install to <prefix>/bin/agent-toolkit (--prefix=… or PREFIX)'
	depends: ['build-cli']
	run:     fn [r] (_ build.Task) ! {
		prefix := install_prefix()
		bindir := join_path(prefix, 'bin')
		mkdir_all(bindir) or {}
		src := join_path(r, 'build', 'agent-toolkit')
		mut from := src
		if !is_file(from) {
			exe := src + '.exe'
			if is_file(exe) {
				from = exe
			} else {
				eprintln('missing ${src}; build-cli did not produce a binary')
				exit(1)
			}
		}
		dest := join_path(bindir, 'agent-toolkit')
		cp(from, dest) or {}
		chmod(dest, 0o755) or {}
		println('Installed ${dest} (V canonical). Rollback: docs/v/rollback.md')
	}
)

context.task(name: 'compile-make', help: 'Precompile to ./make (gitignored)', run: fn [r] (_ build.Task) ! {
	rc := system('"${vbin()}" -prod -skip-running ${join_path(r, 'make.vsh')} -o ${join_path(r, 'make')}')
	if rc != 0 {
		exit(rc)
	}
	println('Wrote ${join_path(r, 'make')}')
})

context.run()
