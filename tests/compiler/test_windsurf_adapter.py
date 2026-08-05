"""Contract tests for the Windsurf / Devin Desktop adapter.

Windsurf has no plugin marketplace. The adapter generates a customization bundle:
AGENTS.md, rules/*.mdc (behavioral constraints), and skills/*.

Semantic distinctions enforced by this contract (from ADR-002):
  Rules   = behavioral constraints (always-on) → rules/<name>.mdc
  Skills  = on-demand procedures               → skills/<name>/SKILL.md
  Memories = personal user state               → NOT generated (deliberately)

Verifies:
- AGENTS.md is generated
- rules/*.mdc are generated for agent personas
- skills/<name>/SKILL.md are generated
- NO memories generated (semantic contract)
- package_type == "customization-bundle" (not "plugin")
- Unsupported capabilities (hooks, MCP) explicitly reported
- check mode leaves filesystem unchanged
- No absolute paths in generated output
"""
from __future__ import annotations

from pathlib import Path

import pytest


from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.windsurf import WindsurfAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def adapter(tmp_path):
    return WindsurfAdapter(tmp_path / "windsurf-output", REPO_ROOT)


# ── AGENTS.md ─────────────────────────────────────────────────────────────────


def test_agents_md_generated(adapter, graph):
    """AGENTS.md must be created at the product root."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    agents_md = adapter.output_root / "agent-toolkit-core" / "AGENTS.md"
    assert agents_md.exists(), "AGENTS.md not generated"
    assert "AGENTS.md" in result.emitted


def test_agents_md_content(adapter, graph):
    """AGENTS.md must have meaningful content."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    text = (adapter.output_root / "agent-toolkit-core" / "AGENTS.md").read_text()
    assert len(text) > 50, "AGENTS.md is too short to be useful"
    # Should contain skill or agent references
    assert "skill" in text.lower() or "agent" in text.lower()


def test_agents_md_no_absolute_paths(adapter, graph):
    """AGENTS.md must not contain machine-specific absolute paths."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    text = (adapter.output_root / "agent-toolkit-core" / "AGENTS.md").read_text()
    assert "/home/" not in text, "Absolute /home/ path in AGENTS.md"
    assert str(Path.home()) not in text, "Home dir path in AGENTS.md"


# ── rules/*.mdc ───────────────────────────────────────────────────────────────


def test_rules_mdc_generated(adapter, graph):
    """Windsurf rules (.mdc) must be generated for agent personas."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    rules_dir = adapter.output_root / "agent-toolkit-core" / "rules"
    assert rules_dir.is_dir(), "rules/ directory not created"

    mdc_files = list(rules_dir.glob("*.mdc"))
    assert len(mdc_files) > 0, "No .mdc rule files generated"

    emitted_rules = [e for e in result.emitted if e.startswith("rule:")]
    assert len(emitted_rules) > 0, "No rules recorded in result.emitted"


def test_rules_have_mdc_extension(adapter, graph):
    """Rule files must use .mdc extension (Windsurf convention)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    rules_dir = adapter.output_root / "agent-toolkit-core" / "rules"
    if rules_dir.exists():
        all_files = list(rules_dir.iterdir())
        non_mdc = [f for f in all_files if f.suffix != ".mdc"]
        assert non_mdc == [], f"Non-.mdc files in rules/: {non_mdc}"


def test_rules_have_frontmatter(adapter, graph):
    """Windsurf .mdc rules must have YAML frontmatter with description and alwaysApply."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    rules_dir = adapter.output_root / "agent-toolkit-core" / "rules"
    for mdc_file in rules_dir.glob("*.mdc"):
        text = mdc_file.read_text()
        assert text.startswith("---"), f"{mdc_file.name} missing YAML frontmatter"
        assert "description:" in text, f"{mdc_file.name} missing 'description' in frontmatter"
        assert "alwaysApply:" in text, f"{mdc_file.name} missing 'alwaysApply' in frontmatter"


def test_rules_no_absolute_paths(adapter, graph):
    """Rule files must not contain machine-specific absolute paths."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    for mdc_file in (adapter.output_root / "agent-toolkit-core").rglob("*.mdc"):
        text = mdc_file.read_text()
        assert "/home/" not in text, f"Absolute /home/ path in {mdc_file}"
        assert str(Path.home()) not in text, f"Home dir path in {mdc_file}"


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
    """CompilationResult must record each emitted skill."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    emitted_skills = [e for e in result.emitted if e.startswith("skill:")]
    assert len(emitted_skills) > 0, "No skills recorded in result.emitted"


def test_no_skill_json(adapter, graph):
    """skill.json must not be generated (removed in v1.0.4)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skill_jsons = list((adapter.output_root / "agent-toolkit-core").rglob("skill.json"))
    assert skill_jsons == [], f"skill.json generated: {skill_jsons}"


def test_skills_no_absolute_paths(adapter, graph):
    """Generated SKILL.md must not contain absolute machine paths."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    for skill_md in (adapter.output_root / "agent-toolkit-core").rglob("SKILL.md"):
        text = skill_md.read_text()
        assert "/home/" not in text, f"Absolute /home/ path in {skill_md}"
        assert str(Path.home()) not in text, f"Home dir path in {skill_md}"


# ── NO memories (semantic contract) ──────────────────────────────────────────


def test_no_memories_generated(adapter, graph):
    """Memories MUST NOT be generated — they are personal per-user state (ADR-002).

    Windsurf memories live in the user's profile, not in a shared repository.
    Generating memories as a distributable artifact would override individual
    user configurations, violating the semantic contract from ADR-002.
    """
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    out_dir = adapter.output_root / "agent-toolkit-core"

    # Check that no memories directory or file exists
    memories_dir = out_dir / "memories"
    assert not memories_dir.exists(), (
        "memories/ directory must NOT be generated — memories are personal per-user "
        "state and must not be distributed as a shared project artifact (ADR-002)"
    )

    # Check that nothing in unsupported or emitted is labeled as memories
    # (we want it in unsupported to document the decision, not as a generated artifact)
    for f in out_dir.rglob("*.memory") if out_dir.exists() else []:
        assert False, f"Memory file found: {f} — memories must not be generated"


def test_memories_documented_as_not_generated(adapter, graph):
    """The decision not to generate memories must be documented in unsupported."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    unsupported_text = " ".join(result.unsupported).lower()
    assert "memor" in unsupported_text, (
        "The decision to not generate memories must be documented in result.unsupported "
        "so callers know the capability was considered and deliberately excluded"
    )


# ── package_type ──────────────────────────────────────────────────────────────


def test_package_type_is_customization_bundle(adapter):
    """Windsurf has no marketplace — package_type must be 'customization-bundle'."""
    assert adapter.package_type == "customization-bundle", (
        f"Expected 'customization-bundle', got '{adapter.package_type}'"
    )


def test_package_type_not_plugin(adapter):
    """package_type must NOT be 'plugin' — Windsurf has no marketplace."""
    assert adapter.package_type != "plugin", (
        "Windsurf has no plugin marketplace. package_type must not be 'plugin'."
    )


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


def test_no_plugin_manifest_generated(adapter, graph):
    """No plugin manifest must be generated — Windsurf has no marketplace."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    out_dir = adapter.output_root / "agent-toolkit-core"
    # None of the known manifest paths should exist
    for manifest_path in (
        out_dir / "plugin.json",
        out_dir / ".windsurf-plugin" / "plugin.json",
        out_dir / ".cursor-plugin" / "plugin.json",
        out_dir / ".claude-plugin" / "plugin.json",
    ):
        assert not manifest_path.exists(), (
            f"Plugin manifest generated at {manifest_path} — "
            "Windsurf has no marketplace; no manifest should be created"
        )


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
    notes = WindsurfAdapter.parity_notes()
    assert "rule" in notes.lower(), "Parity notes must explain rules vs skills"
    assert "memor" in notes.lower(), "Parity notes must explain why memories are excluded"
    assert "hook" in notes.lower(), "Parity notes must explain hooks status"
    assert "mcp" in notes.lower(), "Parity notes must explain MCP status"
    assert "marketplace" in notes.lower(), "Parity notes must explain no marketplace"


# ── all products ──────────────────────────────────────────────────────────────


@pytest.mark.parametrize("product_id", [
    "agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"
])
def test_all_products_compile(adapter, graph, product_id):
    """All defined products must compile without errors."""
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = adapter.compile(graph, graph.products[product_id])
    assert result.errors == [], f"Errors for {product_id}: {result.errors}"
