"""Hatch hook: platform-tag wheels that contain the native V binary (ADR-021)."""

from __future__ import annotations

from pathlib import Path

from hatchling.builders.hooks.plugin.interface import BuildHookInterface


class CustomBuildHook(BuildHookInterface):
    def initialize(self, version: str, build_data: dict) -> None:  # type: ignore[override]
        pkg_bin = Path(self.root) / "src" / "agent_toolkit" / "bin"
        has_native = False
        if pkg_bin.is_dir():
            for p in pkg_bin.iterdir():
                if p.is_file() and p.name.startswith("agent-toolkit") and p.name != ".gitkeep":
                    has_native = True
                    break
        if has_native:
            build_data["pure_python"] = False
            build_data["infer_tag"] = True
