#!/usr/bin/env python3
"""Copy GitHub Release V binaries into npm platform packages (ADR-025 / #536)."""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
META = REPO / "packages/npm/agent-toolkit-cli"
PLATFORMS_PATH = META / "platforms.json"


def load_platforms() -> list[dict]:
    return json.loads(PLATFORMS_PATH.read_text())


def version() -> str:
    return (REPO / "VERSION").read_text().strip()


def write_platform_package(spec: dict, ver: str, src_bin: Path | None) -> Path:
    pkg_dir = REPO / "packages/npm" / spec["npm"]
    bin_dir = pkg_dir / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    pkg = {
        "name": spec["npm"],
        "version": ver,
        "description": f"Native V binary for {spec['npm']} (optionalDependency of agent-toolkit-cli)",
        "license": "MIT",
        "os": [spec["os"]],
        "cpu": [spec["cpu"]],
        "files": ["README.md", f"bin/{spec['bin']}"],
        "homepage": "https://github.com/ulises-jeremias/agent-toolkit",
        "bugs": {
            "url": "https://github.com/ulises-jeremias/agent-toolkit/issues",
        },
        "repository": {
            "type": "git",
            "url": "git+https://github.com/ulises-jeremias/agent-toolkit.git",
            "directory": f"packages/npm/{spec['npm']}",
        },
        "publishConfig": {"access": "public"},
    }
    if spec.get("libc"):
        pkg["libc"] = [spec["libc"]]
    (pkg_dir / "package.json").write_text(json.dumps(pkg, indent=2) + "\n")
    dest = bin_dir / spec["bin"]
    if src_bin is not None and src_bin.is_file():
        shutil.copy2(src_bin, dest)
        dest.chmod(0o755)
        print(f"packed {spec['npm']} <- {src_bin.name}")
    else:
        print(f"skip binary for {spec['npm']} (missing {spec['floating']})")
    return pkg_dir


def sync_meta_version(ver: str) -> None:
    pkg_path = META / "package.json"
    pkg = json.loads(pkg_path.read_text())
    pkg["version"] = ver
    opts = {spec["npm"]: ver for spec in load_platforms()}
    pkg["optionalDependencies"] = opts
    pkg_path.write_text(json.dumps(pkg, indent=2) + "\n")


def main() -> int:
    src = Path(os.environ.get("RELEASE_BIN_DIR", "binaries"))
    ver = os.environ.get("RELEASE_VERSION", version())
    sync_meta_version(ver)
    packed = 0
    for spec in load_platforms():
        src_bin = src / spec["floating"]
        if not src_bin.is_file():
            alt = src / spec["floating"].removesuffix(".exe")
            src_bin = alt if alt.is_file() else src_bin
        write_platform_package(spec, ver, src_bin if src_bin.is_file() else None)
        if (REPO / "packages/npm" / spec["npm"] / "bin" / spec["bin"]).is_file():
            packed += 1
    print(f"npm platform packages with binaries: {packed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
