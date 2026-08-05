"""Contract tests for the OpenCode adapter.

OpenCode companion assets are static files discoverable from the project root.
The adapter generates .opencode/skills/ and .opencode/agents/ along with a
minimal, safe opencode.json.

Verifies:
- Skills placed at .opencode/skills/<name>/SKILL.md
- Agents placed at .opencode/agents/<name>/AGENT.md
- opencode.json is safe (no private URLs, no provider config)
- Unsupported capabilities (runtime plugin features) explicitly reported
- check mode leaves filesystem unchanged
- No absolute machine paths in generated output
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest


from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.opencode import OpenCodeAdapter, _OPENCODE_JSON_TEMPLATE

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def adapter(tmp_path):
    return OpenCodeAdapter(tmp_path / "plugins", REPO_ROOT)


# ── opencode.json ─────────────────────────────────────────────────────────────


def test_opencode_json_created(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    config = adapter.output_root / "agent-toolkit-core" / "opencode.json"
    assert config.exists(), "opencode.json not created"
    assert "opencode-config" in result.emitted


def test_opencode_json_valid(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    config = adapter.output_root / "agent-toolkit-core" / "opencode.json"
    data = json.loads(config.read_text())
    assert isinstance(data, dict)


def test_opencode_json_no_provider_config(adapter, graph):
    """Provider config must not appear — it can contain private LAN URLs (DEFECT-002 class)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    config = adapter.output_root / "agent-toolkit-core" / "opencode.json"
    data = json.loads(config.read_text())
    errors = OpenCodeAdapter.validate_opencode_json(data)
    assert errors == [], f"opencode.json failed security validation: {errors}"


def test_opencode_json_no_private_hostnames(adapter, graph):
    """Generated opencode.json must not contain private hostnames or IPs."""
    for product in graph.products.values():
        adapter.compile(graph, product)
        config_path = adapter.output_root / product.id / "opencode.json"
        if config_path.exists():
            text = config_path.read_text()
            assert ".local" not in text, f"Private .local hostname in {config_path}"
            assert "192.168." not in text, f"Private IP in {config_path}"
            assert "colibri" not in text.lower(), f"Private host 'colibri' in {config_path}"


def test_opencode_json_matches_template(adapter, graph):
    """Generated opencode.json should use safe template defaults."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    config = adapter.output_root / "agent-toolkit-core" / "opencode.json"
    data = json.loads(config.read_text())
    # All template keys must be present
    for k, v in _OPENCODE_JSON_TEMPLATE.items():
        assert data.get(k) == v, f"Template key '{k}' missing or changed"


# ── skills ────────────────────────────────────────────────────────────────────


def test_skills_in_opencode_path(adapter, graph):
    """OpenCode discovers skills at .opencode/skills/<name>/SKILL.md."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skills_dir = adapter.output_root / "agent-toolkit-core" / ".opencode" / "skills"
    assert skills_dir.is_dir(), ".opencode/skills/ not created"

    skill_mds = list(skills_dir.rglob("SKILL.md"))
    assert len(skill_mds) > 0, "No SKILL.md in .opencode/skills/"


def test_no_skill_json(adapter, graph):
    """skill.json must not be generated (removed in v1.0.4)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skill_jsons = list((adapter.output_root / "agent-toolkit-core").rglob("skill.json"))
    assert skill_jsons == [], f"skill.json generated: {skill_jsons}"


def test_no_absolute_paths_in_skills(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    for skill_md in (adapter.output_root / "agent-toolkit-core").rglob("SKILL.md"):
        text = skill_md.read_text()
        assert "/home/" not in text, f"Absolute /home/ in {skill_md}"
        assert str(Path.home()) not in text, f"Home dir in {skill_md}"


# ── agents ────────────────────────────────────────────────────────────────────


def test_agents_in_opencode_path(adapter, graph):
    """OpenCode discovers agents at .opencode/agents/<name>/AGENT.md."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    agents_dir = adapter.output_root / "agent-toolkit-core" / ".opencode" / "agents"
    assert agents_dir.is_dir(), ".opencode/agents/ not created"

    agent_mds = list(agents_dir.rglob("AGENT.md"))
    assert len(agent_mds) > 0, "No AGENT.md in .opencode/agents/"


# ── unsupported capabilities ──────────────────────────────────────────────────


def test_runtime_features_reported_as_unsupported(adapter, graph):
    """Hooks, tools, MCP must be explicitly reported — never silently dropped."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    unsupported_text = " ".join(result.unsupported).lower()
    assert "hook" in unsupported_text, "Lifecycle hooks not reported as unsupported"
    assert "tool" in unsupported_text, "Custom tools not reported as unsupported"
    assert "mcp" in unsupported_text, "MCP not reported as unsupported"


def test_package_type_not_plugin(adapter):
    """OpenCode has no plugin marketplace — package_type must be accurate."""
    assert adapter.package_type != "plugin", (
        "OpenCode does not have a plugin marketplace. "
        "package_type must not be 'plugin' — use 'companion-assets' or similar."
    )


# ── check mode ────────────────────────────────────────────────────────────────


def test_check_mode_no_files_written(adapter, graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before, f"check mode wrote files: {after - before}"
    assert result.artifacts == []
    assert result.is_valid


# ── validate_opencode_json ────────────────────────────────────────────────────


def test_validate_detects_provider_field():
    errors = OpenCodeAdapter.validate_opencode_json({
        "provider": {"my-provider": {"baseURL": "http://colibri.local/v1"}}
    })
    assert len(errors) > 0, "Should detect 'provider' field with private URL"


def test_validate_detects_private_ip():
    errors = OpenCodeAdapter.validate_opencode_json({
        "server": "http://192.168.1.100:8080"
    })
    assert len(errors) > 0, "Should detect private 192.168.x.x IP"


def test_validate_accepts_safe_config():
    errors = OpenCodeAdapter.validate_opencode_json({
        "$schema": "https://opencode.ai/config.schema.json",
        "model": "anthropic/claude-sonnet-4-5",
    })
    assert errors == [], f"Safe config wrongly rejected: {errors}"


# ── parity notes ──────────────────────────────────────────────────────────────


def test_parity_notes_documented():
    notes = OpenCodeAdapter.parity_notes()
    assert "typescript" in notes.lower(), "Parity notes must mention TypeScript plugin"
    assert "opencode.json" in notes.lower(), "Parity notes must explain opencode.json"
    assert "defect" in notes.lower() or "private" in notes.lower(), (
        "Parity notes must explain why provider config is not included"
    )


# ── all products ──────────────────────────────────────────────────────────────


@pytest.mark.parametrize("product_id", [
    "agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"
])
def test_all_products_compile(adapter, graph, product_id):
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = adapter.compile(graph, graph.products[product_id])
    assert result.errors == [], f"Errors for {product_id}: {result.errors}"
