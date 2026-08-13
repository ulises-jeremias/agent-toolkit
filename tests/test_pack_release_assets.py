"""pack_release_assets.py — SHA256SUMS + ADR-022 manifest (#530)."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import jsonschema

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location(
    "pack_release_assets", ROOT / "scripts" / "pack_release_assets.py"
)
_pack = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_pack)
pack_main = _pack.main


def test_pack_release_assets_manifest_and_sums(tmp_path: Path, monkeypatch) -> None:
    src = tmp_path / "binaries"
    src.mkdir()
    (src / "agent-toolkit-linux-x86_64").write_bytes(b"\x7fELF" + b"x" * 200)
    (src / "agent-toolkit-macos-arm64").write_bytes(b"mach" + b"y" * 200)
    license_file = tmp_path / "LICENSE"
    license_file.write_text("MIT\n")
    out = tmp_path / "out"
    monkeypatch.setenv("RELEASE_BIN_DIR", str(src))
    monkeypatch.setenv("RELEASE_OUT_DIR", str(out))
    monkeypatch.setenv("RELEASE_VERSION", "1.10.0")
    monkeypatch.setenv("RELEASE_TAG", "v1.10.0")
    monkeypatch.setenv("LICENSE_PATH", str(license_file))
    assert pack_main() == 0
    assert (out / "SHA256SUMS").is_file()
    sums = (out / "SHA256SUMS").read_text()
    assert "agent-toolkit-linux-x86_64" in sums
    manifest = json.loads((out / "manifest.json").read_text())
    schema = json.loads((ROOT / "schemas" / "release-manifest.schema.json").read_text())
    jsonschema.Draft202012Validator(schema).validate(manifest)
    kinds = {a["kind"] for a in manifest["assets"]}
    assert kinds == {"binary", "archive"}
    assert (out / "agent-toolkit-1.10.0-linux-x86_64.tar.gz").is_file()
