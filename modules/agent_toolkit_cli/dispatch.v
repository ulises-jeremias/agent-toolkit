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
		opts := parse_doctor_options(argv[1..])
		snap := agent_toolkit_core.run_doctor(opts)
		return render(agent_toolkit_core.doctor_result(snap), mode)
	}
	if cmd_name == 'build' {
		opts := parse_build_options(argv[1..])
		report := agent_toolkit_core.run_build(opts)
		return render(agent_toolkit_core.build_result(report), mode)
	}
	if cmd_name == 'install' {
		opts := parse_install_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_install(opts)
		return render(agent_toolkit_core.install_result(report), mode)
	}
	if cmd_name == 'uninstall' {
		opts := parse_uninstall_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_uninstall(opts)
		return render(agent_toolkit_core.uninstall_result(report), mode)
	}
	if cmd_name == 'diff' {
		opts := parse_diff_options(argv[1..])
		report := agent_toolkit_core.run_diff(opts)
		return render(agent_toolkit_core.diff_result(report), mode)
	}
	if cmd_name == 'update' {
		opts := parse_update_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_update(opts)
		return render(agent_toolkit_core.update_result(report), mode)
	}
	if cmd_name == 'skills' {
		opts := parse_skills_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_skills(opts)
		return render(agent_toolkit_core.skills_result(report), mode)
	}
	if cmd_name == 'mcp' {
		opts := parse_mcp_options(argv[1..])
		report := agent_toolkit_core.run_mcp(opts)
		return render(agent_toolkit_core.mcp_result(report), mode)
	}
	if cmd_name == 'plugin' {
		opts := parse_plugin_options(argv[1..])
		report := agent_toolkit_core.run_plugin(opts)
		return render(agent_toolkit_core.plugin_result(report), mode)
	}
	if cmd_name == 'workspace' {
		opts := parse_workspace_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_workspace(opts)
		return render(agent_toolkit_core.workspace_result(report), mode)
	}
	if cmd_name == 'memory' {
		opts := parse_memory_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_memory(opts)
		return render(agent_toolkit_core.memory_result(report), mode)
	}
	if cmd_name == 'project' {
		opts := parse_project_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_project(opts)
		return render(agent_toolkit_core.project_result(report), mode)
	}
	if cmd_name == 'devcompanion' {
		opts := parse_dc_options(argv[1..]) or {
			e := agent_toolkit_core.err_usage_flags('flag.invalid', err.msg())
			return render_error(e, mode)
		}
		report := agent_toolkit_core.run_devcompanion(opts)
		return render(agent_toolkit_core.devcompanion_result(report), mode)
	}
	return render(agent_toolkit_core.not_implemented_result(cmd_name), mode)
}

fn parse_doctor_options(args []string) agent_toolkit_core.DoctorOptions {
	mut fix := false
	for a in args {
		if a == '--fix' {
			fix = true
		}
	}
	return agent_toolkit_core.DoctorOptions{
		fix: fix
	}
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

fn parse_install_options(args []string) !agent_toolkit_core.InstallOptions {
	mut dry_run := false
	mut force := false
	mut offline := false
	mut tools_raw := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			i++
			continue
		}
		if a == '--dry-run' {
			dry_run = true
			i++
			continue
		}
		if a == '--force' {
			force = true
			i++
			continue
		}
		if a == '--offline' {
			offline = true
			i++
			continue
		}
		if a == '--tools' {
			if i + 1 >= args.len {
				return error('--tools requires an argument')
			}
			tools_raw = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--tools=') {
			tools_raw = a.all_after('=')
			i++
			continue
		}
		i++
	}
	mut tools := []string{}
	if tools_raw.len > 0 {
		for part in tools_raw.split(',') {
			t := part.trim_space()
			if t.len > 0 {
				tools << t
			}
		}
	}
	return agent_toolkit_core.InstallOptions{
		tools:   tools
		dry_run: dry_run
		force:   force
		offline: offline
	}
}

fn parse_uninstall_options(args []string) !agent_toolkit_core.UninstallOptions {
	mut dry_run := false
	mut tools_raw := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			i++
			continue
		}
		if a == '--dry-run' {
			dry_run = true
			i++
			continue
		}
		if a == '--rollback' {
			// Alias semantics: uninstall with side effects (not dry-run).
			dry_run = false
			i++
			continue
		}
		if a == '--tools' {
			if i + 1 >= args.len {
				return error('--tools requires an argument')
			}
			tools_raw = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--tools=') {
			tools_raw = a.all_after('=')
			i++
			continue
		}
		i++
	}
	mut tools := []string{}
	if tools_raw.len > 0 {
		for part in tools_raw.split(',') {
			t := part.trim_space()
			if t.len > 0 {
				tools << t
			}
		}
	}
	return agent_toolkit_core.UninstallOptions{
		tools:   tools
		dry_run: dry_run
	}
}

fn parse_diff_options(args []string) agent_toolkit_core.DiffOptions {
	mut target := ''
	mut product := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
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
		i++
	}
	return agent_toolkit_core.DiffOptions{
		target:  target
		product: product
	}
}

fn parse_update_options(args []string) !agent_toolkit_core.UpdateOptions {
	mut check_only := false
	mut tools_raw := ''
	mut pin := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			i++
			continue
		}
		if a == '--check' {
			check_only = true
			i++
			continue
		}
		if a == '--tools' {
			if i + 1 >= args.len {
				return error('--tools requires an argument')
			}
			tools_raw = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--tools=') {
			tools_raw = a.all_after('=')
			i++
			continue
		}
		if a == '--pin' {
			if i + 1 >= args.len {
				return error('--pin requires an argument')
			}
			pin = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--pin=') {
			pin = a.all_after('=')
			i++
			continue
		}
		i++
	}
	mut tools := []string{}
	if tools_raw.len > 0 {
		for part in tools_raw.split(',') {
			t := part.trim_space()
			if t.len > 0 {
				tools << t
			}
		}
	}
	return agent_toolkit_core.UpdateOptions{
		tools:      tools
		check_only: check_only
		pin:        pin
	}
}

fn parse_skills_options(args []string) !agent_toolkit_core.SkillsOptions {
	mut sub := ''
	mut domain := ''
	mut tools_raw := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			i++
			continue
		}
		if a == '--domain' {
			if i + 1 >= args.len {
				return error('--domain requires an argument')
			}
			domain = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--domain=') {
			domain = a.all_after('=')
			i++
			continue
		}
		if a == '--tools' {
			if i + 1 >= args.len {
				return error('--tools requires an argument')
			}
			tools_raw = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--tools=') {
			tools_raw = a.all_after('=')
			i++
			continue
		}
		if !a.starts_with('-') && sub.len == 0 {
			sub = a
			i++
			continue
		}
		i++
	}
	mut tools := []string{}
	if tools_raw.len > 0 {
		for part in tools_raw.split(',') {
			t := part.trim_space()
			if t.len > 0 {
				tools << t
			}
		}
	}
	return agent_toolkit_core.SkillsOptions{
		subcommand: sub
		domain:     domain
		tools:      tools
	}
}

fn parse_mcp_options(args []string) agent_toolkit_core.McpOptions {
	mut sub := ''
	mut provider := ''
	mut offline := false
	for a in args {
		if a in ['--json', '--quiet'] {
			continue
		}
		if a == '--offline' {
			offline = true
			continue
		}
		if a.starts_with('-') {
			continue
		}
		if sub.len == 0 {
			sub = a
			continue
		}
		if provider.len == 0 {
			provider = a
		}
	}
	return agent_toolkit_core.McpOptions{
		subcommand: sub
		provider:   provider
		offline:    offline
	}
}

fn parse_workspace_options(args []string) !agent_toolkit_core.WorkspaceOptions {
	mut sub := ''
	mut dir := ''
	mut name := ''
	mut workspace_path := ''
	mut explain := false
	mut json_out := false
	mut arg := ''
	mut profile := ''
	mut pack := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			if a == '--json' {
				json_out = true
			}
			i++
			continue
		}
		if a == '--explain' {
			explain = true
			i++
			continue
		}
		if a in ['--dir', '--name', '--workspace', '--profile', '--pack'] {
			if i + 1 >= args.len {
				return error('${a} requires an argument')
			}
			val := args[i + 1]
			match a {
				'--dir' { dir = val }
				'--name' { name = val }
				'--workspace' { workspace_path = val }
				'--profile' { profile = val }
				'--pack' { pack = val }
				else {}
			}
			i += 2
			continue
		}
		if a.starts_with('--dir=') {
			dir = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--name=') {
			name = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--workspace=') {
			workspace_path = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--profile=') {
			profile = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--pack=') {
			pack = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('-') {
			i++
			continue
		}
		if sub.len == 0 {
			sub = a
			i++
			continue
		}
		if arg.len == 0 {
			arg = a
		}
		i++
	}
	return agent_toolkit_core.WorkspaceOptions{
		subcommand:     sub
		dir:            dir
		name:           name
		workspace_path: workspace_path
		explain:        explain
		json_out:       json_out
		arg:            arg
		profile:        profile
		pack:           pack
	}
}

fn parse_project_options(args []string) !agent_toolkit_core.ProjectOptions {
	mut sub := ''
	mut workspace_path := ''
	mut arg := ''
	mut ssh := false
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			i++
			continue
		}
		if a == '--ssh' {
			ssh = true
			i++
			continue
		}
		if a == '--workspace' {
			if i + 1 >= args.len {
				return error('${a} requires an argument')
			}
			workspace_path = args[i + 1]
			i += 2
			continue
		}
		if a.starts_with('--workspace=') {
			workspace_path = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('-') {
			i++
			continue
		}
		if sub.len == 0 {
			sub = a
			i++
			continue
		}
		if arg.len == 0 {
			arg = a
		}
		i++
	}
	return agent_toolkit_core.ProjectOptions{
		subcommand:     sub
		workspace_path: workspace_path
		arg:            arg
		ssh:            ssh
	}
}

fn parse_dc_options(args []string) !agent_toolkit_core.DevcompanionOptions {
	mut sub := ''
	mut workspace_path := ''
	mut project := ''
	mut template := ''
	mut request := ''
	mut job_id := ''
	mut no_llm := false
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			i++
			continue
		}
		if a == '--no-llm' {
			no_llm = true
			i++
			continue
		}
		if a in ['--template', '-t', '--request', '-r', '--id', '--workspace'] {
			if i + 1 >= args.len {
				return error('${a} requires an argument')
			}
			val := args[i + 1]
			match a {
				'--template', '-t' { template = val }
				'--request', '-r' { request = val }
				'--id' { job_id = val }
				'--workspace' { workspace_path = val }
				else {}
			}
			i += 2
			continue
		}
		if a.starts_with('--template=') {
			template = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--request=') {
			request = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--id=') {
			job_id = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--workspace=') {
			workspace_path = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('-') {
			i++
			continue
		}
		if sub.len == 0 {
			sub = a
			i++
			continue
		}
		if sub == 'queue' && project.len == 0 {
			project = a
		} else if sub == 'done' && job_id.len == 0 {
			job_id = a
		}
		i++
	}
	mut arg := project
	if sub == 'done' && job_id.len > 0 {
		arg = job_id
	}
	return agent_toolkit_core.DevcompanionOptions{
		subcommand:     sub
		workspace_path: workspace_path
		arg:            arg
		template:       template
		request:        request
		job_id:         job_id
		no_llm:         no_llm
	}
}

fn parse_plugin_options(args []string) agent_toolkit_core.PluginOptions {
	mut sub := ''
	for a in args {
		if a in ['--json', '--quiet'] {
			continue
		}
		if a.starts_with('-') {
			continue
		}
		if sub.len == 0 {
			sub = a
		}
	}
	return agent_toolkit_core.PluginOptions{
		subcommand: sub
	}
}

fn parse_memory_options(args []string) !agent_toolkit_core.MemoryOptions {
	mut sub := ''
	mut entry_type := ''
	mut title := ''
	mut workspace_path := ''
	mut fix := false
	mut stale_after := 0
	mut done := false
	mut rest := []string{}
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--json', '--quiet'] {
			i++
			continue
		}
		if a == '--fix' {
			fix = true
			i++
			continue
		}
		if a == '--done' {
			done = true
			i++
			continue
		}
		if a in ['--type', '--title', '--workspace', '--stale-after'] {
			if i + 1 >= args.len {
				return error('${a} requires an argument')
			}
			val := args[i + 1]
			match a {
				'--type' { entry_type = val }
				'--title' { title = val }
				'--workspace' { workspace_path = val }
				'--stale-after' { stale_after = val.int() }
				else {}
			}
			i += 2
			continue
		}
		if a.starts_with('--type=') {
			entry_type = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--title=') {
			title = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--workspace=') {
			workspace_path = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--stale-after=') {
			stale_after = a.all_after('=').int()
			i++
			continue
		}
		if a.starts_with('-') {
			i++
			continue
		}
		if sub.len == 0 {
			sub = a
			i++
			continue
		}
		rest << a
		i++
	}
	return agent_toolkit_core.MemoryOptions{
		subcommand:     sub
		entry_type:     entry_type
		title:          title
		content:        rest.join(' ')
		query:          rest.join(' ')
		workspace_path: workspace_path
		fix:            fix
		stale_after:    stale_after
		show_done:      done
	}
}

fn allowed_flag(cmd string, a string) bool {
	if a in ['-h', '--help', '--json', '--quiet'] {
		return true
	}
	if cmd == 'doctor' && a in ['--fix', '--provenance'] {
		return true
	}
	if cmd == 'install' {
		if a in ['--dry-run', '--force', '--offline'] {
			return true
		}
		if a.starts_with('--tools') {
			return true
		}
	}
	if cmd == 'uninstall' {
		if a in ['--dry-run', '--rollback'] {
			return true
		}
		if a.starts_with('--tools') {
			return true
		}
	}
	if cmd == 'update' {
		if a == '--check' {
			return true
		}
		if a.starts_with('--tools') || a.starts_with('--pin') {
			return true
		}
	}
	if cmd == 'skills' {
		if a.starts_with('--domain') || a.starts_with('--tools') {
			return true
		}
	}
	if cmd == 'mcp' {
		if a == '--offline' {
			return true
		}
	}
	if cmd == 'diff' {
		if a.starts_with('--target') || a.starts_with('--product') {
			return true
		}
	}
	if cmd == 'build' {
		if a == '--check' {
			return true
		}
		if a.starts_with('--target') || a.starts_with('--product') || a.starts_with('--output') {
			return true
		}
	}
	if cmd == 'workspace' {
		if a in ['--explain', '--dir', '--name', '--workspace', '--profile', '--pack'] {
			return true
		}
		if a.starts_with('--dir') || a.starts_with('--name') || a.starts_with('--workspace')
			|| a.starts_with('--profile') || a.starts_with('--pack') {
			return true
		}
	}
	if cmd == 'memory' {
		if a in ['--fix', '--done'] {
			return true
		}
		if a.starts_with('--type') || a.starts_with('--title') || a.starts_with('--workspace')
			|| a.starts_with('--stale-after') {
			return true
		}
	}
	if cmd == 'project' {
		if a in ['--ssh', '--workspace'] {
			return true
		}
		if a.starts_with('--workspace') {
			return true
		}
	}
	if cmd == 'devcompanion' {
		if a in ['--no-llm', '--template', '--request', '--id', '--workspace', '-t', '-r'] {
			return true
		}
		if a.starts_with('--template') || a.starts_with('--request') || a.starts_with('--id')
			|| a.starts_with('--workspace') {
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
		description: 'Composable AI agent toolkit CLI\n\nSee docs/CLI_SURFACES.md for consumer vs advanced commands.'
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

Compile canonical capabilities into target artifacts (Tier-1 + remaining emitters).

  --check            Dry-run + compare emitted skills/agents to plugins/ (exit 1 on drift)
  --target TARGET    Target id (default: all implemented emitters)
  --product PRODUCT  Product id (default: all products)
  --output DIR       Output directory (default: <repo>/plugins)
	--json             Structured CommandResult JSON
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
'
	}
	if name == 'update' {
		return 'Usage: agent-toolkit update [--tools LIST] [--check] [--pin VERSION] [--json]

Refresh installed profiles from toolkit capability data (not binary self-update).

  --tools LIST   Comma-separated tools (default: auto-detect installed)
  --check        Dry-run — show what would change without writing
  --pin VERSION  Download capability data for a release before updating
  --json         Structured CommandResult JSON
'
	}
	if name == 'doctor' {
		return 'Usage: agent-toolkit doctor [--fix] [--json]

Read-only health checks by default. --fix allowlists profile refresh only.

  --fix   Attempt auto-repair for missing profiles (runs capability update)
  --json  Structured CommandResult JSON
'
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
	mut c := cli.Command{
		name:        name
		description: '${name} — not yet implemented in V; use the Python package for unfinished advanced commands (docs/v/cutover.md)'
	}
	c.setup()
	return c.help_message()
}
