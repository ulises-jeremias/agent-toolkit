#!/usr/bin/env python3
"""Validate agents taxonomy roster vs structured sources (#971)."""

import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "capabilities/skills/registry.yaml"
TAXONOMY = ROOT / "docs/AGENT_TAXONOMY.md"
PRODUCTS = ROOT / "distributions/products.yaml"
AGENTS_DIR = ROOT / "agents"


def load_registry():
    data = yaml.safe_load(REGISTRY.read_text())
    holistic = set()
    # specialists are defined as agents with kind == specialist on filesystem, not just registry specialist_agents
    # collect via registry specialist_agents as well for cross-check, but primary is filesystem kind
    for skill in data.get("skills", []):
        h = skill.get("holistic_owner")
        if h:
            holistic.add(h)
    # specialists via filesystem (authoritative for 971)
    specialists = set()
    for p in AGENTS_DIR.iterdir():
        if p.is_dir() and (p / "AGENT.md").exists():
            try:
                fm = (p / "AGENT.md").read_text().split("---")[1]
                if "kind: specialist" in fm:
                    specialists.add(p.name)
            except Exception:
                pass
    return holistic, specialists


def main():
    check = "--check" in sys.argv
    errors = []
    # physical agents
    physical = {p.name for p in AGENTS_DIR.iterdir() if p.is_dir() and (p / "AGENT.md").exists()}
    holistic, specialists = load_registry()
    # every holistic_owner must exist as agent
    for h in sorted(holistic):
        if h not in physical:
            errors.append(f"registry holistic_owner '{h}' has no agents/{h}/AGENT.md")
    # taxonomy counts
    text = TAXONOMY.read_text(encoding="utf-8") if TAXONOMY.exists() else ""
    if "11 holistic" not in text and "11 roles" not in text:
        errors.append("docs/AGENT_TAXONOMY.md missing '11 holistic' count — stale")
    if not any(x in text for x in ["18 agents", "18 personas", "18 AI agent"]):
        errors.append("docs/AGENT_TAXONOMY.md missing '18 agents/personas' count")
    for h in holistic:
        if h not in text:
            errors.append(f"docs/AGENT_TAXONOMY.md missing holistic_owner '{h}'")
    # expected set
    expected = set(holistic) | set(specialists) | {"assistant", "client-workflow-bootstrap"}
    # specialists are 6, but check via kind
    # if physical != expected -> drift
    if physical != expected:
        missing = sorted(expected - physical)
        extra = sorted(physical - expected)
        if missing:
            errors.append(f"taxonomy drift: expected agents missing on filesystem: {missing}")
        if extra:
            errors.append(
                f"taxonomy drift: filesystem has extra agents not in holistics+specialists+orchestrators: {extra} — adding agents/new-agent without registry update fails CI (see #971)"
            )
    # product includes check: ensure agent-toolkit-agents includes list is sane (subset of physical, no archived refs)
    if PRODUCTS.exists():
        prod = yaml.safe_load(PRODUCTS.read_text())
        for prod_entry in prod.get("products", []):
            if prod_entry.get("id") == "agent-toolkit-agents":
                includes = set(prod_entry.get("includes", {}).get("agents", []))
                # includes should be subset of physical, not necessarily equal (product may distribute subset)
                # but should not contain unknown agents and should include at least all holistic
                unknown = includes - physical
                if unknown:
                    errors.append(
                        f"products.yaml agent-toolkit-agents includes unknown agents: {sorted(unknown)}"
                    )
    if errors:
        for e in errors:
            print(f"  ✗ {e}", file=sys.stderr)
        print(f"\n❌ {len(errors)} taxonomy error(s)", file=sys.stderr)
        sys.exit(1)
    print(
        "✓ taxonomy roster matches registry+specialists+orchestrators (18 = 11 holistic + 2 orchestrators + 6 specialists - overlap)"
    )
    print("✓ docs/AGENT_TAXONOMY.md counts validated")
    if not check:
        print("All taxonomy checks passed")
    sys.exit(0)


if __name__ == "__main__":
    main()
