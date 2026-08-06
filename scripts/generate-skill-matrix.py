#!/usr/bin/env python3
"""
Generate docs/SKILL_PRODUCT_MATRIX.md from distributions/products.yaml.

Source of truth is distributions/products.yaml (products define included
skills/agents). The matrix is checked in but validated in CI via --check.
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PRODUCTS_YAML = REPO_ROOT / "distributions" / "products.yaml"
OUTPUT_MD = REPO_ROOT / "docs" / "SKILL_PRODUCT_MATRIX.md"

def load_products():
    text = PRODUCTS_YAML.read_text(encoding="utf-8")
    try:
        import yaml
        return yaml.safe_load(text)
    except ImportError:
        # minimal: parse product ids and includes naively is not enough; require yaml
        print("PyYAML required to generate matrix", file=sys.stderr)
        sys.exit(1)

def build_matrix():
    data = load_products()
    products = data.get("products", [])
    # collect all skills/agents
    sku_to_products: dict[str, list[str]] = {}
    agent_to_products: dict[str, list[str]] = {}
    product_targets: dict[str, list[str]] = {}
    product_stability: dict[str, str] = {}
    for p in products:
        pid = p["id"]
        product_stability[pid] = p.get("stability", "")
        targets = sorted(p.get("targets", {}).keys())
        product_targets[pid] = targets
        for s in p.get("includes", {}).get("skills", []) or []:
            sku_to_products.setdefault(s, []).append(pid)
        for a in p.get("includes", {}).get("agents", []) or []:
            agent_to_products.setdefault(a, []).append(pid)
    # also enumerate canonical skills/agents from filesystem for uncovered detection
    skills_dir = REPO_ROOT / "skills"
    all_skills = sorted(
        str(p.parent.relative_to(skills_dir)) + "/" + p.parent.name
        if False else ""
        for _ in []
    )
    # simpler: walk
    all_skills = []
    for domain in sorted((REPO_ROOT / "skills").iterdir()):
        if not domain.is_dir():
            continue
        for skill in sorted(domain.iterdir()):
            if (skill / "SKILL.md").is_file():
                all_skills.append(f"{domain.name}/{skill.name}")
    all_agents = sorted(
        d.name for d in (REPO_ROOT / "agents").iterdir() if d.is_dir()
    )
    return products, sku_to_products, agent_to_products, product_targets, product_stability, all_skills, all_agents

def render_md():
    products, sku_to_products, agent_to_products, product_targets, product_stability, all_skills, all_agents = build_matrix()
    product_ids = [p["id"] for p in products]
    # header
    lines = []
    lines.append("# Skill → Product → Target Membership Matrix")
    lines.append("")
    lines.append(f"> Generated from `distributions/products.yaml` — do not hand-edit. Run `python3 scripts/generate-skill-matrix.py` to regenerate, or `python3 scripts/generate-skill-matrix.py --check` in CI.")
    lines.append("")
    lines.append(f"_Generated from {len(products)} products × {len(all_skills)} skills × {len(all_agents)} agents._")
    lines.append("")
    lines.append("## Products and targets")
    lines.append("")
    lines.append("| Product | Stability | Targets | Skills | Agents |")
    lines.append("|---------|-----------|---------|--------|--------|")
    for p in products:
        pid = p["id"]
        stab = product_stability.get(pid, "")
        tgs = ", ".join(product_targets.get(pid, [])) or "—"
        sc = len(p.get("includes", {}).get("skills", []) or [])
        ag = len(p.get("includes", {}).get("agents", []) or [])
        lines.append(f"| `{pid}` | {stab} | {tgs} | {sc} | {ag} |")
    lines.append("")
    lines.append("## Skills → Products")
    lines.append("")
    lines.append("| Skill | Products | Targets (via products) |")
    lines.append("|-------|----------|------------------------|")
    for skill in all_skills:
        prods = sku_to_products.get(skill, [])
        if prods:
            prod_str = ", ".join(f"`{p}`" for p in sorted(prods))
            tset = sorted({t for pr in prods for t in product_targets.get(pr, [])})
            target_str = ", ".join(tset) if tset else "—"
        else:
            prod_str = "_uncovered_"
            target_str = "—"
        lines.append(f"| `{skill}` | {prod_str} | {target_str} |")
    lines.append("")
    lines.append("## Agents → Products")
    lines.append("")
    lines.append("| Agent | Products | Targets (via products) |")
    lines.append("|-------|----------|------------------------|")
    for agent in all_agents:
        prods = agent_to_products.get(agent, [])
        if prods:
            prod_str = ", ".join(f"`{p}`" for p in sorted(prods))
            tset = sorted({t for pr in prods for t in product_targets.get(pr, [])})
            target_str = ", ".join(tset) if tset else "—"
        else:
            prod_str = "_uncovered_"
            target_str = "—"
        lines.append(f"| `{agent}` | {prod_str} | {target_str} |")
    lines.append("")
    lines.append("## How to read")
    lines.append("")
    lines.append("- A skill appears in a marketplace plugin when its product is built for that target (`agent-toolkit build --product <id> --target <target>`).")
    lines.append("- `_uncovered_` means the skill/agent is not in any stable product yet — it exists canonically but is not shipped. See Wave 5 curation for promotion decisions.")
    lines.append("- Verify membership locally via `agent-toolkit inventory` (canonical counts) or `python3 scripts/generate-skill-matrix.py --check`.")
    lines.append("")
    lines.append("## See also")
    lines.append("")
    lines.append("- `distributions/products.yaml` — source of truth")
    lines.append("- `agent-toolkit inventory` — CLI inventory")
    lines.append("- `agent-toolkit build --check` — drift check")
    lines.append("")
    return "\n".join(lines) + "\n"

def main() -> int:
    parser = argparse.ArgumentParser(description="Generate skill→product→target matrix")
    parser.add_argument("--check", action="store_true", help="Fail if matrix is out of date")
    parser.add_argument("--output", default=str(OUTPUT_MD), help="Output path")
    args = parser.parse_args()
    content = render_md()
    out = Path(args.output)
    if args.check:
        if not out.is_file():
            print(f"Missing matrix file: {out.relative_to(REPO_ROOT)}", file=sys.stderr)
            return 1
        existing = out.read_text(encoding="utf-8")
        if existing != content:
            print(f"Matrix out of date: {out.relative_to(REPO_ROOT)} differs from distributions/products.yaml", file=sys.stderr)
            print(f"Run: python3 scripts/generate-skill-matrix.py", file=sys.stderr)
            return 1
        print(f"Matrix up to date: {out.relative_to(REPO_ROOT)}")
        return 0
    # also handle --check fallback if yaml missing to just write
    out.write_text(content, encoding="utf-8")
    print(f"Wrote matrix to {out.relative_to(REPO_ROOT)} ({len(content.splitlines())} lines)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
