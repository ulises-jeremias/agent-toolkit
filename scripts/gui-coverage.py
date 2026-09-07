#!/usr/bin/env python3
"""gui-coverage.py — CLI ↔ GUI coverage audit.

Extracts the agent-toolkit CLI command surface from `build/agent-toolkit --help`
and checks every command has a GUI affordance in the desktop palette
(cmd/agent-toolkit-desktop/main.v `palette_items()`).

Usage:
  python3 scripts/gui-coverage.py            # print report
  python3 scripts/gui-coverage.py --check    # exit 1 if coverage < 100%

The desktop GUI also manages commands beyond the palette (panel-scoped forms:
skills install/toggle, MCP toggle, targets install, doctor fix, loop run/sched,
swarm launch/approve, workspace IDE, onboarding wizard, insights tabs), so a
missing palette row is a hint, not always a gap — the report marks those.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN = ROOT / "cmd" / "agent-toolkit-desktop" / "main.v"
BIN = ROOT / "build" / "agent-toolkit"

# CLI command → palette id(s) / panel affordance that manages it
COVERAGE = {
    "install": ["install", "install_full"],
    "update": ["update"],
    "uninstall": ["uninstall"],
    "doctor": ["doctor", "doctor_fix", "panel.doctor"],
    "diff": ["diff"],
    "skills": ["skills_sync", "panel.skills"],
    "mcp": ["mcp_health", "panel.mcp"],
    "plugin": ["build"],
    "completion": ["completion"],
    "gui": ["command_palette"],  # `agent-toolkit gui` IS this app
    "loop": ["loop_run", "panel.loops"],
    "workspace": ["workspace_sync", "panel.workspace"],
    "memory": ["memory"],
    "project": ["project_clone"],
    "devcompanion": ["devcompanion"],
    "insights": ["insights_cli", "panel.insights"],
    "build": ["build"],
    "inventory": ["inventory"],
    "swarm": ["swarm_start", "panel.swarm"],
    "serve": ["serve"],
    "help": ["command_palette"],  # palette + `h` help overlay
    "matrix": ["doctor"],  # capability matrix runs as a doctor check
}

# Commands intentionally NOT in the GUI (removed or CI-only per the CLI itself)
INTENTIONAL_NA = {"tui", "release"}


def cli_commands() -> dict[str, str]:
    out = subprocess.run([str(BIN), "--help"], capture_output=True, text=True, timeout=30).stdout
    cmds: dict[str, str] = {}
    for line in out.splitlines():
        m = re.match(r"^  ([a-z][a-z ()a-z-]*?)\s{2,}(.*)$", line)
        if not m:
            continue
        names, desc = m.group(1).strip(), m.group(2).strip()
        primary = names.split(" ")[0]
        if primary in ("version",):
            continue
        cmds[primary] = desc
    return cmds


def palette_ids() -> set[str]:
    """Palette affordance ids from both sources (S4 #1119).

    S4A moved navigation rows out of the static `palette_items()` list into the
    typed registry (`modules/desktop/palette/registry.v`); the static list keeps
    only not-yet-migrated CLI-command rows. Coverage therefore reads both:
    static rows from main.v and registry navigation panels from the registry
    module. S4C (#1119) replaces this CLI-row parity with task/workflow
    coverage of the registry's critical workflows.
    """
    src = MAIN.read_text()
    ids = set(re.findall(r"PaletteItem\{'([a-z_]+)'", src))
    reg = (ROOT / "modules" / "desktop" / "palette" / "registry.v").read_text()
    block = re.search(r"production_nav_panels\s*=\s*\[(.*?)\]", reg, re.DOTALL)
    if block:
        panels = set(re.findall(r"nav\.PanelId\.([a-z_]+)", block.group(1)))
        # registry navigation panels map to their CLI-command affordance keys
        panel_to_cmd = {
            "world_view": "world",
            "skills": "skills",
            "agents": "agents",
            "mcp": "mcp",
            "targets": "targets",
            "doctor": "doctor",
            "jobs": "jobs",
            "loops": "loops",
            "swarm": "swarm",
            "workspace": "workspace",
            "products": "products",
            "onboarding": "onboarding",
            "insights": "insights",
        }
        ids |= {panel_to_cmd[p] for p in panels if p in panel_to_cmd}
    return ids


def main() -> int:
    if not BIN.exists():
        print(f"error: {BIN} not found — run make.vsh build-cli first", file=sys.stderr)
        return 2
    cmds = cli_commands()
    pal = palette_ids()
    rows, missing = [], []
    for cmd, desc in sorted(cmds.items()):
        want = COVERAGE.get(cmd, [])
        hit = [p for p in want if p in pal]
        panel = cmd in pal  # 'Go to <cmd>' palette row ⇒ dedicated panel
        if hit:
            rows.append((cmd, desc, "palette", ",".join(hit)))
        elif panel:
            rows.append((cmd, desc, "panel", f"panel.{cmd}"))
        else:
            rows.append((cmd, desc, "MISSING", ""))
            missing.append(cmd)
    rows = [r for r in rows if r[0] not in INTENTIONAL_NA]
    missing = [m for m in missing if m not in INTENTIONAL_NA]
    total = len(rows)
    covered = total - len(missing)
    print(
        f"# CLI ↔ GUI coverage — {covered}/{total} commands ({100 * covered // max(total, 1)}%)\n"
    )
    print("| CLI command | GUI affordance | via |")
    print("|---|---|---|")
    for cmd, desc, how, via in rows:
        mark = "✅" if how != "MISSING" else "⚠️"
        print(f"| {mark} `{cmd}` | {desc[:60]} | {how} |")
    if missing:
        print("\nGaps: " + ", ".join(f"`{m}`" for m in missing))
    if "--check" in sys.argv and missing:
        print(f"\nFAIL: {len(missing)} CLI commands without GUI affordance", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
