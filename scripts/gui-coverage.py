#!/usr/bin/env python3
"""gui-coverage.py — critical product workflow coverage report for the Desktop.

Since S4 (#1119), the typed registry (modules/desktop/palette/registry.v +
actions.v) is the sole palette/search authority: the static palette_items()
command list was deleted. This report therefore no longer asserts CLI→palette
row parity. It reports how each **critical product workflow** is reachable
through the registry, by consuming the registry/action definitions themselves.

The authority is the V reachability gate:
    cmd/agent-toolkit-desktop/registry_reachability_test.v
run by `./make.vsh test` inside Required CI (Check V Modules). This script is
an advisory, human-readable view of the same contract — it never gates.

Usage:
  python3 scripts/gui-coverage.py            # print report
  python3 scripts/gui-coverage.py --check    # exit 1 if a workflow is unbacked
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REG = ROOT / "modules" / "desktop" / "palette" / "registry.v"
ACT = ROOT / "modules" / "desktop" / "palette" / "actions.v"
MAIN = ROOT / "cmd" / "agent-toolkit-desktop" / "main.v"
GATE = ROOT / "cmd" / "agent-toolkit-desktop" / "registry_reachability_test.v"

# Critical product workflow → (registry constructs that must exist, the
# reachability-gate function that proves it). Tokens are V identifiers as
# they literally appear in the registry/action definitions.
WORKFLOWS: dict[str, tuple[set[str], str]] = {
    "discover skill": (
        {"build_skill_entries", "skills_catalog"},
        "test_workflow_skill_discovery_install",
    ),
    "inspect skill (deep link)": ({"deep_link_select"}, "test_workflow_skill_discovery_install"),
    "install skill where supported": ({"skill_install"}, "test_workflow_skill_discovery_install"),
    "remove skill (config truth)": ({"skill_remove"}, "test_workflow_skill_discovery_install"),
    "discover agent": ({"build_agent_entries", "agents_catalog"}, "test_workflow_agent_discovery"),
    "inspect agent": ({"build_agent_entries"}, "test_workflow_agent_discovery"),
    "discover target": ({"build_target_entries"}, "test_workflow_target_discovery_install_toggle"),
    "install target where supported": (
        {"target_install", "target_install_supported"},
        "test_workflow_target_discovery_install_toggle",
    ),
    "enable/disable target": (
        {"target_enable", "target_disable", "set_target_enabled"},
        "test_workflow_target_discovery_install_toggle",
    ),
    "discover MCP provider": ({"build_mcp_entries"}, "test_workflow_mcp_discovery_toggle_probe"),
    "enable/disable provider": (
        {"mcp_enable", "mcp_disable"},
        "test_workflow_mcp_discovery_toggle_probe",
    ),
    "probe provider": ({"mcp_probe"}, "test_workflow_mcp_discovery_toggle_probe"),
    "Doctor preview repair": ({"doctor_fix_preview"}, "test_workflow_doctor_preview_repair"),
    "Doctor execute repair": (
        {"doctor_repair", "doctor_fix("},
        "test_workflow_doctor_preview_repair",
    ),
    "run loop": ({"loop_run", "run_loop("}, "test_workflow_loop_run"),
    "toggle loop schedule": (
        {"loop_schedule_toggle", "toggle_loop_cron("},
        "test_workflow_loop_run",
    ),
    "launch/request swarm": ({"swarm_launch("}, "test_workflow_swarm_launch"),
    "navigate primary surfaces": (
        {"production_nav_panels", "build_nav_entries"},
        "test_workflow_skill_discovery_install",
    ),
    "application: theme": ({"app_theme_cycle"}, "test_workflow_app_level_actions"),
    "application: update (honest unavailability)": (
        {"app_update_check"},
        "test_workflow_app_level_actions",
    ),
    "application: uninstall (preview+confirm)": (
        {"app_uninstall", "uninstall_targets"},
        "test_workflow_app_level_actions",
    ),
}

# The production shell must consume the registry — no static command authority.
REMAINING_LEGACY = re.compile(r"palette_items|struct PaletteItem|palette_best_score")


def read(path: Path) -> str:
    return path.read_text() if path.exists() else ""


def strip_v_comments(src: str) -> str:
    """Remove // line comments so removed-name mentions don't count as code."""
    return "\n".join(line.split("//")[0] for line in src.splitlines())


def v_declarations(src: str) -> set[str]:
    """Collect actual V function declarations, enum members and consts.

    Works on comment-stripped source and matches declarations — not arbitrary
    substrings — so a commented-out function can never satisfy the report.
    """
    out: set[str] = set()
    for line in strip_v_comments(src).splitlines():
        s = line.strip()
        m = re.match(r"(?:pub\s+)?fn\s+(?:\([^)]*\)\s*)?([A-Za-z0-9_]+)\s*\(", s)
        if m:
            out.add(m.group(1))
            continue
        m2 = re.fullmatch(r"([a-z_0-9]+),?", s)
        if m2:
            out.add(m2.group(1))
            continue
        m3 = re.match(r"const\s+([a-z_0-9]+)\s*=", s)
        if m3:
            out.add(m3.group(1))
    return out


def engine_seam_sources() -> list[Path]:
    """The typed Engine seams the registry actions invoke (S4B/S4C)."""
    return sorted((ROOT / "modules" / "desktop_engine").glob("*.v"))


def main() -> int:
    reg_raw, act_raw, gate_raw = read(REG), read(ACT), read(GATE)
    main_src = strip_v_comments(read(MAIN))
    if not reg_raw or not act_raw:
        print("error: registry/action definitions not found", file=sys.stderr)
        return 2
    # declarations/members only — commented-out code never counts. The
    # backing universe includes the typed Engine seams the actions invoke.
    backing: set[str] = set()
    calls = ""
    for p in [REG, ACT, MAIN, *engine_seam_sources()]:
        src = read(p)
        backing |= v_declarations(src)
        calls += strip_v_comments(src) + "\n"

    rows: list[tuple[str, str, str]] = []
    missing: list[str] = []
    gate_fns = v_declarations(gate_raw)
    for wf, (needs, gate_fn) in sorted(WORKFLOWS.items()):
        unbacked = []
        for n in needs:
            if n.endswith("("):
                if n not in calls:
                    unbacked.append(n)
            elif n not in backing:
                unbacked.append(n)
        gated = gate_fn in gate_fns
        if unbacked:
            status, via = "MISSING", ",".join(unbacked)
            missing.append(wf)
        elif gated:
            status, via = "covered", "reachability gate"
        else:
            status, via = "backed", "registry definitions (gate function missing)"
            missing.append(wf)
        rows.append((wf, status, via))

    total = len(rows)
    covered = total - len(missing)
    print(f"# Critical workflow coverage — {covered}/{total} workflows backed\n")
    print("| Workflow | Status | Via |")
    print("|---|---|---|")
    for wf, status, via in rows:
        mark = "✅" if status != "MISSING" else "⚠️"
        print(f"| {mark} {wf} | {status} | {via} |")

    legacy = REMAINING_LEGACY.findall(main_src)
    if legacy:
        print(
            "\n⚠️ legacy palette authority still present in production: "
            + ", ".join(sorted(set(legacy)))
        )
        missing.append("legacy authority retirement")
    else:
        print("\n✅ static palette authority fully retired from the production shell")

    if "--check" in sys.argv and missing:
        print(f"\nFAIL: {len(missing)} workflow coverage gap(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
