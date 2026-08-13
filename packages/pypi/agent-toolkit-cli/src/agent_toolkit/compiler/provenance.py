"""
Provenance tracking for generated compiler artifacts.

Every generated plugin bundle gets a .provenance.json sidecar that records:
- Generator version
- Source file paths and digests for each artifact
- Build metadata (no timestamps in reproducible content)

This enables drift detection: agent-toolkit plugin check compares
artifact digests against provenance to catch manual edits.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class ArtifactRecord:
    """Provenance record for a single generated file."""

    path: str  # relative path from plugin root
    source_file: str  # canonical source (e.g. skills/core/assistant/SKILL.md)
    source_digest: str  # SHA256[:12] of source content
    generated_digest: str  # SHA256[:12] of generated content


@dataclass
class ProvenanceManifest:
    """Provenance manifest for a complete plugin bundle."""

    generator_version: str
    product: str
    target: str
    artifacts: list[ArtifactRecord] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "generatorVersion": self.generator_version,
            "product": self.product,
            "target": self.target,
            "artifacts": [
                {
                    "path": a.path,
                    "sourceFile": a.source_file,
                    "sourceDigest": a.source_digest,
                    "generatedDigest": a.generated_digest,
                }
                for a in self.artifacts
            ],
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2) + "\n"


def file_digest(path: Path) -> str:
    """SHA256[:12] of file content."""
    if not path.exists():
        return "missing"
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def write_provenance(
    out_dir: Path,
    product_id: str,
    target_id: str,
    artifact_records: list[ArtifactRecord],
) -> Path:
    """Write .provenance.json to the plugin bundle root."""
    try:
        from agent_toolkit import __version__

        version = __version__
    except ImportError:
        version = "unknown"

    manifest = ProvenanceManifest(
        generator_version=version,
        product=product_id,
        target=target_id,
        artifacts=artifact_records,
    )
    provenance_path = out_dir / ".provenance.json"
    provenance_path.write_text(manifest.to_json(), encoding="utf-8")
    return provenance_path


def load_provenance(path: Path) -> ProvenanceManifest | None:
    """Load a .provenance.json manifest. Returns None if missing or invalid."""
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None

    artifacts = [
        ArtifactRecord(
            path=item["path"],
            source_file=item["sourceFile"],
            source_digest=item["sourceDigest"],
            generated_digest=item["generatedDigest"],
        )
        for item in data.get("artifacts", [])
    ]
    return ProvenanceManifest(
        generator_version=data.get("generatorVersion", "unknown"),
        product=data.get("product", ""),
        target=data.get("target", ""),
        artifacts=artifacts,
    )


def verify_generated_digests(
    plugins_dir: Path,
    provenance_path: Path,
) -> list[str]:
    """Compare recorded generatedDigest values to current artifact content.

    Artifact paths in the manifest are relative to *plugins_dir* (compiler
    output root). Returns human-readable drift messages (empty when in sync).
    """
    manifest = load_provenance(provenance_path)
    if manifest is None:
        return []

    errors: list[str] = []
    for record in manifest.artifacts:
        artifact_path = plugins_dir / record.path
        current = file_digest(artifact_path)
        if current != record.generated_digest:
            errors.append(
                f"provenance digest drift: {record.path} "
                f"(expected {record.generated_digest}, got {current})"
            )
    return errors
