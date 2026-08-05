"""Abstract base for target adapters."""
from __future__ import annotations

import tempfile
from abc import ABC, abstractmethod
from pathlib import Path

from agent_toolkit.compiler.model import CanonicalGraph, CompilationResult, Product, Skill
from agent_toolkit.compiler.provenance import ArtifactRecord, file_digest, write_provenance


class PathEscapeError(ValueError):
    """Raised when a path resolves outside its containment root."""


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

    def _safe_relpath(self, file: Path, root: Path) -> Path:
        """Return *file* relative to *root* after resolving symlinks.

        Raises PathEscapeError when the resolved path is not under *root*.
        """
        root_resolved = root.resolve()
        file_resolved = file.resolve()
        try:
            return file_resolved.relative_to(root_resolved)
        except ValueError as exc:
            raise PathEscapeError(
                f"Path escapes containment root {root}: {file} -> {file_resolved}"
            ) from exc

    def _iter_contained_files(
        self,
        root: Path,
        result: CompilationResult,
        *,
        label: str = "",
    ) -> list[Path]:
        """List files under *root*, skipping entries that escape after symlink resolution."""
        if not root.is_dir():
            return []

        root_resolved = root.resolve()
        prefix = f"{label}: " if label else ""
        safe: list[Path] = []

        for path in sorted(root.rglob("*")):
            if path.is_dir():
                continue
            try:
                resolved = path.resolve()
            except OSError as exc:
                result.errors.append(f"{prefix}cannot resolve {path}: {exc}")
                continue
            if not resolved.is_file():
                continue
            try:
                resolved.relative_to(root_resolved)
            except ValueError:
                result.errors.append(
                    f"{prefix}reference escapes containment root {root}: {path}"
                )
                continue
            safe.append(path)

        return safe

    def _copy_skill_references(
        self,
        skill: Skill,
        dst: Path,
        result: CompilationResult,
        *,
        text_mode: bool = False,
    ) -> None:
        """Copy skill ``references/`` into *dst* with path containment checks."""
        refs_src = skill.source_path.parent / "references"
        if not refs_src.is_dir():
            return

        skill_root = skill.source_path.parent
        label = f"skill:{skill.id}"

        for ref_file in self._iter_contained_files(refs_src, result, label=label):
            try:
                rel = self._safe_relpath(ref_file, skill_root)
            except PathEscapeError as exc:
                result.errors.append(f"{label}: {exc}")
                continue

            ref_dst = dst / rel
            if text_mode:
                ref_content = ref_file.read_text(encoding="utf-8", errors="replace")
                self._write_file(ref_dst, ref_content, result, source_file=ref_file)
            else:
                ref_dst.parent.mkdir(parents=True, exist_ok=True)
                ref_dst.write_bytes(ref_file.read_bytes())
                result.artifacts.append(ref_dst)
