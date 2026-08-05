"""Shared toolkit path resolution — works in both editable and wheel installs."""
from __future__ import annotations

import os
from pathlib import Path


def _offline_mode() -> bool:
    return os.environ.get("AGENT_TOOLKIT_OFFLINE", "").strip().lower() in ("1", "true", "yes")


def _bundled_data_paths() -> list[Path]:
    paths: list[Path] = []
    try:
        import importlib.resources as _ir

        paths.append(Path(str(_ir.files("agent_toolkit").joinpath("data"))))
    except (ImportError, TypeError, ModuleNotFoundError, FileNotFoundError):
        pass

    pkg_dir = Path(__file__).resolve().parent
    paths.append(pkg_dir / "data")
    return paths


def _is_data_root(path: Path) -> bool:
    return path.is_dir() and (path / "profiles").is_dir()


def find_toolkit_root(*, offline: bool | None = None) -> Path:
    """
    Locate the agent-toolkit root directory (where skills/, loops/, profiles/ live).

    Resolution order:
    1. AGENT_TOOLKIT_ROOT / AI_WORKSPACE env var (user override)
    2. importlib.resources / package data (wheel install)
    3. XDG cache (~/.local/share/agent-toolkit/data) or first-run GitHub download
    4. Walk up from module file (editable install)
    5. CWD fallback

    Raises EnvironmentError if no root can be found with required subdirs.
    """
    offline = _offline_mode() if offline is None else offline

    for env in ("AGENT_TOOLKIT_ROOT", "AI_WORKSPACE"):
        val = os.environ.get(env, "").strip()
        if val:
            p = Path(val)
            if (p / "skills").is_dir() or (p / "loops").is_dir() or _is_data_root(p):
                return p

    for data_path in _bundled_data_paths():
        if _is_data_root(data_path):
            return data_path

    from agent_toolkit.data_sync import data_cache_dir, ensure_data, is_valid_data_root

    cache = data_cache_dir()
    if is_valid_data_root(cache):
        return cache

    if not offline:
        try:
            downloaded = ensure_data(offline=False)
            if downloaded and is_valid_data_root(downloaded):
                return downloaded
        except RuntimeError as exc:
            raise EnvironmentError(str(exc)) from exc

    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "skills").is_dir() and (parent / "loops").is_dir():
            return parent

    cwd = Path.cwd()
    if (cwd / "skills").is_dir() or (cwd / "loops").is_dir():
        return cwd

    hint = (
        "Set AGENT_TOOLKIT_ROOT to your agent-toolkit checkout, "
        "or run without --offline to download data on first use."
    )
    if offline:
        hint = (
            "Offline mode: bundled/cache data missing. "
            "Install the full wheel or populate ~/.local/share/agent-toolkit/data."
        )
    raise EnvironmentError(f"Cannot locate agent-toolkit data directory.\n{hint}")


_root: Path | None = None


def reset_toolkit_root() -> None:
    """Clear cached toolkit root (e.g. after toggling offline mode)."""
    global _root
    _root = None


def toolkit_root(*, offline: bool | None = None) -> Path:
    """Cached toolkit root."""
    global _root
    if _root is None or offline is not None:
        resolved = find_toolkit_root(offline=offline)
        if offline is None:
            _root = resolved
        return resolved
    return _root
