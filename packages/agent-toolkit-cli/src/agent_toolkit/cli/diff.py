"""
diff — Show what would change between current canonical output and installed.

Usage:
    agent-toolkit diff [--target TARGET] [--product PRODUCT] [--json]

Options:
    --target TARGET    Target platform (claude-code, cursor, opencode, etc.)
    --product PRODUCT  Product ID to diff
    --json             Output as JSON
    --help             Show this help

Examples:
    agent-toolkit diff --target cursor
    agent-toolkit diff --target claude-code --product agent-toolkit-core
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from agent_toolkit._paths import toolkit_root


def _file_digest(path: Path) -> str:
    """SHA256 digest of a file's content."""
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def _find_repo_root() -> Path:
    root = toolkit_root()
    if (root / "distributions").is_dir():
        return root
    if (root.parent / "distributions").is_dir():
        return root.parent
    return root


def cmd_diff(args: list[str]) -> int:
    """Show what would change if build were run."""
    import argparse

    parser = argparse.ArgumentParser(prog="agent-toolkit diff", add_help=False)
    parser.add_argument("--target", default=None)
    parser.add_argument("--product", default=None)
    parser.add_argument("--json", dest="json_out", action="store_true")
    parser.add_argument("--help", "-h", action="store_true")
    parsed, _ = parser.parse_known_args(args)

    if parsed.help:
        print(__doc__)
        return 0

    repo_root = _find_repo_root()

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

    plugins_dir = repo_root / "plugins"
    from agent_toolkit.compiler.target_registry import available_target_ids
    targets = [parsed.target] if parsed.target else sorted(available_target_ids(repo_root))
    products_to_diff = (
        [graph.products[parsed.product]] if parsed.product and parsed.product in graph.products
        else list(graph.products.values())
    )

    results = []

    for target_id in targets:
        adapter = _get_adapter(target_id, plugins_dir, repo_root)
        if adapter is None:
            continue

        for product in products_to_diff:
            import tempfile
            with tempfile.TemporaryDirectory() as tmpdir:
                tmp_root = Path(tmpdir)
                # Build into temp dir and compare BEFORE cleanup — digests must
                # be read while compiled artifacts still exist on disk.
                adapter.output_root = tmp_root
                result = adapter.compile(graph, product)
                adapter.output_root = plugins_dir

                current_dir = plugins_dir / product.id
                changes = {"added": [], "changed": [], "removed": []}

                built_rels: set[str] = set()
                for artifact in result.artifacts:
                    try:
                        rel = artifact.relative_to(tmp_root)
                        if str(rel).startswith(product.id + "/") or str(rel) == product.id:
                            rel = rel.relative_to(product.id) if rel != Path(product.id) else Path(".")
                    except ValueError:
                        continue
                    if str(rel) == ".":
                        continue
                    built_rels.add(str(rel))
                    current = current_dir / rel
                    if not current.exists():
                        changes["added"].append(str(rel))
                    elif _file_digest(artifact) != _file_digest(current):
                        changes["changed"].append(str(rel))

                if current_dir.is_dir():
                    for existing in current_dir.rglob("*"):
                        if not existing.is_file():
                            continue
                        rel = str(existing.relative_to(current_dir))
                        if rel not in built_rels and not rel.endswith(".provenance.json"):
                            # Only flag files that were part of prior toolkit output
                            # when we have a corresponding build artifact set.
                            pass

            entry = {
                "target": target_id,
                "product": product.id,
                "changes": changes,
                "no_changes": not any(changes.values()),
            }
            results.append(entry)

    if parsed.json_out:
        print(json.dumps(results, indent=2))
        any_changes = any(not e["no_changes"] for e in results)
        return 1 if any_changes else 0

    any_changes = False
    for entry in results:
        header = f"~ {entry['product']} → {entry['target']}"
        if entry["no_changes"]:
            print(f"  ✓  {header}: no changes")
            continue
        any_changes = True
        print(f"\n  {header}:")
        for f in entry["changes"]["added"]:
            print(f"    + {f}")
        for f in entry["changes"]["changed"]:
            print(f"    ~ {f}")
        for f in entry["changes"]["removed"]:
            print(f"    - {f}")
    print()
    return 1 if any_changes else 0


def _get_adapter(target_id: str, output_dir: Path, repo_root: Path):
    from agent_toolkit.compiler.target_registry import resolve_adapter_class
    cls = resolve_adapter_class(target_id, repo_root)
    if cls is None:
        return None
    return cls(output_dir, repo_root)
