module agent_toolkit_cli

import agent_toolkit_core
import cli

// atk_exec is the shared vlib/cli callback for command nodes.
// Production uses Command.parse → this callback; non-zero domain codes call exit().
fn atk_exec(cmd cli.Command) ! {
	code := invoke_from_cli_cmd(cmd)
	if code != 0 {
		exit(code)
	}
}

fn root_pre_exec(cmd cli.Command) ! {
	if cmd.flags.get_bool('version') or { false } {
		ver := agent_toolkit_core.resolve_toolkit_version()
		code := render(agent_toolkit_core.version_result(ver), mode_from_cmd(cmd))
		exit(code)
	}
}

fn root_exec(cmd cli.Command) ! {
	if cmd.args.len == 0 {
		print(grouped_help_from_cmd(cmd))
		return
	}
	tok := cmd.args[0]
	if tok == 'help' {
		print(grouped_help_from_cmd(cmd))
		return
	}
	if tok.starts_with('-') {
		e := agent_toolkit_core.err_usage_flags('flag.unknown', 'unknown flag: ${tok}')
		exit(render_error(e, mode_from_cmd(cmd)))
	}
	eprintln('Unknown command: ${tok}')
	eprintln("Run 'agent-toolkit help' for usage.")
	eprintln('See docs/CLI_SURFACES.md for consumer vs advanced commands.')
	exit(1)
}

fn mode_from_cmd(cmd cli.Command) agent_toolkit_core.RenderMode {
	if cmd.flags.get_bool('json') or { false } {
		return .json
	}
	if cmd.flags.get_bool('quiet') or { false } {
		return .quiet
	}
	return .human
}

fn grouped_help_from_cmd(cmd cli.Command) string {
	ver := agent_toolkit_core.resolve_toolkit_version()
	mut out := 'agent-toolkit — Composable AI agent toolkit CLI (${ver})\n\n'
	out += cmd.help_message()
	if !out.contains('alias: rollback') {
		out += '\nAliases: uninstall (alias: rollback), devcompanion (alias: dc)\n'
	}
	return out
}

// command_path returns names from the top-level family down to cmd (excludes root).
fn command_path(cmd cli.Command) []string {
	mut names := []string{}
	mut cur := cmd
	for !cur.is_root() {
		names << cur.name
		if isnil(cur.parent) {
			break
		}
		cur = *cur.parent
	}
	mut out := []string{}
	for i := names.len - 1; i >= 0; i-- {
		out << names[i]
	}
	return out
}

fn flags_as_argv(cmd cli.Command) []string {
	mut out := []string{}
	for f in cmd.flags.get_all_found() {
		if f.name in ['help', 'version', 'man'] {
			continue
		}
		if f.name in ['json', 'quiet'] {
			out << '--${f.name}'
			continue
		}
		match f.flag {
			.bool {
				if f.get_bool() or { false } {
					out << '--${f.name}'
				}
			}
			.string {
				v := f.get_string() or { '' }
				if v.len > 0 {
					out << '--${f.name}'
					out << v
				}
			}
			.int {
				out << '--${f.name}'
				out << '${f.get_int() or { 0 }}'
			}
			.float {
				out << '--${f.name}'
				out << '${f.get_float() or { 0.0 }}'
			}
			.string_array {
				for v in f.get_strings() or { []string{} } {
					out << '--${f.name}'
					out << v
				}
			}
			.int_array {
				for v in f.get_ints() or { []int{} } {
					out << '--${f.name}'
					out << '${v}'
				}
			}
			.float_array {
				for v in f.get_floats() or { []f64{} } {
					out << '--${f.name}'
					out << '${v}'
				}
			}
		}
	}
	return out
}

// invoke_from_cli_cmd maps a parsed cli.Command onto execute_command (shared with test dispatch).
fn invoke_from_cli_cmd(cmd cli.Command) int {
	path := command_path(cmd)
	if path.len == 0 {
		return 0
	}
	top := path[0]
	mut rest := []string{}
	if path.len > 1 {
		rest << path[1..]
	}
	rest << flags_as_argv(cmd)
	rest << cmd.args
	for a in rest {
		if a in ['-h', '--help'] {
			print(subcommand_help(top))
			return 0
		}
	}
	return execute_command(top, rest, mode_from_cmd(cmd))
}

// wire_executes attaches atk_exec to every node that has no callback yet.
fn wire_executes(mut cmd cli.Command) {
	if isnil(cmd.execute) {
		cmd.execute = atk_exec
	}
	for mut sub in cmd.commands {
		wire_executes(mut sub)
	}
}

// promote_family_flags marks flags on parents with subcommands as global so
// `loop run name --force` works (vlib only copies Flag.global to children).
fn promote_family_flags(mut cmd cli.Command) {
	if cmd.commands.len > 0 {
		for mut f in cmd.flags {
			if f.name in ['help', 'version', 'man', 'json', 'quiet'] {
				continue
			}
			f.global = true
		}
		for mut sub in cmd.commands {
			promote_family_flags(mut sub)
		}
	}
}
