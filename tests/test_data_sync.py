"""Tests for GitHub Release data download and cache resolution."""
from __future__ import annotations

import tarfile
from pathlib import Path
from unittest import mock

import pytest

from agent_toolkit import data_sync


def _make_fake_release_tarball(path: Path) -> None:
    root = path.parent / "agent-toolkit-9.9.9"
    (root / "profiles" / "cursor" / "rules").mkdir(parents=True)
    (root / "profiles" / "cursor" / "rules" / "assistant.mdc").write_text("rule")
    (root / "skills" / "core").mkdir(parents=True)
    (root / "skills" / "core" / "SKILL.md").write_text("skill")
    with tarfile.open(path, "w:gz") as tar:
        tar.add(root, arcname=root.name)


def test_is_valid_data_root(tmp_path: Path) -> None:
    assert not data_sync.is_valid_data_root(tmp_path)
    (tmp_path / "profiles").mkdir()
    (tmp_path / "skills").mkdir()
    assert data_sync.is_valid_data_root(tmp_path)


def test_download_data_extracts_to_cache(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cache = tmp_path / "cache"
    monkeypatch.setattr(data_sync, "data_cache_dir", lambda: cache)

    fake_tar = tmp_path / "release.tar.gz"
    _make_fake_release_tarball(fake_tar)

    def fake_urlretrieve(url: str, dest: str) -> None:
        Path(dest).write_bytes(fake_tar.read_bytes())

    monkeypatch.setattr(data_sync.urllib.request, "urlretrieve", fake_urlretrieve)

    out = data_sync.download_data("9.9.9", force=True, quiet=True)
    assert out == cache
    assert (cache / "profiles" / "cursor" / "rules" / "assistant.mdc").is_file()
    assert data_sync.cached_version() == "9.9.9"


def test_ensure_data_offline_without_cache(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cache = tmp_path / "cache"
    monkeypatch.setattr(data_sync, "data_cache_dir", lambda: cache)
    assert data_sync.ensure_data(offline=True) is None


def test_find_toolkit_root_uses_cache(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    from agent_toolkit import _paths

    cache = tmp_path / "cache"
    (cache / "profiles").mkdir(parents=True)
    (cache / "skills").mkdir()
    monkeypatch.setattr(data_sync, "data_cache_dir", lambda: cache)
    monkeypatch.setattr(data_sync, "is_valid_data_root", lambda p: p == cache)
    monkeypatch.setattr(_paths, "_bundled_data_paths", lambda: [])
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.delenv("AI_WORKSPACE", raising=False)
    monkeypatch.setenv("AGENT_TOOLKIT_OFFLINE", "1")
    _paths.reset_toolkit_root()
    assert _paths.find_toolkit_root(offline=True) == cache
