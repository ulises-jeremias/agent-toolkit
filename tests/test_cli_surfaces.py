"""CLI surface grouping tests (#84)."""

from pathlib import Path

from agent_toolkit.cli import main as main_mod

# Required advanced harness surfaces (PORT/REDESIGN per #560). Not DEPRECATE/REMOVE.
REQUIRED_ADVANCED = (
    "loop",
    "workspace",
    "memory",
    "project",
    "devcompanion",
    "swarm",
)


def test_help_lists_advanced_section() -> None:
    help_text = main_mod._CONSUMER_HELP
    assert "Advanced commands" in help_text
    assert "loop" in help_text
    assert "devcompanion" in help_text
    assert "CLI_SURFACES.md" in help_text


def test_advanced_commands_include_harness() -> None:
    for cmd in REQUIRED_ADVANCED:
        assert cmd in main_mod.ADVANCED_COMMANDS


def test_insights_release_not_required_advanced() -> None:
    """insights is DEPRECATE (#526); release is REMOVE (#527) — not required ADVANCED_COMMANDS.

    Quarantined Python may still register the names for compatibility; tests must not
    treat them as members of the required advanced harness set (T01 / #692).
    """
    assert "insights" not in REQUIRED_ADVANCED
    assert "release" not in REQUIRED_ADVANCED

    surfaces = Path("docs/CLI_SURFACES.md").read_text()
    assert "DEPRECATE" in surfaces and "#526" in surfaces
    assert "REMOVE" in surfaces and "#527" in surfaces
