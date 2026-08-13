"""Quarantined Python CLI notice (docs/v/python-fallback.md)."""

from __future__ import annotations

from agent_toolkit.cli.main import emit_quarantine_notice


def test_quarantine_notice_quiet_env(monkeypatch, capsys):
    monkeypatch.setenv("AGENT_TOOLKIT_PY_QUIET", "1")
    emit_quarantine_notice()
    assert capsys.readouterr().err == ""


def test_quarantine_notice_non_tty(monkeypatch, capsys):
    monkeypatch.delenv("AGENT_TOOLKIT_PY_QUIET", raising=False)
    monkeypatch.setattr("sys.stderr.isatty", lambda: False)
    emit_quarantine_notice()
    assert capsys.readouterr().err == ""


def test_quarantine_notice_tty(monkeypatch, capsys):
    monkeypatch.delenv("AGENT_TOOLKIT_PY_QUIET", raising=False)
    monkeypatch.setattr("sys.stderr.isatty", lambda: True)
    emit_quarantine_notice()
    err = capsys.readouterr().err
    assert "quarantined Python fallback" in err
    assert "docs/v/python-fallback.md" in err
