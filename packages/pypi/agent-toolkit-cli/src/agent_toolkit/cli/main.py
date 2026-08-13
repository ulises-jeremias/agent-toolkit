#!/usr/bin/env python3
"""Quarantined Python CLI (`agent-toolkit-py`) — not the product.

Product commands are `agent-toolkit` / `agent-toolkit-cli` (V launcher).
See docs/v/python-fallback.md.
"""

from __future__ import annotations

import os
import sys

_QUIET_VALUES = frozenset({"1", "true", "yes", "on"})


def emit_quarantine_notice() -> None:
    """Warn interactive users; stay quiet in CI / captured pytest."""
    raw = os.environ.get("AGENT_TOOLKIT_PY_QUIET", "").strip().lower()
    if raw in _QUIET_VALUES:
        return
    try:
        if not sys.stderr.isatty():
            return
    except OSError:
        return
    sys.stderr.write(
        "agent-toolkit-py: quarantined Python fallback (not the product CLI). "
        "Use `agent-toolkit` (native V). See docs/v/python-fallback.md\n"
    )

CONSUMER_COMMANDS: tuple[str, ...] = (
    "install",
    "update",
    "uninstall",
    "doctor",
    "diff",
    "skills",
    "mcp",
    "plugin",
)
ADVANCED_COMMANDS: tuple[str, ...] = (
    "loop",
    "workspace",
    "memory",
    "project",
    "devcompanion",
    "dc",
    "insights",
    "build",
    "inventory",
    "matrix",
    "release",
    "swarm",
)

_CONSUMER_HELP = """\
agent-toolkit — Composable AI agent toolkit CLI

Usage:
    agent-toolkit <command> [args...]

Consumer commands:
    install       Install profiles for detected AI tools
    update        Refresh installed profiles from latest toolkit data
    uninstall     Remove toolkit-owned files using install receipts
    doctor        Check system health and tool availability
    diff          Show changes vs currently installed plugin bundles
    skills        Skill management: sync, list, validate
    mcp           MCP provider management: setup, list, doctor
    plugin        Plugin bundle management: sync, check

Advanced commands (workstation / power-user — docs/CLI_SURFACES.md):
    loop          Loop engineering: init, run, status, audit, cost, schedule, sync
    workspace     Workspace scaffolding: init, context, sync
    memory        Knowledge base: add, search, inject, review, todo
    project       Project management: clone, list, add, remove, scan
    devcompanion  Background job queue: queue, run-once, status, done, sync-todos
    insights      AI tool usage insights: opencode, cursor, claude
    build         Compile canonical capabilities into target-native artifacts
    inventory     List all canonical skills, agents, and products
    matrix        Show platform capability matrix
    release       Generate release artifacts (maintainer)
    swarm         Multi-agent swarm orchestration (pair/team/full, Herdr/tmux)

Run 'agent-toolkit <command> --help' for details.
"""


def main() -> None:
    emit_quarantine_notice()
    argv = sys.argv[1:]
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(_CONSUMER_HELP)
        sys.exit(0)

    if argv[0] in ("-V", "--version", "version"):
        from agent_toolkit import __version__

        print(f"agent-toolkit {__version__}")
        sys.exit(0)

    command = argv[0]
    rest = argv[1:]

    match command:
        case "release":
            from agent_toolkit.cli.release import cmd_release

            sys.exit(cmd_release(rest))
        case "diff":
            from agent_toolkit.cli.diff import cmd_diff

            sys.exit(cmd_diff(rest))
        case "build":
            from agent_toolkit.cli.build import cmd_build

            sys.exit(cmd_build(rest))
        case "inventory":
            from agent_toolkit.cli.build import cmd_inventory

            sys.exit(cmd_inventory(rest))
        case "matrix":
            from agent_toolkit.cli.build import cmd_matrix

            sys.exit(cmd_matrix(rest))
        case "install":
            from agent_toolkit.cli.install import cmd_install

            sys.exit(cmd_install(rest))
        case "update":
            from agent_toolkit.cli.update import cmd_update

            sys.exit(cmd_update(rest))
        case "uninstall" | "rollback":
            from agent_toolkit.cli.uninstall import cmd_uninstall

            sys.exit(cmd_uninstall(rest))
        case "doctor":
            from agent_toolkit.cli.doctor import cmd_doctor

            sys.exit(cmd_doctor(rest))
        case "loop":
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
        case "workspace":
            from agent_toolkit.cli.workspace import cmd_workspace

            sys.exit(cmd_workspace(rest))
        case "memory":
            from agent_toolkit.cli.memory import cmd_memory

            sys.exit(cmd_memory(rest))
        case "project":
            from agent_toolkit.cli.project import cmd_project

            sys.exit(cmd_project(rest))
        case "devcompanion" | "dc":
            from agent_toolkit.cli.devcompanion import cmd_devcompanion

            sys.exit(cmd_devcompanion(rest))
        case "insights":
            from agent_toolkit.cli.insights import cmd_insights

            sys.exit(cmd_insights(rest))
        case "swarm":
            from agent_toolkit.swarm.cli import main as swarm_main

            sys.exit(swarm_main(rest))
        case _:
            print(f"Unknown command: {command}", file=sys.stderr)
            print("Run 'agent-toolkit help' for usage.", file=sys.stderr)
            if command not in CONSUMER_COMMANDS and command not in ADVANCED_COMMANDS:
                print(
                    "See docs/CLI_SURFACES.md for consumer vs advanced commands.",
                    file=sys.stderr,
                )
            sys.exit(1)


if __name__ == "__main__":
    main()
