module agent_toolkit_cli

import agent_toolkit_core

fn parse_doctor_options(args []string) agent_toolkit_core.DoctorOptions {
	mut fix := false
	mut provenance := false
	for a in args {
		if a == '--fix' {
			fix = true
		}
		if a == '--provenance' {
			provenance = true
		}
	}
	return agent_toolkit_core.DoctorOptions{
		fix:        fix
		provenance: provenance
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

fn parse_loop_options(args []string) !agent_toolkit_core.LoopOptions {
	mut sub := ''
	mut workspace_path := ''
	mut name := ''
	mut custom_name := ''
	mut force := false
	mut quiet := false
	mut runner := ''
	mut pack := ''
	mut no_llm := false
	mut dry_run := false
	mut cron := ''
	mut list_mode := false
	mut remove_mode := false
	mut platform := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a == '--json' {
			i++
			continue
		}
		if a == '--quiet' {
			quiet = true
			i++
			continue
		}
		if a == '--force' {
			force = true
			i++
			continue
		}
		if a == '--no-llm' {
			no_llm = true
			i++
			continue
		}
		if a == '--dry-run' {
			dry_run = true
			i++
			continue
		}
		if a == '--list' {
			list_mode = true
			i++
			continue
		}
		if a == '--remove' {
			remove_mode = true
			i++
			continue
		}
		if a in ['--name', '--runner', '--pack', '--workspace', '--cron', '--platform'] {
			if i + 1 >= args.len {
				return error('${a} requires an argument')
			}
			val := args[i + 1]
			match a {
				'--name' { custom_name = val }
				'--runner' { runner = val }
				'--pack' { pack = val }
				'--workspace' { workspace_path = val }
				'--cron' { cron = val }
				'--platform' { platform = val }
				else {}
			}
			i += 2
			continue
		}
		if a.starts_with('--name=') {
			custom_name = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--runner=') {
			runner = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--pack=') {
			pack = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--workspace=') {
			workspace_path = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--cron=') {
			cron = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--platform=') {
			platform = a.all_after('=')
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
		if name.len == 0 {
			name = a
		}
		i++
	}
	if no_llm && runner.len == 0 {
		runner = 'skeleton'
	}
	return agent_toolkit_core.LoopOptions{
		subcommand:     sub
		workspace_path: workspace_path
		name:           name
		custom_name:    custom_name
		force:          force
		quiet:          quiet
		runner:         runner
		pack:           pack
		no_llm:         no_llm
		dry_run:        dry_run
		cron:           cron
		list_mode:      list_mode
		remove_mode:    remove_mode
		platform:       platform
	}
}

fn parse_swarm_options(args []string) !agent_toolkit_core.SwarmOptions {
	mut sub := ''
	mut workspace_path := ''
	mut run_id := ''
	mut gate_id := ''
	mut recipe := ''
	mut backend := ''
	mut reason := ''
	mut dry_run := false
	mut force := false
	mut task_parts := []string{}
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
		if a in ['--recipe', '--backend', '--ui', '--workspace', '--reason'] {
			if i + 1 >= args.len {
				return error('${a} requires an argument')
			}
			val := args[i + 1]
			match a {
				'--recipe' { recipe = val }
				'--backend' { backend = val }
				'--ui' { backend = val }
				'--workspace' { workspace_path = val }
				'--reason' { reason = val }
				else {}
			}
			i += 2
			continue
		}
		if a.starts_with('--recipe=') {
			recipe = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--backend=') || a.starts_with('--ui=') {
			backend = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--workspace=') {
			workspace_path = a.all_after('=')
			i++
			continue
		}
		if a.starts_with('--reason=') {
			reason = a.all_after('=')
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
		if run_id.len == 0 {
			run_id = a
			i++
			continue
		}
		if gate_id.len == 0 && sub in ['approve', 'reject'] {
			gate_id = a
			i++
			continue
		}
		task_parts << a
		i++
	}
	mut task := task_parts.join(' ')
	if sub == 'start' && task.len == 0 {
		task = run_id
		run_id = ''
	}
	return agent_toolkit_core.SwarmOptions{
		subcommand:     sub
		workspace_path: workspace_path
		run_id:         run_id
		gate_id:        gate_id
		recipe:         recipe
		backend:        backend
		task:           task
		reason:         reason
		dry_run:        dry_run
		force:          force
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
