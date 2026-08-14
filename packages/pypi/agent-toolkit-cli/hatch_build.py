"""Hatch hook: platform-tag wheels that contain the native V binary (ADR-021).

Linux wheels MUST use PEP 600 manylinux tags. PyPI rejected v1.11.0 with
unsupported platform tag ``linux_x86_64`` (raw ``sysconfig.get_platform()``).

The GitHub Release linux ELF needs GLIBC_2.38, so the honest tags are
``manylinux_2_38_x86_64`` and ``manylinux_2_38_aarch64``. Do not claim
manylinux_2_17 / 2_35.

When CI packs Release assets on a Linux runner (``scripts/pack_pypi.vsh``),
set ``AGENT_TOOLKIT_WHEEL_TAG`` so the tag matches the bundled binary rather
than the builder OS.
"""

from __future__ import annotations

import os
import sysconfig
from pathlib import Path

try:
    from hatchling.builders.hooks.plugin.interface import BuildHookInterface
except ImportError:  # tests import tag helpers without hatchling installed

    class BuildHookInterface:  # type: ignore[no-redef]
        pass


# sysconfig.get_platform() variants → PEP 600 manylinux (glibc 2.38).
_LINUX_TAGS = {
    "linux-x86_64": "manylinux_2_38_x86_64",
    "linux_x86_64": "manylinux_2_38_x86_64",
    "linux-aarch64": "manylinux_2_38_aarch64",
    "linux_aarch64": "manylinux_2_38_aarch64",
    "linux-arm64": "manylinux_2_38_aarch64",
    "linux_arm64": "manylinux_2_38_aarch64",
}


def wheel_platform_tag(
    *,
    override: str | None = None,
    sysconfig_platform: str | None = None,
) -> str:
    """Return the PEP 425/600 platform tag for a wheel that embeds the V binary."""
    if override:
        tag = override.strip()
        if tag:
            return tag
    plat = sysconfig_platform if sysconfig_platform is not None else sysconfig.get_platform()
    if plat in _LINUX_TAGS:
        return _LINUX_TAGS[plat]
    dashed = plat.replace("_", "-")
    if dashed in _LINUX_TAGS:
        return _LINUX_TAGS[dashed]
    underscored = plat.replace("-", "_")
    if underscored in _LINUX_TAGS:
        return _LINUX_TAGS[underscored]
    return plat.replace("-", "_").replace(".", "_")


def has_native_binary(root: Path) -> bool:
    pkg_bin = root / "src" / "agent_toolkit" / "bin"
    if not pkg_bin.is_dir():
        return False
    for p in pkg_bin.iterdir():
        if p.is_file() and p.name.startswith("agent-toolkit") and p.name != ".gitkeep":
            return True
    return False


class CustomBuildHook(BuildHookInterface):
    def initialize(self, version: str, build_data: dict) -> None:
        # Editable installs and sdist→wheel (macOS/Windows CI) have no bundled ELF.
        # Product scripts still point at the launcher (exit 127), not agent-toolkit-py.
        if version == "editable" or not has_native_binary(Path(self.root)):
            return
        # Binary is CPython-ABI agnostic; cp311-cp311-* wheels fail on other Pythons.
        build_data["pure_python"] = False
        build_data["infer_tag"] = False
        build_data["tag"] = "py3-none-" + wheel_platform_tag(
            override=os.environ.get("AGENT_TOOLKIT_WHEEL_TAG"),
        )
