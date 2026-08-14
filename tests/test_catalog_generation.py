"""Catalogs must match filesystem inventory (#78)."""

from __future__ import annotations

import subprocess
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent


def test_generate_catalogs_matches_disk_ids():
    subprocess.check_call(["v", "run", str(REPO / "scripts" / "generate-catalogs.vsh")], cwd=REPO)
    skills = yaml.safe_load((REPO / "catalogs" / "skill-catalog.yaml").read_text())["skills"]
    disk = {f"{p.parent.parent.name}/{p.parent.name}" for p in (REPO / "skills").rglob("SKILL.md")}
    assert {s["id"] for s in skills} == disk

    agents = yaml.safe_load((REPO / "catalogs" / "agent-catalog.yaml").read_text())["agents"]
    disk_a = {p.parent.name for p in (REPO / "agents").rglob("AGENT.md")}
    assert {a["id"] for a in agents} == disk_a

    loops = yaml.safe_load((REPO / "catalogs" / "loop-catalog.yaml").read_text())["loops"]
    disk_l = {p.parent.name for p in (REPO / "loops").glob("*/loop.yaml")}
    assert {x["id"] for x in loops} == disk_l
