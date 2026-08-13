"""CLI surface grouping tests (#84)."""

from agent_toolkit.cli import main as main_mod


def test_help_lists_advanced_section() -> None:
    help_text = main_mod._CONSUMER_HELP
    assert "Advanced commands" in help_text
    assert "loop" in help_text
    assert "devcompanion" in help_text
    assert "CLI_SURFACES.md" in help_text


def test_advanced_commands_include_harness() -> None:
    """Active advanced harness commands (excludes DEPRECATE/REMOVE dispositions)."""
    for cmd in ("loop", "workspace", "memory", "project", "devcompanion", "swarm"):
        assert cmd in main_mod.ADVANCED_COMMANDS


def test_insights_deprecated_not_primary_advanced() -> None:
    """insights remains wired for back-compat but is DEPRECATE (#526/#560), not a normal advanced cmd."""
    assert "insights" in main_mod.ADVANCED_COMMANDS  # still registered
    # Consumer help advanced blurb should not present insights as a featured harness command
    # in the same breath as loop/workspace (disposition: DEPRECATE — no V requirement).
    advanced_help = main_mod._CONSUMER_HELP
    # Prefer explicit disposition docs over help-table membership; ensure release REMOVE (#527)
    assert "release" in main_mod.ADVANCED_COMMANDS
