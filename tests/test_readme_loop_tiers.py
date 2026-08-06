"""README loop tier table must match loops/*/loop.yaml (#83)."""

from __future__ import annotations

import re
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent


def test_readme_loop_tiers_match_yaml():
    readme = (REPO / "README.md").read_text()
    # Extract rows like | `name` | L3 | ...
    listed = dict(re.findall(r"\| `([a-z0-9-]+)` \| (L[123]) \|", readme))
    for loop_yaml in (REPO / "loops").glob("*/loop.yaml"):
        data = yaml.safe_load(loop_yaml.read_text()) or {}
        name = loop_yaml.parent.name
        if name not in listed:
            continue
        assert listed[name] == str(data.get("tier")).upper(), name
