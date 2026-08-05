"""Contract tests for the Cursor adapter.

Verifies:
- Required manifest exists with correct fields
- Native paths are correct (skills/, agents/ in plugin bundle)
- Names/versions match canonical sources
- Unsupported capabilities are reported explicitly (not silently dropped)
- No absolute machine paths in generated output
- No forbidden settings (no dangerous bypasses)
- No private provider URLs
"""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

import pytest

# Skip entire module gracefully if PyYAML not installed (CI installs it)

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.model import CompilationResult
from agent_toolkit.compiler.targets.cursor import CursorAdapter


REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def tmp_output(tmp_path):
    return tmp_path / "plugins"


@pytest.fixture
def adapter(tmp_output):
    return CursorAdapter(tmp_output, REPO_ROOT)


# ── manifest ──────────────────────────────────────────────────────────────────


def test_plugin_manifest_created(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".cursor-plugin" / "plugin.json"
    assert manifest.exists(), f".cursor-plugin/plugin.json not found at {manifest}"
    assert "plugin-manifest" in result.emitted


def test_plugin_manifest_valid_json(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".cursor-plugin" / "plugin.json"
    data = json.loads(manifest.read_text())

    # Required fields per Cursor plugin spec
    assert "name" in data, "manifest missing 'name'"
    assert "version" in data, "manifest missing 'version'"
    assert "description" in data, "manifest missing 'description'"
    assert "author" in data, "manifest missing 'author'"


def test_manifest_name_matches_product(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".cursor-plugin" / "plugin.json"
    data = json.loads(manifest.read_text())
    assert data["name"] == "agent-toolkit-core"


def test_manifest_no_dangerous_settings(adapter, graph):
    """Cursor plugin must not bypass permission prompts."""
    for product in graph.products.values():
        adapter.compile(graph, product)
        manifest_path = (
            adapter.output_root / product.id / ".cursor-plugin" / "plugin.json"
        )
        if manifest_path.exists():
            data = json.loads(manifest_path.read_text())
            assert "skipDangerousModePermissionPrompt" not in data
            assert "autoAcceptPermissions" not in data


def test_manifest_no_private_providers(adapter, graph):
    """Plugin manifest must not contain internal hostnames."""
    for product in graph.products.values():
        adapter.compile(graph, product)
        manifest_path = (
            adapter.output_root / product.id / ".cursor-plugin" / "plugin.json"
        )
        if manifest_path.exists():
            text = manifest_path.read_text()
            assert ".local" not in text, "Private .local hostname in manifest"
            assert "192.168." not in text, "Private IP in manifest"


# ── skills ────────────────────────────────────────────────────────────────────


def test_skills_emitted(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    emitted_skills = [e for e in result.emitted if e.startswith("skill:")]
    assert len(emitted_skills) > 0, "No skills emitted for agent-toolkit-core"


def test_skill_md_in_correct_path(adapter, graph):
    """Cursor discovers skills at <plugin-root>/skills/<name>/SKILL.md."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skills_dir = adapter.output_root / "agent-toolkit-core" / "skills"
    assert skills_dir.is_dir(), "skills/ directory not created"

    skill_mds = list(skills_dir.rglob("SKILL.md"))
    assert len(skill_mds) > 0, "No SKILL.md files found in skills/"


def test_no_skill_json_files(adapter, graph):
    """skill.json must not be generated (removed from spec in v1.0.4)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skill_jsons = list((adapter.output_root / "agent-toolkit-core").rglob("skill.json"))
    assert skill_jsons == [], f"skill.json found: {skill_jsons}"


def test_no_absolute_paths_in_skill_md(adapter, graph):
    """Generated SKILL.md must not contain absolute machine paths."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    for skill_md in (adapter.output_root / "agent-toolkit-core").rglob("SKILL.md"):
        text = skill_md.read_text()
        assert "/home/" not in text, f"Absolute /home/ path in {skill_md}"
        assert str(Path.home()) not in text, f"Home dir path in {skill_md}"


# ── agents ────────────────────────────────────────────────────────────────────


def test_agents_emitted(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    emitted_agents = [e for e in result.emitted if e.startswith("agent:")]
    assert len(emitted_agents) > 0, "No agents emitted"


def test_agent_md_in_correct_path(adapter, graph):
    """Cursor discovers agents at <plugin-root>/agents/<name>/AGENT.md."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    agents_dir = adapter.output_root / "agent-toolkit-core" / "agents"
    assert agents_dir.is_dir(), "agents/ directory not created"

    agent_mds = list(agents_dir.rglob("AGENT.md"))
    assert len(agent_mds) > 0, "No AGENT.md files found in agents/"


# ── unsupported capabilities ──────────────────────────────────────────────────


def test_unsupported_capabilities_reported(adapter, graph):
    """Hooks and MCP must be explicitly reported as unsupported — never silently dropped."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    unsupported_text = " ".join(result.unsupported).lower()
    assert "hook" in unsupported_text, (
        "Hooks not reported in unsupported list — must be explicit, not silently dropped"
    )
    assert "mcp" in unsupported_text, (
        "MCP not reported in unsupported list — must be explicit, not silently dropped"
    )


def test_no_silent_drops(adapter, graph):
    """CompilationResult must never have zero emitted AND zero unsupported."""
    for product in graph.products.values():
        result = adapter.compile(graph, product)
        # Either something was emitted OR something was explicitly unsupported/omitted
        assert result.emitted or result.unsupported or result.omitted, (
            f"Product {product.id}: CompilationResult has no emitted, unsupported, "
            "or omitted — this suggests silent drops"
        )


# ── check mode ────────────────────────────────────────────────────────────────


def test_check_mode_produces_no_files(adapter, graph, tmp_path):
    """--check must not write any files to the output directory."""
    product = graph.products["agent-toolkit-core"]

    # Record directory contents before check
    before = set(tmp_path.rglob("*"))

    result = adapter.check(graph, product)

    # Verify no files were written to the output_root
    after = set(tmp_path.rglob("*"))
    assert after == before, (
        f"check mode wrote {after - before} files — output_root must not be modified"
    )
    assert result.artifacts == [], "check mode must clear artifacts list"
    assert result.is_valid


# ── parity notes ──────────────────────────────────────────────────────────────


def test_parity_notes_documented():
    """CursorAdapter must document capability parity (rules vs skills distinction)."""
    notes = CursorAdapter.parity_notes()
    assert "rule" in notes.lower(), "Parity notes must explain rules vs skills"
    assert "mcp" in notes.lower(), "Parity notes must explain MCP status"
    assert "hook" in notes.lower(), "Parity notes must explain hooks status"


# ── all products ──────────────────────────────────────────────────────────────


@pytest.mark.parametrize("product_id", ["agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"])
def test_all_products_compile_cleanly(adapter, graph, product_id):
    """All defined products must compile without errors."""
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not in catalog")

    product = graph.products[product_id]
    result = adapter.compile(graph, product)
    assert result.errors == [], f"Errors compiling {product_id}: {result.errors}"
