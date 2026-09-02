module agent_toolkit_cli

import agent_toolkit_core
import os

const completion_shells = ['bash', 'zsh', 'fish', 'powershell']

const completion_commands = 'install update uninstall doctor diff skills mcp plugin loop workspace memory project devcompanion dc insights build inventory matrix release swarm tui serve completion help version'

const completion_loop_cmds = 'init run status audit cost schedule sync templates help'

const completion_install_tools = 'claude-code cursor opencode copilot windsurf pi muse-code'

fn completion_help_text() string {
	return 'Usage: agent-toolkit completion <bash|zsh|fish|powershell>

Emit a shell completion script for the V CLI. Install examples:

  agent-toolkit completion bash >> ~/.bashrc
  agent-toolkit completion zsh  >> ~/.zshrc
  agent-toolkit completion fish > ~/.config/fish/completions/agent-toolkit.fish
  agent-toolkit completion powershell >> \$PROFILE
'
}

fn run_completion(args []string) int {
	if args.len == 0 || args[0] in ['-h', '--help', 'help'] {
		print(completion_help_text())
		return 0
	}
	shell := args[0].to_lower()
	script := completion_script(shell) or {
		eprintln('Unknown shell: ${shell}')
		eprintln('Supported: ${completion_shells.join(', ')}')
		return 2
	}
	print(script)
	if !script.ends_with('\n') {
		print('\n')
	}
	return 0
}

fn completion_script(shell string) !string {
	return match shell {
		'bash' { completion_bash() }
		'zsh' { completion_zsh() }
		'fish' { completion_fish() }
		'powershell', 'pwsh' { completion_powershell() }
		else { error('unknown shell') }
	}
}

fn completion_loop_names() string {
	root := agent_toolkit_core.find_toolkit_root() or { return '' }
	loops_dir := os.join_path(root.path, 'loops')
	if !os.is_dir(loops_dir) {
		return ''
	}
	entries := os.ls(loops_dir) or { return '' }
	mut names := []string{}
	for e in entries {
		dir := os.join_path(loops_dir, e)
		if os.is_dir(dir) && (os.is_file(os.join_path(dir, 'loop.yaml')) || os.is_file(os.join_path(dir, 'LOOP.md'))) {
			names << e
		}
	}
	names.sort()
	return names.join(' ')
}

fn completion_bash() string {
	loops := completion_loop_names()
	return '# agent-toolkit bash completion
_agent_toolkit_completions() {
    local cur prev words cword
    _init_completion || return
    local commands="' + completion_commands + '"
    local loop_cmds="' + completion_loop_cmds + '"
    local loop_names="' + loops + '"
    local install_tools="' + completion_install_tools + '"
    if [[ \$cword -eq 1 ]]; then
        COMPREPLY=( \$(compgen -W "\$commands" -- "\$cur") )
        return
    fi
    case "\${words[1]}" in
        install|update)
            COMPREPLY=( \$(compgen -W "--tools --dry-run --force --offline --check --pin --help \$install_tools" -- "\$cur") )
            ;;
        loop)
            if [[ \$cword -eq 2 ]]; then
                COMPREPLY=( \$(compgen -W "\$loop_cmds" -- "\$cur") )
            elif [[ "\${words[2]}" == "run" || "\${words[2]}" == "init" ]] && [[ \$cword -eq 3 ]]; then
                COMPREPLY=( \$(compgen -W "\$loop_names" -- "\$cur") )
            fi
            ;;
        completion)
            COMPREPLY=( \$(compgen -W "bash zsh fish powershell" -- "\$cur") )
            ;;
        *)
            COMPREPLY=( \$(compgen -W "--help --json --quiet" -- "\$cur") )
            ;;
    esac
}
complete -F _agent_toolkit_completions agent-toolkit
complete -F _agent_toolkit_completions agent-toolkit-cli
'
}

fn completion_zsh() string {
	loops := completion_loop_names()
	return '#compdef agent-toolkit agent-toolkit-cli
_agent_toolkit() {
    local -a commands loop_cmds loop_names install_tools
    commands=(' + completion_commands + ')
    loop_cmds=(' + completion_loop_cmds + ')
    loop_names=(' + loops + ')
    install_tools=(' + completion_install_tools + ')
    _arguments -C "1:command:->command" "*::arg:->args"
    case \$state in
        command)
            _describe "command" commands
            ;;
        args)
            case \$words[1] in
                loop)
                    _arguments "1:loop subcommand:(\$loop_cmds)" "2:loop name:(\$loop_names)"
                    ;;
                completion)
                    _arguments "1:shell:(bash zsh fish powershell)"
                    ;;
                install|update)
                    _arguments "--tools[Tools]:tool:(\$install_tools)" "--dry-run" "--force" "--help"
                    ;;
            esac
            ;;
    esac
}
_agent_toolkit "\$@"
'
}

fn completion_fish() string {
	loops := completion_loop_names()
	mut lines := []string{}
	lines << '# agent-toolkit fish completion'
	lines << 'complete -c agent-toolkit -f'
	lines << 'complete -c agent-toolkit-cli -f'
	lines << "complete -c agent-toolkit -n '__fish_use_subcommand' -a '${completion_commands}'"
	lines << "complete -c agent-toolkit-cli -n '__fish_use_subcommand' -a '${completion_commands}'"
	lines << "complete -c agent-toolkit -n '__fish_seen_subcommand_from loop' -a '${completion_loop_cmds}'"
	if loops.len > 0 {
		lines << "complete -c agent-toolkit -n '__fish_seen_subcommand_from loop; and __fish_seen_subcommand_from run init' -a '${loops}'"
	}
	lines << "complete -c agent-toolkit -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish powershell'"
	return lines.join('\n') + '\n'
}

fn completion_powershell() string {
	return 'Register-ArgumentCompleter -Native -CommandName agent-toolkit,agent-toolkit-cli -ScriptBlock {
    param(\$wordToComplete, \$commandAst, \$cursorPosition)
    \$cmds = @(\'install\',\'update\',\'uninstall\',\'doctor\',\'diff\',\'skills\',\'mcp\',\'plugin\',\'loop\',\'workspace\',\'memory\',\'project\',\'devcompanion\',\'dc\',\'insights\',\'build\',\'inventory\',\'matrix\',\'release\',\'swarm\',\'tui\',\'serve\',\'completion\',\'help\',\'version\')
    \$shells = @(\'bash\',\'zsh\',\'fish\',\'powershell\')
    \$tokens = \$commandAst.CommandElements | ForEach-Object { \$_.ToString() }
    if (\$tokens.Count -le 2) {
        \$cmds | Where-Object { \$_ -like "\$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(\$_, \$_, \'ParameterValue\', \$_)
        }
        return
    }
    if (\$tokens[1] -eq \'completion\') {
        \$shells | Where-Object { \$_ -like "\$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(\$_, \$_, \'ParameterValue\', \$_)
        }
    }
}
'
}
