"""Tests for MCP CLI health/setup/uninstall surface."""
from __future__ import annotations

import json

from agent_toolkit.cli.mcp import cmd_mcp


def test_mcp_help_lists_health_and_uninstall(capsys):
    rc = cmd_mcp(["--help"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "health" in out
    assert "uninstall" in out
    assert "setup" in out


def test_mcp_health_github_offline(capsys):
    rc = cmd_mcp(["health", "github"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "GITHUB_TOKEN" in out
    assert "registry:" in out


def test_mcp_health_unknown_provider(capsys):
    rc = cmd_mcp(["health", "not-a-real-provider"])
    out = capsys.readouterr().out
    assert rc == 1
    assert "Not in mcp/registry" in out


def test_mcp_uninstall_removes_provider(tmp_path, monkeypatch, capsys):
    cfg_dir = tmp_path / ".config" / "agent-toolkit"
    cfg_dir.mkdir(parents=True)
    cfg_path = cfg_dir / "mcp-config.json"
    cfg_path.write_text(
        json.dumps({"providers": {"github": {"enabled": True, "required_env": ["GITHUB_TOKEN"]}}})
    )
    monkeypatch.setenv("HOME", str(tmp_path))

    rc = cmd_mcp(["uninstall", "github"])
    assert rc == 0
    data = json.loads(cfg_path.read_text())
    assert "github" not in data["providers"]
