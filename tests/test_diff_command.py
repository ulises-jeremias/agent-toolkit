"""Tests for agent-toolkit diff command."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

pytest.importorskip("yaml")

REPO_ROOT = Path(__file__).parent.parent


def run_diff(args=None):
    sys.path.insert(0, str(REPO_ROOT / "src"))
    import os

    os.environ["AGENT_TOOLKIT_ROOT"] = str(REPO_ROOT)
    from agent_toolkit.cli.diff import cmd_diff

    return cmd_diff(args or [])


def test_diff_no_changes_returns_0():
    """When plugin bundles match canonical, diff returns 0."""
    result = run_diff(["--target", "claude-code", "--product", "agent-toolkit-core"])
    assert result == 0


def test_diff_json_output():
    import contextlib
    import io

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        run_diff(["--target", "claude-code", "--json"])
    output = buf.getvalue()
    data = json.loads(output)
    assert isinstance(data, list)
    assert len(data) > 0


def test_diff_detects_content_changes():
    """Mutating an installed plugin file must report 'changed' (regression for tempfile bug)."""
    import os

    os.environ["AGENT_TOOLKIT_ROOT"] = str(REPO_ROOT)
    sys.path.insert(0, str(REPO_ROOT / "src"))

    target = REPO_ROOT / "plugins" / "agent-toolkit-core" / ".claude-plugin" / "plugin.json"
    assert target.is_file()
    original = target.read_bytes()
    try:
        target.write_bytes(original + b"\n")
        import contextlib
        import io

        from agent_toolkit.cli.diff import cmd_diff

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            cmd_diff(
                [
                    "--target",
                    "claude-code",
                    "--product",
                    "agent-toolkit-core",
                    "--json",
                ]
            )
        data = json.loads(buf.getvalue())
        entry = next(e for e in data if e["product"] == "agent-toolkit-core")
        assert entry["changes"]["changed"], f"expected content changes, got: {entry['changes']}"
        assert entry["no_changes"] is False
    finally:
        target.write_bytes(original)


def test_diff_help():
    result = run_diff(["--help"])
    assert result == 0
