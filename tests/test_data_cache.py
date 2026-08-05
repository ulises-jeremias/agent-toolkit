"""Tests for GitHub Release data cache resolution."""
from __future__ import annotations

from pathlib import Path

from agent_toolkit.data_cache import cache_dir, ensure_cached_data, is_cache_current


def test_cache_dir_under_xdg(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    monkeypatch.delenv("AGENT_TOOLKIT_OFFLINE", raising=False)
    assert cache_dir() == tmp_path / "cache" / "agent-toolkit"


def test_ensure_cached_data_offline_without_data_returns_none(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    result = ensure_cached_data(offline=True)
    assert result is None


def test_ensure_cached_data_offline_with_profiles(tmp_path, monkeypatch):
    cache = tmp_path / "cache" / "agent-toolkit"
    (cache / "profiles").mkdir(parents=True)
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    result = ensure_cached_data(offline=True)
    assert result == cache


def test_is_cache_current_false_when_missing(monkeypatch):
    monkeypatch.setattr("agent_toolkit.data_cache.CACHE_VERSION_FILE", Path("/nonexistent/version.json"))
    assert is_cache_current() is False
