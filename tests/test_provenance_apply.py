"""Tests for upstream SKILL.md fidelity helpers and body_checksum."""

from __future__ import annotations

import hashlib
from pathlib import Path

import scripts.provenance as prov


def test_split_skill_text_roundtrip_body():
    text = "---\nname: demo\ndescription: x\n---\n\n# Body\n\nhello\n"
    fm, body = prov._split_skill_text(text)
    assert fm["name"] == "demo"
    assert body == "\n# Body\n\nhello\n"
    assert prov._body_sha256(body) == f"sha256:{hashlib.sha256(body.encode()).hexdigest()}"


def test_merge_preserves_upstream_body_bytes():
    upstream_fm = {"name": "demo", "description": "from upstream", "license": "MIT"}
    overlay = {
        "origin": {"type": "upstream"},
        "upstream": {
            "repository": "acme/skills",
            "path": "skills/demo",
            "ref": "a" * 40,
            "license": "MIT",
        },
        "trust": {"tier": "reviewed"},
        "distribution": {"mode": "vendored", "redistribution_allowed": True},
        "security": {
            "scripts": False,
            "shell": False,
            "network": False,
            "mcp": [],
            "hooks": [],
            "dangerous_permissions": [],
            "cve_policy": "not-applicable",
        },
    }
    body = "# Title\n\nExact body bytes.\n"
    merged = prov._merge_skill_md(upstream_fm, overlay, body)
    fm2, body2 = prov._split_skill_text(merged)
    assert body2 == body
    assert fm2["name"] == "demo"
    assert fm2["description"] == "from upstream"
    assert fm2["origin"]["type"] == "upstream"
    assert fm2["trust"]["tier"] == "reviewed"
    assert "sources" not in fm2 or fm2.get("upstream")


def test_toolkit_overlay_does_not_leak_into_body():
    upstream_fm = {"name": "x", "description": "y"}
    overlay = {"origin": {"type": "upstream"}, "trust": {"tier": "experimental"}}
    body = "line1\nline2\n"
    merged = prov._merge_skill_md(upstream_fm, overlay, body)
    assert "origin:" not in merged.split("---\n", 2)[-1]
    assert merged.endswith("line1\nline2\n") or merged.endswith("line1\nline2\n\n")


def test_body_checksum_mismatch_detection(tmp_path: Path):
    skill = tmp_path / "SKILL.md"
    skill.write_text(
        "---\nname: t\n---\n\n# Original\n",
        encoding="utf-8",
    )
    _fm, body = prov._split_skill_file(skill)
    good = prov._body_sha256(body)
    skill.write_text(
        "---\nname: t\n---\n\n# Tampered\n",
        encoding="utf-8",
    )
    _fm2, body2 = prov._split_skill_file(skill)
    bad = prov._body_sha256(body2)
    assert good != bad


def test_skill_md_path_for_source():
    assert prov._skill_md_path_for_source("skills/frontend-design") == "skills/frontend-design/SKILL.md"
    assert (
        prov._skill_md_path_for_source("skills/megalinter/SKILL.md") == "skills/megalinter/SKILL.md"
    )
    assert prov._skill_md_path_for_source("command.md") == "command.md"
