"""PyPI wheel tags: manylinux_2_38, never raw linux_x86_64 (ADR-021)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

PKG = Path(__file__).resolve().parents[1] / "packages/pypi/agent-toolkit-cli"
sys.path.insert(0, str(PKG))

from hatch_build import CustomBuildHook, wheel_platform_tag  # noqa: E402


@pytest.mark.parametrize(
    ("plat", "expected"),
    [
        ("linux-x86_64", "manylinux_2_38_x86_64"),
        ("linux_x86_64", "manylinux_2_38_x86_64"),
        ("linux-aarch64", "manylinux_2_38_aarch64"),
        ("linux-arm64", "manylinux_2_38_aarch64"),
        ("macosx-15.0-arm64", "macosx_15_0_arm64"),
        ("win-amd64", "win_amd64"),
    ],
)
def test_wheel_platform_tag_maps_linux_to_manylinux_2_38(plat: str, expected: str) -> None:
    assert wheel_platform_tag(sysconfig_platform=plat) == expected


def test_never_emits_raw_linux_x86_64() -> None:
    tag = wheel_platform_tag(sysconfig_platform="linux-x86_64")
    assert tag == "manylinux_2_38_x86_64"
    assert tag != "linux_x86_64"
    assert "2_17" not in tag
    assert "2_35" not in tag


def test_override_wins() -> None:
    assert (
        wheel_platform_tag(
            override="manylinux_2_38_aarch64",
            sysconfig_platform="linux-x86_64",
        )
        == "manylinux_2_38_aarch64"
    )


def test_platforms_json_linux_tags_are_honest_2_38() -> None:
    import json

    specs = json.loads((PKG / "platforms.json").read_text())
    linux = [s for s in specs if s["floating"].startswith("agent-toolkit-linux-")]
    assert linux
    for spec in linux:
        assert spec["wheel_tag"].startswith("manylinux_2_38_"), spec
        assert "linux_x86_64" not in spec["wheel_tag"]


def test_hook_allows_sdist_wheel_without_native_binary(tmp_path: Path) -> None:
    """pip install sdist on macOS/Windows builds a wheel with no bundled ELF."""
    hook = CustomBuildHook.__new__(CustomBuildHook)
    hook.root = str(tmp_path)
    hook.target_name = "wheel"
    build_data: dict = {}
    hook.initialize("1.11.0", build_data)
    assert "tag" not in build_data
