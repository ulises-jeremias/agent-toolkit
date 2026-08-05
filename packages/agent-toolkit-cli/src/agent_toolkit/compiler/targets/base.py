"""Abstract base for target adapters."""
from __future__ import annotations

import tempfile
from abc import ABC, abstractmethod
from pathlib import Path

from agent_toolkit.compiler.model import CanonicalGraph, CompilationResult, Product


class TargetAdapter(ABC):
    """Base class for all target adapters."""

    target_id: str = ""
    package_type: str = ""
    maturity: str = "stable"

    def __init__(self, output_root: Path, repo_root: Path):
        self.output_root = output_root
        self.repo_root = repo_root

    @abstractmethod
    def compile(
        self,
        graph: CanonicalGraph,
        product: Product,
    ) -> CompilationResult:
        """
        Compile canonical IR into target-specific artifacts.
        Must return a CompilationResult documenting all emitted, transformed,
        omitted, and unsupported capabilities. Never silently drop a capability.
        """

    def check(self, graph: CanonicalGraph, product: Product) -> CompilationResult:
        """Dry-run: validate without writing any files to disk.

        Uses a temporary directory that is discarded after compilation,
        so the real output_root is never touched.
        """
        with tempfile.TemporaryDirectory(prefix="agent-toolkit-check-") as tmpdir:
            real_output_root = self.output_root
            self.output_root = Path(tmpdir)
            try:
                result = self.compile(graph, product)
            finally:
                self.output_root = real_output_root

        result.artifacts.clear()
        return result

    def _write_file(self, path: Path, content: str, result: CompilationResult) -> None:
        """Write content to path and record it in result.artifacts."""
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        result.artifacts.append(path)

    def _cleanup_stale_artifacts(self, product: Product, result: CompilationResult) -> None:
        """Remove files under product output not in current artifacts (#69)."""
        out_dir = self.output_root / product.id
        if not out_dir.is_dir():
            return
        keep = {p.resolve() for p in result.artifacts if p.exists()}
        removed = 0
        for path in sorted(out_dir.rglob("*"), reverse=True):
            if not path.is_file():
                continue
            if path.resolve() in keep:
                continue
            path.unlink(missing_ok=True)
            removed += 1
        for path in sorted(out_dir.rglob("*"), reverse=True):
            if path.is_dir():
                try:
                    path.rmdir()
                except OSError:
                    pass
        if removed:
            result.emitted.append(f"stale-cleaned:{removed}")
