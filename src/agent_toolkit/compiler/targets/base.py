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
            # Temporarily redirect output to the throwaway temp dir
            real_output_root = self.output_root
            self.output_root = Path(tmpdir)
            try:
                result = self.compile(graph, product)
            finally:
                self.output_root = real_output_root

        # Artifacts were in the temp dir (now deleted) — report paths as relative
        # so callers know what WOULD have been created, but clear actual paths
        result.artifacts.clear()
        return result

    def _write_file(self, path: Path, content: str, result: CompilationResult) -> None:
        """Write content to path and record it in result.artifacts."""
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        result.artifacts.append(path)
