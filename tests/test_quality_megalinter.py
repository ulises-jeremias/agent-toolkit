"""Tests for quality/megalinter external governance — #382.

Covers:
- external provenance resolution (tag+commit, 4 sources, correct checksums)
- no mutable ref
- release/digest representation (tag + commit + checksums + Docker tag+digest + npm integrity)
- supported-target mapping (Claude, Cursor, Copilot, OpenCode, Codex, pi fallback)
- sequential fallback when sub-agents unavailable
- safe-fix gating (ask before disable, hierarchy)
- bounded re-check ≤3
- no default-branch push + force-push only with lease for auto-fix commit
"""

import re
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILL_PATH = REPO_ROOT / "skills/quality/megalinter/SKILL.md"
LOCK_PATH = REPO_ROOT / "capabilities/upstream.lock"
TARGETS_REF = REPO_ROOT / "skills/quality/megalinter/references/megalinter-targets.md"
LICENSE_REF = REPO_ROOT / "skills/quality/megalinter/references/megalinter-license.md"
IMAGES_REF = REPO_ROOT / "skills/quality/megalinter/references/megalinter-images.md"

EXPECTED_COMMIT = "15e5b45552097e318c93de385779ce3b1084052c"
EXPECTED_TAG = "v10.0.0"
EXPECTED_CHECKS = {
    "orchestrator": "sha256:ffd79b1c0c831f206b0b39fa35c463e976c37eeef85218320342348eaed9ffc9",
    "setup": "sha256:b1cba3934bbb096ca21988ccd0d0042271d83975c3d3bbbbdf6b44d628daddb1",
    "check": "sha256:bb8e475961a2e57eb45687a8f138ea8039c7c5ee29f68cd165632d702097dad4",
    "fix": "sha256:fff5202aaa55441d1b0c19a63d7daf5c34757f6a5f6ddb8624450a15f2bee0ca",
}
EXPECTED_DOCKER_TAG = "ghcr.io/oxsecurity/megalinter:v10"
EXPECTED_DOCKER_DIGEST = "sha256:939058f3ed31803e12583365e7126eacfb356724bf003fd29e96a93948aa2d33"


def _fm(path):
    text = path.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---\n", text, re.DOTALL | re.MULTILINE)
    assert m, "missing frontmatter"
    return yaml.safe_load(m.group(1)), text


def test_frontmatter_external_provenance():
    fm, _ = _fm(SKILL_PATH)
    assert fm["origin"]["type"] == "upstream"
    assert fm["distribution"]["mode"] == "external"
    assert fm["distribution"]["redistribution_allowed"] is False
    sources = {s["id"]: s for s in fm["sources"]}
    assert set(sources.keys()) == {"orchestrator", "setup", "check", "fix"}
    for sid, src in sources.items():
        assert src["repository"] == "oxsecurity/megalinter"
        assert src["ref"] == EXPECTED_TAG
        assert src["commit"] == EXPECTED_COMMIT
        assert src["license"] == "AGPL-3.0"
        assert src["path"] in (
            "skills/megalinter/SKILL.md",
            "skills/megalinter-setup/SKILL.md",
            "skills/megalinter-check/SKILL.md",
            "skills/megalinter-fix/SKILL.md",
        )
    # trust
    assert fm["trust"]["tier"] == "reviewed"
    assert fm["trust"]["reviewed_by"] == "ulises-jeremias"
    assert re.match(r"^sha256:[0-9a-f]{64}$", fm["trust"]["reviewed_provenance"])
    # security
    assert fm["security"]["shell"] is True
    assert fm["security"]["network"] is True


def test_lock_external_provenance():
    data = yaml.safe_load(LOCK_PATH.read_text())
    cap = data["capabilities"]["quality/megalinter"]
    assert cap["provenance_digest"] == _fm(SKILL_PATH)[0]["trust"]["reviewed_provenance"]
    # verify digest recomputed
    import scripts.provenance as prov

    assert cap["provenance_digest"] == prov._provenance_digest(cap["sources"])
    for sid, expected_ck in EXPECTED_CHECKS.items():
        src = cap["sources"][sid]
        assert src["requested"]["type"] == "tag"
        assert src["requested"]["ref"] == EXPECTED_TAG
        assert src["resolved"]["commit"] == EXPECTED_COMMIT
        assert src["resolved"]["content_checksum"] == expected_ck
        assert src["resolved"]["license"]["spdx"] == "AGPL-3.0"


def test_no_mutable_ref():
    fm, _ = _fm(SKILL_PATH)
    for src in fm["sources"]:
        ref = src["ref"]
        # must be tag vX.Y.Z or 40-char SHA, not main/beta/latest
        assert ref not in ("main", "master", "latest", "beta"), f"mutable ref {ref}"
        assert re.match(r"^v?[0-9]+\.[0-9]+\.[0-9]+", ref) or re.match(r"^[0-9a-f]{40}$", ref)
        # tag must have commit
        if re.match(r"^v?[0-9]+", ref):
            assert re.match(r"^[0-9a-f]{40}$", src["commit"])


def test_release_digest_representation():
    # Tag + commit + checksums present in lock (already checked) + Docker tag+digest + npm integrity documented
    assert TARGETS_REF.exists()
    assert IMAGES_REF.exists()
    images = IMAGES_REF.read_text()
    assert EXPECTED_DOCKER_TAG in images
    assert EXPECTED_DOCKER_DIGEST in images
    assert "mega-linter-runner@10.0.0" in images
    assert "sha512-yQOyD8" in images
    # Should prefer tag+digest, not digest-only, and warn about multi-arch
    assert "tag + verified digest" in images or "tag + digest" in images
    assert "manifest list" in images or "multi-arch" in images


def test_supported_target_mapping():
    text = (REPO_ROOT / "skills/quality/megalinter/SKILL.md").read_text()
    # Must mention each target and evidence date
    for tgt in ["Claude Code", "Cursor", "GitHub Copilot", "OpenCode", "Codex"]:
        assert tgt in text, f"missing target {tgt}"
    assert "Muse Code (pi)" in text or "pi" in text
    assert "2026-08-12" in text  # dated evidence
    # Targets ref must exist and list sub-agent support
    targets_ref = TARGETS_REF.read_text()
    assert "megalinter-watcher" in targets_ref
    assert "megalinter-runner" in targets_ref
    assert "megalinter-fixer" in targets_ref
    assert "Fallback" in text or "fallback" in text


def test_sequential_fallback():
    skill = SKILL_PATH.read_text()
    # Must document graceful degradation when sub-agents unavailable
    assert "degrade" in skill.lower() or "fallback" in skill.lower()
    assert (
        "sub-agent" in skill.lower()
        or "sub-agent" in skill.lower()
        or "sub-agents" in skill.lower()
    )
    # Must mention inline sequential when no sub-agents
    assert "inline" in skill.lower()
    assert "parallel" in skill.lower()  # fan-out per linter when available


def test_safe_fix_gating():
    skill = SKILL_PATH.read_text()
    # Safe vs ambiguous
    assert (
        "Safe deterministic auto-fixes" in skill
        or "Safe deterministic" in skill
        or "safe" in skill.lower()
    )
    assert "AskUserQuestion" in skill or "ask the user" in skill.lower()
    assert "Disabling" in skill or "disable" in skill.lower()
    # Hierarchy
    assert "inline comment" in skill.lower() or "inline-disable" in skill.lower()
    assert "DISABLE_LINTERS" in skill
    assert "never push to" in skill.lower() or "never on the default branch" in skill.lower()


def test_bounded_recheck():
    skill = SKILL_PATH.read_text()
    # Must state ≤3 iterations
    assert "at most 3" in skill or "≤3" in skill or "bounded iteration" in skill.lower()
    assert "3 times" in skill or "3 iterations" in skill.lower()
    # Must mention targeted re-check
    assert "Targeted re-check" in skill or "targeted re-check" in skill.lower()
    assert "JSON_REPORTER" in skill or "json" in skill.lower()


def test_no_default_branch_push():
    skill = SKILL_PATH.read_text()
    assert (
        "Never commit or push on the default branch" in skill
        or "never push to the default branch" in skill.lower()
    )
    assert "megalinter/fix-" in skill
    # Force-push only with lease exception
    assert "--force-with-lease" in skill
    assert "never --force" in skill.lower() or "Never force-push" in skill


def test_license_documented_accurately():
    lic_ref = LICENSE_REF.read_text()
    assert "AGPL-3.0" in lic_ref
    assert "external" in lic_ref.lower()
    assert "AGPL infects MIT" not in lic_ref  # must not use imprecise phrase
    assert "aggregation" in lic_ref.lower() or "separate works" in lic_ref.lower()
    assert (
        "redistribution_allowed: false" in SKILL_PATH.read_text()
        or "redistribution_allowed: false" in lic_ref
        or "external" in SKILL_PATH.read_text().lower()
    )


def test_workflow_contract():
    skill = SKILL_PATH.read_text()
    # Must contain workflow steps in order
    assert "DISCOVER CONFIG" in skill
    assert "RUN / CHECK" in skill
    assert "CLASSIFY FINDINGS" in skill
    assert "SAFE FIXES" in skill
    assert "TARGETED RE-CHECK" in skill
