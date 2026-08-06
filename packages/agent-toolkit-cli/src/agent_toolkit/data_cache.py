"""GitHub Release data cache for lighter wheel installs."""

from __future__ import annotations

import json
import os
import urllib.request
from pathlib import Path

from agent_toolkit import __version__


def _xdg_cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))


def cache_dir() -> Path:
    return _xdg_cache_home() / "agent-toolkit"


CACHE_DIR = cache_dir()  # default at import; tests should patch cache_dir()
CACHE_VERSION_FILE = cache_dir() / "cached_version.json"
GITHUB_RELEASES_API = "https://api.github.com/repos/ulises-jeremias/agent-toolkit/releases/latest"


def cached_version() -> str | None:
    version_file = cache_dir() / "cached_version.json"
    if not version_file.is_file():
        return None
    try:
        data = json.loads(version_file.read_text())
        return str(data.get("version", "")) or None
    except (json.JSONDecodeError, OSError):
        return None


def is_cache_current() -> bool:
    cached = cached_version()
    return cached is not None and cached == __version__


def ensure_cached_data(*, offline: bool = False, force: bool = False) -> Path | None:
    """Ensure toolkit data exists in XDG cache. Returns cache path or None."""
    dest = cache_dir()
    dest.mkdir(parents=True, exist_ok=True)

    if not force and is_cache_current() and (dest / "profiles").is_dir():
        return dest

    if offline:
        if (dest / "profiles").is_dir():
            return dest
        return None

    try:
        req = urllib.request.Request(
            GITHUB_RELEASES_API,
            headers={"User-Agent": "agent-toolkit-data-cache/1"},
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            release = json.loads(resp.read())
        tag = str(release.get("tag_name", __version__)).lstrip("v")
        tarball_url = release.get("tarball_url")
        if not tarball_url:
            return None
        version_file = dest / "cached_version.json"
        version_file.write_text(
            json.dumps({"version": tag, "source": "github-release", "url": tarball_url}, indent=2)
            + "\n"
        )
        return dest
    except Exception:
        return dest if (dest / "profiles").is_dir() else None


def refresh_cache() -> bool:
    """Force refresh cache metadata from GitHub Releases."""
    result = ensure_cached_data(force=True)
    return result is not None
