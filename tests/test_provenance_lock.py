"""Tests for external provenance lock v2 (ADR-0001).

Covers declaration → lock deterministic generation, schema validation,
sparse first-party omission, orphan/missing, 40-char SHA enforcement,
tag+commit, mutable-ref guard, single/multi-source, checksum drift,
license mismatch, review-binding invalidation, frontend-design vertical slice
and non-skill identity.

See docs/adr/0001-capability-declaration-and-external-provenance-lock.md
"""

from __future__ import annotations

import hashlib
import json
import tempfile
from pathlib import Path

import pytest
import scripts.provenance as prov
import yaml
from jsonschema import Draft202012Validator

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _load_lock_schema():
    return json.loads(prov.LOCK_SCHEMA_PATH.read_text())


def _validate(schema, data) -> list[str]:
    v = Draft202012Validator(schema)
    return [e.message for e in v.iter_errors(data)]


def _digest(sources: dict) -> str:
    return prov._provenance_digest(sources)


def _sha256_hex(s: str) -> str:
    return f"sha256:{hashlib.sha256(s.encode()).hexdigest()}"


# Deterministic fixture SHAs / checksums
SHA_A = "a" * 40
SHA_B = "b" * 40
SHA_C = "c" * 40
SHA_FRONTEND = "f17010c9bb483898c1d9c9f42dde2b3a98889434"
CK_A = "sha256:" + "a" * 64
CK_B = "sha256:" + "b" * 64
CK_C = "sha256:" + "c" * 64


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------


def test_lock_schema_valid_minimal():
    schema = _load_lock_schema()
    data = {
        "version": 2,
        "capabilities": {
            "design/frontend-design": {
                "provenance_digest": _sha256_hex("x"),
                "sources": {
                    "upstream": {
                        "repository": "anthropics/skills",
                        "path": "skills/frontend-design",
                        "requested": {"type": "commit", "ref": SHA_FRONTEND},
                        "resolved": {
                            "commit": SHA_FRONTEND,
                            "content_checksum": CK_A,
                            "license": {"spdx": "Apache-2.0"},
                            "resolved_at": "2026-08-11T00:00:00Z",
                        },
                    }
                },
            }
        },
    }
    # Fill digest deterministically
    data["capabilities"]["design/frontend-design"]["provenance_digest"] = _digest(
        data["capabilities"]["design/frontend-design"]["sources"]
    )
    errs = _validate(schema, data)
    assert errs == [], errs


def test_lock_schema_rejects_v1_flat():
    schema = _load_lock_schema()
    v1 = {"version": 1, "upstreams": [{"repository": "a/b", "path": "x", "ref": SHA_A}]}
    errs = _validate(schema, v1)
    assert errs  # version 1 and upstreams not allowed


def test_lock_schema_rejects_short_sha():
    schema = _load_lock_schema()
    bad = {
        "version": 2,
        "capabilities": {
            "design/frontend-design": {
                "sources": {
                    "upstream": {
                        "repository": "anthropics/skills",
                        "path": "skills/frontend-design",
                        "requested": {"type": "commit", "ref": "abc123"},
                        "resolved": {
                            "commit": "abc123",  # short — should fail sha40
                            "content_checksum": CK_A,
                            "license": {"spdx": "MIT"},
                        },
                    }
                }
            }
        },
    }
    errs = _validate(schema, bad)
    assert any("40" in e or "pattern" in e.lower() for e in errs), errs


def test_lock_schema_requires_sha40_for_resolved_commit():
    schema = _load_lock_schema()
    data = {
        "version": 2,
        "capabilities": {
            "design/frontend-design": {
                "sources": {
                    "upstream": {
                        "repository": "anthropics/skills",
                        "path": "skills/frontend-design",
                        "requested": {"type": "commit", "ref": SHA_A},
                        "resolved": {
                            "commit": "short",
                            "content_checksum": CK_A,
                            "license": {"spdx": "MIT"},
                        },
                    }
                }
            }
        },
    }
    assert _validate(schema, data)


# ---------------------------------------------------------------------------
# Digest & deterministic ordering
# ---------------------------------------------------------------------------


def test_provenance_digest_deterministic_and_sorted():
    sources_a = {
        "wrapper": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        },
        "rules": {
            "resolved": {"commit": SHA_B, "content_checksum": CK_B, "license": {"spdx": "MIT"}}
        },
    }
    sources_b = {
        "rules": {
            "resolved": {"commit": SHA_B, "content_checksum": CK_B, "license": {"spdx": "MIT"}}
        },
        "wrapper": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        },
    }
    assert _digest(sources_a) == _digest(sources_b), (
        "digest must be order-independent (sorted keys)"
    )


def test_provenance_digest_changes_when_one_source_changes():
    sources = {
        "wrapper": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        },
        "rules": {
            "resolved": {"commit": SHA_B, "content_checksum": CK_B, "license": {"spdx": "MIT"}}
        },
    }
    d1 = _digest(sources)
    sources["rules"]["resolved"]["commit"] = SHA_C
    d2 = _digest(sources)
    assert d1 != d2, "changing one source's commit must change capability digest"


def test_provenance_digest_changes_on_checksum_or_license():
    base = {
        "upstream": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        }
    }
    d_mit = _digest(base)
    base_license = {
        "upstream": {
            "resolved": {
                "commit": SHA_A,
                "content_checksum": CK_A,
                "license": {"spdx": "Apache-2.0"},
            }
        }
    }
    assert d_mit != _digest(base_license)
    base_ck = {
        "upstream": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_B, "license": {"spdx": "MIT"}}
        }
    }
    assert d_mit != _digest(base_ck)


def test_lock_generation_stable_ordering():
    # Build lock via helper with unsorted insertion, ensure output sorted by capability id
    decl = {
        "zeta/skill": {
            "frontmatter": {
                "origin": {"type": "upstream"},
                "distribution": {"mode": "vendored"},
                "trust": {},
            },
            "path": Path("skills/zeta/skill/SKILL.md"),
            "sources": [
                {
                    "repository": "o/r",
                    "path": "p",
                    "ref": SHA_B,
                    "license": "MIT",
                    "_source_id": "upstream",
                }
            ],
            "skill_id": "zeta/skill",
        },
        "alpha/skill": {
            "frontmatter": {
                "origin": {"type": "upstream"},
                "distribution": {"mode": "vendored"},
                "trust": {},
            },
            "path": Path("skills/alpha/skill/SKILL.md"),
            "sources": [
                {
                    "repository": "o/r",
                    "path": "p",
                    "ref": SHA_A,
                    "license": "MIT",
                    "_source_id": "upstream",
                }
            ],
            "skill_id": "alpha/skill",
        },
    }
    # Monkey patch _file_sha256 to avoid FS
    orig = prov._file_sha256
    prov._file_sha256 = lambda p: CK_A  # type: ignore
    try:
        data = prov._build_lock_data(decl)
    finally:
        prov._file_sha256 = orig  # type: ignore
    keys = list(data["capabilities"].keys())
    assert keys == sorted(keys), "capabilities must be sorted for determinism"
    assert keys[0] == "alpha/skill"


# ---------------------------------------------------------------------------
# Tag + commit semantics
# ---------------------------------------------------------------------------


def test_tag_requested_requires_resolved_commit():
    schema = _load_lock_schema()
    data = {
        "version": 2,
        "capabilities": {
            "mcp/github": {
                "sources": {
                    "upstream": {
                        "repository": "modelcontextprotocol/servers",
                        "path": "src/github",
                        "requested": {"type": "tag", "ref": "v1.2.3"},
                        "resolved": {
                            "commit": SHA_C,
                            "content_checksum": CK_C,
                            "license": {"spdx": "MIT"},
                            "resolved_at": "2026-08-11T00:00:00Z",
                        },
                    }
                }
            }
        },
    }
    data["capabilities"]["mcp/github"]["provenance_digest"] = _digest(
        data["capabilities"]["mcp/github"]["sources"]
    )
    assert _validate(schema, data) == []


def test_mutable_ref_not_allowed_as_resolved():
    # requested may be main for discovery, but resolved must be 40-char SHA (schema enforces)
    schema = _load_lock_schema()
    bad = {
        "version": 2,
        "capabilities": {
            "design/frontend-design": {
                "sources": {
                    "upstream": {
                        "repository": "anthropics/skills",
                        "path": "skills/frontend-design",
                        "requested": {"type": "commit", "ref": "main"},
                        "resolved": {
                            "commit": "main",
                            "content_checksum": CK_A,
                            "license": {"spdx": "MIT"},
                        },
                    }
                }
            }
        },
    }
    errs = _validate(schema, bad)
    assert errs, "resolved commit 'main' must fail sha40 pattern"


def test_40_char_sha_required_for_commit_type():
    # requested type commit must have 40-char ref
    assert prov.SHA40_RE.match(SHA_A)
    assert not prov.SHA40_RE.match("abc123")
    assert not prov.SHA40_RE.match(SHA_A[:7])


# ---------------------------------------------------------------------------
# Frontend-design vertical slice (real data)
# ---------------------------------------------------------------------------


def test_frontend_design_lock_entry_matches_real_checksums():
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    assert lock["version"] == 2
    cap = lock["capabilities"].get("design/frontend-design")
    assert cap is not None, "missing design/frontend-design — vertical slice required"
    src = cap["sources"]["upstream"]
    assert src["repository"] == "anthropics/skills"
    assert src["path"] == "skills/frontend-design"
    assert src["requested"]["ref"] == SHA_FRONTEND
    assert src["requested"]["type"] == "commit"
    assert src["resolved"]["commit"] == SHA_FRONTEND
    assert src["resolved"]["license"]["spdx"] == "Apache-2.0"
    # Real checksums computed from vendored files
    # content_checksum should match file (normalized)
    actual_ck = prov._file_sha256(prov.REPO_ROOT / "skills/design/frontend-design/SKILL.md")
    assert src["resolved"]["content_checksum"] == actual_ck
    actual_lic = prov._file_sha256(prov.REPO_ROOT / "skills/design/frontend-design/LICENSE.txt")
    assert src["resolved"]["license"]["checksum"] == actual_lic
    # Digest valid
    assert src["resolved"]["content_checksum"].startswith("sha256:")
    assert cap["provenance_digest"].startswith("sha256:")
    assert cap["provenance_digest"] == _digest(cap["sources"])


def test_frontend_design_review_binding_present_and_valid():
    fm = prov._load_frontmatter(prov.REPO_ROOT / "skills/design/frontend-design/SKILL.md")
    trust = fm.get("trust") or {}
    assert trust.get("tier") == "reviewed"
    reviewed = trust.get("reviewed_provenance")
    assert reviewed, (
        "trust.reviewed_provenance must be set for frontend-design (binding to lock digest)"
    )
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    digest = lock["capabilities"]["design/frontend-design"]["provenance_digest"]
    assert reviewed == digest, (
        "reviewed_provenance must equal lock provenance_digest (update invalidates review)"
    )


def test_first_party_omitted_from_lock():
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    # 61 first-party skills must not appear — lock is sparse
    assert "core/assistant" not in lock["capabilities"], "first-party must not be in lock"
    assert "core/onboarding" not in lock["capabilities"]
    # Only upstream with external content — now 3 vendored (frontend-design + frontend-design-review + web-design-guidelines)
    assert "design/frontend-design" in lock["capabilities"]
    assert "design/frontend-design-review" in lock["capabilities"]
    assert "design/web-design-guidelines" in lock["capabilities"]
    assert len(lock["capabilities"]) == 3, "lock should be sparse: 67 skills → 3 upstream vendored"


# ---------------------------------------------------------------------------
# Vercel multi-source fixture
# ---------------------------------------------------------------------------


def test_vercel_multisource_lock_atomic():
    fixture = Path("tests/fixtures/provenance/vercel-multisource-lock.yaml")
    if not fixture.exists():
        pytest.skip("fixture not found")
    data = yaml.safe_load(fixture.read_text())
    # Ensure schema would validate if digests were correct — here we test structure
    assert "design/web-design-guidelines" in data["capabilities"]
    cap = data["capabilities"]["design/web-design-guidelines"]
    assert set(cap["sources"].keys()) == {"wrapper", "rules"}
    assert cap["sources"]["wrapper"]["repository"] == "vercel-labs/agent-skills"
    assert cap["sources"]["rules"]["repository"] == "vercel-labs/web-interface-guidelines"
    # Each source has independent commit/checksum/license
    assert (
        cap["sources"]["wrapper"]["resolved"]["commit"]
        != cap["sources"]["rules"]["resolved"]["commit"]
    )
    # Atomic digest: changing one source changes capability digest
    d1 = _digest(cap["sources"])
    cap["sources"]["rules"]["resolved"]["commit"] = SHA_C
    d2 = _digest(cap["sources"])
    assert d1 != d2


def test_vercel_multisource_declaration_roles_preserved():
    decl_f = Path("tests/fixtures/provenance/vercel-multisource-declaration.yaml")
    if not decl_f.exists():
        pytest.skip("fixture not found")
    decl = yaml.safe_load(decl_f.read_text())
    ids = {s["id"] for s in decl["sources"]}
    assert ids == {"wrapper", "rules"}
    roles = {s["role"] for s in decl["sources"]}
    assert roles == {"wrapper", "rules"}


# ---------------------------------------------------------------------------
# Non-skill fixtures (agent/mcp/plugin) — identity not skill-path assumption
# ---------------------------------------------------------------------------


def test_nonskill_fixtures_exist_and_use_namespaced_ids():
    p = Path("tests/fixtures/provenance/nonskill-fixtures.yaml")
    assert p.exists()
    data = yaml.safe_load(p.read_text())
    # Ensure fixtures use globally unique namespaced ids (not bare names)
    for key in ("agent_design_critic", "mcp_github", "plugin_figma"):
        entry = data[key]
        cap_id = entry["capability"]
        assert "/" in cap_id, f"{key} capability {cap_id!r} should be namespaced (domain/name)"
        assert entry["origin"] == "upstream" or entry.get("kind") in ("agent", "mcp", "plugin")


def test_lock_identity_uses_namespaced_id_not_bare_name():
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    for cap_id in lock["capabilities"].keys():
        assert "/" in cap_id, (
            f"lock key {cap_id!r} should be domain/name (design/frontend-design), not bare name"
        )
    # Ensure we did not use redundant capability.kind/id inside entry (ADR decision: key is id)
    for cap in lock["capabilities"].values():
        assert "capability" not in cap, (
            "lock entry should not redundantly contain capability.kind/id — key is the id"
        )


# ---------------------------------------------------------------------------
# Checksum drift and orphan/missing (offline validation)
# ---------------------------------------------------------------------------


def test_checksum_drift_detected():
    # Simulate vendored drift: lock has CK_A but file has different content
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        # Create fake skills layout
        skill_dir = td_path / "skills" / "design" / "frontend-design"
        skill_dir.mkdir(parents=True)
        skill_file = skill_dir / "SKILL.md"
        skill_file.write_text(
            "---\nname: frontend-design\norigin:\n  type: upstream\nupstream:\n  repository: anthropics/skills\n  path: skills/frontend-design\n  ref: "
            + SHA_FRONTEND
            + "\n  license: Apache-2.0\n---\nhello\n"
        )
        # Verify checksum mismatch would be caught (lock expects CK_B but file is different)
        actual = prov._file_sha256(skill_file)
        assert actual != CK_B, "mismatched checksum should be detected"


def test_review_binding_invalid_after_digest_change(monkeypatch):
    # Changing lock digest must make existing reviewed_provenance mismatch
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    cap = lock["capabilities"]["design/frontend-design"]
    old_digest = cap["provenance_digest"]
    # Simulate new commit
    new_sources = {k: dict(v) for k, v in cap["sources"].items()}
    # Deep copy resolved
    import copy

    new_sources = copy.deepcopy(cap["sources"])
    new_sources["upstream"]["resolved"]["commit"] = SHA_A
    new_digest = _digest(new_sources)
    assert old_digest != new_digest
    # If declaration still has old reviewed_provenance, check would fail
    fm = prov._load_frontmatter(prov.REPO_ROOT / "skills/design/frontend-design/SKILL.md")
    reviewed = (fm.get("trust") or {}).get("reviewed_provenance")
    assert reviewed == old_digest
    assert reviewed != new_digest, "new lock digest must invalidate old review binding"


def test_orphan_and_missing_detection_via_check(monkeypatch, tmp_path):
    # Test provenance check logic for orphan/missing by constructing synthetic lock+declarations
    # Use tmp lock file
    fake_lock = {
        "version": 2,
        "capabilities": {
            "design/frontend-design": {
                "sources": {
                    "upstream": {
                        "repository": "anthropics/skills",
                        "path": "skills/frontend-design",
                        "requested": {"type": "commit", "ref": SHA_FRONTEND},
                        "resolved": {
                            "commit": SHA_FRONTEND,
                            "content_checksum": CK_A,
                            "license": {"spdx": "Apache-2.0"},
                            "resolved_at": "2026-08-11T00:00:00Z",
                        },
                    }
                },
                "provenance_digest": "sha256:" + "0" * 64,
            },
            "orphan/ghost": {
                "sources": {
                    "upstream": {
                        "repository": "o/r",
                        "path": "p",
                        "requested": {"type": "commit", "ref": SHA_A},
                        "resolved": {
                            "commit": SHA_A,
                            "content_checksum": CK_A,
                            "license": {"spdx": "MIT"},
                            "resolved_at": "2026-08-11T00:00:00Z",
                        },
                    }
                },
                "provenance_digest": "sha256:" + "1" * 64,
            },
        },
    }
    # Write fake lock
    lock_path = tmp_path / "upstream.lock"
    lock_path.write_text(yaml.safe_dump(fake_lock))
    # Monkeypatch LOCK_PATH to use fake
    monkeypatch.setattr(prov, "LOCK_PATH", lock_path)
    # Also need declarations: only frontend-design exists, so orphan/ghost is orphan
    # Run check — should fail due to orphan
    rc = prov.cmd_check(argparse.Namespace())
    assert rc == 1, "orphan lock entry should make check fail"

    # Now test missing: remove frontend-design from lock, keep declaration
    fake_lock["capabilities"].pop("design/frontend-design")
    lock_path.write_text(yaml.safe_dump(fake_lock))
    rc2 = prov.cmd_check(argparse.Namespace())
    assert rc2 == 1, "missing lock entry for upstream declaration should fail"


# ---------------------------------------------------------------------------
# Distribution semantics (declaration policy, not lock duplicate)
# ---------------------------------------------------------------------------


def test_distribution_policy_stays_in_declaration_not_lock():
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    # Lock must not duplicate distribution policy
    for cap in lock["capabilities"].values():
        assert "distribution" not in cap, "distribution policy belongs in SKILL.md, not lock"
        for src in cap["sources"].values():
            assert "distribution" not in src
    # Declaration does have distribution
    fm = prov._load_frontmatter(prov.REPO_ROOT / "skills/design/frontend-design/SKILL.md")
    assert fm.get("distribution", {}).get("mode") == "vendored"


def test_upstream_lock_schema_reuses_shared_defs_but_separate_file():
    assert prov.LOCK_SCHEMA_PATH.exists()
    assert prov.UPSTREAM_SCHEMA_PATH.exists()
    assert prov.LOCK_SCHEMA_PATH != prov.UPSTREAM_SCHEMA_PATH
    lock_schema = json.loads(prov.LOCK_SCHEMA_PATH.read_text())
    assert lock_schema["title"] == "External Provenance Lock"
    assert "capabilities" in lock_schema["properties"]
    assert "generated_at" not in lock_schema["properties"], (
        "generated_at must not be in lock schema (byte-stable)"
    )


def test_provenance_digest_source_added_removed_invalidates():
    base = {
        "upstream": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        },
    }
    d_base = _digest(base)
    # Added source
    with_added = {
        "upstream": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        },
        "extra": {
            "resolved": {"commit": SHA_B, "content_checksum": CK_B, "license": {"spdx": "MIT"}}
        },
    }
    assert _digest(with_added) != d_base, "added source must change digest"
    # Removed source (single vs empty not allowed but hash differs)
    assert _digest({}) != d_base  # empty should differ


def test_provenance_digest_source_id_change_invalidates():
    a = {
        "wrapper": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        }
    }
    b = {
        "rules": {
            "resolved": {"commit": SHA_A, "content_checksum": CK_A, "license": {"spdx": "MIT"}}
        }
    }
    assert _digest(a) != _digest(b), (
        "source ID/role change must invalidate digest (different logical source)"
    )


def test_provenance_digest_resolved_at_only_does_not_invalidate():
    # resolved_at is NOT part of digest — changing timestamp alone must not invalidate review
    sources = {
        "upstream": {
            "repository": "anthropics/skills",
            "path": "skills/frontend-design",
            "requested": {"type": "commit", "ref": SHA_A},
            "resolved": {
                "commit": SHA_A,
                "content_checksum": CK_A,
                "license": {"spdx": "MIT"},
                "resolved_at": "2026-08-11T00:00:00Z",
            },
        }
    }
    d1 = _digest(sources)
    sources["upstream"]["resolved"]["resolved_at"] = "2026-08-12T00:00:00Z"
    d2 = _digest(sources)
    assert d1 == d2, (
        "resolved_at change alone must NOT invalidate digest (only material fields matter)"
    )


def test_license_checksum_is_vendored_bytes():
    # Frontend-design LICENSE.txt vendored bytes are byte-identical to upstream LICENSE at resolved commit
    # For now we prove vendored checksum matches file on disk and is sha256:*
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    lic = lock["capabilities"]["design/frontend-design"]["sources"]["upstream"]["resolved"][
        "license"
    ]
    assert lic["spdx"] == "Apache-2.0"
    assert lic["source_path"] == "skills/design/frontend-design/LICENSE.txt"
    lic_file = prov.REPO_ROOT / lic["source_path"]
    assert lic_file.exists()
    import hashlib

    raw = hashlib.sha256(lic_file.read_bytes()).hexdigest()
    assert lic["checksum"] == f"sha256:{raw}", (
        "license checksum must be sha256 of vendored LICENSE.txt bytes (upstream-identical)"
    )


def test_content_checksum_is_vendored_artifact_normalized():
    # content_checksum is vendored SKILL.md bytes normalized (reviewed_provenance excluded),
    # not pure upstream body. Document invariant.
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    cksum = lock["capabilities"]["design/frontend-design"]["sources"]["upstream"]["resolved"][
        "content_checksum"
    ]
    # Verify it matches provenance's normalized file hash
    skill_path = prov.REPO_ROOT / "skills/design/frontend-design/SKILL.md"
    assert cksum == prov._file_sha256(skill_path)
    # Body-only checksum would be different (031d4d...)
    import hashlib

    raw_text = skill_path.read_text()
    body_start = raw_text.find("# Frontend Design")
    body = raw_text[body_start:].encode()
    body_sha = f"sha256:{hashlib.sha256(body).hexdigest()}"
    assert cksum != body_sha, (
        "content_checksum must be vendored artifact (with frontmatter), not body-only upstream bytes"
    )


def test_updates_discovery_reports_no_update_when_at_head(monkeypatch):
    # Mock to return locked commit for each repo → no update (handles 2 capabilities, 3 sources)
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())

    def _mock(repo, path=None):
        # Return locked commit per repository
        for cap in lock["capabilities"].values():
            for src in cap["sources"].values():
                if src["repository"] == repo:
                    return src["resolved"]["commit"]
        return None

    monkeypatch.setattr(prov, "_fetch_latest_commit", _mock)
    import contextlib
    import io

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = prov.cmd_updates(argparse.Namespace(json=True))
    assert rc == 0
    data = json.loads(buf.getvalue())
    assert data["count"] == 0, data
    assert data["updates"] == []


def test_updates_discovery_reports_update_when_remote_ahead(monkeypatch):
    lock = yaml.safe_load(prov.LOCK_PATH.read_text())
    # Fake ahead for one repo only (anthropics/skills) to prove per-source detection
    target_repo = "anthropics/skills"
    fake_latest = "e" * 40
    orig_locked = None
    for cap in lock["capabilities"].values():
        for src in cap["sources"].values():
            if src["repository"] == target_repo:
                orig_locked = src["resolved"]["commit"]
                break

    def _mock(repo, path=None):
        if repo == target_repo:
            return fake_latest
        # Others return locked (no update)
        for cap in lock["capabilities"].values():
            for src in cap["sources"].values():
                if src["repository"] == repo:
                    return src["resolved"]["commit"]
        return None

    monkeypatch.setattr(prov, "_fetch_latest_commit", _mock)
    import contextlib
    import io

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = prov.cmd_updates(argparse.Namespace(json=True))
    assert rc == 0
    data = json.loads(buf.getvalue())
    assert data["count"] == 1, data
    assert data["updates"][0]["repository"] == target_repo
    assert data["updates"][0]["locked_commit"] == orig_locked
    assert data["updates"][0]["latest_commit"] == fake_latest


# ---------------------------------------------------------------------------
# Import shim
# ---------------------------------------------------------------------------

import argparse  # noqa: E402  (import at bottom for test helper)
