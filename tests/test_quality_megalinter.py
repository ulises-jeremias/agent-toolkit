"""Tests for vendored quality/megalinter* skills — fidelity + AGPL aggregation.

Covers the post-#737 contract (literal upstream bodies, Toolkit frontmatter only):
- four capabilities (orchestrator/setup/check/fix) with origin.upstream + vendored mode
- immutable tag+commit pin, body_checksum in lock, AGPL LICENSE beside each skill
- Toolkit docs live in docs/megalinter/ (not patched into SKILL.md bodies)
- safety phrases that exist in upstream bodies (default-branch, ≤3, DISABLE_LINTERS)
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
LOCK_PATH = REPO_ROOT / "capabilities/upstream.lock"
DOCS_DIR = REPO_ROOT / "docs/megalinter"
TARGETS_REF = DOCS_DIR / "megalinter-targets.md"
LICENSE_REF = DOCS_DIR / "megalinter-license.md"
IMAGES_REF = DOCS_DIR / "megalinter-images.md"
AGPL_POLICY = DOCS_DIR / "AGPL-VENDING.md"

SKILLS = {
    "quality/megalinter": {
        "dir": REPO_ROOT / "skills/quality/megalinter",
        "source_id": "orchestrator",
        "path": "skills/megalinter",
        "role": "orchestrator",
    },
    "quality/megalinter-setup": {
        "dir": REPO_ROOT / "skills/quality/megalinter-setup",
        "source_id": "setup",
        "path": "skills/megalinter-setup",
        "role": "setup",
    },
    "quality/megalinter-check": {
        "dir": REPO_ROOT / "skills/quality/megalinter-check",
        "source_id": "check",
        "path": "skills/megalinter-check",
        "role": "check",
    },
    "quality/megalinter-fix": {
        "dir": REPO_ROOT / "skills/quality/megalinter-fix",
        "source_id": "fix",
        "path": "skills/megalinter-fix",
        "role": "fix",
    },
}

EXPECTED_COMMIT = "15e5b45552097e318c93de385779ce3b1084052c"
EXPECTED_TAG = "v10.0.0"
EXPECTED_DOCKER_TAG = "ghcr.io/oxsecurity/megalinter:v10"
EXPECTED_DOCKER_DIGEST = "sha256:939058f3ed31803e12583365e7126eacfb356724bf003fd29e96a93948aa2d33"


def _fm(path: Path):
    text = path.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---\n", text, re.DOTALL | re.MULTILINE)
    assert m, f"missing frontmatter in {path}"
    return yaml.safe_load(m.group(1)), text


def test_four_skills_vendored_with_license():
    for cap_id, meta in SKILLS.items():
        skill = meta["dir"] / "SKILL.md"
        license_file = meta["dir"] / "LICENSE"
        assert skill.exists(), f"missing {skill}"
        assert license_file.exists(), f"AGPL LICENSE required beside {cap_id}"
        assert "GNU AFFERO GENERAL PUBLIC LICENSE" in license_file.read_text()
        fm, _ = _fm(skill)
        assert fm["origin"]["type"] == "upstream"
        assert fm["distribution"]["mode"] == "vendored"
        assert fm["distribution"]["redistribution_allowed"] is True
        assert fm["distribution"].get("attribution_file") == "LICENSE"
        upstream = fm["upstream"]
        assert upstream["repository"] == "oxsecurity/megalinter"
        assert upstream["path"] == meta["path"]
        assert upstream["ref"] == EXPECTED_TAG
        assert upstream["commit"] == EXPECTED_COMMIT
        assert upstream["license"] == "AGPL-3.0"
        assert upstream.get("role") == meta["role"]
        assert fm["trust"]["tier"] == "reviewed"
        assert fm["trust"]["reviewed_by"] == "ulises-jeremias"
        assert re.match(r"^sha256:[0-9a-f]{64}$", fm["trust"]["reviewed_provenance"])
        assert fm["security"]["shell"] is True
        assert fm["security"]["network"] is True
        # Fidelity: Toolkit overlay keys stay in frontmatter, not a sources[] adapter
        assert "sources" not in fm


def test_lock_vendored_provenance():
    data = yaml.safe_load(LOCK_PATH.read_text())
    import scripts.provenance as prov

    for cap_id, meta in SKILLS.items():
        cap = data["capabilities"][cap_id]
        fm, _ = _fm(meta["dir"] / "SKILL.md")
        assert cap["provenance_digest"] == fm["trust"]["reviewed_provenance"]
        assert cap["provenance_digest"] == prov._provenance_digest(cap["sources"])
        src = cap["sources"][meta["source_id"]]
        assert src["repository"] == "oxsecurity/megalinter"
        assert src["path"] == meta["path"]
        assert src["requested"]["type"] == "tag"
        assert src["requested"]["ref"] == EXPECTED_TAG
        assert src["resolved"]["commit"] == EXPECTED_COMMIT
        assert src["resolved"]["license"]["spdx"] == "AGPL-3.0"
        assert re.match(r"^sha256:[0-9a-f]{64}$", src["resolved"]["content_checksum"])
        assert re.match(r"^sha256:[0-9a-f]{64}$", src["resolved"]["body_checksum"])
        skill_path = meta["dir"] / "SKILL.md"
        assert src["resolved"]["content_checksum"] == prov._file_sha256(skill_path)
        _fm_local, body = prov._split_skill_file(skill_path)
        assert src["resolved"]["body_checksum"] == prov._body_sha256(body)
        lic_path = REPO_ROOT / src["resolved"]["license"]["source_path"]
        assert lic_path.exists()
        assert src["resolved"]["license"]["checksum"] == prov._file_sha256(lic_path)


def test_no_mutable_ref():
    for meta in SKILLS.values():
        fm, _ = _fm(meta["dir"] / "SKILL.md")
        ref = fm["upstream"]["ref"]
        commit = fm["upstream"]["commit"]
        assert ref not in ("main", "master", "latest", "beta"), f"mutable ref {ref}"
        assert re.match(r"^v?[0-9]+\.[0-9]+\.[0-9]+", ref)
        assert re.match(r"^[0-9a-f]{40}$", commit)


def test_release_digest_representation():
    assert TARGETS_REF.exists()
    assert IMAGES_REF.exists()
    assert AGPL_POLICY.exists()
    images = IMAGES_REF.read_text()
    assert EXPECTED_DOCKER_TAG in images
    assert EXPECTED_DOCKER_DIGEST in images
    assert "mega-linter-runner@10.0.0" in images
    assert "sha512-yQOyD8" in images
    assert "tag + verified digest" in images or "tag + digest" in images
    assert "manifest list" in images or "multi-arch" in images


def test_supported_target_mapping():
    targets_ref = TARGETS_REF.read_text()
    for tgt in ["Claude Code", "Cursor", "GitHub Copilot", "OpenCode", "Codex"]:
        assert tgt in targets_ref, f"missing target {tgt} in docs/megalinter/megalinter-targets.md"
    assert "2026-08-12" in targets_ref
    assert "megalinter-watcher" in targets_ref
    assert "megalinter-runner" in targets_ref
    assert "megalinter-fixer" in targets_ref
    assert "Fallback" in targets_ref or "fallback" in targets_ref or "degrade" in targets_ref


def test_orchestrator_upstream_workflow():
    skill = (SKILLS["quality/megalinter"]["dir"] / "SKILL.md").read_text()
    assert "at most 3 times" in skill
    assert "Never commit or push on the default branch" in skill
    assert "megalinter/fix-" in skill
    assert "sub-agent" in skill.lower() or "sub-agents" in skill.lower()
    assert "inline" in skill.lower()
    # Toolkit-only adapter headings must not be patched into the literal body
    assert "DISCOVER CONFIG" not in skill
    assert "--force-with-lease" not in skill


def test_check_and_fix_upstream_contracts():
    check = (SKILLS["quality/megalinter-check"]["dir"] / "SKILL.md").read_text()
    fix = (SKILLS["quality/megalinter-fix"]["dir"] / "SKILL.md").read_text()
    assert "JSON_REPORTER" in check
    assert "targeted re-check" in check.lower()
    assert "DISABLE_LINTERS" in fix
    assert "inline-disable" in fix.lower() or "inline-disable" in fix
    assert "never push to the default branch" in fix.lower()
    assert "ask" in fix.lower()


def test_license_documented_as_vendored_aggregation():
    lic_ref = LICENSE_REF.read_text()
    policy = AGPL_POLICY.read_text()
    assert "AGPL-3.0" in lic_ref
    assert "AGPL infects MIT" not in lic_ref
    assert "aggregation" in lic_ref.lower() or "separate works" in lic_ref.lower()
    assert "vendored" in policy.lower()
    assert "aggregation" in policy.lower()
    assert "LICENSE" in policy
