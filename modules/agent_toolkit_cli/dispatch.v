module agent_toolkit_cli

import agent_toolkit_core
import cli

// run is the library entry used by cmd/agent-toolkit.
pub fn run(args []string) int {
	return dispatch(args)
}

// dispatch implements the root command contract (CLI_SURFACES consumer/advanced split).
pub fn dispatch(args []string) int {
	// Drop program name
	mut argv := []string{}
	if args.len > 1 {
		argv = args[1..].clone()
	}
	mode := mode_from_argv(argv)
	if argv.len == 0 || argv[0] in ['-h', '--help', 'help'] {
		print(grouped_help())
		return 0
	}
	if argv[0] in ['-V', '--version', 'version'] {
		ver := agent_toolkit_core.resolve_toolkit_version()
		return render(agent_toolkit_core.version_result(ver), mode)
	}
	// Bad flags before a command (argparse parity → exit 2)
	if argv[0].starts_with('-')
		&& argv[0] !in ['-h', '--help', '-V', '--version', '--json', '--quiet'] {
		e := agent_toolkit_core.err_usage_flags('flag.unknown', 'unknown flag: ${argv[0]}')
		return render_error(e, mode)
	}
	cmd_name := resolve_alias(argv[0])
	if !is_known_command(cmd_name) {
		eprintln('Unknown command: ${argv[0]}')
		eprintln("Run 'agent-toolkit help' for usage.")
		eprintln('See docs/CLI_SURFACES.md for consumer vs advanced commands.')
		return 1
	}
	// Remaining tokens may include unknown flags → exit 2
	for a in argv[1..] {
		if a.starts_with('-') && !allowed_flag(cmd_name, a) {
			e := agent_toolkit_core.err_usage_flags('flag.unknown', 'unknown flag: ${a}')
			return render_error(e, mode)
		}
		if a in ['-h', '--help'] {
			print(subcommand_help(cmd_name))
			return 0
		}
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
		snap := agent_toolkit_core.run_doctor_readonly()
		return render(agent_toolkit_core.doctor_result(snap), mode)
	}
	if cmd_name == 'build' {
		opts := parse_build_options(argv[1..])
		report := agent_toolkit_core.run_build(opts)
		return render(agent_toolkit_core.build_result(report), mode)
	}
	return render(agent_toolkit_core.not_implemented_result(cmd_name), mode)
}

fn parse_build_options(args []string) agent_toolkit_core.BuildOptions {
	mut check := false
	mut write_files := true
	mut target := ''
	mut product := ''
	mut output_dir := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a == '--check' {
			check = true
			write_files = false
			i++
			continue
		}
		if a == '--target' && i + 1 < args.len {
			target = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--target=') {
			target = a.all_after('=')
			i++
			continue
		}
		if a == '--product' && i + 1 < args.len {
			product = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--product=') {
			product = a.all_after('=')
			i++
			continue
		}
		if a == '--output' && i + 1 < args.len {
			output_dir = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--output=') {
			output_dir = a.all_after('=')
			i++
			continue
		}
		i++
	}
	return agent_toolkit_core.BuildOptions{
		check:       check
		target:      target
		product:     product
		output_dir:  output_dir
		write_files: write_files
	}
}

fn allowed_flag(cmd string, a string) bool {
	if a in ['-h', '--help', '--json', '--quiet'] {
		return true
	}
	if cmd == 'doctor' && a in ['--fix', '--provenance'] {
		return true
	}
	if cmd == 'build' {
		if a in ['--check'] {
			return true
		}
		if a.starts_with('--target') || a.starts_with('--product') || a.starts_with('--output') {
			return true
		}
	}
	return false
}

fn resolve_alias(name string) string {
	return match name {
		'dc' { 'devcompanion' }
		'rollback' { 'uninstall' }
		else { name }
	}
}

fn is_known_command(name string) bool {
	for c in consumer_commands() {
		if c == name {
			return true
		}
	}
	for c in advanced_commands() {
		if c == name {
			return true
		}
	}
	return false
}

fn consumer_commands() []string {
	return ['install', 'update', 'uninstall', 'doctor', 'diff', 'skills', 'mcp', 'plugin']
}

fn advanced_commands() []string {
	return ['loop', 'workspace', 'memory', 'project', 'devcompanion', 'insights', 'build',
		'inventory', 'matrix', 'release', 'swarm']
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

fn grouped_help() string {
	mut root := cli.Command{
		name:        'agent-toolkit'
		description: 'Composable AI agent toolkit CLI (V experimental)\n\nSee docs/CLI_SURFACES.md for consumer vs advanced commands.'
		version:     agent_toolkit_core.resolve_toolkit_version()
		commands:    help_commands()
	}
	root.setup()
	return root.help_message()
}

fn help_commands() []cli.Command {
	mut cmds := []cli.Command{}
	cmds << cli.Command{
		name:        'version'
		description: 'Print agent-toolkit version'
	}
	for name in consumer_commands() {
		cmds << cli.Command{
			name:        name
			description: '${name} (consumer)'
			group:       'Consumer'
		}
	}
	for name in advanced_commands() {
		mut c := cli.Command{
			name:        name
			description: '${name} (advanced)'
			group:       'Advanced'
		}
		if name == 'devcompanion' {
			c.alias = 'dc'
		}
		if name == 'uninstall' {
			c.description = 'uninstall / rollback (consumer alias rollback)'
		}
		cmds << c
	}
	return cmds
}

fn subcommand_help(name string) string {
	if name == 'build' {
		return 'Usage: agent-toolkit build [--check] [--target TARGET] [--product PRODUCT] [--output DIR] [--json]

Compile canonical capabilities into Tier-1 target artifacts (cursor, claude-code, opencode).

  --check            Dry-run + compare emitted skills/agents to plugins/ (exit 1 on drift)
  --target TARGET    Tier-1 target id (default: all Tier-1)
  --product PRODUCT  Product id (default: all products)
  --output DIR       Output directory (default: <repo>/plugins)
  --json             Structured CommandResult JSON
'
	}
	mut c := cli.Command{
		name:        name
		description: '${name} — not yet implemented in V experimental binary'
	}
	c.setup()
	return c.help_message()
}
