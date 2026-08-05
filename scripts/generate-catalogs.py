#!/usr/bin/env python3
"""Regenerate catalogs/{skill,agent,loop}-catalog.yaml from the filesystem (#78).

Usage:
    python3 scripts/generate-catalogs.py          # write catalogs/
    python3 scripts/generate-catalogs.py --check  # fail if catalogs would change (CI)
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]


def _fm(text: str) -> dict:
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.S)
    if not m:
        return {}
    data = yaml.safe_load(m.group(1)) or {}
    return data if isinstance(data, dict) else {}


def gen_skills() -> dict:
    skills = []
    for skill_md in sorted((ROOT / "skills").rglob("SKILL.md")):
        domain = skill_md.parent.parent.name
        name = skill_md.parent.name
        fm = _fm(skill_md.read_text(errors="replace"))
        skills.append({
            "id": f"{domain}/{name}",
            "name": fm.get("name", name),
            "domain": domain,
            "description": str(fm.get("description", ""))[:200],
            "stability": fm.get("stability", "stable"),
        })
    return {"version": 1, "generated": True, "count": len(skills), "skills": skills}


def gen_agents() -> dict:
    agents = []
    for agent_md in sorted((ROOT / "agents").glob("*/AGENT.md")):
        name = agent_md.parent.name
        fm = _fm(agent_md.read_text(errors="replace"))
        agents.append({
            "id": name,
            "name": fm.get("name", name),
            "description": str(fm.get("description", ""))[:200],
        })
    return {"version": 1, "generated": True, "count": len(agents), "agents": agents}


def gen_loops() -> dict:
    loops = []
    for loop_yaml in sorted((ROOT / "loops").glob("*/loop.yaml")):
        data = yaml.safe_load(loop_yaml.read_text(encoding="utf-8")) or {}
        loop_name = data.get("name", loop_yaml.parent.name)
        loops.append({
            "id": loop_name,
            "name": loop_name,
            "tier": data.get("tier"),
            "cadence": data.get("cadence") or data.get("schedule"),
            "description": str(data.get("description", ""))[:200],
        })
    return {"version": 1, "generated": True, "count": len(loops), "loops": loops}


def _render(data: dict) -> str:
    return yaml.safe_dump(data, sort_keys=False, allow_unicode=True)


def _catalogs() -> dict[str, dict]:
    return {
        "skill-catalog.yaml": gen_skills(),
        "agent-catalog.yaml": gen_agents(),
        "loop-catalog.yaml": gen_loops(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if on-disk catalogs differ from generated output",
    )
    args = parser.parse_args()

    out_dir = ROOT / "catalogs"
    out_dir.mkdir(exist_ok=True)
    drift = False

    for name, data in _catalogs().items():
        path = out_dir / name
        rendered = _render(data)
        if args.check:
            if not path.is_file() or path.read_text(encoding="utf-8") != rendered:
                print(f"  DRIFT: {path} is out of date — run: python3 scripts/generate-catalogs.py")
                drift = True
            else:
                print(f"  OK: {path} ({data['count']} entries)")
            continue
        path.write_text(rendered, encoding="utf-8")
        print(f"wrote {path} ({data['count']} entries)")

    if args.check and drift:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
