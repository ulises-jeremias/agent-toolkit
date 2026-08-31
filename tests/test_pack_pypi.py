"""pack_pypi.vsh maps GitHub Release assets to PEP 600 wheel tags."""

from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PLATFORMS = REPO / "packages/pypi/agent-toolkit-cli/platforms.json"


def test_platforms_json_linux_is_manylinux_2_38():
    plats = {p["floating"]: p for p in json.loads(PLATFORMS.read_text())}
    assert plats["agent-toolkit-linux-x86_64"]["wheel_tag"] == "manylinux_2_38_x86_64"
    assert plats["agent-toolkit-linux-arm64"]["wheel_tag"] == "manylinux_2_38_aarch64"
    assert plats["agent-toolkit-windows-x86_64.exe"]["wheel_tag"] == "win_amd64"
    assert plats["agent-toolkit-macos-arm64"]["bin"] == "agent-toolkit"
