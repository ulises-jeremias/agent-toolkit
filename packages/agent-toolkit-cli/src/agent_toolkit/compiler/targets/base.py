"""Abstract base for target adapters."""
from __future__ import annotations

import tempfile
from abc import ABC, abstractmethod
from pathlib import Path

from agent_toolkit.compiler.model import CanonicalGraph, CompilationResult, Product
from agent_toolkit.compiler.provenance import ArtifactRecord, file_digest, write_provenance


class TargetAdapter(ABC):
    """Base class for all target adapters."""

    target_id: str = ""
    package_type: str = ""
    maturity: str = "stable"

    def __init__(self, output_root: Path, repo_root: Path):
        self.output_root = output_root
        self.repo_root = repo_root
        self._provenance_records: list[ArtifactRecord] = []

    @abstractmethod
    def compile(
        self,
        graph: CanonicalGraph,
        product: Product,
    ) -> CompilationResult:
        """Compile canonical IR into target-specific artifacts."""

    def check(self, graph: CanonicalGraph, product: Product) -> CompilationResult:
        """Dry-run: validate without writing any files to disk."""
        with tempfile.TemporaryDirectory(prefix="agent-toolkit-check-") as tmpdir:
            real_output_root = self.output_root
            self.output_root = Path(tmpdir)
            self._provenance_records = []
            try:
                result = self.compile(graph, product)
            finally:
                self.output_root = real_output_root
                self._provenance_records = []
        result.artifacts.clear()
        return result

    def _write_file(
        self,
        path: Path,
        content: str,
        result: CompilationResult,
        *,
        source_file: str | Path | None = None,
    ) -> None:
        """Write content to path and record it in result.artifacts (+ provenance)."""
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        result.artifacts.append(path)
        source = str(source_file) if source_file is not None else "generated"
        try:
            rel = str(path.relative_to(self.output_root))
        except ValueError:
            rel = path.name
        src_path = Path(source_file) if source_file is not None else None
        self._provenance_records.append(
            ArtifactRecord(
                path=rel,
                source_file=source,
                source_digest=file_digest(src_path) if src_path and src_path.exists() else "n/a",
                generated_digest=file_digest(path),
            )
        )

    def _finalize_provenance(self, product: Product, result: CompilationResult) -> None:
        """Write .provenance.json under the product output directory (#67)."""
        out_dir = self.output_root / product.id
        if not out_dir.exists():
            return
        path = write_provenance(
            out_dir,
            product.id,
            self.target_id,
            list(self._provenance_records),
        )
        result.artifacts.append(path)
        result.emitted.append("provenance")
        self._provenance_records = []

    def _cleanup_stale_artifacts(self, product: Product, result: CompilationResult) -> None:
        """Remove files under product output that were not emitted this compile (#69)."""
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
