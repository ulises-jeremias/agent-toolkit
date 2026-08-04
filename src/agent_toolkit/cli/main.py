#!/usr/bin/env python3
"""
agent-toolkit — Composable AI agent toolkit CLI

Usage:
    agent-toolkit <command> [args...]

Commands:
    install      Install profiles for detected AI tools
    doctor       Check system health and tool availability
    loop         Loop engineering: init, run, status, audit, cost, schedule, sync
    mcp          MCP provider management: setup, list, doctor
    skills       Skill management: sync, list, validate
    plugin       Plugin bundle management: sync, check

Run 'agent-toolkit <command> --help' for details.
"""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> None:
    argv = sys.argv[1:]
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        sys.exit(0)

    if argv[0] in ("-V", "--version", "version"):
        from agent_toolkit import __version__
        print(f"agent-toolkit {__version__}")
        sys.exit(0)

    command = argv[0]
    rest = argv[1:]

    match command:
        case "install":
            from agent_toolkit.cli.install import cmd_install
            sys.exit(cmd_install(rest))
        case "doctor":
            from agent_toolkit.cli.doctor import cmd_doctor
            sys.exit(cmd_doctor(rest))
        case "loop":
            # Delegate to loop runner
            from agent_toolkit.loop import runner
            sys.argv = ["agent-toolkit loop"] + rest
            runner.main()
        case "mcp":
            from agent_toolkit.cli.mcp import cmd_mcp
            sys.exit(cmd_mcp(rest))
        case "skills":
            from agent_toolkit.cli.skills import cmd_skills
            sys.exit(cmd_skills(rest))
        case "plugin":
            from agent_toolkit.cli.plugin import cmd_plugin
            sys.exit(cmd_plugin(rest))
        case _:
            print(f"Unknown command: {command}", file=sys.stderr)
            print("Run 'agent-toolkit help' for usage.", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
