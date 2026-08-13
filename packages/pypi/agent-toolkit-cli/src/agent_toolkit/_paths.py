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

    # 2b. XDG cache (GitHub Release download on first run — see data_cache.py)
    if os.environ.get("AGENT_TOOLKIT_OFFLINE", "").strip() not in ("1", "true", "yes"):
        try:
            from agent_toolkit.data_cache import ensure_cached_data

            cached = ensure_cached_data(offline=False)
            if cached and (cached / "profiles").is_dir():
                return cached
        except Exception:
            pass
    else:
        cache_home = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
        cached_data = cache_home / "agent-toolkit"
        if (cached_data / "profiles").is_dir():
            return cached_data

    # 2c. Direct path relative to the package (uvx / pip installs)
    pkg_dir = Path(__file__).resolve().parent  # .../site-packages/agent_toolkit/
    data_dir = pkg_dir / "data"
    if data_dir.is_dir() and (data_dir / "profiles").is_dir():
        return data_dir

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


def find_workspace_root(*, override: str | None = None) -> Path | None:
    """Locate the user harness / AI workspace root (not toolkit package data).

    Resolution order (#207):
    1. Explicit override (CLI ``--workspace``)
    2. ``AGENT_TOOLKIT_WORKSPACE``
    3. ``HARNESS_DIR`` (agentic-harness compatibility)
    4. Walk up from CWD for ``AGENTS.md`` or ``knowledge/``
    """
    if override:
        p = Path(override).expanduser().resolve()
        return p if p.is_dir() else None

    for env in ("AGENT_TOOLKIT_WORKSPACE", "HARNESS_DIR"):
        val = os.environ.get(env, "").strip()
        if val:
            p = Path(val).expanduser().resolve()
            if p.is_dir():
                return p

    current = Path.cwd()
    for candidate in [current, *current.parents]:
        if (candidate / "AGENTS.md").exists() or (candidate / "knowledge").is_dir():
            return candidate

    return None
