#!/usr/bin/env python3
"""Regenerate catalogs/{skill,agent,loop}-catalog.yaml from the filesystem (#78)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]


class IndentDumper(yaml.SafeDumper):
    """Force indented sequences so yamllint indentation rule passes."""

    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)



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
    for agent_md in sorted((ROOT / "agents").rglob("AGENT.md")):
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
        data = yaml.safe_load(loop_yaml.read_text()) or {}
        loops.append({
            "id": data.get("id", loop_yaml.parent.name),
            "name": data.get("name", loop_yaml.parent.name),
            "tier": data.get("tier"),
            "cadence": data.get("cadence") or data.get("schedule"),
            "description": str(data.get("description", ""))[:200],
        })
    return {"version": 1, "generated": True, "count": len(loops), "loops": loops}


def main() -> int:
    out = ROOT / "catalogs"
    out.mkdir(exist_ok=True)
    mapping = {
        "skill-catalog.yaml": gen_skills(),
        "agent-catalog.yaml": gen_agents(),
        "loop-catalog.yaml": gen_loops(),
    }
    for name, data in mapping.items():
        path = out / name
        path.write_text(yaml.dump(data, Dumper=IndentDumper, sort_keys=False, allow_unicode=True, default_flow_style=False))
        print(f"wrote {path} ({data['count']} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
