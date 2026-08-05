"""
release — Generate release artifacts and checksums without publishing.

Usage:
    agent-toolkit release --dry-run [--output DIR] [--target all]

Options:
    --dry-run       Required: prevents accidental publishing
    --output DIR    Output directory (default: dist/)
    --target TARGET Specific target or 'all' (default: all)
    --json          JSON output
    --help          Show this help

Example:
    agent-toolkit release --dry-run --output dist/
"""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

from agent_toolkit._paths import toolkit_root


def _file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _find_repo_root() -> Path:
    root = toolkit_root()
    if (root / "distributions").is_dir():
        return root
    if (root.parent / "distributions").is_dir():
        return root.parent
    return root


def cmd_release(args: list[str]) -> int:
    import argparse

    parser = argparse.ArgumentParser(prog="agent-toolkit release", add_help=False)
    parser.add_argument("--dry-run", action="store_true", required=True,
                        help="Required: prevents accidental publishing")
    parser.add_argument("--output", default="dist/")
    parser.add_argument("--target", default="all")
    parser.add_argument("--json", dest="json_out", action="store_true")
    parser.add_argument("--help", "-h", action="store_true")
    parsed, _ = parser.parse_known_args(args)

    if parsed.help:
        print(__doc__)
        return 0

    if not parsed.dry_run:
        print("  ✗  --dry-run is required to prevent accidental publishing", file=sys.stderr)
        return 1

    repo_root = _find_repo_root()
    output_dir = Path(parsed.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        import yaml  # noqa: F401
        from agent_toolkit.compiler.loader import load_graph
    except ImportError as e:
        print(f"  ✗  Compiler unavailable: {e}", file=sys.stderr)
        return 1

    graph = load_graph(repo_root)
    if graph.errors:
        for err in graph.errors:
            print(f"  ✗  {err}", file=sys.stderr)
        return 1

    print(f"\nRelease dry run — output: {output_dir}\n")

    from agent_toolkit.compiler.target_registry import load_target_registry
    registry = load_target_registry(repo_root)
    # canonical id -> adapter path (dedupe aliases)
    targets = {spec.id: spec.adapter for spec in {s.id: s for s in registry.values()}.values()}

    target_filter = parsed.target
    if target_filter != "all":
        targets = {k: v for k, v in targets.items() if k == target_filter}

    artifacts_summary = []
    checksums: dict[str, str] = {}

    for target_id, adapter_path in targets.items():
        try:
            module_path, cls_name = adapter_path.rsplit(".", 1)
            import importlib
            mod = importlib.import_module(module_path)
            AdapterCls = getattr(mod, cls_name)
        except (ImportError, AttributeError):
            print(f"  ⚠  {target_id}: adapter not available — skipping")
            continue

        target_out = output_dir / target_id
        target_out.mkdir(parents=True, exist_ok=True)

        with tempfile.TemporaryDirectory() as tmpdir:
            adapter = AdapterCls(Path(tmpdir), repo_root)
            for product in graph.products.values():
                result = adapter.compile(graph, product)
                if result.errors:
                    print(f"  ✗  {target_id}/{product.id}: {result.errors}")
                    continue

                # Create tarball
                tarball = target_out / f"{product.id}.tar.gz"
                product_dir = Path(tmpdir) / product.id
                if product_dir.is_dir():
                    with tarfile.open(tarball, "w:gz") as tar:
                        tar.add(product_dir, arcname=product.id)
                    digest = _file_digest(tarball)
                    checksums[str(tarball.relative_to(output_dir))] = digest
                    artifacts_summary.append({
                        "target": target_id,
                        "product": product.id,
                        "artifact": str(tarball),
                        "digest": digest,
                    })
                    print(f"  ✓  {target_id}/{product.id} → {tarball.name}")

    # Write checksums
    checksums_dir = output_dir / "checksums"
    checksums_dir.mkdir(exist_ok=True)
    checksums_file = checksums_dir / "SHA256SUMS"
    with checksums_file.open("w") as f:
        for path, digest in sorted(checksums.items()):
            f.write(f"{digest}  {path}\n")

    # Write release manifest
    manifests_dir = output_dir / "manifests"
    manifests_dir.mkdir(exist_ok=True)
    manifest = {
        "targets": list(targets.keys()),
        "products": list(graph.products.keys()),
        "artifactCount": len(artifacts_summary),
    }
    (manifests_dir / "release-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )

    print(f"\n  ✓  {len(artifacts_summary)} artifacts generated")
    print(f"  ✓  Checksums: {checksums_file}")
    print(f"  ✓  Manifest: {manifests_dir / 'release-manifest.json'}")
    print(f"\n  ℹ  Dry run complete — nothing published\n")

    if parsed.json_out:
        print(json.dumps(artifacts_summary, indent=2))

    return 0
