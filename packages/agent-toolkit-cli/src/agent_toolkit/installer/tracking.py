"""Track installed artifacts and persist InstallReceipt."""
from __future__ import annotations

import hashlib
from pathlib import Path

from agent_toolkit import __version__
from agent_toolkit.installer.receipt import ArtifactEntry, InstallReceipt

PRODUCT = "agent-toolkit-profiles"
SCOPE = "user-home"


def receipt_dir() -> Path:
    """Return the install receipt directory (under the current HOME)."""
    return Path.home() / ".config" / "agent-toolkit" / "receipts"


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def source_digest(root: Path) -> str:
    marker = root / "profiles"
    if marker.is_dir():
        return hashlib.sha256(str(marker.resolve()).encode()).hexdigest()[:12]
    return __version__


class InstallTracker:
    """Collect artifact entries during install and write receipt on save."""

    def __init__(
        self,
        target: str,
        *,
        dry_run: bool,
        receipt_dir_path: Path | None = None,
        toolkit_root: Path | None = None,
    ) -> None:
        root = toolkit_root or Path()
        self.dry_run = dry_run
        self.receipt_dir_path = receipt_dir_path or receipt_dir()
        self.receipt = InstallReceipt.create(
            PRODUCT,
            target,
            SCOPE,
            __version__,
            source_digest(root),
        )

    def record_created(self, path: Path) -> None:
        if not path.is_file():
            return
        self.receipt.artifacts.append(
            ArtifactEntry(str(path.resolve()), file_digest(path), "created")
        )

    def save(self) -> Path | None:
        if self.dry_run or not self.receipt.artifacts:
            return None
        return self.receipt.save(self.receipt_dir_path)
