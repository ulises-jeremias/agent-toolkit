#!/usr/bin/env -S v run
// V foundation targets for modules/ (ADR-009).
// Usage: ./make.vsh [--tasks] [help|fmt|fmt-check|vet|test|build|build-cli|install-cli|ui-smoke|golden|browser-install|enter-regression|dmg-boot|clean-machine|first-run|workspace-lifecycle|gen-surface|gen-target-matrix|compile-make]
// Artifact harnesses (clean-machine|first-run|workspace-lifecycle) take --artifact=<desktop-archive.tar.gz>.
// Optional: ./make.vsh compile-make && ./make <target>
//
// vlib build (context.run) only runs non-hyphen args as tasks; flags like
// `--prefix=/usr/local` are skipped by the runner and parsed here manually.
// See: https://github.com/vlang/v/tree/master/vlib/build
// Style: bobatea/make.vsh + examples/build_system/build.vsh

import build
import os

const mods = ['agent_toolkit_core', 'agent_toolkit_cli', 'agent_toolkit_server', 'agent_toolkit_gui', 'desktop_engine', 'desktop']

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

// run_harness executes a scripts/*.vsh harness via VBIN (shebang/env -S is
// unreliable on Windows GHA — see validate.yml). Artifact harnesses read
// the --artifact= knob.
fn run_harness(r string, script string, extra string) {
	args := flag_value('artifact')
	mut cmd := '"${vbin()}" run ${join_path(r, 'scripts', script)}'
	if args.len > 0 {
		cmd += ' "${args}"'
	}
	if extra.len > 0 {
		cmd += ' ${extra}'
	}
	rc := system(cmd)
	if rc != 0 {
		exit(rc)
	}
}

// has_flag reports a bare `--name` runtime flag (vlib/build skips hyphen
// args when selecting tasks, so knobs arrive via os.args).
fn has_flag(name string) bool {
	return '--${name}' in os.args
}

fn need_artifact() string {
	a := flag_value('artifact')
	if a.len == 0 {
		eprintln('missing --artifact=<desktop-archive.tar.gz> (build it via the release.yml pack step or scripts/pack_release_assets.vsh)')
		exit(2)
	}
	return a
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
		println('  ui-smoke | golden | browser-install | enter-regression | dmg-boot')
		println('  tofu | contrast | coverage')
		println('  clean-machine | first-run | workspace-lifecycle  (need --artifact=<desktop-archive.tar.gz>)')
		println('  gen-surface | gen-target-matrix')
		println('  install-cli flags: --prefix=/path  (or PREFIX env; default ~/.local)')
		println('  ui-smoke/golden/enter-regression need build/agent-toolkit-desktop-native (see release.yml build step)')
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
	// The production Desktop shell's tests (#1119) — including the
	// registry reachability gate for critical workflows — live under
	// cmd/agent-toolkit-desktop and are part of the Required CI test path.
	// The suite compiles gg/sokol + pty C interop; the pinned master V build
	// cannot resolve macOS SDK headers on CI runners (the release toolchain
	// builds the same binary fine from the V 0.5.2 zip), so it runs on Linux
	// runners. macOS legs keep covering modules. Packaging validation
	// (#1130) will revisit macOS shell testing.
	if os.user_os() == 'linux' {
		println('==> test cmd/agent-toolkit-desktop')
		rc := vcmd('test ${join_path(r, 'cmd', 'agent-toolkit-desktop')}')
		if rc != 0 {
			exit(rc)
		}
	}
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

context.task(name: 'gen-embedded', help: 'Generate modules/agent_toolkit_core/embedded_data.v', run: fn [r] (_ build.Task) ! {
	gen_vsh := join_path(r, 'scripts', 'generate-embedded-data.vsh')
	if !is_file(gen_vsh) {
		println('gen-embedded: generator not found, skipping')
		return
	}
	println('==> gen-embedded (vsh)')
	rc := vcmd('run ${gen_vsh}')
	if rc != 0 {
		eprintln('gen-embedded vsh failed')
		exit(rc)
	}
})

context.task(name: 'gen-surface', help: 'Emit OpenAPI + CLI help from cli-contract.yaml', run: fn [r] (_ build.Task) ! {
	println('==> gen-surface (vsh)')
	rc := vcmd('run ${join_path(r, 'scripts', 'generate_surface.vsh')}')
	if rc != 0 {
		eprintln('gen-surface failed')
		exit(rc)
	}
})

context.task(name: 'gen-target-matrix', help: 'Emit docs/TARGET_CAPABILITY_MATRIX.md from targets registry', run: fn [r] (_ build.Task) ! {
	println('==> gen-target-matrix (vsh)')
	rc := vcmd('run ${join_path(r, 'scripts', 'generate-target-matrix.vsh')}')
	if rc != 0 {
		eprintln('gen-target-matrix failed')
		exit(rc)
	}
})

context.task(name: 'build-cli', help: 'Build build/agent-toolkit', depends: ['gen-embedded'], run: fn [r] (_ build.Task) ! {
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
		println('Installed ${dest} (V canonical). Rollback: docs/v/archive/rollback.md')
	}
)

context.task(name: 'build-desktop', help: 'Build desktop shell (headless vet; window boot smoke)', run: fn [r] (_ build.Task) ! {
	println('==> build-desktop (desktop shell vet + headless boot)')
	// vet desktop + deps headless — window not opened in CI
	rc1 := vcmd('vet ${join_path(r, 'modules', 'desktop')}')
	if rc1 != 0 {
		exit(rc1)
	}
	rc2 := vcmd('test ${join_path(r, 'modules', 'desktop')}')
	if rc2 != 0 {
		exit(rc2)
	}
	// headless boot smoke via v run of window harness
	tmpdir := join_path(temp_dir(), 'atk-desktop-smoke')
	rmdir_all(tmpdir) or {}
	mkdir_all(tmpdir) or {}
	main_v := join_path(tmpdir, 'main.v')
	write_file(main_v, 'module main\nimport desktop\nimport os\nfn main() { os.setenv("ATK_GUI_HEADLESS", "1", true)\nmut d := desktop.new_desktop(desktop.DesktopBootArgs{})\nd.boot() or { panic(err) }\nprintln(d.smoke_message())\nd.shutdown() or { panic(err) }\nprintln("desktop smoke PASS") }\n') or {}
	rc3 := vcmd('run ${main_v}')
	rmdir_all(tmpdir) or {}
	if rc3 != 0 {
		exit(rc3)
	}
})

context.task(name: 'ui-smoke', help: 'Xvfb UI smoke: panel tour + screenshots (needs desktop binary)', run: fn [r] (_ build.Task) ! {
	println('==> ui-smoke (needs build/agent-toolkit-desktop-native or SMOKE_BIN)')
	run_harness(r, 'ui-smoke.vsh', '')
})

context.task(name: 'golden', help: 'Golden-image compare vs fixtures (ATK_GOLDEN_THEME=ink for ink)', run: fn [r] (_ build.Task) ! {
	println('==> golden compare (needs build/agent-toolkit-desktop-native or SMOKE_BIN)')
	run_harness(r, 'golden.vsh', 'compare')
})

context.task(name: 'browser-install', help: 'GUI install-path acceptance (builds CLI, isolated HOME)', run: fn [r] (_ build.Task) ! {
	println('==> browser-install')
	run_harness(r, 'browser-install.vsh', '')
})

context.task(name: 'enter-regression', help: 'Enter-key regression: keys never kill/hang/blank the app', run: fn [r] (_ build.Task) ! {
	println('==> enter-regression')
	run_harness(r, 'enter-regression.vsh', '')
})

context.task(name: 'dmg-boot', help: 'macOS DMG first-boot (SKIP elsewhere)', run: fn [r] (_ build.Task) ! {
	println('==> dmg-boot')
	run_harness(r, 'dmg-boot.vsh', '')
})

context.task(name: 'tofu', help: 'Tofu detector: bundled-fonts proof + fixture sanity (needs golden-app.log)', run: fn [r] (_ build.Task) ! {
	println('==> tofu')
	run_harness(r, 'check-tofu.vsh', '')
})

context.task(name: 'contrast', help: 'Contrast gate: Paper/Ink WCAG 4.5:1 from tokens.v', run: fn [r] (_ build.Task) ! {
	println('==> contrast')
	run_harness(r, 'check-contrast.vsh', '')
})

context.task(name: 'coverage', help: 'Workflow coverage report (add --check to gate)', run: fn [r] (_ build.Task) ! {
	println('==> coverage')
	run_harness(r, 'gui-coverage.vsh', if has_flag('check') { '--check' } else { '' })
})

context.task(name: 'clean-machine', help: 'Layered clean-machine acceptance (needs --artifact=)', run: fn [r] (_ build.Task) ! {
	need_artifact()
	println('==> clean-machine')
	run_harness(r, 'clean-machine.vsh', '')
})

context.task(name: 'first-run', help: 'Zero-to-working first-run acceptance (needs --artifact=)', run: fn [r] (_ build.Task) ! {
	need_artifact()
	println('==> first-run')
	run_harness(r, 'first-run.vsh', '')
})

context.task(name: 'workspace-lifecycle', help: 'Workspace panel lifecycle acceptance (needs --artifact=)', run: fn [r] (_ build.Task) ! {
	need_artifact()
	println('==> workspace-lifecycle')
	run_harness(r, 'workspace-lifecycle.vsh', '')
})

context.task(name: 'package-desktop-macos', help: 'Package macOS bundle + DMG (cross-build on Linux, real on macos-latest)', run: fn [r] (_ build.Task) ! {
	script := join_path(r, 'distribution', 'desktop', 'macos', 'package.sh')
	if !is_file(script) {
		eprintln('missing ${script}')
		exit(1)
	}
	rc := system('bash ${script}')
	if rc != 0 {
		exit(rc)
	}
})

context.task(name: 'package-desktop-windows', help: 'Package Windows installer (cross-build on Linux, real on windows-latest)', run: fn [r] (_ build.Task) ! {
	script := join_path(r, 'distribution', 'desktop', 'windows', 'package.sh')
	if !is_file(script) {
		eprintln('missing ${script}')
		exit(1)
	}
	rc := system('bash ${script}')
	if rc != 0 {
		exit(rc)
	}
})

context.task(name: 'package-desktop', help: 'Package desktop for current host (macos/windows bundle structure)', run: fn [r] (_ build.Task) ! {
	// cross-build both structures on Linux for CI artifact
	macos := join_path(r, 'distribution', 'desktop', 'macos', 'package.sh')
	windows := join_path(r, 'distribution', 'desktop', 'windows', 'package.sh')
	if is_file(macos) {
		rc1 := system('bash ${macos}')
		if rc1 != 0 {
			exit(rc1)
		}
	}
	if is_file(windows) {
		rc2 := system('bash ${windows}')
		if rc2 != 0 {
			exit(rc2)
		}
	}
})

context.task(name: 'compile-make', help: 'Precompile to ./make (gitignored)', run: fn [r] (_ build.Task) ! {
	rc := system('"${vbin()}" -prod -skip-running ${join_path(r, 'make.vsh')} -o ${join_path(r, 'make')}')
	if rc != 0 {
		exit(rc)
	}
	println('Wrote ${join_path(r, 'make')}')
})

context.run()
