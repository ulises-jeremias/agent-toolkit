"""
build — Compile canonical capabilities into target-specific artifacts.

Usage:
    agent-toolkit build [--target TARGET] [--product PRODUCT] [--check] [--output DIR]

Options:
    --target TARGET    Target platform (claude-code, cursor, etc.)
    --product PRODUCT  Product ID to compile (agent-toolkit-core, etc.)
    --check            Dry-run: validate without writing files
    --output DIR       Output directory (default: plugins/)
    --json             Output results as JSON
    --help             Show this help

Examples:
    agent-toolkit build --target claude-code --product agent-toolkit-core
    agent-toolkit build --check
    agent-toolkit inventory
    agent-toolkit matrix
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from agent_toolkit._paths import toolkit_root

import sys as _sys
if _sys.platform == 'win32':
    try:
        _sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        _sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass


def _find_repo_root() -> Path:
    """Find the repo root (where distributions/ lives)."""
    root = toolkit_root()
    # Prefer root with distributions/ directory
    if (root / "distributions").is_dir():
        return root
    # Try package data parent
    if (root.parent / "distributions").is_dir():
        return root.parent
    return root


def cmd_build(args: list[str]) -> int:
    """Build canonical capabilities into target-native artifacts."""
    import argparse

    parser = argparse.ArgumentParser(prog="agent-toolkit build", add_help=False)
    parser.add_argument("--target", default=None)
    parser.add_argument("--product", default=None)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output", default=None)
    parser.add_argument("--json", dest="json_out", action="store_true")
    parser.add_argument("--help", "-h", action="store_true")

    parsed, _ = parser.parse_known_args(args)

    if parsed.help:
        print(__doc__)
        return 0

    repo_root = _find_repo_root()
    json_mode = parsed.json_out

    def _say(*args, **kwargs):
        if not json_mode:
            print(*args, **kwargs)

    try:
        from agent_toolkit.compiler.loader import load_graph
    except ImportError as e:
        print(f"  ✗  Compiler not available: {e}", file=sys.stderr)
        return 1

    _say("\nLoading canonical graph...")
    graph = load_graph(repo_root)

    if graph.errors:
        print(f"  ✗  {len(graph.errors)} error(s) loading canonical sources:", file=sys.stderr)
        for err in graph.errors:
            print(f"     {err}", file=sys.stderr)
        return 1

    if graph.warnings:
        for w in graph.warnings:
            _say(f"  ⚠  {w}")

    _say(f"  ✓  {len(graph.skills)} skills, {len(graph.agents)} agents, "
         f"{len(graph.products)} products loaded")

    # Select products to build
    products_to_build = list(graph.products.values())
    if parsed.product:
        if parsed.product not in graph.products:
            print(f"  ✗  Product '{parsed.product}' not found", file=sys.stderr)
            print(f"     Available: {', '.join(graph.products)}", file=sys.stderr)
            return 1
        products_to_build = [graph.products[parsed.product]]

    # Select targets
    available_targets = {"claude-code", "cursor", "opencode", "gemini-cli", "copilot-cli", "copilot-repository", "pi", "windsurf", "codex", "muse-code", "muse"}  # expand as adapters are added
    targets_to_build = [parsed.target] if parsed.target else list(available_targets)

    for t in targets_to_build:
        if t not in available_targets:
            print(f"  ✗  Unknown target '{t}'. Available: {', '.join(sorted(available_targets))}", file=sys.stderr)
            return 1

    output_dir = Path(parsed.output) if parsed.output else repo_root / "plugins"
    mode = "check" if parsed.check else "build"
    _say(f"\nMode: {mode}  Output: {output_dir}\n")

    all_results = []
    exit_code = 0

    for target_id in targets_to_build:
        adapter = _get_adapter(target_id, output_dir, repo_root)
        if adapter is None:
            _say(f"  ⚠  No adapter for target '{target_id}' — skipping")
            continue

        for product in products_to_build:
            _say(f"  Building {product.id} → {target_id}...")
            adapter._provenance_records = []
            if parsed.check:
                result = adapter.check(graph, product)
            else:
                result = adapter.compile(graph, product)
                if hasattr(adapter, "_finalize_provenance"):
                    adapter._finalize_provenance(product, result)

            all_results.append(result)
            _say(result.report())
            _say()

            if not result.is_valid:
                exit_code = 1

    if json_mode:
        out = [
            {
                "target": r.target,
                "product": r.product,
                "emitted": r.emitted,
                "transformed": r.transformed,
                "omitted": r.omitted,
                "unsupported": r.unsupported,
                "warnings": r.warnings,
                "errors": r.errors,
                "artifacts": [str(a) for a in r.artifacts],
            }
            for r in all_results
        ]
        print(json.dumps(out, indent=2))

    return exit_code


def cmd_inventory(args: list[str]) -> int:
    """List all canonical capabilities."""
    repo_root = _find_repo_root()
    from agent_toolkit.compiler.loader import load_graph

    graph = load_graph(repo_root)

    print("\n═══ agent-toolkit Inventory ═══\n")

    # Skills by domain
    by_domain: dict[str, list] = {}
    for skill in sorted(graph.skills.values(), key=lambda s: s.id):
        by_domain.setdefault(skill.domain, []).append(skill)

    print(f"Skills: {len(graph.skills)} across {len(by_domain)} domains\n")
    for domain, skills in sorted(by_domain.items()):
        print(f"  {domain}/ ({len(skills)})")
        for s in skills:
            desc = s.description[:60] + "…" if len(s.description) > 60 else s.description
            print(f"    ✓  {s.name:<40} {desc}")

    print(f"\nAgents: {len(graph.agents)}")
    for agent in sorted(graph.agents.values(), key=lambda a: a.name):
        desc = agent.description[:60] + "…" if len(agent.description) > 60 else agent.description
        print(f"  ✓  {agent.name:<40} {desc}")

    print(f"\nProducts: {len(graph.products)}")
    for product in sorted(graph.products.values(), key=lambda p: p.id):
        print(f"  ✓  {product.id}")
        print(f"     skills: {len(product.included_skills)}  "
              f"agents: {len(product.included_agents)}")

    if graph.errors:
        print(f"\nErrors: {len(graph.errors)}")
        for e in graph.errors:
            print(f"  ✗ {e}")

    return 0


def cmd_matrix(args: list[str]) -> int:
    """Show platform capability matrix from research docs."""
    AT = _find_repo_root()
    matrix_path = AT / "docs" / "research" / "platform-capability-matrix.md"
    if matrix_path.exists():
        print(matrix_path.read_text())
    else:
        print("Matrix not found. Run the research pipeline first.")
        print(f"Expected at: {matrix_path}")
    return 0


def _get_adapter(target_id: str, output_dir: Path, repo_root: Path):
    """Return the adapter for a given target ID."""
    if target_id == "claude-code":
        from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter
        return ClaudeCodeAdapter(output_dir, repo_root)
    if target_id == "cursor":
        from agent_toolkit.compiler.targets.cursor import CursorAdapter
        return CursorAdapter(output_dir, repo_root)
    if target_id in ("gemini-cli", "gemini"):
        from agent_toolkit.compiler.targets.gemini_cli import GeminiCLIAdapter
        return GeminiCLIAdapter(output_dir, repo_root)
    if target_id in ("copilot-cli", "copilot"):
        from agent_toolkit.compiler.targets.copilot import CopilotCLIAdapter
        return CopilotCLIAdapter(output_dir, repo_root)
    if target_id == "copilot-repository":
        from agent_toolkit.compiler.targets.copilot import CopilotRepositoryAdapter
        return CopilotRepositoryAdapter(output_dir, repo_root)
    if target_id == "pi":
        from agent_toolkit.compiler.targets.pi import PiAdapter
        return PiAdapter(output_dir, repo_root)
    if target_id == "windsurf":
        from agent_toolkit.compiler.targets.windsurf import WindsurfAdapter
        return WindsurfAdapter(output_dir, repo_root)
    if target_id == "codex":
        from agent_toolkit.compiler.targets.codex import CodexAdapter
        return CodexAdapter(output_dir, repo_root)
    if target_id == "opencode":
        from agent_toolkit.compiler.targets.opencode import OpenCodeAdapter
        return OpenCodeAdapter(output_dir, repo_root)
    if target_id in ("muse-code", "muse"):
        from agent_toolkit.compiler.targets.muse_code import MuseCodeAdapter
        return MuseCodeAdapter(output_dir, repo_root)
    return None
