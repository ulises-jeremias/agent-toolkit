"""Thin PyPI V launcher (ADR-021 / #535)."""

from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit import launcher


def test_missing_binary_exits_127(monkeypatch, capsys):
    monkeypatch.delenv("AGENT_TOOLKIT_BIN", raising=False)
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.setattr(launcher, "bundled_binary", lambda: None)
    with pytest.raises(SystemExit) as ei:
        launcher.main(["agent-toolkit", "version"])
    assert ei.value.code == 127
    err = capsys.readouterr().err
    assert "native V binary not found" in err
    assert "agent-toolkit-py" in err


def test_run_native_exports_wheel_data_root(monkeypatch, tmp_path: Path):
    data = tmp_path / "data"
    (data / "skills").mkdir(parents=True)
    fake = tmp_path / "agent-toolkit"
    fake.write_text("#!/bin/sh\n")
    fake.chmod(0o755)
    monkeypatch.setenv("AGENT_TOOLKIT_BIN", str(fake))
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.setattr(launcher, "bundled_data_root", lambda: data)
    recorded: dict[str, str | None] = {}

    def fake_execv(path: str, args: list[str]) -> None:
        recorded["root"] = launcher.os.environ.get("AGENT_TOOLKIT_ROOT")
        raise OSError("execv mocked")

    monkeypatch.setattr(launcher.os, "execv", fake_execv)
    monkeypatch.setattr(launcher.os, "name", "posix")
    with pytest.raises(OSError, match="execv mocked"):
        launcher.main(["agent-toolkit", "doctor"])
    assert recorded["root"] == str(data)


def test_run_native_preserves_existing_toolkit_root(monkeypatch, tmp_path: Path):
    data = tmp_path / "data"
    (data / "skills").mkdir(parents=True)
    override = tmp_path / "override"
    override.mkdir()
    fake = tmp_path / "agent-toolkit"
    fake.write_text("#!/bin/sh\n")
    fake.chmod(0o755)
    monkeypatch.setenv("AGENT_TOOLKIT_BIN", str(fake))
    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(override))
    monkeypatch.setattr(launcher, "bundled_data_root", lambda: data)
    recorded: dict[str, str | None] = {}

    def fake_execv(path: str, args: list[str]) -> None:
        recorded["root"] = launcher.os.environ.get("AGENT_TOOLKIT_ROOT")
        raise OSError("execv mocked")

    monkeypatch.setattr(launcher.os, "execv", fake_execv)
    monkeypatch.setattr(launcher.os, "name", "posix")
    with pytest.raises(OSError, match="execv mocked"):
        launcher.main(["agent-toolkit", "version"])
    assert recorded["root"] == str(override)


def test_env_bin_posix_execv(monkeypatch, tmp_path: Path):
    fake = tmp_path / "agent-toolkit"
    fake.write_text("#!/bin/sh\n")
    fake.chmod(0o755)
    monkeypatch.setenv("AGENT_TOOLKIT_BIN", str(fake))
    recorded: list[list[str]] = []

    def fake_execv(path: str, args: list[str]) -> None:
        recorded.append([path, *args])
        raise OSError("execv mocked")

    monkeypatch.setattr(launcher.os, "execv", fake_execv)
    monkeypatch.setattr(launcher.os, "name", "posix")
    with pytest.raises(OSError, match="execv mocked"):
        launcher.main(["agent-toolkit", "skills", "list"])
    assert recorded
    assert recorded[0][0] == str(fake)
    assert recorded[0][1] == str(fake)
    assert recorded[0][2:] == ["skills", "list"]


def test_resolve_from_toolkit_root_build(monkeypatch, tmp_path: Path):
    build = tmp_path / "build"
    build.mkdir()
    native = build / "agent-toolkit-v"
    native.write_text("x")
    monkeypatch.delenv("AGENT_TOOLKIT_BIN", raising=False)
    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(tmp_path))
    monkeypatch.setattr(launcher, "bundled_binary", lambda: None)
    assert launcher.resolve_native_bin() == native


def test_product_scripts_point_at_launcher():
    pyproject = (
        Path(__file__).resolve().parents[1] / "packages/pypi/agent-toolkit-cli/pyproject.toml"
    )
    text = pyproject.read_text(encoding="utf-8")
    assert 'agent-toolkit = "agent_toolkit.launcher:main"' in text
    assert 'agent-toolkit-cli = "agent_toolkit.launcher:main"' in text
    assert 'agent-toolkit-py = "agent_toolkit.cli.main:main"' in text
