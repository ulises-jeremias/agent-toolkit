"""Tests for consumer vs advanced help grouping."""
from __future__ import annotations

from agent_toolkit.cli import main as main_module


def test_help_groups_advanced_commands():
    doc = main_module._CONSUMER_HELP
    assert "Advanced commands" in doc
    assert "Consumer commands" in doc
    assert "docs/CLI_SURFACES.md" in doc
    assert doc.index("install") < doc.index("loop")
    assert "workspace" in doc
    assert doc.index("skills") < doc.index("loop")
