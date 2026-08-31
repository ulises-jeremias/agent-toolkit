module agent_toolkit_cli

import agent_toolkit_core
import os
import agent_toolkit_server
import cli

// run is the library entry used by cmd/agent-toolkit.
// Idiomatic path: ADR-010 bad-flag shim (exit 2), then Command.parse + execute.
pub fn run(args []string) int {
	if code := preflight_bad_flags(args) {
		return code
	}
	mut root := build_root_command()
	// Re-link parents after return-by-value: build_root_command's setup() points
	// subcommand.parent at a stack slot that may move on return (Windows TCC crash
	// on `version` when execute walks parent via command_path / is_root).
	root.setup()
	root.parse(args)
	return 0
}

// dispatch is the return-code adapter for unit tests (Command.parse calls exit()).
// Shares the bad-flag shim, then walks to execute_command without noreturn parse().
pub fn dispatch(args []string) int {
	if code := preflight_bad_flags(args) {
		return code
	}
	return dispatch_walk(args)
}

// preflight_bad_flags is the only hand-rolled argv pass: vlib/cli always exit(1)
// on unknown flags; ADR-010 / cli-contract require exit 2 (see docs/v/archive/vlib-cli-spike.md).
fn preflight_bad_flags(args []string) ?int {
	root := build_root_command()
	mut argv := []string{}
	if args.len > 1 {
		argv = args[1..].clone()
	}
	mode := mode_from_argv(argv)
	mut i := 0
	for i < argv.len && argv[i] in ['--json', '--quiet'] {
		i++
	}
	mut peeled := if i > 0 { argv[i..].clone() } else { argv.clone() }
	if peeled.len == 0 {
		return none
	}
	first := peeled[0]
	if first in ['-h', '--help', 'help', '-V', '--version', 'version'] {
		return none
	}
	if first.starts_with('-') {
		if flag_listed(root.flags, first) {
			return none
		}
		e := agent_toolkit_core.err_usage_flags('flag.unknown', 'unknown flag: ${first}')
		return render_error(e, mode)
	}
	cmd := find_command(root, first) or { return none }
	for a in peeled[1..] {
		if !a.starts_with('-') {
			continue
		}
		if a in ['-h', '--help'] {
			// Rich family help before parse (parity + nested Command parents).
			// Defer prune/cleanup detailed help to domain (swarm_prune_help_text)
			if cmd.name == 'swarm' && peeled.len > 1 && peeled[1] in ['prune', 'cleanup'] {
				continue
			}
			print(subcommand_help(cmd.name))
			return 0
		}
		if a in ['--json', '--quiet'] {
			continue
		}
		if !flag_allowed_on(cmd, a) {
			e := agent_toolkit_core.err_usage_flags('flag.unknown', 'unknown flag: ${a}')
			return render_error(e, mode)
		}
	}
	return none
}

fn dispatch_walk(args []string) int {
	root := build_root_command()
	mut argv := []string{}
	if args.len > 1 {
		argv = args[1..].clone()
	}
	mode := mode_from_argv(argv)
	mut i := 0
	for i < argv.len && argv[i] in ['--json', '--quiet'] {
		i++
	}
	if i > 0 {
		argv = argv[i..].clone()
	}
	if argv.len == 0 {
		print(grouped_help_from(root))
		return 0
	}
	first := argv[0]
	if first in ['-h', '--help', 'help'] {
		if argv.len >= 2 && !argv[1].starts_with('-') {
			name := resolve_command_name(root, argv[1]) or {
				eprintln('Unknown command: ${argv[1]}')
				eprintln("Run 'agent-toolkit help' for usage.")
				return 1
			}
			print(subcommand_help(name))
			return 0
		}
		print(grouped_help_from(root))
		return 0
	}
	if first in ['-V', '--version', 'version'] {
		ver := agent_toolkit_core.resolve_toolkit_version()
		return render(agent_toolkit_core.version_result(ver), mode)
	}
	cmd := find_command(root, first) or {
		eprintln('Unknown command: ${first}')
		eprintln("Run 'agent-toolkit help' for usage.")
		eprintln('See docs/CLI_SURFACES.md for consumer vs advanced commands.')
		return 1
	}
	rest := argv[1..].clone()
	for a in rest {
		if a in ['-h', '--help'] {
			// detailed prune help is rendered by domain; let it flow to execute_command
			if cmd.name == 'swarm' && rest.len > 0 && rest[0] in ['prune', 'cleanup'] {
				break
			}
			print(subcommand_help(cmd.name))
			return 0
		}
	}
	return execute_command(cmd.name, rest, mode)
}

fn execute_command(cmd_name string, rest []string, mode agent_toolkit_core.RenderMode) int {
	if cmd_name == 'version' {
		ver := agent_toolkit_core.resolve_toolkit_version()
		return render(agent_toolkit_core.version_result(ver), mode)
	}
	if cmd_name == 'inventory' {
		snap := agent_toolkit_core.load_inventory() or {
			e := agent_toolkit_core.err_env('root.missing', err.msg())
			return render_error(e, mode)
		}
		return render(agent_toolkit_core.inventory_result(snap), mode)
	}
	if cmd_name == 'matrix' {
		return render(agent_toolkit_core.matrix_result(), mode)
	}
	if cmd_name == 'doctor' {
		opts := parse_doctor_options(rest)
		snap := agent_toolkit_core.run_doctor(opts)
		return render(agent_toolkit_core.doctor_result(snap), mode)
	}
	if cmd_name == 'build' {
		opts := parse_build_options(rest)
		report := agent_toolkit_core.run_build(opts)
		return render(agent_toolkit_core.build_result(report), mode)
	}
	if cmd_name == 'install' {
		opts := parse_install_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_install(opts)
		return render(agent_toolkit_core.install_result(report), mode)
	}
	if cmd_name == 'uninstall' {
		opts := parse_uninstall_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_uninstall(opts)
		return render(agent_toolkit_core.uninstall_result(report), mode)
	}
	if cmd_name == 'diff' {
		opts := parse_diff_options(rest)
		report := agent_toolkit_core.run_diff(opts)
		return render(agent_toolkit_core.diff_result(report), mode)
	}
	if cmd_name == 'update' {
		opts := parse_update_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_update(opts)
		return render(agent_toolkit_core.update_result(report), mode)
	}
	if cmd_name == 'skills' {
		opts := parse_skills_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_skills(opts)
		return render(agent_toolkit_core.skills_result(report), mode)
	}
	if cmd_name == 'mcp' {
		opts := parse_mcp_options(rest)
		report := agent_toolkit_core.run_mcp(opts)
		return render(agent_toolkit_core.mcp_result(report), mode)
	}
	if cmd_name == 'plugin' {
		opts := parse_plugin_options(rest)
		report := agent_toolkit_core.run_plugin(opts)
		return render(agent_toolkit_core.plugin_result(report), mode)
	}
	if cmd_name == 'workspace' {
		opts := parse_workspace_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_workspace(opts)
		return render(agent_toolkit_core.workspace_result(report), mode)
	}
	if cmd_name == 'memory' {
		opts := parse_memory_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_memory(opts)
		return render(agent_toolkit_core.memory_result(report), mode)
	}
	if cmd_name == 'project' {
		opts := parse_project_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_project(opts)
		return render(agent_toolkit_core.project_result(report), mode)
	}
	if cmd_name == 'devcompanion' {
		opts := parse_dc_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_devcompanion(opts)
		return render(agent_toolkit_core.devcompanion_result(report), mode)
	}
	if cmd_name == 'loop' {
		opts := parse_loop_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_loop(opts)
		return render(agent_toolkit_core.loop_result(report), mode)
	}
	if cmd_name == 'swarm' {
		mut opts := parse_swarm_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		if opts.subcommand == 'list' && mode == .json && !opts.json_output {
			opts = agent_toolkit_core.SwarmOptions{
				...opts
				json_output: true
			}
		}
		report := agent_toolkit_core.run_swarm(opts)
		if mode == .json && opts.subcommand in ['runners', 'models'] && report.ok {
			println(report.message)
			return 0
		}
		// For `swarm recipes --json` / `swarm recipe show --json`, emit raw recipe JSON
		// (Python parity: `json.dumps(recipe)` directly, not wrapped in CommandResult).
		if opts.json_output && opts.subcommand in ['recipes', 'recipe'] {
			println(report.message)
			if report.ok {
				return 0
			}
			return agent_toolkit_core.err_user('command.failed', report.message).exit_code()
		}
		if opts.subcommand in ['status', 'list'] && (opts.json_output || mode == .json) {
			trimmed := report.message.trim_space()
			if trimmed.starts_with('{') || trimmed.starts_with('[') {
				println(report.message)
				if report.ok {
					return 0
				}
				return agent_toolkit_core.err_user('command.failed', report.message).exit_code()
			}
		}
		if opts.subcommand == 'list' && opts.json_output {
			println(report.message)
			return if report.ok { 0 } else { 1 }
		}
		// Fallback for __raw_json (incoming parity)
		if mode == .json && report.data['__raw_json'] != '' {
			println(report.data['__raw_json'])
			return 0
		}
		return render(agent_toolkit_core.swarm_result(report), mode)
	}
	if cmd_name == 'tui' {
		eprintln('agent-toolkit tui was removed in 1.23.0 (ADR-030: binary-first consolidation).')
		eprintln('Use the CLI commands directly or the programmatic API: agent-toolkit serve')
		return 1
	}
	if cmd_name == 'serve' {
		opts := parse_serve_options(rest) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_server.run_serve(opts)
		res := agent_toolkit_core.CommandResult{
			command: 'serve'
			ok:      report.ok
			message: report.message
			data:    report.data
		}
		return render(res, mode)
	}
	if cmd_name == 'completion' {
		return run_completion(rest)
	}
	if cmd_name == 'insights' {
		mut opts := parse_insights_options(rest)
		if mode == .json {
			opts = agent_toolkit_core.InsightsOptions{
				...opts
				json_mode: true
			}
		}
		report := agent_toolkit_core.run_insights(opts)
		return render(agent_toolkit_core.insights_result(report), mode)
	}
	if cmd_name == 'release' {
		print(release_help_text())
		return 1
	}
	return render(agent_toolkit_core.not_implemented_result(cmd_name), mode)
}

fn flag_allowed_on(cmd cli.Command, a string) bool {
	if a in ['-h', '--help', '--json', '--quiet'] {
		return true
	}
	if flag_listed(cmd.flags, a) {
		return true
	}
	for sub in cmd.commands {
		if flag_listed(sub.flags, a) {
			return true
		}
	}
	if cmd.name == 'devcompanion' && a in ['-t', '-r'] {
		return true
	}
	return false
}

fn flag_listed(flags []cli.Flag, a string) bool {
	for f in flags {
		long := '--${f.name}'
		if a == long || a.starts_with('${long}=') {
			return true
		}
		if f.abbrev.len > 0 {
			short := '-${f.abbrev}'
			if a == short || a.starts_with('${short}=') {
				return true
			}
		}
	}
	return false
}

fn mode_from_argv(argv []string) agent_toolkit_core.RenderMode {
	for a in argv {
		if a == '--json' {
			return .json
		}
		if a == '--quiet' {
			return .quiet
		}
	}
	return .human
}

// grouped_help renders root help from the cli.Command tree (Consumer / Advanced groups).
pub fn grouped_help() string {
	return grouped_help_from(build_root_command())
}

fn grouped_help_from(root cli.Command) string {
	ver := agent_toolkit_core.resolve_toolkit_version()
	mut out := 'agent-toolkit — Composable AI agent toolkit CLI (${ver})\n\n'
	out += root.help_message()
	if !out.contains('alias: rollback') {
		out += '\nAliases: uninstall (alias: rollback), devcompanion (alias: dc)\n'
	}
	return out
}

pub fn subcommand_help(name string) string {
	if name == 'build' {
		return 'Usage: agent-toolkit build [--check] [--target TARGET] [--product PRODUCT] [--output DIR] [--json]

Compile canonical capabilities into target artifacts (Tier-1 + remaining emitters).

  --check            Dry-run + compare emitted skills/agents to plugins/ (exit 1 on drift)
  --target TARGET    Target id (default: all implemented emitters)
  --product PRODUCT  Product id (default: all products)
  --output DIR       Output directory (default: <repo>/plugins)
  --json             Structured CommandResult JSON

Examples:
  agent-toolkit build --check
  agent-toolkit build --target cursor --product agent-toolkit-core
  AGENT_TOOLKIT_ROOT=/path/to/checkout agent-toolkit build --check
'
	}
	if name == 'install' {
		return 'Usage: agent-toolkit install [--tools LIST] [--dry-run] [--force] [--offline] [--json]

Install profiles for detected or selected AI tools.

  --tools LIST   Comma-separated tools (default: auto-detect)
                 Valid: claude-code, cursor, opencode, copilot, windsurf, pi, muse-code
  --dry-run      Show what would happen without making changes
  --force        Overwrite existing files without prompting
  --offline      Use only bundled/cached data (skip GitHub Release refresh)
  --json         Structured CommandResult JSON

Examples:
  agent-toolkit install --dry-run --offline
  agent-toolkit install --tools cursor,opencode --offline
'
	}
	if name == 'uninstall' {
		return 'Usage: agent-toolkit uninstall [--tools LIST] [--dry-run] [--rollback] [--json]

Remove agent-toolkit profile files recorded in install receipts.
Alias: rollback

  --tools LIST   Comma-separated tools (default: all with receipts)
  --dry-run      Show what would be removed without deleting
  --rollback     Alias for uninstall (removes toolkit-owned files)
  --json         Structured CommandResult JSON
'
	}
	if name == 'diff' {
		return 'Usage: agent-toolkit diff [--target TARGET] [--product PRODUCT] [--json]

Show what would change between freshly compiled output and plugins/.

  --target TARGET    Target platform (default: Tier-1 cursor/claude-code/opencode)
  --product PRODUCT  Product ID to diff (default: all products)
  --json             Structured CommandResult JSON

Examples:
  agent-toolkit diff --target cursor
  agent-toolkit diff --target claude-code --product agent-toolkit-core
'
	}
	if name == 'update' {
		return 'Usage: agent-toolkit update [--tools LIST] [--check] [--pin VERSION] [--json]

Refresh installed profiles from toolkit capability data (not binary self-update).

  --tools LIST   Comma-separated tools (default: auto-detect installed)
  --check        Dry-run — show what would change without writing
  --pin VERSION  Download capability data for a release before updating
  --json         Structured CommandResult JSON

Examples:
  agent-toolkit update --check
  agent-toolkit update --tools cursor,opencode
'
	}
	if name == 'doctor' {
		return 'Usage: agent-toolkit doctor [--fix] [--provenance] [--json]

Read-only health checks by default. --fix allowlists profile refresh only.

  --fix          Attempt auto-repair for missing profiles (runs capability update)
  --provenance   Report capabilities/upstream.lock SHA + expiry (full provenance)
  --json         Structured CommandResult JSON

Exit codes:
  0  no errors detected
  1  one or more errors detected
'
	}
	if name == 'inventory' {
		return 'Usage: agent-toolkit inventory [--json]

List canonical skills, agents, and products from the toolkit tree.

  --json  Structured CommandResult JSON (counts in data)

Set AGENT_TOOLKIT_ROOT to the checkout or wheel data directory if auto-detect fails.
'
	}
	if name == 'matrix' {
		return 'Usage: agent-toolkit matrix [--json]

Print docs/research/platform-capability-matrix.md from the toolkit tree.

  --json  Structured CommandResult JSON

If the matrix file is missing, prints where it is expected (research pipeline).
'
	}
	if name == 'insights' {
		return insights_help_text()
	}
	if name == 'release' {
		return release_help_text()
	}
	if name == 'skills' {
		return agent_toolkit_core.skills_help_text()
	}
	if name == 'mcp' {
		return agent_toolkit_core.mcp_help_text()
	}
	if name == 'plugin' {
		return agent_toolkit_core.plugin_help_text()
	}
	if name == 'workspace' {
		return agent_toolkit_core.workspace_help_text()
	}
	if name == 'project' {
		return agent_toolkit_core.project_help_text()
	}
	if name == 'memory' {
		return agent_toolkit_core.memory_help_text()
	}
	if name == 'devcompanion' {
		return agent_toolkit_core.dc_help_text()
	}
	if name == 'loop' {
		return agent_toolkit_core.loop_help_text()
	}
	if name == 'swarm' {
		return agent_toolkit_core.swarm_help_text()
	}
	if name == 'prune' || name == 'cleanup' {
		return agent_toolkit_core.swarm_prune_help_text()
	}
	if name == 'tui' {
		return 'Usage: agent-toolkit tui

REMOVED in 1.23.0 (ADR-030 — binary-first consolidation).

The interactive TUI is no longer a supported product surface.
Capabilities remain available via:
  - CLI commands (agent-toolkit --help)
  - Programmatic API (agent-toolkit serve -> http://127.0.0.1:3847/api/v1)

See docs/adrs/ADR-030-capability-contract-binary-first.md
'
	}
	if name == 'serve' {
		return 'Usage: agent-toolkit serve [--host HOST] [--port PORT] [--allow-remote] [--auth-token TOKEN] [--no-browser] [--json]

Run the agent-toolkit HTTP server (feature-complete API over core).

  --host HOST       Bind address (default 127.0.0.1; remote requires --allow-remote + token)
  --port PORT       Port (default 3847)
  --allow-remote    Allow binding non-localhost (requires --auth-token)
  --auth-token TEXT Bearer token for remote access (or env AGENT_TOOLKIT_TOKEN)
  --no-browser      Don\'t open browser on start
  --json            Structured CommandResult JSON

Examples:
  agent-toolkit serve
  agent-toolkit serve --port 3847 --no-browser
  agent-toolkit serve --host 0.0.0.0 --allow-remote --auth-token \$TOKEN

See: docs/v/advanced-command-disposition.md
'
	}
	if name == 'completion' {
		return completion_help_text()
	}
	mut c := cli.Command{
		name:        name
		description: '${name} — not implemented in the product V CLI (see docs/v/advanced-command-disposition.md)'
	}
	c.setup()
	return c.help_message()
}

fn insights_subcommand(args []string) string {
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--days', '--output'] {
			// flag with value: skip value if next token is not a flag
			if i + 1 < args.len && !args[i + 1].starts_with('-') {
				i += 2
				continue
			}
			i++
			continue
		}
		if a.starts_with('--days=') || a.starts_with('--output=') {
			i++
			continue
		}
		if a.starts_with('-') {
			i++
			continue
		}
		return a
	}
	return ''
}

fn insights_help_text() string {
	return agent_toolkit_core.insights_help_text()
}

fn release_help_text() string {
	return 'release — Generate release artifacts (removed from V; #527).

Maintainer artifact generation belongs in GitHub Actions / docs/RELEASING.md, not the runtime CLI.

See docs/v/advanced-command-disposition.md.
'
}
