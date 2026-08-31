#!/usr/bin/env python3
"""Generate docs/TARGET_CAPABILITY_MATRIX.md from capabilities/targets/registry.yaml.

Usage:
  python3 scripts/generate-target-matrix.py              # write docs/TARGET_CAPABILITY_MATRIX.md
  python3 scripts/generate-target-matrix.py --check      # fail on drift
  python3 scripts/generate-target-matrix.py --output PATH

Also validates that registry covers all profiles/ dirs (copilot maps to copilot-cli + copilot-repository).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = REPO_ROOT / "capabilities" / "targets" / "registry.yaml"
DEFAULT_OUTPUT = REPO_ROOT / "docs" / "TARGET_CAPABILITY_MATRIX.md"
PROFILES_DIR = REPO_ROOT / "profiles"

# Capability order per issue #862
CAPABILITIES = [
    "agent_skills",
    "agent_plugins",
    "native_custom_agents",
    "primary_agents",
    "subagents",
    "automatic_delegation",
    "nested_delegation",
    "parallel_agents",
    "agent_permissions",
    "agent_models",
    "mcp",
    "hooks",
    "commands",
    "rules",
    "plugin_marketplace",
]

CAP_LABELS = {
    "agent_skills": "Agent Skills",
    "agent_plugins": "Agent Plugins",
    "native_custom_agents": "Native Custom Agents",
    "primary_agents": "Primary / Default Agents",
    "subagents": "Subagents",
    "automatic_delegation": "Automatic Delegation",
    "nested_delegation": "Nested Delegation",
    "parallel_agents": "Parallel Agents",
    "agent_permissions": "Agent Permissions",
    "agent_models": "Agent Models",
    "mcp": "MCP",
    "hooks": "Hooks",
    "commands": "Commands",
    "rules": "Rules / Instructions",
    "plugin_marketplace": "Plugin Marketplace",
}


# Human-readable cell rendering
def fmt(val) -> str:  # noqa: ANN001
    if val is True:
        return "✅"
    if val is False:
        return "❌"
    if val is None:
        return "—"
    s = str(val).strip()
    # normalize lower
    low = s.lower()
    mapping = {
        "true": "✅",
        "false": "❌",
        "partial": "◐ partial",
        "unknown": "❓ unknown",
        "unknown-blocked": "❓ unknown-blocked",
        "native": "✅ native",
        "native-experimental": "🧪 native-experimental",
        "generated": "🔧 generated",
        "bridged": "🔗 bridged",
        "manual": "✋ manual",
        "unsupported": "❌ unsupported",
        "v1": "`v1`",
        "none": "—",
        "custom": "`custom`",
    }
    return mapping.get(low, s)


def load_registry():
    text = REGISTRY_PATH.read_text(encoding="utf-8")
    data = yaml.safe_load(text)
    if not isinstance(data, dict) or "targets" not in data:
        print("FAIL: registry.yaml missing 'targets' key", file=sys.stderr)
        sys.exit(1)
    return data


def validate_profiles_coverage(targets):
    """Ensure registry covers all profiles/ dirs. copilot -> copilot-cli + copilot-repository."""
    if not PROFILES_DIR.is_dir():
        return
    profile_ids = sorted([p.name for p in PROFILES_DIR.iterdir() if p.is_dir()])
    # Map profiles to expected registry ids
    expected = set()
    for pid in profile_ids:
        if pid == "copilot":
            expected.update(["copilot-cli", "copilot-repository"])
        else:
            expected.add(pid)
    # agent-plugins is synthetic, not in profiles — allow it
    registry_ids = {t["id"] for t in targets}
    # Check coverage
    missing = expected - registry_ids
    extra = registry_ids - expected - {"agent-plugins"}
    msgs = []
    if missing:
        msgs.append(
            f"registry missing profiles coverage: {sorted(missing)} (profiles={profile_ids})"
        )
    if extra:
        # extra synthetic is okay only for agent-plugins; otherwise warn
        msgs.append(f"registry has extra ids not in profiles/: {sorted(extra)}")
    if msgs:
        for m in msgs:
            print(f"FAIL: {m}", file=sys.stderr)
        sys.exit(1)


def validate_agent_plugins_extension(targets):
    """Validate portable vs extension annotation (#973).

    - agent_plugins == v1 must have extension 'portable'
    - agent_plugins == none must have extension 'none'
    - agent_plugins == custom must have a client-specific extension (not portable/none)
    Fails on ambiguous custom without extension annotation.
    """
    for t in targets:
        tid = t.get("id", "<unknown>")
        caps = t.get("capabilities", {})
        ap = caps.get("agent_plugins")
        ext = t.get("agent_plugins_extension")
        if ext is None or str(ext).strip() == "":
            print(
                f"FAIL: {tid}: missing agent_plugins_extension (required #973 to distinguish portable vs extension)",
                file=sys.stderr,
            )
            sys.exit(1)
        ext_norm = str(ext).strip()
        if ap == "custom":
            if ext_norm.lower() in ("portable", "none"):
                print(
                    f"FAIL: {tid}: agent_plugins is 'custom' but extension is {ext!r} — must specify client extension like 'opencode.json' or 'gemini-extension.json' (#973)",
                    file=sys.stderr,
                )
                sys.exit(1)
            if len(ext_norm) < 3:
                print(
                    f"FAIL: {tid}: agent_plugins custom extension too short: {ext!r}",
                    file=sys.stderr,
                )
                sys.exit(1)
        elif ap == "v1":
            if ext_norm != "portable":
                print(
                    f"FAIL: {tid}: agent_plugins 'v1' must have extension 'portable' (got {ext!r})",
                    file=sys.stderr,
                )
                sys.exit(1)
        elif ap == "none":
            if ext_norm != "none":
                print(
                    f"FAIL: {tid}: agent_plugins 'none' must have extension 'none' (got {ext!r})",
                    file=sys.stderr,
                )
                sys.exit(1)


def render_md(data) -> str:
    targets = data["targets"]
    # preserve registry order
    validate_profiles_coverage(targets)
    validate_agent_plugins_extension(targets)

    lines = []
    lines.append("# Target Capability Matrix")
    lines.append("")
    lines.append("> Generated from `capabilities/targets/registry.yaml` — do not hand-edit.")
    lines.append(
        "> Run `python3 scripts/generate-target-matrix.py` to regenerate, or `python3 scripts/generate-target-matrix.py --check` in CI."
    )
    lines.append("")
    researched = data.get("researched_at") or (targets[0].get("researched_at") if targets else "")
    if researched:
        lines.append(f"_Researched at: {researched} — sources per target below._")
        lines.append("")
    # Tier Definitions (#868)
    lines.append("## Adapter Tiers (#868)")
    lines.append("")
    lines.append(
        "Tiers describe the **harness adapter richness** — what the harness natively supports "
        "and what the compiler may emit. Least-common-denominator is rejected: each target "
        "receives the richest correct subset it supports. `tier` is stored in "
        "`capabilities/targets/registry.yaml` (`tier: A/B/C/D`) per #868."
    )
    lines.append("")
    lines.append("| Tier | Label | What the adapter supports | Targets |")
    lines.append("|------|-------|---------------------------|---------|")
    # Collect tier members
    tier_members: dict[str, list[str]] = {"A": [], "B": [], "C": [], "D": []}
    for t in targets:
        tier = str(t.get("tier", "")).strip().upper()
        if tier in tier_members:
            tier_members[tier].append(t.get("display_name") or t["id"])
    lines.append(
        f"| **A** | Rich multi-agent | Holistic + specialist agents, delegation "
        f"(auto/nested/parallel), permissions, models, hooks, MCP, marketplace | "
        f"{', '.join(tier_members['A']) or '—'} |"
    )
    lines.append(
        f"| **B** | Custom agents, limited delegation | Agents + routing guidance, "
        f"explicit handoffs; some delegation/MCP/hooks partial or bridged | "
        f"{', '.join(tier_members['B']) or '—'} |"
    )
    lines.append(
        f"| **C** | Skills + instructions | Agent Skills, global routing guidance, "
        f"rules/instructions, MCP where native; no subagents/delegation | "
        f"{', '.join(tier_members['C']) or '—'} |"
    )
    lines.append(
        f"| **D** | Minimal | Richest correct subset only (rules + manual MCP); "
        f"no marketplace/extensions, no custom agent delegation | "
        f"{', '.join(tier_members['D']) or '—'} |"
    )
    lines.append("")
    lines.append(
        "> **Gating:** if a capability is `false`/`unknown` the compiler **must not** emit its "
        "config (e.g., no subagent config where `subagents: false`). "
        "Partial/unknown degrade gracefully via instruction fallback, not invalid config."
    )
    lines.append("")
    # Legend
    lines.append("## Legend")
    lines.append("")
    lines.append("| Symbol | Meaning |")
    lines.append("|--------|---------|")
    lines.append("| ✅ | Supported (native/stable) |")
    lines.append("| ❌ | Not supported |")
    lines.append("| ◐ partial | Partial / bridged / requires runtime |")
    lines.append("| ❓ unknown | Could not confirm from official docs |")
    lines.append("| `v1` | Agent Plugins 1.0 portable |")
    lines.append("| `v1` (portable) | Portable via agent-plugins.org (skills + mcp.json) |")
    lines.append("| `custom` | Tool-specific custom format |")
    lines.append(
        "| `custom` (requires extension X) | Custom agents via client extension — not portable without that extension |"
    )
    lines.append("| — | None / not applicable |")
    lines.append("")
    lines.append(
        "> **Portable vs extension (#973):** `agent_plugins: v1` with `agent_plugins_extension: portable` means portable Agent Plugins 1.0 (skills + mcp.json) per https://agent-plugins.org — guaranteed across Cursor, VS Code, Copilot, Codex, Claude Code. `custom` with `agent_plugins_extension: <extension>` (e.g. `opencode.json`, `gemini-extension.json`, `pi-package.json`) means custom-agent support requires that vendor-specific extension inside an otherwise portable `plugin.json` — not portable without it. `none` = no plugin manifest."
    )
    lines.append("")

    # Main Capability x Target table
    lines.append("## Capability × Target")
    lines.append("")
    # Header row
    header = (
        "| Capability | " + " | ".join(t.get("display_name") or t["id"] for t in targets) + " |"
    )
    sep = "|---|" + "|".join(["---"] * len(targets)) + "|"
    lines.append(header)
    lines.append(sep)
    caps = targets[0].get("capabilities", {}) if targets else {}
    # Use canonical CAPABILITIES order; append any extra keys not in list
    remaining = [k for k in caps.keys() if k not in CAPABILITIES]
    ordered = CAPABILITIES + sorted(remaining)
    for cap in ordered:
        label = CAP_LABELS.get(cap, cap)
        row = [label]
        for t in targets:
            v = t.get("capabilities", {}).get(cap, "—")
            # #973: annotate agent_plugins with portable vs extension distinction
            if cap == "agent_plugins":
                ext = t.get("agent_plugins_extension", "")
                if v == "v1" and ext == "portable":
                    row.append("`v1` (portable)")
                elif v == "custom" and ext and ext not in ("portable", "none"):
                    # show custom + requires extension, truncate long extension for cell readability
                    short = ext.split(" (")[0]
                    row.append(f"`custom` (requires {short})")
                else:
                    row.append(fmt(v))
            else:
                row.append(fmt(v))
        lines.append("| " + " | ".join(row) + " |")
    lines.append("")

    # Commands build/diff/release + Tier table (keep existing fields visible)
    lines.append("## Build Commands & Tiers")
    lines.append("")
    lines.append("| Target | `build` | `diff` | `release` | Tier | Maturity | Aliases |")
    lines.append("|--------|---------|--------|-----------|------|----------|---------|")
    for t in targets:
        cmds = t.get("commands", {})
        aliases = ", ".join(f"`{a}`" for a in t.get("aliases", [])) or "—"
        mat = t.get("maturity", "—")
        tier = t.get("tier", "—")
        lines.append(
            f"| {t.get('display_name') or t['id']} (`{t['id']}`) | {fmt(cmds.get('build'))} | {fmt(cmds.get('diff'))} | {fmt(cmds.get('release'))} | {tier} | {mat} | {aliases} |"
        )
    lines.append("")
    # Tier Assignment table
    lines.append("## Tier Assignment")
    lines.append("")
    lines.append("| Target | Tier | Rationale |")
    lines.append("|--------|------|-----------|")
    for t in targets:
        tier = t.get("tier", "—")
        rationale = (t.get("tier_rationale", "") or "").replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {t.get('display_name') or t['id']} (`{t['id']}`) | {tier} | {rationale} |")
    lines.append("")

    # Per-target details: researched_at, sources, notes, adapter
    lines.append("## Per-Target Details")
    lines.append("")
    for t in targets:
        lines.append(f"### {t.get('display_name') or t['id']} (`{t['id']}`)")
        lines.append("")
        lines.append(f"- **Adapter:** `{t.get('adapter', '')}`")
        lines.append(f"- **Aliases:** {', '.join(f'`{a}`' for a in t.get('aliases', [])) or '—'}")
        cmds = t.get("commands", {})
        lines.append(
            f"- **Commands:** build={fmt(cmds.get('build'))} diff={fmt(cmds.get('diff'))} release={fmt(cmds.get('release'))}"
        )
        lines.append(f"- **Tier:** {t.get('tier', '—')}")
        if t.get("tier_rationale"):
            lines.append(f"- **Tier rationale:** {t.get('tier_rationale')}")
        # #973 portable vs extension
        ext = t.get("agent_plugins_extension", "—")
        caps = t.get("capabilities", {})
        ap = caps.get("agent_plugins", "—")
        if ap == "v1" and ext == "portable":
            lines.append(f"- **Agent Plugins:** `{ap}` (portable via https://agent-plugins.org)")
        elif ap == "custom" and ext not in ("portable", "none", "—", ""):
            lines.append(
                f"- **Agent Plugins:** `{ap}` (requires extension `{ext}` — not portable without it)"
            )
        else:
            lines.append(f"- **Agent Plugins:** `{ap}` / extension `{ext}`")
        lines.append(f"- **Maturity:** {t.get('maturity', '—')}")
        lines.append(f"- **Researched at:** {t.get('researched_at', '—')}")
        srcs = t.get("sources", [])
        if srcs:
            lines.append("- **Sources:**")
            for s in srcs:
                lines.append(f"  - {s}")
        else:
            lines.append("- **Sources:** —")
        if t.get("notes"):
            lines.append(f"- **Notes:** {t['notes']}")
        lines.append("")

    lines.append("## See also")
    lines.append("")
    lines.append(
        "- `capabilities/targets/registry.yaml` — source of truth (validated by `schemas/target-capability-registry.schema.json`)"
    )
    lines.append("- `schemas/target-capability-registry.schema.json` — JSON schema")
    lines.append("- `docs/TARGETS.md` — supported targets overview and install commands")
    lines.append(
        "- `docs/research/platform-capability-matrix.md` — prior research (2026-08-04) and capability value definitions"
    )
    lines.append("- `docs/research/source-ledger.md` — source URLs and dates")
    lines.append("- `agent-toolkit build --check` — compiler drift check")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--check",
        action="store_true",
        help="fail if docs/TARGET_CAPABILITY_MATRIX.md drifts from registry",
    )
    ap.add_argument("--output", default=str(DEFAULT_OUTPUT), help="output path")
    args = ap.parse_args()
    data = load_registry()
    content = render_md(data)
    out = Path(args.output)
    if not out.is_absolute():
        out = REPO_ROOT / out
    if args.check:
        if not out.is_file():
            print(f"Missing matrix file: {out}", file=sys.stderr)
            sys.exit(1)
        existing = out.read_text(encoding="utf-8")
        if existing != content:
            print(f"Matrix out of date: {out} differs from {REGISTRY_PATH}", file=sys.stderr)
            print("Run: python3 scripts/generate-target-matrix.py", file=sys.stderr)
            # show diff hint
            import difflib

            diff = difflib.unified_diff(
                existing.splitlines(),
                content.splitlines(),
                fromfile=str(out),
                tofile="generated",
                lineterm="",
            )
            for line in list(diff)[:200]:
                print(line)
            sys.exit(1)
        print(f"Matrix up to date: {out}")
        return
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(content, encoding="utf-8")
    print(f"Wrote matrix to {out} ({len(content.splitlines())} lines)")


if __name__ == "__main__":
    main()
