"""Download and cache agent-toolkit capability data from GitHub Releases."""
from __future__ import annotations

import json
import os
import shutil
import tarfile
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

from agent_toolkit import __version__

GITHUB_REPO = "ulises-jeremias/agent-toolkit"
DATA_SUBDIRS = ("skills", "agents", "loops", "profiles", "mcp", "catalogs")
VERSION_FILE = ".version"


def data_cache_dir() -> Path:
    """XDG data directory for downloaded capability trees."""
    xdg = os.environ.get("XDG_DATA_HOME", "").strip()
    base = Path(xdg).expanduser() if xdg else Path.home() / ".local" / "share"
    return base / "agent-toolkit" / "data"


def is_valid_data_root(path: Path) -> bool:
    return (
        path.is_dir()
        and (path / "profiles").is_dir()
        and ((path / "skills").is_dir() or (path / "loops").is_dir())
    )


def cached_version() -> str | None:
    vf = data_cache_dir() / VERSION_FILE
    if vf.is_file():
        return vf.read_text(encoding="utf-8").strip() or None
    return None


def _release_tag(version: str) -> str:
    return version if version.startswith("v") else f"v{version}"


def _fetch_latest_release_tag() -> str:
    url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    tag = payload.get("tag_name", "")
    if not tag:
        raise RuntimeError("GitHub Releases API returned no tag_name")
    return tag


def _copy_data_tree(src_root: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for name in DATA_SUBDIRS:
        src = src_root / name
        if not src.is_dir():
            continue
        dst = dest / name
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst)


def download_data(
    version: str | None = None,
    *,
    force: bool = False,
    quiet: bool = False,
) -> Path:
    """Download capability data from a GitHub Release source tarball into the cache."""
    cache = data_cache_dir()
    target_version = version or cached_version() or _release_tag(__version__)

    if not force and is_valid_data_root(cache):
        current = cached_version()
        if current and current.lstrip("v") == target_version.lstrip("v"):
            return cache

    tag = _release_tag(target_version)
    url = f"https://github.com/{GITHUB_REPO}/archive/refs/tags/{tag}.tar.gz"
    if not quiet:
        print(f"[agent-toolkit] Downloading capability data ({tag})…", flush=True)

    with tempfile.TemporaryDirectory(prefix="agent-toolkit-data-") as tmp:
        tarball = Path(tmp) / "source.tar.gz"
        try:
            urllib.request.urlretrieve(url, tarball)
        except urllib.error.HTTPError as exc:
            raise RuntimeError(
                f"Failed to download {url} (HTTP {exc.code}). "
                "Set AGENT_TOOLKIT_ROOT to a checkout or run with bundled wheel data."
            ) from exc

        extract_dir = Path(tmp) / "extract"
        extract_dir.mkdir()
        with tarfile.open(tarball, "r:gz") as tar:
            tar.extractall(extract_dir, filter="data")

        roots = [p for p in extract_dir.iterdir() if p.is_dir()]
        if not roots:
            raise RuntimeError(f"No top-level directory in release tarball for {tag}")
        src_root = roots[0]
        if not is_valid_data_root(src_root):
            raise RuntimeError(f"Release {tag} tarball does not contain capability data")

        if cache.exists():
            shutil.rmtree(cache)
        _copy_data_tree(src_root, cache)
        (cache / VERSION_FILE).write_text(tag.lstrip("v"), encoding="utf-8")

    if not quiet:
        print(f"[agent-toolkit] Cached data at {cache}", flush=True)
    return cache


def ensure_data(
    *,
    offline: bool = False,
    force: bool = False,
    version: str | None = None,
) -> Path | None:
    """Return cached/downloaded data root, or None when offline and cache is missing."""
    cache = data_cache_dir()
    if is_valid_data_root(cache) and not force:
        cv = cached_version()
        pin = version or __version__
        if cv is None or cv.lstrip("v") == pin.lstrip("v"):
            return cache

    if offline:
        return cache if is_valid_data_root(cache) else None

    return download_data(version, force=force)
