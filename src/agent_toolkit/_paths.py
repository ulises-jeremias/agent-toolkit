"""Shared toolkit path resolution — works in both editable and wheel installs."""
from __future__ import annotations
import os
from pathlib import Path


def find_toolkit_root() -> Path:
    """
    Locate the agent-toolkit root directory (where skills/, loops/, profiles/ live).

    Resolution order:
    1. AGENT_TOOLKIT_ROOT env var (user override)
    2. AI_WORKSPACE env var (ai-workspace compat)
    3. importlib.resources data (wheel install — data packed into the wheel)
    4. Walk up from module file to find profiles/ (editable install)
    5. CWD fallback

    Raises EnvironmentError if no root can be found with required subdirs.
    """
    # 1. Explicit env override
    for env in ("AGENT_TOOLKIT_ROOT", "AI_WORKSPACE"):
        val = os.environ.get(env, "").strip()
        if val:
            p = Path(val)
            if (p / "skills").is_dir() or (p / "loops").is_dir():
                return p

    # 2. Importlib resources (wheel installs pack data alongside the package)
    try:
        import importlib.resources as _ir
        import agent_toolkit.data as _data_pkg  # noqa: F401
        data_path = Path(str(_ir.files("agent_toolkit.data")))
        if data_path.is_dir():
            return data_path
    except (ImportError, TypeError, ModuleNotFoundError):
        pass

    # 3. Walk up from this file (editable install)
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "skills").is_dir() and (parent / "loops").is_dir():
            return parent

    # 4. CWD
    cwd = Path.cwd()
    if (cwd / "skills").is_dir() or (cwd / "loops").is_dir():
        return cwd

    raise EnvironmentError(
        "Cannot locate agent-toolkit data directory.\n"
        "Set AGENT_TOOLKIT_ROOT to your agent-toolkit checkout or install root."
    )


# Lazy singleton
_root: Path | None = None


def toolkit_root() -> Path:
    """Cached toolkit root."""
    global _root
    if _root is None:
        _root = find_toolkit_root()
    return _root
