"""Tests for the provenance module."""

from __future__ import annotations

import json
from pathlib import Path

from agent_toolkit.compiler.provenance import (
    ArtifactRecord,
    ProvenanceManifest,
    file_digest,
    load_provenance,
    verify_generated_digests,
    write_provenance,
)

REPO_ROOT = Path(__file__).parent.parent


def test_file_digest_stable(tmp_path):
    f = tmp_path / "test.txt"
    f.write_text("hello")
    d1 = file_digest(f)
    d2 = file_digest(f)
    assert d1 == d2
    assert len(d1) == 12


def test_file_digest_missing_returns_sentinel():
    assert file_digest(Path("/nonexistent/file.txt")) == "missing"


def test_provenance_manifest_to_dict():
    manifest = ProvenanceManifest(
        generator_version="1.1.0",
        product="agent-toolkit-core",
        target="claude-code",
        artifacts=[
            ArtifactRecord(
                path="skills/assistant/SKILL.md",
                source_file="skills/core/assistant/SKILL.md",
                source_digest="abc123def456",
                generated_digest="abc123def456",
            )
        ],
    )
    d = manifest.to_dict()
    assert d["product"] == "agent-toolkit-core"
    assert d["target"] == "claude-code"
    assert len(d["artifacts"]) == 1
    assert d["artifacts"][0]["path"] == "skills/assistant/SKILL.md"


def test_write_provenance_creates_json(tmp_path):
    records = [
        ArtifactRecord(
            path="plugin.json",
            source_file="distributions/products.yaml",
            source_digest="abc123",
            generated_digest="abc123",
        )
    ]
    provenance_path = write_provenance(tmp_path, "agent-toolkit-core", "cursor", records)
    assert provenance_path.exists()
    data = json.loads(provenance_path.read_text())
    assert "generatorVersion" in data
    assert "artifacts" in data
    assert len(data["artifacts"]) == 1


def test_provenance_json_no_timestamps():
    """Provenance content must be deterministic (no timestamps in content)."""
    manifest = ProvenanceManifest(
        generator_version="1.0.0",
        product="test",
        target="cursor",
    )
    content = manifest.to_json()
    assert "timestamp" not in content.lower()
    assert "date" not in content.lower()


def test_load_provenance_round_trip(tmp_path):
    records = [
        ArtifactRecord(
            path="agent-toolkit-core/skills/foo/SKILL.md",
            source_file="skills/core/foo/SKILL.md",
            source_digest="abc123",
            generated_digest="def456",
        )
    ]
    path = write_provenance(tmp_path, "agent-toolkit-core", "cursor", records)
    loaded = load_provenance(path)
    assert loaded is not None
    assert loaded.product == "agent-toolkit-core"
    assert len(loaded.artifacts) == 1
    assert loaded.artifacts[0].generated_digest == "def456"


def test_verify_generated_digests_detects_drift(tmp_path):
    plugins_dir = tmp_path / "plugins"
    bundle = plugins_dir / "agent-toolkit-core" / "skills" / "foo"
    bundle.mkdir(parents=True)
    skill_md = bundle / "SKILL.md"
    skill_md.write_text("original", encoding="utf-8")
    digest = file_digest(skill_md)

    provenance_path = plugins_dir / "agent-toolkit-core" / ".provenance.json"
    provenance_path.parent.mkdir(parents=True, exist_ok=True)
    provenance_path.write_text(
        ProvenanceManifest(
            generator_version="1.0.0",
            product="agent-toolkit-core",
            target="cursor",
            artifacts=[
                ArtifactRecord(
                    path="agent-toolkit-core/skills/foo/SKILL.md",
                    source_file="generated",
                    source_digest="n/a",
                    generated_digest=digest,
                )
            ],
        ).to_json(),
        encoding="utf-8",
    )

    assert verify_generated_digests(plugins_dir, provenance_path) == []

    skill_md.write_text("tampered", encoding="utf-8")
    drift = verify_generated_digests(plugins_dir, provenance_path)
    assert len(drift) == 1
    assert "digest drift" in drift[0]
