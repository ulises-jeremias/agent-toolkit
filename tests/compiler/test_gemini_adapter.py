"""Contract tests for the Gemini CLI extension adapter."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.gemini_cli import GeminiCLIAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def adapter(tmp_path):
    return GeminiCLIAdapter(tmp_path / "plugins", REPO_ROOT)


def test_manifest_created(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)
    manifest = adapter.output_root / "agent-toolkit-core" / "gemini-extension.json"
    assert manifest.exists(), "gemini-extension.json not found"
    assert "extension-manifest" in result.emitted


def test_manifest_valid_json(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)
    manifest = adapter.output_root / "agent-toolkit-core" / "gemini-extension.json"
    data = json.loads(manifest.read_text())
    for field in ("name", "version", "description"):
        assert field in data


def test_manifest_no_absolute_paths(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)
    manifest = adapter.output_root / "agent-toolkit-core" / "gemini-extension.json"
    text = manifest.read_text()
    assert "/home/" not in text, "Absolute /home/ path in manifest"
    assert str(Path.home()) not in text


def test_manifest_no_private_hostnames(adapter, graph):
    for product in graph.products.values():
        adapter.compile(graph, product)
        manifest_path = adapter.output_root / product.id / "gemini-extension.json"
        if manifest_path.exists():
            text = manifest_path.read_text()
            assert ".local" not in text
            assert "192.168." not in text


def test_commands_toml_created(adapter, graph):
    """Gemini uses TOML for commands (not YAML frontmatter)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)
    commands = adapter.output_root / "agent-toolkit-core" / "commands.toml"
    assert commands.exists(), "commands.toml not found"
    assert "commands.toml" in [r for r in adapter.compile(graph, product).emitted]


def test_commands_toml_valid_toml_like(adapter, graph):
    """Verify commands.toml has TOML-format [[commands]] blocks."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)
    commands = adapter.output_root / "agent-toolkit-core" / "commands.toml"
    text = commands.read_text()
    assert "[[commands]]" in text, "No [[commands]] block in TOML"
    assert "name" in text
    assert "description" in text


def test_commands_prompt_injects_skill_body_not_stub(adapter, graph):
    """Regression #90: prompts must @{skills/.../SKILL.md}, not stub one-liners."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)
    out = adapter.output_root / "agent-toolkit-core"
    commands = (out / "commands.toml").read_text()
    assert "skill for full instructions" not in commands
    assert "@{skills/" in commands
    assert "/SKILL.md}" in commands
    # Bundled skill files exist and contain real markdown body
    skill_mds = list((out / "skills").rglob("SKILL.md"))
    assert skill_mds, "expected bundled skills/*/SKILL.md"
    body = skill_mds[0].read_text()
    assert len(body) > 80


def test_package_type_is_extension(adapter):
    assert adapter.package_type == "extension"


def test_unsupported_reported(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)
    unsupported = " ".join(result.unsupported).lower()
    assert "hook" in unsupported
    assert "mcp" in unsupported


def test_check_mode_no_files(adapter, graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before
    assert result.artifacts == []
    assert result.is_valid


@pytest.mark.parametrize("product_id", [
    "agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"
])
def test_all_products(adapter, graph, product_id):
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = adapter.compile(graph, graph.products[product_id])
    assert result.errors == []
