"""Contract tests for GitHub Copilot CLI and Repository adapters.

Two distinct surfaces are tested independently:
1. CopilotCLIAdapter — root-level plugin.json, agents as .agent.md
2. CopilotRepositoryAdapter — .github/ directory assets
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.copilot import CopilotCLIAdapter, CopilotRepositoryAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def cli_adapter(tmp_path):
    return CopilotCLIAdapter(tmp_path / "copilot-cli", REPO_ROOT)


@pytest.fixture
def repo_adapter(tmp_path):
    return CopilotRepositoryAdapter(tmp_path / "copilot-repo", REPO_ROOT)


# ── CLI Plugin ────────────────────────────────────────────────────────────────


def test_cli_plugin_json_at_root(cli_adapter, graph):
    """plugin.json must be at root level (not .copilot-plugin/)."""
    product = graph.products["agent-toolkit-core"]
    cli_adapter.compile(graph, product)

    manifest = cli_adapter.output_root / "agent-toolkit-core" / "plugin.json"
    assert manifest.exists(), "Root-level plugin.json not found"

    # Must NOT be in .copilot-plugin/ (that's Claude Code / Cursor convention)
    wrong = cli_adapter.output_root / "agent-toolkit-core" / ".copilot-plugin" / "plugin.json"
    assert not wrong.exists(), ".copilot-plugin/plugin.json must not exist for Copilot CLI"


def test_cli_manifest_valid_json(cli_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    cli_adapter.compile(graph, product)

    manifest = cli_adapter.output_root / "agent-toolkit-core" / "plugin.json"
    data = json.loads(manifest.read_text())
    for field in ("name", "version", "description"):
        assert field in data, f"CLI plugin.json missing '{field}'"


def test_cli_agents_use_agent_md_extension(cli_adapter, graph):
    """Copilot CLI agents use .agent.md extension (not AGENT.md)."""
    product = graph.products["agent-toolkit-core"]
    cli_adapter.compile(graph, product)

    agents_dir = cli_adapter.output_root / "agent-toolkit-core" / "agents"
    assert agents_dir.is_dir(), "agents/ directory not created"

    agent_md_files = list(agents_dir.glob("*.agent.md"))
    plain_md_files = list(agents_dir.glob("AGENT.md"))

    assert len(agent_md_files) > 0, "No .agent.md files found"
    assert plain_md_files == [], "AGENT.md files must not exist — use .agent.md convention"


def test_cli_skills_at_skills_dir(cli_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    cli_adapter.compile(graph, product)

    skills_dir = cli_adapter.output_root / "agent-toolkit-core" / "skills"
    assert skills_dir.is_dir()
    assert list(skills_dir.rglob("SKILL.md")) != []


def test_cli_no_dangerous_settings(cli_adapter, graph):
    for product in graph.products.values():
        cli_adapter.compile(graph, product)
        manifest_path = cli_adapter.output_root / product.id / "plugin.json"
        if manifest_path.exists():
            data = json.loads(manifest_path.read_text())
            assert "skipDangerousModePermissionPrompt" not in data
            assert "autoAcceptPermissions" not in data


def test_cli_unsupported_reported(cli_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = cli_adapter.compile(graph, product)
    unsupported = " ".join(result.unsupported).lower()
    assert "hook" in unsupported
    assert "mcp" in unsupported


def test_cli_check_mode_no_files(cli_adapter, graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = cli_adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before
    assert result.artifacts == []


# ── Repository Surface ────────────────────────────────────────────────────────


def test_repo_copilot_instructions_created(repo_adapter, graph):
    """.github/copilot-instructions.md must be generated."""
    product = graph.products["agent-toolkit-core"]
    repo_adapter.compile(graph, product)

    instructions = (
        repo_adapter.output_root / "agent-toolkit-core" / ".github" / "copilot-instructions.md"
    )
    assert instructions.exists(), ".github/copilot-instructions.md not found"
    assert "copilot-instructions.md" in [
        e for e in repo_adapter.compile(graph, product).emitted
    ]


def test_repo_copilot_instructions_content(repo_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    repo_adapter.compile(graph, product)

    instructions = (
        repo_adapter.output_root / "agent-toolkit-core" / ".github" / "copilot-instructions.md"
    )
    text = instructions.read_text()
    assert len(text) > 50, "copilot-instructions.md is too short"
    assert "skill" in text.lower() or "agent" in text.lower()


def test_repo_agents_in_github_dir(repo_adapter, graph):
    """.github/agents/<name>.agent.md — repository surface agent format."""
    product = graph.products["agent-toolkit-core"]
    repo_adapter.compile(graph, product)

    agents_dir = repo_adapter.output_root / "agent-toolkit-core" / ".github" / "agents"
    if agents_dir.exists():
        agent_mds = list(agents_dir.glob("*.agent.md"))
        assert len(agent_mds) > 0, "No .agent.md in .github/agents/"


def test_repo_skills_in_github_dir(repo_adapter, graph):
    """.github/skills/<name>/SKILL.md — repository surface skill format."""
    product = graph.products["agent-toolkit-core"]
    repo_adapter.compile(graph, product)

    skills_dir = repo_adapter.output_root / "agent-toolkit-core" / ".github" / "skills"
    if skills_dir.exists():
        skill_mds = list(skills_dir.rglob("SKILL.md"))
        assert len(skill_mds) > 0, "No SKILL.md in .github/skills/"


def test_repo_no_absolute_paths(repo_adapter, graph):
    product = graph.products["agent-toolkit-core"]
    repo_adapter.compile(graph, product)

    for f in (repo_adapter.output_root / "agent-toolkit-core").rglob("*.md"):
        text = f.read_text()
        assert "/home/" not in text, f"Absolute /home/ in {f}"


def test_repo_check_mode_no_files(repo_adapter, graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = repo_adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before
    assert result.artifacts == []


# ── Surface independence ──────────────────────────────────────────────────────


def test_two_surfaces_are_independent(cli_adapter, repo_adapter, graph):
    """CLI plugin and repository surface must generate different structures."""
    product = graph.products["agent-toolkit-core"]

    cli_result = cli_adapter.compile(graph, product)
    repo_result = repo_adapter.compile(graph, product)

    # CLI has root plugin.json, repo has .github/ — they're different
    assert cli_result.emitted != repo_result.emitted or (
        cli_result.artifacts[0].name != repo_result.artifacts[0].name
        if cli_result.artifacts and repo_result.artifacts else True
    )


# ── All products ──────────────────────────────────────────────────────────────


@pytest.mark.parametrize("product_id", [
    "agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"
])
def test_cli_all_products(cli_adapter, graph, product_id):
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = cli_adapter.compile(graph, graph.products[product_id])
    assert result.errors == []


@pytest.mark.parametrize("product_id", [
    "agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"
])
def test_repo_all_products(repo_adapter, graph, product_id):
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = repo_adapter.compile(graph, graph.products[product_id])
    assert result.errors == []
