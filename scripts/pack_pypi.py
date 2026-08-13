#!/usr/bin/env python3
"""Build PyPI sdist + platform wheels from GitHub Release V binaries (ADR-021).

npm equivalent: pack_npm.py writes optionalDependency packages.
PyPI has no optionalDependencies — one project, many PEP 425/600 wheel tags.

Usage (after Release assets exist):

    export RELEASE_BIN_DIR=binaries
    export RELEASE_VERSION="$(tr -d '[:space:]' < VERSION)"  # optional
    python3 scripts/pack_pypi.py

Wheels land in dist/ (or $RELEASE_OUT_DIR). Linux tags are manylinux_2_38_*
because the v1.11.0 ELF needs GLIBC_2.38.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PKG = REPO / "packages/pypi/agent-toolkit-cli"
PLATFORMS_PATH = PKG / "platforms.json"
BIN_DIR = PKG / "src/agent_toolkit/bin"


def load_platforms() -> list[dict]:
    return json.loads(PLATFORMS_PATH.read_text())


def version() -> str:
    env = os.environ.get("RELEASE_VERSION", "").strip()
    if env:
        return env
    return (REPO / "VERSION").read_text().strip()


def bin_dir_from_env() -> Path:
    raw = os.environ.get("RELEASE_BIN_DIR", "binaries")
    p = Path(raw)
    return p if p.is_absolute() else REPO / p


def out_dir() -> Path:
    raw = os.environ.get("RELEASE_OUT_DIR", "dist")
    p = Path(raw)
    return p if p.is_absolute() else REPO / p


def clear_native_bin() -> None:
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    for p in BIN_DIR.iterdir():
        if p.name == ".gitkeep":
            continue
        if p.is_file():
            p.unlink()


def write_native_bin(src: Path, dest_name: str) -> Path:
    clear_native_bin()
    dest = BIN_DIR / dest_name
    shutil.copy2(src, dest)
    dest.chmod(0o755)
    return dest


def uv_build(kind: str, dest: Path, *, wheel_tag: str | None = None) -> None:
    env = os.environ.copy()
    if wheel_tag:
        env["AGENT_TOOLKIT_WHEEL_TAG"] = wheel_tag
    elif "AGENT_TOOLKIT_WHEEL_TAG" in env:
        del env["AGENT_TOOLKIT_WHEEL_TAG"]
    cmd = ["uv", "build", f"--{kind}", "--out-dir", str(dest), str(PKG)]
    subprocess.run(cmd, cwd=REPO, env=env, check=True)


def main() -> int:
    src_root = bin_dir_from_env()
    dest = out_dir()
    dest.mkdir(parents=True, exist_ok=True)
    ver = version()
    print(f"pack_pypi: version={ver} bin_dir={src_root} out={dest}")

    clear_native_bin()
    uv_build("sdist", dest)

    built = 0
    for spec in load_platforms():
        src = src_root / spec["floating"]
        if not src.is_file():
            print(f"skip {spec['floating']} (missing under {src_root})")
            continue
        write_native_bin(src, spec["bin"])
        uv_build("wheel", dest, wheel_tag=spec["wheel_tag"])
        built += 1
        print(f"wheel {spec['wheel_tag']} ← {spec['floating']}")

    clear_native_bin()
    if built == 0:
        print("pack_pypi: no platform binaries found; sdist only", file=sys.stderr)
        return 1
    print(f"pack_pypi: {built} wheel(s) + sdist in {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
