"""Installation receipt management — records what was installed and where."""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

RECEIPT_DIR = Path.home() / ".config" / "agent-toolkit" / "receipts"


@dataclass
class ArtifactEntry:
    path: str
    digest: str
    ownership: Literal["created", "merged"]


@dataclass
class InstallReceipt:
    schema_version: int
    product: str
    target: str
    scope: str
    version: str
    installed_at: str
    source_digest: str
    artifacts: list[ArtifactEntry] = field(default_factory=list)
    config_patches: list[dict] = field(default_factory=list)
    secrets: list = field(default_factory=list)  # always empty

    @classmethod
    def create(cls, product, target, scope, version, source_digest):
        return cls(
            schema_version=1, product=product, target=target, scope=scope,
            version=version, installed_at=datetime.now(timezone.utc).isoformat(),
            source_digest=source_digest,
        )

    def to_dict(self):
        return {
            "schemaVersion": self.schema_version, "product": self.product,
            "target": self.target, "scope": self.scope, "version": self.version,
            "installedAt": self.installed_at, "sourceDigest": self.source_digest,
            "artifacts": [{"path": a.path, "digest": a.digest, "ownership": a.ownership}
                         for a in self.artifacts],
            "configPatches": self.config_patches, "secrets": [],
        }

    def save(self, receipt_dir=None):
        d = Path(receipt_dir) if receipt_dir else RECEIPT_DIR
        d.mkdir(parents=True, exist_ok=True)
        p = d / f"{self.target}-{self.product}.json"
        p.write_text(json.dumps(self.to_dict(), indent=2) + "\n")
        return p

    @classmethod
    def load(cls, target, product, receipt_dir=None):
        d = Path(receipt_dir) if receipt_dir else RECEIPT_DIR
        p = d / f"{target}-{product}.json"
        if not p.exists():
            return None
        data = json.loads(p.read_text())
        r = cls(schema_version=data.get("schemaVersion", 1), product=data["product"],
                target=data["target"], scope=data.get("scope", "project"),
                version=data["version"], installed_at=data.get("installedAt", ""),
                source_digest=data.get("sourceDigest", ""))
        for a in data.get("artifacts", []):
            r.artifacts.append(ArtifactEntry(a["path"], a["digest"], a["ownership"]))
        r.config_patches = list(data.get("configPatches", []))
        return r
