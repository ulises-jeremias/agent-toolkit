"""
completion — Emit shell completion scripts for agent-toolkit.

Usage:
    agent-toolkit completion bash
    agent-toolkit completion zsh
    agent-toolkit completion fish

Install:
    agent-toolkit completion bash >> ~/.bashrc
    agent-toolkit completion zsh  >> ~/.zshrc
    agent-toolkit completion fish >> ~/.config/fish/completions/agent-toolkit.fish
"""

from __future__ import annotations

import sys

from agent_toolkit._paths import toolkit_root

TOP_LEVEL_COMMANDS = (
    "install",
    "doctor",
    "diff",
    "build",
    "inventory",
    "matrix",
    "loop",
    "workspace",
    "memory",
    "project",
    "devcompanion",
    "dc",
    "insights",
    "skills",
    "mcp",
    "plugin",
    "release",
    "update",
    "completion",
    "help",
    "version",
)

INSTALL_TOOLS = ("claude-code", "cursor", "opencode", "copilot", "windsurf", "pi")

LOOP_SUBCOMMANDS = (
    "init",
    "run",
    "status",
    "audit",
    "cost",
    "schedule",
    "sync",
    "templates",
    "help",
)

MCP_SUBCOMMANDS = ("list", "setup", "doctor", "help")

INSTALL_FLAGS = ("--tools", "--dry-run", "--force", "--offline", "--help")

UPDATE_FLAGS = ("--tools", "--check", "--pin", "--help")

LOOP_RUN_FLAGS = ("--force", "--quiet", "--pack", "--help")


def _loop_names() -> list[str]:
    try:
        root = toolkit_root()
    except EnvironmentError:
        return []
    loops_dir = root / "loops"
    if not loops_dir.is_dir():
        return []
    return sorted(
        d.name
        for d in loops_dir.iterdir()
        if d.is_dir() and ((d / "LOOP.md").exists() or (d / "loop.yaml").exists())
    )


def _mcp_providers() -> list[str]:
    try:
        root = toolkit_root()
    except EnvironmentError:
        return []
    templates = root / "mcp" / "templates"
    if not templates.is_dir():
        return []
    return sorted(p.name for p in templates.iterdir() if p.is_dir())


def _quote_words(words: tuple[str, ...] | list[str]) -> str:
    return " ".join(words)


def completion_bash() -> str:
    loops = _loop_names()
    mcps = _mcp_providers()
    return f"""# agent-toolkit bash completion
_agent_toolkit_completions() {{
    local cur prev words cword
    _init_completion || return

    local commands="{_quote_words(TOP_LEVEL_COMMANDS)}"
    local install_tools="{_quote_words(INSTALL_TOOLS)}"
    local loop_cmds="{_quote_words(LOOP_SUBCOMMANDS)}"
    local loop_names="{_quote_words(loops)}"
    local mcp_cmds="{_quote_words(MCP_SUBCOMMANDS)}"
    local mcp_providers="{_quote_words(mcps)}"

    if [[ $cword -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return
    fi

    case "${{words[1]}}" in
        install)
            if [[ "$prev" == "--tools" ]]; then
                COMPREPLY=( $(compgen -W "$install_tools" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "--tools --dry-run --force --offline --help $install_tools" -- "$cur") )
            fi
            ;;
        update)
            if [[ "$prev" == "--tools" ]]; then
                COMPREPLY=( $(compgen -W "$install_tools" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "--tools --check --pin --help $install_tools" -- "$cur") )
            fi
            ;;
        loop)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$loop_cmds" -- "$cur") )
            elif [[ "${{words[2]}}" == "run" && $cword -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "$loop_names" -- "$cur") )
            elif [[ "${{words[2]}}" == "init" && $cword -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "$loop_names" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "--force --quiet --help" -- "$cur") )
            fi
            ;;
        mcp)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$mcp_cmds" -- "$cur") )
            elif [[ "${{words[2]}}" == "setup" && $cword -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "$mcp_providers" -- "$cur") )
            fi
            ;;
        completion)
            COMPREPLY=( $(compgen -W "bash zsh fish" -- "$cur") )
            ;;
        doctor|diff|build|skills|plugin|workspace|memory|project|devcompanion|insights)
            COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            ;;
    esac
}}

complete -F _agent_toolkit_completions agent-toolkit
"""


def completion_zsh() -> str:
    loops = _loop_names()
    mcps = _mcp_providers()
    return f"""#compdef agent-toolkit

_agent_toolkit() {{
    local -a commands install_tools loop_cmds loop_names mcp_cmds mcp_providers
    commands=({" ".join(TOP_LEVEL_COMMANDS)})
    install_tools=({" ".join(INSTALL_TOOLS)})
    loop_cmds=({" ".join(LOOP_SUBCOMMANDS)})
    loop_names=({" ".join(loops)})
    mcp_cmds=({" ".join(MCP_SUBCOMMANDS)})
    mcp_providers=({" ".join(mcps)})

    _arguments -C \\
        '1:command:->command' \\
        '*::arg:->args'

    case $state in
        command)
            _describe 'command' commands
            ;;
        args)
            case $words[1] in
                install)
                    _arguments \\
                        '--tools[Tools to install]:tool:($install_tools)' \\
                        '--dry-run[Show planned changes]' \\
                        '--force[Overwrite existing files]' \\
                        '--offline[Use bundled/cached data only]' \\
                        '--help[Show help]'
                    ;;
                update)
                    _arguments \\
                        '--tools[Tools to update]:tool:($install_tools)' \\
                        '--check[Dry-run — show pending changes]' \\
                        '--pin[Release version to fetch]:version:' \\
                        '--help[Show help]'
                    ;;
                loop)
                    _arguments \\
                        '1:loop subcommand:($loop_cmds)' \\
                        '--force[Bypass daily budget]' \\
                        '--quiet[Suppress live progress]' \\
                        '--help[Show help]'
                    if [[ $words[2] == run || $words[2] == init ]]; then
                        _arguments '2:loop name:($loop_names)'
                    fi
                    ;;
                mcp)
                    _arguments '1:mcp subcommand:($mcp_cmds)'
                    if [[ $words[2] == setup ]]; then
                        _arguments '2:provider:($mcp_providers)'
                    fi
                    ;;
                completion)
                    _arguments '1:shell:(bash zsh fish)'
                    ;;
            esac
            ;;
    esac
}}

_agent_toolkit "$@"
"""


def completion_fish() -> str:
    loops = _loop_names()
    mcps = _mcp_providers()
    lines = [
        "# agent-toolkit fish completion",
        "complete -c agent-toolkit -f",
        f"complete -c agent-toolkit -n '__fish_use_subcommand' -a '{' '.join(TOP_LEVEL_COMMANDS)}'",
    ]
    for tool in INSTALL_TOOLS:
        lines.append(
            f"complete -c agent-toolkit -n '__fish_seen_subcommand_from install update; "
            f"and __fish_seen_argument --tools' -a '{tool}'"
        )
    lines.extend(
        [
            "complete -c agent-toolkit -n '__fish_seen_subcommand_from install' -l tools -d 'Tools to install'",
            "complete -c agent-toolkit -n '__fish_seen_subcommand_from install' -l dry-run",
            "complete -c agent-toolkit -n '__fish_seen_subcommand_from install' -l force",
            "complete -c agent-toolkit -n '__fish_seen_subcommand_from install' -l offline",
            "complete -c agent-toolkit -n '__fish_seen_subcommand_from update' -l tools -d 'Tools to update'",
            "complete -c agent-toolkit -n '__fish_seen_subcommand_from update' -l check",
            "complete -c agent-toolkit -n '__fish_seen_subcommand_from update' -l pin -d 'Release version'",
        ]
    )
    lines.append(
        f"complete -c agent-toolkit -n '__fish_seen_subcommand_from loop' -a '{' '.join(LOOP_SUBCOMMANDS)}'"
    )
    for name in loops:
        lines.append(
            f"complete -c agent-toolkit -n '__fish_seen_subcommand_from loop; "
            f"and __fish_seen_subcommand_from run init' -a '{name}'"
        )
    lines.append(
        f"complete -c agent-toolkit -n '__fish_seen_subcommand_from mcp' -a '{' '.join(MCP_SUBCOMMANDS)}'"
    )
    for prov in mcps:
        lines.append(
            f"complete -c agent-toolkit -n '__fish_seen_subcommand_from mcp; "
            f"and __fish_seen_subcommand_from setup' -a '{prov}'"
        )
    lines.append(
        "complete -c agent-toolkit -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'"
    )
    return "\n".join(lines) + "\n"


_EMITTERS = {
    "bash": completion_bash,
    "zsh": completion_zsh,
    "fish": completion_fish,
}


def cmd_completion(args: list[str]) -> int:
    if not args or args[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0

    shell = args[0].lower()
    emitter = _EMITTERS.get(shell)
    if emitter is None:
        print(f"Unknown shell: {shell}", file=sys.stderr)
        print(f"Supported: {', '.join(_EMITTERS)}", file=sys.stderr)
        return 2

    print(emitter(), end="" if emitter().__endswith("\n") else "\n")
    return 0
