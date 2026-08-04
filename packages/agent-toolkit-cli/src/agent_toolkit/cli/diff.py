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
    targets = [parsed.target] if parsed.target else ["claude-code", "cursor", "opencode"]
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
                # Build into temp dir
                adapter.output_root = Path(tmpdir)
                result = adapter.compile(graph, product)
                adapter.output_root = plugins_dir

            # Compare with current plugin bundle
            current_dir = plugins_dir / product.id
            changes = {"added": [], "changed": [], "removed": []}

            for artifact in result.artifacts:
                try:
                    rel = artifact.relative_to(Path(tmpdir))
                    rel = rel.relative_to(product.id) if str(rel).startswith(product.id + '/') else rel
                except ValueError:
                    continue
                current = current_dir / rel
                if not current.exists():
                    changes["added"].append(str(rel))
                elif artifact.exists() and current.exists() and _file_digest(artifact) != _file_digest(current):
                    changes["changed"].append(str(rel))

            entry = {
                "target": target_id,
                "product": product.id,
                "changes": changes,
                "no_changes": not any(changes.values()),
            }
            results.append(entry)

    if parsed.json_out:
        print(json.dumps(results, indent=2))
        return 0

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
    if target_id == "claude-code":
        from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter
        return ClaudeCodeAdapter(output_dir, repo_root)
    if target_id == "cursor":
        from agent_toolkit.compiler.targets.cursor import CursorAdapter
        return CursorAdapter(output_dir, repo_root)
    if target_id == "opencode":
        from agent_toolkit.compiler.targets.opencode import OpenCodeAdapter
        return OpenCodeAdapter(output_dir, repo_root)
    return None
