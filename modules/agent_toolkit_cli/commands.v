module agent_toolkit_cli

import agent_toolkit_core
import cli

// build_root_command constructs the vlib/cli Command tree (docs/v/vlib-cli-spike.md).
// Groups mirror docs/CLI_SURFACES.md. Nested families match cli_groups.v style.
// Production dispatch uses Command.parse + execute callbacks (see handlers.v).
pub fn build_root_command() cli.Command {
	ver := agent_toolkit_core.resolve_toolkit_version()
	mut app := cli.Command{
		name:        'agent-toolkit'
		description: 'Composable AI agent toolkit CLI (${ver})'
		version:     ver
		posix_mode:  true
		sort_flags:  false
		sort_commands: false
		pre_execute: root_pre_exec
		execute:     root_exec
		defaults:    struct {
			help:    true
			version: false // custom -V / version command (contract: agent-toolkit <ver>)
			man:     false
		}
		examples: [
			'$ agent-toolkit install --dry-run --offline',
			'$ agent-toolkit doctor --json',
			'$ agent-toolkit skills list',
			'$ agent-toolkit workspace context --json',
		]
		learn_more: 'Run `agent-toolkit <command> --help` for details.\nConsumer vs advanced: docs/CLI_SURFACES.md'
	}
	app.add_flag(cli.Flag{
		flag:        .bool
		name:        'json'
		description: 'Structured CommandResult JSON (most commands)'
		global:      true
	})
	app.add_flag(cli.Flag{
		flag:        .bool
		name:        'quiet'
		description: 'Suppress human output'
		global:      true
	})
	app.add_flag(cli.Flag{
		flag:        .bool
		name:        'version'
		abbrev:      'V'
		description: 'Print version'
	})
	app.add_commands([
		version_command(),
		install_command(),
		update_command(),
		uninstall_command(),
		doctor_command(),
		diff_command(),
		skills_command(),
		mcp_command(),
		plugin_command(),
		completion_command(),
		loop_command(),
		workspace_command(),
		memory_command(),
		project_command(),
		devcompanion_command(),
		insights_command(),
		build_command(),
		inventory_command(),
		matrix_command(),
		release_command(),
		swarm_command(),
	])
	promote_family_flags(mut app)
	wire_executes(mut app)
	app.setup()
	return app
}

fn version_command() cli.Command {
	return cli.Command{
		name:        'version'
		description: 'Print version'
		group:       'Meta'
	}
}

fn install_command() cli.Command {
	return cli.Command{
		name:        'install'
		description: 'Install profiles for detected AI tools'
		group:       'Consumer commands'
		flags:       [
			cli.Flag{
				flag:        .string
				name:        'tools'
				description: 'Comma-separated tools (default: auto-detect)'
			},
			cli.Flag{
				flag:        .bool
				name:        'dry-run'
				description: 'Show what would happen without making changes'
			},
			cli.Flag{
				flag:        .bool
				name:        'force'
				description: 'Overwrite existing files without prompting'
			},
			cli.Flag{
				flag:        .bool
				name:        'offline'
				description: 'Use only bundled/cached data'
			},
		]
	}
}

fn update_command() cli.Command {
	return cli.Command{
		name:        'update'
		description: 'Refresh installed profiles from latest toolkit data'
		group:       'Consumer commands'
		flags:       [
			cli.Flag{
				flag:        .string
				name:        'tools'
				description: 'Comma-separated tools'
			},
			cli.Flag{
				flag:        .bool
				name:        'check'
				description: 'Dry-run — show what would change without writing'
			},
			cli.Flag{
				flag:        .string
				name:        'pin'
				description: 'Download capability data for a release before updating'
			},
		]
	}
}

fn uninstall_command() cli.Command {
	return cli.Command{
		name:        'uninstall'
		alias:       'rollback'
		description: 'Remove toolkit-owned files using install receipts (alias: rollback)'
		group:       'Consumer commands'
		flags:       [
			cli.Flag{
				flag:        .string
				name:        'tools'
				description: 'Comma-separated tools'
			},
			cli.Flag{
				flag:        .bool
				name:        'dry-run'
				description: 'Show what would be removed without deleting'
			},
			cli.Flag{
				flag:        .bool
				name:        'rollback'
				description: 'Alias for uninstall (removes toolkit-owned files)'
			},
		]
	}
}

fn doctor_command() cli.Command {
	return cli.Command{
		name:        'doctor'
		description: 'Check system health and tool availability'
		group:       'Consumer commands'
		flags:       [
			cli.Flag{
				flag:        .bool
				name:        'fix'
				description: 'Attempt auto-repair for missing profiles'
			},
			cli.Flag{
				flag:        .bool
				name:        'provenance'
				description: 'Report capabilities/upstream.lock presence'
			},
		]
	}
}

fn diff_command() cli.Command {
	return cli.Command{
		name:        'diff'
		description: 'Show changes vs currently installed plugin bundles'
		group:       'Consumer commands'
		flags:       [
			cli.Flag{
				flag:        .string
				name:        'target'
				description: 'Target platform'
			},
			cli.Flag{
				flag:        .string
				name:        'product'
				description: 'Product ID to diff'
			},
		]
	}
}

fn skills_command() cli.Command {
	// Flags live on the parent only; promote_family_flags marks them global so
	// `skills list --domain X` works without duplicating names on children.
	return cli.Command{
		name:        'skills'
		description: 'Skill management: sync, list, validate'
		group:       'Consumer commands'
		commands:    [
			cli.Command{
				name:        'list'
				description: 'List skills grouped by domain'
			},
			cli.Command{
				name:        'sync'
				description: 'Sync skills to tool-specific directories'
			},
			cli.Command{
				name:        'validate'
				description: 'Validate SKILL.md frontmatter'
			},
		]
		flags:       [
			cli.Flag{
				flag:        .string
				name:        'domain'
				description: 'Filter by domain (list)'
			},
			cli.Flag{
				flag:        .string
				name:        'tools'
				description: 'Comma-separated tools (sync)'
			},
		]
	}
}

fn mcp_command() cli.Command {
	return cli.Command{
		name:        'mcp'
		description: 'MCP provider management: setup, list, doctor'
		group:       'Consumer commands'
		commands:    [
			cli.Command{ name: 'list', description: 'List MCP providers' },
			cli.Command{ name: 'setup', description: 'Interactive MCP setup', usage: '<provider>' },
			cli.Command{ name: 'health', description: 'Check provider health' },
			cli.Command{ name: 'doctor', description: 'MCP doctor checks' },
			cli.Command{ name: 'uninstall', description: 'Remove MCP provider config', usage: '<provider>' },
		]
		flags:       [
			cli.Flag{
				flag:        .bool
				name:        'offline'
				description: 'Skip network lookups'
			},
		]
	}
}

fn plugin_command() cli.Command {
	return cli.Command{
		name:        'plugin'
		description: 'Plugin bundle management: sync, check'
		group:       'Consumer commands'
		commands:    [
			cli.Command{ name: 'sync', description: 'Sync canonical agents/skills into plugin bundles' },
			cli.Command{ name: 'check', description: 'Verify plugin bundles are in sync' },
		]
	}
}

fn completion_command() cli.Command {
	return cli.Command{
		name:        'completion'
		description: 'Emit bash/zsh/fish/PowerShell completion scripts'
		group:       'Consumer commands'
		usage:       '<bash|zsh|fish|powershell>'
		commands:    [
			cli.Command{ name: 'bash', description: 'Bash completion script' },
			cli.Command{ name: 'zsh', description: 'Zsh completion script' },
			cli.Command{ name: 'fish', description: 'Fish completion script' },
			cli.Command{ name: 'powershell', description: 'PowerShell completion script' },
		]
	}
}

fn loop_command() cli.Command {
	return cli.Command{
		name:        'loop'
		description: 'Loop engineering: init, run, status, audit, cost, schedule, sync'
		group:       'Advanced commands'
		commands:    [
			cli.Command{ name: 'init', description: 'Scaffold a loop from a template', usage: '<pattern>' },
			cli.Command{ name: 'run', description: 'Execute one loop iteration', usage: '<name>' },
			cli.Command{ name: 'status', description: 'Show loop instances' },
			cli.Command{ name: 'audit', description: 'Review past runs', usage: '<name>' },
			cli.Command{ name: 'cost', description: 'Estimate loop cost', usage: '<name>' },
			cli.Command{ name: 'schedule', description: 'Install systemd/launchd timer', usage: '<name>' },
			cli.Command{ name: 'sync', description: 'Sync loop templates' },
			cli.Command{ name: 'list', alias: 'ls', description: 'List loop instances' },
			cli.Command{ name: 'templates', description: 'List available templates' },
		]
		flags:       loop_flags()
	}
}

fn loop_flags() []cli.Flag {
	return [
		cli.Flag{ flag: .bool, name: 'force', description: 'Force overwrite' },
		cli.Flag{ flag: .bool, name: 'no-llm', description: 'Use skeleton runner' },
		cli.Flag{ flag: .bool, name: 'dry-run', description: 'Plan without applying' },
		cli.Flag{ flag: .bool, name: 'list', description: 'List mode for schedule' },
		cli.Flag{ flag: .bool, name: 'remove', description: 'Remove scheduled timer' },
		cli.Flag{ flag: .bool, name: 'status', description: 'Schedule status (legacy flag)' },
		cli.Flag{ flag: .string, name: 'name', description: 'Custom loop name' },
		cli.Flag{ flag: .string, name: 'runner', description: 'Runner backend' },
		cli.Flag{ flag: .string, name: 'pack', description: 'Pack name' },
		cli.Flag{ flag: .string, name: 'workspace', description: 'Workspace path' },
		cli.Flag{ flag: .string, name: 'cron', description: 'Cron expression' },
	]
}

fn workspace_command() cli.Command {
	return cli.Command{
		name:        'workspace'
		description: 'Workspace scaffolding: init, context, sync'
		group:       'Advanced commands'
		commands:    [
			cli.Command{ name: 'init', description: 'Scaffold a new harness workspace' },
			cli.Command{ name: 'context', description: 'Output a session state snapshot' },
			cli.Command{ name: 'sync', description: 'Sync workspace knowledge' },
			cli.Command{ name: 'use-persona', description: 'Activate a work mode', usage: '<name>' },
			cli.Command{ name: 'handoff', description: 'Handoff between personas' },
			cli.Command{ name: 'history', description: 'Show persona history' },
			cli.Command{ name: 'personas', description: 'List personas' },
			cli.Command{ name: 'load', description: 'Load a context pack', usage: '<pack.yaml>' },
			cli.Command{ name: 'profiles', description: 'List or manage profiles' },
			cli.Command{ name: 'validate', description: 'Validate workspace schemas' },
			cli.Command{ name: 'budget', description: 'Analyze context footprint' },
		]
		flags:       [
			cli.Flag{ flag: .bool, name: 'explain', description: 'Explain context sources' },
			cli.Flag{ flag: .string, name: 'dir', description: 'Target directory' },
			cli.Flag{ flag: .string, name: 'name', description: 'Workspace name' },
			cli.Flag{ flag: .string, name: 'workspace', description: 'Workspace path' },
			cli.Flag{ flag: .string, name: 'profile', description: 'Profile name' },
			cli.Flag{ flag: .string, name: 'pack', description: 'Pack path or name' },
		]
	}
}

fn memory_command() cli.Command {
	return cli.Command{
		name:        'memory'
		description: 'Knowledge base: add, search, inject, review, todo'
		group:       'Advanced commands'
		commands:    [
			cli.Command{ name: 'add', description: 'Add a learning, process, or todo entry' },
			cli.Command{ name: 'search', description: 'Search knowledge files', usage: '<query>' },
			cli.Command{ name: 'inject', description: 'Output knowledge for session injection' },
			cli.Command{ name: 'review', description: 'Detect duplicates and stale refs' },
			cli.Command{ name: 'todo', description: 'List unchecked todos' },
		]
		flags:       [
			cli.Flag{ flag: .bool, name: 'fix', description: 'Auto-fix review findings' },
			cli.Flag{ flag: .bool, name: 'done', description: 'Include completed todos' },
			cli.Flag{ flag: .string, name: 'type', description: 'Entry type for add' },
			cli.Flag{ flag: .string, name: 'title', description: 'Entry title' },
			cli.Flag{ flag: .string, name: 'workspace', description: 'Workspace path' },
			cli.Flag{ flag: .int, name: 'stale-after', description: 'Stale threshold (days)' },
		]
	}
}

fn project_command() cli.Command {
	return cli.Command{
		name:        'project'
		description: 'Project management: clone, list, add, remove, scan'
		group:       'Advanced commands'
		commands:    [
			cli.Command{ name: 'init', description: 'Create repos/ and projects/ scaffolding' },
			cli.Command{ name: 'clone', description: 'Clone a GitHub repo and symlink', usage: '<owner/repo>' },
			cli.Command{ name: 'list', description: 'List symlinked projects' },
			cli.Command{ name: 'add', description: 'Symlink an already-cloned repo', usage: '<path>' },
			cli.Command{ name: 'remove', description: 'Remove symlink', usage: '<name>' },
			cli.Command{ name: 'scan', description: 'Scan for projects' },
		]
		flags:       [
			cli.Flag{ flag: .bool, name: 'ssh', description: 'Clone via SSH' },
			cli.Flag{ flag: .string, name: 'workspace', description: 'Workspace path' },
		]
	}
}

fn devcompanion_command() cli.Command {
	return cli.Command{
		name:        'devcompanion'
		alias:       'dc'
		description: 'Background job queue: queue, run-once, status, done, sync-todos (alias: dc)'
		group:       'Advanced commands'
		commands:    [
			cli.Command{ name: 'queue', description: 'Queue a background job', usage: '<project>' },
			cli.Command{ name: 'run-once', description: 'Process next job' },
			cli.Command{ name: 'status', description: 'Show queue state' },
			cli.Command{ name: 'done', description: 'Mark job complete', usage: '<job-id>' },
			cli.Command{ name: 'sync-todos', description: 'Sync todos from knowledge' },
		]
		flags:       [
			cli.Flag{ flag: .bool, name: 'no-llm', description: 'Skeleton plan only' },
			cli.Flag{ flag: .string, name: 'template', abbrev: 't', description: 'Job template' },
			cli.Flag{ flag: .string, name: 'request', abbrev: 'r', description: 'Free-form request' },
			cli.Flag{ flag: .string, name: 'id', description: 'Job id' },
			cli.Flag{ flag: .string, name: 'workspace', description: 'Workspace path' },
		]
	}
}

fn insights_command() cli.Command {
	return cli.Command{
		name:        'insights'
		description: 'AI tool usage insights (removed from product CLI; #526)'
		group:       'Advanced commands'
	}
}

fn build_command() cli.Command {
	return cli.Command{
		name:        'build'
		description: 'Compile canonical capabilities into target-native artifacts'
		group:       'Advanced commands'
		flags:       [
			cli.Flag{ flag: .bool, name: 'check', description: 'Dry-run + compare to plugins/' },
			cli.Flag{ flag: .string, name: 'target', description: 'Target id' },
			cli.Flag{ flag: .string, name: 'product', description: 'Product id' },
			cli.Flag{ flag: .string, name: 'output', description: 'Output directory' },
		]
	}
}

fn inventory_command() cli.Command {
	return cli.Command{
		name:        'inventory'
		description: 'List all canonical skills, agents, and products'
		group:       'Advanced commands'
	}
}

fn matrix_command() cli.Command {
	return cli.Command{
		name:        'matrix'
		description: 'Show platform capability matrix'
		group:       'Advanced commands'
	}
}

fn release_command() cli.Command {
	return cli.Command{
		name:        'release'
		description: 'Not in V — use CI / docs/RELEASING.md (#527)'
		group:       'Advanced commands'
	}
}

fn swarm_command() cli.Command {
	return cli.Command{
		name:        'swarm'
		description: 'Multi-agent swarm orchestration (pair/team/full, Herdr/tmux)'
		group:       'Advanced commands'
		commands:    [
			cli.Command{ name: 'recipes', description: 'List or show recipes' },
			cli.Command{ name: 'backends', description: 'List backends' },
			cli.Command{ name: 'doctor', description: 'Swarm environment checks' },
			cli.Command{ name: 'start', description: 'Start a swarm run' },
			cli.Command{ name: 'list', description: 'List runs' },
			cli.Command{ name: 'status', description: 'Show run status' },
			cli.Command{ name: 'approve', description: 'Approve a gate' },
			cli.Command{ name: 'reject', description: 'Reject a gate' },
			cli.Command{ name: 'cancel', description: 'Cancel a run' },
		]
		flags:       [
			cli.Flag{ flag: .bool, name: 'dry-run', description: 'Plan without starting' },
			cli.Flag{ flag: .bool, name: 'force', description: 'Force action' },
			cli.Flag{ flag: .string, name: 'recipe', description: 'Recipe name' },
			cli.Flag{ flag: .string, name: 'backend', description: 'Backend id' },
			cli.Flag{ flag: .string, name: 'ui', description: 'UI backend alias' },
			cli.Flag{ flag: .string, name: 'workspace', description: 'Workspace path' },
			cli.Flag{ flag: .string, name: 'reason', description: 'Reject reason' },
		]
	}
}

// command_matches mirrors cli.Command.matches (private in vlib).
fn command_matches(cmd cli.Command, token string) bool {
	return cmd.name == token || (cmd.alias.len > 0 && cmd.alias == token)
}

// find_command returns a top-level command by name or alias.
fn find_command(root cli.Command, token string) ?cli.Command {
	for c in root.commands {
		if command_matches(c, token) {
			return c
		}
	}
	return none
}

// resolve_command_name maps argv token to canonical command name (aliases → primary).
fn resolve_command_name(root cli.Command, token string) ?string {
	c := find_command(root, token) or { return none }
	return c.name
}
