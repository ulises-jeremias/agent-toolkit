"""
completion — Emit shell completion scripts for agent-toolkit.

Usage:
    agent-toolkit completion bash
    agent-toolkit completion zsh
    agent-toolkit completion fish
"""
from __future__ import annotations

import sys

_INSTALL_TOOLS = "claude-code cursor opencode copilot windsurf pi gemini-cli codex"
_MCP_PROVIDERS = "github slack notion linear figma clickup"
_LOOP_COMMANDS = "init run status audit cost schedule sync templates"
_TOP_COMMANDS = (
    "install update doctor diff build inventory matrix loop mcp skills plugin "
    "workspace memory project devcompanion insights completion"
)


def _bash_completion() -> str:
    return f"""# agent-toolkit bash completion
_agent_toolkit_completions() {{
  local cur prev words cword
  _init_completion || return

  local commands="{_TOP_COMMANDS}"
  local install_tools="{_INSTALL_TOOLS}"
  local mcp_providers="{_MCP_PROVIDERS}"
  local loop_cmds="{_LOOP_COMMANDS}"

  case "${{COMP_WORDS[1]}}" in
    install)
      case "${{prev}}" in
        --tools) COMPREPLY=( $(compgen -W "${{install_tools}}" -- "${{cur}}") ); return ;;
      esac
      COMPREPLY=( $(compgen -W "--tools --dry-run --force --help" -- "${{cur}}") )
      ;;
    mcp)
      case "${{COMP_WORDS[2]}}" in
        setup|doctor|health|uninstall)
          COMPREPLY=( $(compgen -W "${{mcp_providers}}" -- "${{cur}}") ); return ;;
      esac
      COMPREPLY=( $(compgen -W "list setup health doctor uninstall --help" -- "${{cur}}") )
      ;;
    loop)
      COMPREPLY=( $(compgen -W "${{loop_cmds}}" -- "${{cur}}") )
      ;;
    build)
      COMPREPLY=( $(compgen -W "--target --product --check --output --json --help" -- "${{cur}}") )
      ;;
    *)
      COMPREPLY=( $(compgen -W "${{commands}}" -- "${{cur}}") )
      ;;
  esac
}}
complete -F _agent_toolkit_completions agent-toolkit
"""


def _zsh_completion() -> str:
    return f"""#compdef agent-toolkit

_agent_toolkit() {{
  local -a commands install_tools mcp_providers loop_cmds
  commands=({_TOP_COMMANDS.split()})
  install_tools=({_INSTALL_TOOLS.split()})
  mcp_providers=({_MCP_PROVIDERS.split()})
  loop_cmds=({_LOOP_COMMANDS.split()})

  _arguments -C \\
    '1: :->cmd' \\
    '*:: :->args'

  case $state in
    cmd) _describe 'command' commands ;;
    args)
      case $words[1] in
        install) _arguments '--tools[tools]:tool:($install_tools)' ;;
        mcp) _arguments '1: :($mcp_providers)' ;;
        loop) _arguments '1: :($loop_cmds)' ;;
      esac
      ;;
  esac
}}
compdef _agent_toolkit agent-toolkit
"""


def _fish_completion() -> str:
    tools = " ".join(_INSTALL_TOOLS.split())
    providers = " ".join(_MCP_PROVIDERS.split())
    return f"""# agent-toolkit fish completion
complete -c agent-toolkit -f
complete -c agent-toolkit -n '__fish_use_subcommand' -a 'install update doctor diff build inventory matrix loop mcp skills plugin workspace memory project devcompanion insights completion'
complete -c agent-toolkit -n '__fish_seen_subcommand_from install' -l tools -a '{tools}'
complete -c agent-toolkit -n '__fish_seen_subcommand_from mcp' -a 'list setup health doctor uninstall'
complete -c agent-toolkit -n '__fish_seen_subcommand_from mcp' -a '{providers}' -n '__fish_seen_subcommand_from setup doctor health uninstall'
complete -c agent-toolkit -n '__fish_seen_subcommand_from loop' -a 'init run status audit cost schedule sync templates'
"""


def cmd_completion(args: list[str]) -> int:
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0

    shell = args[0].lower()
    scripts = {
        "bash": _bash_completion,
        "zsh": _zsh_completion,
        "fish": _fish_completion,
    }
    fn = scripts.get(shell)
    if fn is None:
        print(f"Unknown shell: {shell}", file=sys.stderr)
        print(f"Supported: {', '.join(sorted(scripts))}", file=sys.stderr)
        return 2

    print(fn())
    return 0
