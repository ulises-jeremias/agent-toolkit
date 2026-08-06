"""Contract tests for Pi, Windsurf, and Codex adapters."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.codex import CodexAdapter
from agent_toolkit.compiler.targets.pi import PiAdapter
from agent_toolkit.compiler.targets.windsurf import WindsurfAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


# ── Pi ────────────────────────────────────────────────────────────────────────


@pytest.fixture
def pi_adapter(tmp_path):
    return PiAdapter(tmp_path / "plugins", REPO_ROOT)


def test_pi_package_json_created(pi_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = pi_adapter.compile(graph, product)
    pkg = pi_adapter.output_root / "agent-toolkit-core" / "pi-package.json"
    assert pkg.exists()
    assert "pi-package-json" in result.emitted


def test_pi_package_json_has_pi_field(pi_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    pi_adapter.compile(graph, product)
    pkg = pi_adapter.output_root / "agent-toolkit-core" / "pi-package.json"
    data = json.loads(pkg.read_text())
    assert "pi" in data, "pi-package.json must have 'pi' field"


def test_pi_package_type_not_plugin(pi_adapter):
    assert pi_adapter.package_type != "plugin"


def test_pi_skills_created(pi_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    pi_adapter.compile(graph, product)
    skills = pi_adapter.output_root / "agent-toolkit-core" / "skills"
    assert skills.is_dir()
    assert list(skills.rglob("SKILL.md")) != []


def test_pi_ts_features_reported_unsupported(pi_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = pi_adapter.compile(graph, product)
    unsupported = " ".join(result.unsupported).lower()
    assert "hook" in unsupported
    assert "tool" in unsupported


def test_pi_no_private_hostnames(pi_adapter, graph):
    for product in graph.products.values():
        pi_adapter.compile(graph, product)
        pkg_path = pi_adapter.output_root / product.id / "pi-package.json"
        if pkg_path.exists():
            text = pkg_path.read_text()
            assert ".local" not in text
            assert "192.168." not in text


def test_pi_check_mode_no_files(pi_adapter, graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = pi_adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before
    assert result.artifacts == []


# ── Windsurf ──────────────────────────────────────────────────────────────────


@pytest.fixture
def windsurf_adapter(tmp_path):
    return WindsurfAdapter(tmp_path / "plugins", REPO_ROOT)


def test_windsurf_agents_md_created(windsurf_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = windsurf_adapter.compile(graph, product)
    agents_md = windsurf_adapter.output_root / "agent-toolkit-core" / "AGENTS.md"
    assert agents_md.exists(), "AGENTS.md not created"
    assert "AGENTS.md" in result.emitted


def test_windsurf_rules_mdc_created(windsurf_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    windsurf_adapter.compile(graph, product)
    rules_dir = windsurf_adapter.output_root / "agent-toolkit-core" / "rules"
    assert rules_dir.is_dir()
    assert list(rules_dir.glob("*.mdc")) != []


def test_windsurf_package_type_customization_bundle(windsurf_adapter):
    assert windsurf_adapter.package_type == "customization-bundle"
    assert windsurf_adapter.package_type != "plugin"


def test_windsurf_no_memories_generated(windsurf_adapter, graph):
    """Memories must NEVER be generated — they're personal per-user state."""
    product = graph.products["agent-toolkit-core"]
    windsurf_adapter.compile(graph, product)
    memories = list((windsurf_adapter.output_root / "agent-toolkit-core").rglob("*memor*"))
    assert memories == [], f"Memories must not be generated: {memories}"


def test_windsurf_no_plugin_manifest(windsurf_adapter, graph):
    """Windsurf has no marketplace — no plugin.json should be generated."""
    product = graph.products["agent-toolkit-core"]
    windsurf_adapter.compile(graph, product)
    manifests = list((windsurf_adapter.output_root / "agent-toolkit-core").rglob("plugin.json"))
    assert manifests == [], "No plugin.json should exist for Windsurf (no marketplace)"


def test_windsurf_unsupported_reported(windsurf_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = windsurf_adapter.compile(graph, product)
    unsupported = " ".join(result.unsupported).lower()
    assert "hook" in unsupported or "marketplace" in unsupported


def test_windsurf_check_mode_no_files(windsurf_adapter, graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = windsurf_adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before
    assert result.artifacts == []


# ── Codex ─────────────────────────────────────────────────────────────────────


@pytest.fixture
def codex_adapter(tmp_path):
    return CodexAdapter(tmp_path / "plugins", REPO_ROOT)


def test_codex_manifest_in_codex_plugin_dir(codex_adapter, graph):
    """.codex-plugin/plugin.json — different path from .claude-plugin/."""
    product = graph.products["agent-toolkit-core"]
    codex_adapter.compile(graph, product)
    manifest = codex_adapter.output_root / "agent-toolkit-core" / ".codex-plugin" / "plugin.json"
    assert manifest.exists(), ".codex-plugin/plugin.json not found"

    # Must NOT use Claude Code's path
    wrong = codex_adapter.output_root / "agent-toolkit-core" / ".claude-plugin" / "plugin.json"
    assert not wrong.exists(), ".claude-plugin/ must not exist for Codex"


def test_codex_maturity_is_experimental(codex_adapter):
    """Codex marketplace is very new (March 2026) — must be labeled experimental."""
    assert codex_adapter.maturity == "experimental"


def test_codex_no_dangerous_settings(codex_adapter, graph):
    for product in graph.products.values():
        codex_adapter.compile(graph, product)
        manifest_path = codex_adapter.output_root / product.id / ".codex-plugin" / "plugin.json"
        if manifest_path.exists():
            data = json.loads(manifest_path.read_text())
            assert "skipDangerousModePermissionPrompt" not in data


def test_codex_unknown_blocked_reported(codex_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = codex_adapter.compile(graph, product)
    unsupported = " ".join(result.unsupported).lower()
    assert "hook" in unsupported
    assert "mcp" in unsupported


def test_codex_check_mode_no_files(codex_adapter, graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = codex_adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before
    assert result.artifacts == []


# ── All products for all new targets ─────────────────────────────────────────


@pytest.mark.parametrize(
    "target_cls,product_id",
    [
        (PiAdapter, "agent-toolkit-core"),
        (PiAdapter, "agent-toolkit-agents"),
        (WindsurfAdapter, "agent-toolkit-core"),
        (WindsurfAdapter, "agent-toolkit-forge"),
        (CodexAdapter, "agent-toolkit-core"),
        (CodexAdapter, "agent-toolkit-agents"),
    ],
)
def test_all_adapters_all_products_compile(graph, tmp_path, target_cls, product_id):
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    adapter = target_cls(tmp_path / "plugins", REPO_ROOT)
    result = adapter.compile(graph, graph.products[product_id])
    assert result.errors == [], f"Errors: {result.errors}"
