"""CLI surface grouping tests (#84)."""
from agent_toolkit.cli import main as main_mod


def test_help_lists_advanced_section() -> None:
    help_text = main_mod._CONSUMER_HELP
    assert "Advanced commands" in help_text
    assert "loop" in help_text
    assert "devcompanion" in help_text
    assert "CLI_SURFACES.md" in help_text


def test_advanced_commands_include_harness() -> None:
    for cmd in ("loop", "workspace", "memory", "project", "devcompanion", "insights"):
        assert cmd in main_mod.ADVANCED_COMMANDS
