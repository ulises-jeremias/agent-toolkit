"""Wave 4 #272 — path and package-data resolution tests (no network).

Resolution precedence (documented here, align with #266 ADR):

1. AGENT_TOOLKIT_ROOT / AI_WORKSPACE env var (user override)
2. importlib.resources / bundled package data (wheel install) — _bundled_data_paths()
3. XDG cache (~/.cache/agent-toolkit or $XDG_CACHE_HOME/agent-toolkit) via ensure_cached_data
4. Walk up from agent_toolkit/_paths.py location (editable install)
5. CWD fallback (contains skills/ or loops/)
6. Failure -> EnvironmentError

Tests cover: editable vs bundled vs env-override vs XDG cache vs missing-data
failure, offline mode handling, and data_cache helpers. No network is used;
urllib is mocked where needed.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest import mock

import pytest

import agent_toolkit._paths as paths_mod
from agent_toolkit._paths import (
    find_toolkit_root,
    find_workspace_root,
    toolkit_root,
)
from agent_toolkit.data_cache import cache_dir, ensure_cached_data, is_cache_current


def test_precedence_env_override_takes_priority(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Doc: env var AGENT_TOOLKIT_ROOT wins over bundled/editable."""
    fake_root = tmp_path / "my-toolkit"
    (fake_root / "skills").mkdir(parents=True)
    (fake_root / "loops").mkdir()
    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(fake_root))
    # Even with AI_WORKSPACE set, AGENT_TOOLKIT_ROOT should win (first checked)
    monkeypatch.setenv("AI_WORKSPACE", str(tmp_path / "other"))
    result = find_toolkit_root()
    assert result == fake_root


def test_precedence_ai_workspace_fallback_when_root_unset(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Doc: AI_WORKSPACE is second env fallback when AGENT_TOOLKIT_ROOT misses."""
    fake = tmp_path / "aiws"
    (fake / "skills").mkdir(parents=True)
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.setenv("AI_WORKSPACE", str(fake))
    # patch bundled + cache to not interfere
    with mock.patch.object(paths_mod, "_bundled_data_paths", return_value=[]):
        with mock.patch("agent_toolkit.data_cache.ensure_cached_data", return_value=None):
            result = find_toolkit_root()
            assert result == fake


def test_bundled_data_wins_over_editable_when_present(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Doc: wheel-bundled data (via _bundled_data_paths) beats editable walk-up."""
    bundled = tmp_path / "bundled"
    (bundled / "profiles").mkdir(parents=True)
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.delenv("AI_WORKSPACE", raising=False)
    monkeypatch.setenv("AGENT_TOOLKIT_OFFLINE", "1")
    with mock.patch.object(paths_mod, "_bundled_data_paths", return_value=[bundled]):
        result = find_toolkit_root()
        assert result == bundled


def test_xdg_cache_used_when_bundled_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Doc: XDG cache is consulted when bundled data is absent."""
    cached = tmp_path / "xcache" / "agent-toolkit"
    (cached / "profiles").mkdir(parents=True)
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.delenv("AI_WORKSPACE", raising=False)
    monkeypatch.setenv("AGENT_TOOLKIT_OFFLINE", "0")
    with mock.patch.object(paths_mod, "_bundled_data_paths", return_value=[]):
        with mock.patch("agent_toolkit.data_cache.ensure_cached_data", return_value=cached):
            result = find_toolkit_root()
            assert result == cached


def test_offline_mode_uses_cached_profiles_if_present(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Doc: in offline mode, existing XDG cache with profiles is returned."""
    monkeypatch.setenv("AGENT_TOOLKIT_OFFLINE", "1")
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.delenv("AI_WORKSPACE", raising=False)
    cached = tmp_path / "cache" / "agent-toolkit"
    (cached / "profiles").mkdir(parents=True)
    with mock.patch.object(paths_mod, "_bundled_data_paths", return_value=[]):
        result = find_toolkit_root()
        assert result == cached


def test_missing_data_raises_environment_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Doc: when no source has data, find_toolkit_root raises EnvironmentError."""
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.delenv("AI_WORKSPACE", raising=False)
    monkeypatch.setenv("AGENT_TOOLKIT_OFFLINE", "1")
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "empty-cache"))
    with mock.patch.object(paths_mod, "_bundled_data_paths", return_value=[]):
        with pytest.raises(EnvironmentError, match="Cannot locate"):
            find_toolkit_root()


def test_toolkit_root_caching_and_reset(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Doc: toolkit_root() caches; reset_toolkit_root() clears."""
    fake = tmp_path / "cached"
    (fake / "skills").mkdir(parents=True)
    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(fake))
    paths_mod._root = None  # type: ignore[attr-defined]
    r1 = toolkit_root()
    r2 = toolkit_root()
    assert r1 == r2 == fake
    paths_mod.reset_toolkit_root()
    assert paths_mod._root is None  # type: ignore[attr-defined]
    # next call re-resolves
    r3 = toolkit_root()
    assert r3 == fake
    paths_mod.reset_toolkit_root()


def test_find_workspace_root_override(tmp_path: Path) -> None:
    """Doc: explicit override wins."""
    ws = tmp_path / "ws"
    ws.mkdir()
    assert find_workspace_root(override=str(ws)) == ws.resolve()
    assert find_workspace_root(override="/nonexistent/path/xyz") is None


def test_find_workspace_root_env_vars(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Doc: AGENT_TOOLKIT_WORKSPACE > HARNESS_DIR."""
    ws1 = tmp_path / "ws1"
    ws2 = tmp_path / "ws2"
    ws1.mkdir()
    ws2.mkdir()
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(ws1))
    monkeypatch.setenv("HARNESS_DIR", str(ws2))
    assert find_workspace_root() == ws1.resolve()
    monkeypatch.delenv("AGENT_TOOLKIT_WORKSPACE", raising=False)
    assert find_workspace_root() == ws2.resolve()


def test_is_data_root_detection(tmp_path: Path) -> None:
    from agent_toolkit._paths import _is_data_root

    assert _is_data_root(tmp_path) is False
    (tmp_path / "profiles").mkdir()
    assert _is_data_root(tmp_path) is True


# ── data_cache helpers (no network) ──


def test_cache_dir_respects_xdg(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "mycache"))
    assert cache_dir() == tmp_path / "mycache" / "agent-toolkit"


def test_ensure_cached_data_offline_no_data_returns_none(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    assert ensure_cached_data(offline=True) is None


def test_ensure_cached_data_offline_with_existing_returns_path(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    c = tmp_path / "cache" / "agent-toolkit"
    (c / "profiles").mkdir(parents=True)
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    assert ensure_cached_data(offline=True) == c


def test_is_cache_current_roundtrip(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    from agent_toolkit import __version__

    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    c = cache_dir()
    c.mkdir(parents=True, exist_ok=True)
    (c / "cached_version.json").write_text(json.dumps({"version": __version__}))
    assert is_cache_current() is True
    (c / "cached_version.json").write_text(json.dumps({"version": "0.0.0-fake"}))
    assert is_cache_current() is False


def test_ensure_cached_data_no_network_on_offline(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """No urllib call when offline=True even if cache is stale."""
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    with mock.patch("urllib.request.urlopen") as mock_urlopen:
        result = ensure_cached_data(offline=True)
        mock_urlopen.assert_not_called()
        assert result is None


def test_prepare_package_data_script_lists_all_datasets() -> None:
    """prepare-package-data.sh must copy key datasets for wheel."""
    script = Path("scripts/prepare-package-data.sh").read_text(encoding="utf-8")
    for name in ["skills", "loops", "profiles", "mcp", "catalogs", "capabilities"]:
        assert name in script, f"{name} missing from prepare-package-data.sh"
