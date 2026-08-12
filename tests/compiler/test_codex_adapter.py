"""Contract tests for the OpenAI Codex adapter.

Codex plugin support is EXPERIMENTAL. Marketplace launched March 2026; self-serve
submission is "coming soon" as of 2026-08-04.

Generated artifacts:
  .codex-plugin/plugin.json   — manifest (distinct from .claude-plugin/)
  skills/<name>/SKILL.md
  agents/<name>/AGENT.md

Verifies:
- .codex-plugin/plugin.json created at the correct path (NOT .claude-plugin/)
- maturity == "experimental" in plugin.json (important safety label)
- No forbidden dangerous settings in manifest
- No private hostnames in generated output
- Unsupported capabilities (hooks, MCP) explicitly reported
- check mode leaves filesystem unchanged
- No absolute paths in generated output
- All products compile cleanly (parametrized)
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.codex import CodexAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def adapter(tmp_path):
    return CodexAdapter(tmp_path / "codex-output", REPO_ROOT)


# ── manifest ──────────────────────────────────────────────────────────────────


def test_plugin_json_at_codex_path(adapter, graph):
    """.codex-plugin/plugin.json must be at the Codex-specific path."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".codex-plugin" / "plugin.json"
    assert manifest.exists(), ".codex-plugin/plugin.json not found"
    assert "plugin-manifest" in result.emitted


def test_plugin_json_not_at_claude_path(adapter, graph):
    """plugin.json must NOT be at .claude-plugin/ — that is Claude Code's path."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    wrong_path = adapter.output_root / "agent-toolkit-core" / ".claude-plugin" / "plugin.json"
    assert not wrong_path.exists(), (
        ".claude-plugin/plugin.json must NOT exist for Codex adapter — "
        "Codex uses .codex-plugin/, not .claude-plugin/"
    )


def test_plugin_json_not_at_cursor_path(adapter, graph):
    """plugin.json must NOT be at .cursor-plugin/ — that is Cursor's path."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    wrong_path = adapter.output_root / "agent-toolkit-core" / ".cursor-plugin" / "plugin.json"
    assert not wrong_path.exists(), (
        ".cursor-plugin/plugin.json must NOT exist for Codex adapter — Codex uses .codex-plugin/"
    )


def test_plugin_json_valid(adapter, graph):
    """plugin.json must be valid JSON."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".codex-plugin" / "plugin.json"
    data = json.loads(manifest.read_text())
    assert isinstance(data, dict)


def test_plugin_json_required_fields(adapter, graph):
    """plugin.json must contain standard manifest fields."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".codex-plugin" / "plugin.json"
    data = json.loads(manifest.read_text())

    for field in ("name", "version", "description", "license"):
        assert field in data, f"plugin.json missing required field '{field}'"


def test_maturity_is_experimental(adapter, graph):
    """maturity MUST be 'experimental' — Codex marketplace is gated and evolving.

    This is an important safety label. Changing it to 'stable' before the
    Codex plugin API stabilizes would misrepresent the reliability of this surface.
    """
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".codex-plugin" / "plugin.json"
    data = json.loads(manifest.read_text())

    assert "maturity" in data, "plugin.json missing 'maturity' field"
    assert data["maturity"] == "experimental", (
        f"maturity must be 'experimental', got '{data['maturity']}'. "
        "Codex marketplace is gated and self-serve submission is 'coming soon' "
        "as of 2026-08-04. Do not mark as stable prematurely."
    )


def test_adapter_maturity_is_experimental(adapter):
    """The adapter class itself must declare maturity = 'experimental'."""
    assert adapter.maturity == "experimental", (
        f"CodexAdapter.maturity must be 'experimental', got '{adapter.maturity}'"
    )


def test_plugin_json_no_dangerous_settings(adapter, graph):
    """Plugin must not bypass permission prompts or safety mechanisms."""
    for product in graph.products.values():
        adapter.compile(graph, product)
        manifest_path = adapter.output_root / product.id / ".codex-plugin" / "plugin.json"
        if manifest_path.exists():
            data = json.loads(manifest_path.read_text())
            assert "skipDangerousModePermissionPrompt" not in data
            assert "autoAcceptPermissions" not in data
            assert "disablePermissionPrompts" not in data
            assert "allowUnsafeCode" not in data


def test_plugin_json_no_private_hostnames(adapter, graph):
    """plugin.json must not contain private hostnames or IPs."""
    for product in graph.products.values():
        adapter.compile(graph, product)
        manifest_path = adapter.output_root / product.id / ".codex-plugin" / "plugin.json"
        if manifest_path.exists():
            text = manifest_path.read_text()
            assert ".local" not in text, "Private .local hostname in manifest"
            assert "192.168." not in text, "Private IP in manifest"
            assert "colibri" not in text.lower(), "Private host 'colibri' in manifest"


def test_manifest_name_matches_product(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    manifest = adapter.output_root / "agent-toolkit-core" / ".codex-plugin" / "plugin.json"
    data = json.loads(manifest.read_text())
    assert data["name"] == "agent-toolkit-core"


# ── skills ────────────────────────────────────────────────────────────────────


def test_skills_generated(adapter, graph):
    """Skills must be placed at skills/<name>/SKILL.md."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skills_dir = adapter.output_root / "agent-toolkit-core" / "skills"
    assert skills_dir.is_dir(), "skills/ directory not created"

    skill_mds = list(skills_dir.rglob("SKILL.md"))
    assert len(skill_mds) > 0, "No SKILL.md files found in skills/"


def test_skills_emitted_in_result(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    emitted_skills = [e for e in result.emitted if e.startswith("skill:")]
    assert len(emitted_skills) > 0, "No skills recorded in result.emitted"


def test_no_absolute_paths_in_skills(adapter, graph):
    """Generated SKILL.md must not contain absolute machine paths."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    for skill_md in (adapter.output_root / "agent-toolkit-core").rglob("SKILL.md"):
        text = skill_md.read_text()
        assert "/home/" not in text, f"Absolute /home/ path in {skill_md}"
        assert str(Path.home()) not in text, f"Home dir path in {skill_md}"


# ── agents ────────────────────────────────────────────────────────────────────


def test_agents_generated(adapter, graph):
    """Agents must be placed at agents/<name>/AGENT.md."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    agents_dir = adapter.output_root / "agent-toolkit-core" / "agents"
    assert agents_dir.is_dir(), "agents/ directory not created"

    agent_mds = list(agents_dir.rglob("AGENT.md"))
    assert len(agent_mds) > 0, "No AGENT.md files found in agents/"


def test_no_absolute_paths_in_agents(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    for agent_md in (adapter.output_root / "agent-toolkit-core").rglob("AGENT.md"):
        text = agent_md.read_text()
        assert "/home/" not in text, f"Absolute /home/ path in {agent_md}"
        assert str(Path.home()) not in text, f"Home dir path in {agent_md}"


# ── unsupported capabilities ──────────────────────────────────────────────────


def test_hooks_reported_as_unsupported(adapter, graph):
    """Hooks must be explicitly reported as unsupported — never silently dropped."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    unsupported_text = " ".join(result.unsupported).lower()
    assert "hook" in unsupported_text, "Lifecycle hooks not reported as unsupported"


def test_mcp_reported_as_unsupported(adapter, graph):
    """MCP must be explicitly reported as unsupported — never silently dropped."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    unsupported_text = " ".join(result.unsupported).lower()
    assert "mcp" in unsupported_text, "MCP not reported as unsupported"


# ── experimental maturity warning ─────────────────────────────────────────────


def test_experimental_warning_in_result(adapter, graph):
    """Each compilation result must include an experimental maturity warning."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    warning_text = " ".join(result.warnings).lower()
    assert "experimental" in warning_text, (
        "Compilation result must include a warning about experimental maturity"
    )


# ── validate_plugin_json ──────────────────────────────────────────────────────


def test_validate_detects_dangerous_settings():
    errors = CodexAdapter.validate_plugin_json(
        {
            "name": "test",
            "skipDangerousModePermissionPrompt": True,
        }
    )
    assert len(errors) > 0, "Should detect skipDangerousModePermissionPrompt"


def test_validate_detects_private_ip():
    errors = CodexAdapter.validate_plugin_json(
        {
            "name": "test",
            "server": "http://192.168.1.100:8080",
        }
    )
    assert len(errors) > 0, "Should detect private 192.168.x.x IP"


def test_validate_detects_private_hostname():
    errors = CodexAdapter.validate_plugin_json(
        {
            "name": "test",
            "endpoint": "http://colibri.local/v1",
        }
    )
    assert len(errors) > 0, "Should detect private .local hostname"


def test_validate_accepts_semver_with_ten_minor():
    """Regression: version 1.10.0 must not trip the private 10.x IP check."""
    errors = CodexAdapter.validate_plugin_json(
        {
            "name": "agent-toolkit-core",
            "version": "1.10.0",
            "description": "Agent Toolkit for Codex",
            "maturity": "experimental",
            "license": "MIT",
        }
    )
    assert errors == [], f"Semver 1.10.0 wrongly rejected: {errors}"


def test_validate_detects_private_10_dot_ip():
    errors = CodexAdapter.validate_plugin_json(
        {
            "name": "test",
            "server": "http://10.0.0.5:8080",
        }
    )
    assert len(errors) > 0, "Should detect private 10.x.x.x IP"


def test_validate_accepts_safe_manifest():
    errors = CodexAdapter.validate_plugin_json(
        {
            "name": "agent-toolkit-core",
            "version": "1.0.0",
            "description": "Agent Toolkit for Codex",
            "maturity": "experimental",
            "license": "MIT",
        }
    )
    assert errors == [], f"Safe manifest wrongly rejected: {errors}"


# ── check mode ────────────────────────────────────────────────────────────────


def test_check_mode_no_files_written(adapter, graph, tmp_path):
    """check mode must not write any files to the filesystem."""
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before, f"check mode wrote files: {after - before}"
    assert result.artifacts == []
    assert result.is_valid


# ── parity notes ──────────────────────────────────────────────────────────────


def test_parity_notes_documented():
    notes = CodexAdapter.parity_notes()
    assert "experimental" in notes.lower(), "Parity notes must mention experimental status"
    assert "marketplace" in notes.lower(), "Parity notes must explain marketplace status"
    assert "hook" in notes.lower(), "Parity notes must explain hooks status"
    assert "mcp" in notes.lower(), "Parity notes must explain MCP status"
    assert "codex-plugin" in notes.lower(), "Parity notes must document the manifest path"


def test_agent_skills_layout(adapter, graph):
    """Skills and agents follow Agent Skills convention (agentskills.io alignment)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    out_dir = adapter.output_root / "agent-toolkit-core"
    skill_mds = list((out_dir / "skills").rglob("SKILL.md"))
    agent_mds = list((out_dir / "agents").rglob("AGENT.md"))

    assert skill_mds, "skills/<name>/SKILL.md required for Agent Skills alignment"
    assert agent_mds, "agents/<name>/AGENT.md required for agent personas"
    for skill_md in skill_mds:
        assert skill_md.parent.name != "skills", "Skills must be nested skills/<name>/SKILL.md"


def test_maturity_must_remain_experimental_contract():
    """Contract guard: Codex must stay experimental until official API stabilizes."""
    assert CodexAdapter.maturity == "experimental"
    notes = CodexAdapter.parity_notes().lower()
    assert "stable" in notes or "must not" in notes or "not be changed" in notes, (
        "Parity notes must warn against premature stable labeling"
    )


# ── all products ──────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "product_id", ["agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"]
)
def test_all_products_compile(adapter, graph, product_id):
    """All defined products must compile without errors."""
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = adapter.compile(graph, graph.products[product_id])
    assert result.errors == [], f"Errors for {product_id}: {result.errors}"
