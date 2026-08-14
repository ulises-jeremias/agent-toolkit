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
    assert (
        prov._skill_md_path_for_source("skills/frontend-design")
        == "skills/frontend-design/SKILL.md"
    )
    assert (
        prov._skill_md_path_for_source("skills/megalinter/SKILL.md") == "skills/megalinter/SKILL.md"
    )
    assert prov._skill_md_path_for_source("command.md") == "command.md"


def test_apply_skill_update_sets_experimental(tmp_path, monkeypatch):
    skill_dir = tmp_path / "skills" / "quality" / "megalinter"
    skill_dir.mkdir(parents=True)
    skill = skill_dir / "SKILL.md"
    skill.write_text(
        "---\n"
        "name: megalinter\n"
        "description: local\n"
        "origin:\n"
        "  type: upstream\n"
        "upstream:\n"
        "  repository: oxsecurity/megalinter\n"
        "  path: skills/megalinter\n"
        "  ref: v10.0.0\n"
        "  commit: 15e5b45552097e318c93de385779ce3b1084052c\n"
        "  license: AGPL-3.0\n"
        "  role: orchestrator\n"
        "trust:\n"
        "  tier: reviewed\n"
        "  reviewed_by: tester\n"
        "  reviewed_provenance: sha256:" + ("a" * 64) + "\n"
        "distribution:\n"
        "  mode: vendored\n"
        "---\n"
        "\n# Old body\n",
        encoding="utf-8",
    )
    upstream = "---\nname: megalinter\ndescription: from upstream\n---\n\n# New body\n"
    monkeypatch.setattr(prov, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(prov, "_fetch_raw_bytes", lambda *a, **k: upstream.encode())
    monkeypatch.setattr(prov, "_copy_upstream_tree", lambda *a, **k: [])

    result = prov._apply_skill_update(
        cap_id="quality/megalinter",
        source_id="orchestrator",
        repository="oxsecurity/megalinter",
        path="skills/megalinter",
        new_commit="b" * 40,
        new_ref="v10.1.0",
        req_type="tag",
        skill_path=skill,
    )
    fm, body = prov._split_skill_file(skill)
    assert fm["trust"]["tier"] == "experimental"
    assert "reviewed_provenance" not in fm["trust"]
    assert body == "\n# New body\n"
    assert fm["upstream"]["ref"] == "v10.1.0"
    assert fm["upstream"]["commit"] == "b" * 40
    assert result["body_checksum"] == prov._body_sha256(body)


def test_upstream_pr_body_lists_applied_updates():
    from scripts.upstream_pr_body import render

    md = render(
        {
            "applied": [
                {
                    "capability": "design/frontend-design",
                    "source": "upstream",
                    "old_commit": "a" * 40,
                    "new_commit": "b" * 40,
                    "body_checksum": "sha256:" + "c" * 64,
                }
            ]
        }
    )
    assert "Do not auto-merge" in md
    assert "design/frontend-design" in md
    assert "experimental" in md
    assert md.endswith("\n")
