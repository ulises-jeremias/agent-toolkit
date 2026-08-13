"""Hatch hook: platform-tag wheels that contain the native V binary (ADR-021)."""

from __future__ import annotations

import sysconfig
from pathlib import Path

from hatchling.builders.hooks.plugin.interface import BuildHookInterface


def _platform_tag() -> str:
    # linux-x86_64 → linux_x86_64; macosx-15.0-arm64 → macosx_15_0_arm64
    return sysconfig.get_platform().replace("-", "_").replace(".", "_")


class CustomBuildHook(BuildHookInterface):
    def initialize(self, version: str, build_data: dict) -> None:
        pkg_bin = Path(self.root) / "src" / "agent_toolkit" / "bin"
        has_native = False
        if pkg_bin.is_dir():
            for p in pkg_bin.iterdir():
                if p.is_file() and p.name.startswith("agent-toolkit") and p.name != ".gitkeep":
                    has_native = True
                    break
        if has_native:
            # Binary is CPython-ABI agnostic; cp311-cp311-* wheels fail on other Pythons.
            build_data["pure_python"] = False
            build_data["infer_tag"] = False
            build_data["tag"] = f"py3-none-{_platform_tag()}"
