"""pack_pypi.py maps GitHub Release assets to PEP 600 wheel tags."""

from __future__ import annotations

import importlib.util
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "scripts/pack_pypi.py"


def _load():
    spec = importlib.util.spec_from_file_location("pack_pypi", SCRIPT)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_platforms_json_linux_is_manylinux_2_38():
    mod = _load()
    plats = {p["floating"]: p for p in mod.load_platforms()}
    assert plats["agent-toolkit-linux-x86_64"]["wheel_tag"] == "manylinux_2_38_x86_64"
    assert plats["agent-toolkit-linux-arm64"]["wheel_tag"] == "manylinux_2_38_aarch64"
    assert plats["agent-toolkit-windows-x86_64.exe"]["wheel_tag"] == "win_amd64"
    assert plats["agent-toolkit-macos-arm64"]["bin"] == "agent-toolkit"


def test_write_native_bin_copies_and_clears(tmp_path: Path, monkeypatch):
    mod = _load()
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    monkeypatch.setattr(mod, "BIN_DIR", bin_dir)
    src = tmp_path / "elf"
    src.write_bytes(b"fake-elf")
    dest = mod.write_native_bin(src, "agent-toolkit")
    assert dest.read_bytes() == b"fake-elf"
    leftover = bin_dir / "agent-toolkit.exe"
    leftover.write_bytes(b"old")
    src2 = tmp_path / "elf2"
    src2.write_bytes(b"new")
    dest2 = mod.write_native_bin(src2, "agent-toolkit")
    assert dest2.read_bytes() == b"new"
    assert not leftover.exists()
