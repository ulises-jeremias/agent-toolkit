"""Thin PyPI launcher — replace this process with the bundled V binary (ADR-021 / #535).

No Python business logic. Product commands agent-toolkit and agent-toolkit-cli
hand off to the native binary.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

_BIN_DIR = Path(__file__).resolve().parent / "bin"
_NATIVE_NAMES = ("agent-toolkit.exe", "agent-toolkit")


def bundled_binary() -> Path | None:
    for name in _NATIVE_NAMES:
        cand = _BIN_DIR / name
        if cand.is_file():
            return cand
    return None


def bundled_data_root() -> Path | None:
    """Wheel layout: agent_toolkit/data/{skills,loops,profiles} next to this module."""
    cand = Path(__file__).resolve().parent / "data"
    if (cand / "skills").is_dir() or (cand / "loops").is_dir() or (cand / "profiles").is_dir():
        return cand
    return None


def resolve_native_bin() -> Path | None:
    env = os.environ.get("AGENT_TOOLKIT_BIN", "").strip()
    if env:
        p = Path(env)
        if p.is_file():
            return p
        return None
    bundled = bundled_binary()
    if bundled is not None:
        return bundled
    root = os.environ.get("AGENT_TOOLKIT_ROOT", "").strip()
    if root:
        for rel in ("build/agent-toolkit", "build/agent-toolkit-v", "build/agent-toolkit.exe"):
            cand = Path(root) / rel
            if cand.is_file():
                return cand
    return None


def run_native(bin_path: Path, rest: list[str]) -> None:
    data = bundled_data_root()
    if data is not None and not os.environ.get("AGENT_TOOLKIT_ROOT", "").strip():
        os.environ["AGENT_TOOLKIT_ROOT"] = str(data)
    argv = [str(bin_path), *rest]
    if os.name == "nt":
        proc = subprocess.run(argv, check=False)
        raise SystemExit(int(proc.returncode))
    os.execv(argv[0], argv)


def missing_binary_message() -> str:
    return (
        "agent-toolkit: native V binary not found (ADR-021).\n"
        "  Packaged wheels bundle the binary under agent_toolkit/bin/.\n"
        "  Dev: make build-cli, or set AGENT_TOOLKIT_BIN to that executable.\n"
        "  Quarantined Python fallback: agent-toolkit-py\n"
    )


def main(argv: list[str] | None = None) -> None:
    args = list(sys.argv if argv is None else argv)
    rest = args[1:] if len(args) > 1 else []
    bin_path = resolve_native_bin()
    if bin_path is None:
        sys.stderr.write(missing_binary_message())
        raise SystemExit(127)
    run_native(bin_path, rest)
