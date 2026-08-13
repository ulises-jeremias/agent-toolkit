#!/usr/bin/env python3
"""Pack ADR-018 floating binaries + versioned archives, SHA256SUMS, and manifest.json (#530 / ADR-022)."""

from __future__ import annotations

import hashlib
import json
import os
import tarfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

FLOATING = (
    ("agent-toolkit-linux-x86_64", "linux", "x86_64", "gnu", "tar"),
    ("agent-toolkit-linux-arm64", "linux", "arm64", "gnu", "tar"),
    ("agent-toolkit-macos-arm64", "macos", "arm64", None, "tar"),
    ("agent-toolkit-macos-x86_64", "macos", "x86_64", None, "tar"),
    ("agent-toolkit-windows-x86_64.exe", "windows", "x86_64", None, "zip"),
)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    src = Path(os.environ.get("RELEASE_BIN_DIR", "binaries"))
    out = Path(os.environ.get("RELEASE_OUT_DIR", "release-assets"))
    version = os.environ["RELEASE_VERSION"]  # semver without v
    tag = os.environ.get("RELEASE_TAG", f"v{version}")
    license_path = Path(os.environ.get("LICENSE_PATH", "LICENSE"))
    out.mkdir(parents=True, exist_ok=True)

    assets: list[dict] = []
    packed: list[Path] = []

    for floating, os_name, arch, libc, archive_kind in FLOATING:
        src_bin = src / floating
        if not src_bin.is_file():
            # Windows job may upload without .exe suffix; accept that alias.
            alt = src / floating.removesuffix(".exe")
            if alt.is_file():
                src_bin = alt
            else:
                print(f"skip missing {floating}")
                continue
        dest_float = out / floating
        dest_float.write_bytes(src_bin.read_bytes())
        dest_float.chmod(0o755)
        packed.append(dest_float)
        inner = "agent-toolkit.exe" if os_name == "windows" else "agent-toolkit"
        if archive_kind == "zip":
            archive_name = f"agent-toolkit-{version}-windows-{arch}.zip"
            archive_path = out / archive_name
            with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
                zf.write(dest_float, arcname=inner)
                if license_path.is_file():
                    zf.write(license_path, arcname="LICENSE")
        else:
            archive_name = f"agent-toolkit-{version}-{os_name}-{arch}.tar.gz"
            archive_path = out / archive_name
            with tarfile.open(archive_path, "w:gz") as tf:
                tf.add(dest_float, arcname=inner)
                if license_path.is_file():
                    tf.add(license_path, arcname="LICENSE")
        packed.append(archive_path)

        base_url = f"https://github.com/ulises-jeremias/agent-toolkit/releases/download/{tag}"
        bin_entry = {
            "os": os_name,
            "arch": arch,
            "channel": "stable",
            "kind": "binary",
            "filename": floating,
            "sha256": sha256_file(dest_float),
            "url": f"{base_url}/{floating}",
        }
        if libc:
            bin_entry["libc"] = libc
        assets.append(bin_entry)
        arch_entry = {
            "os": os_name,
            "arch": arch,
            "channel": "stable",
            "kind": "archive",
            "filename": archive_name,
            "sha256": sha256_file(archive_path),
            "url": f"{base_url}/{archive_name}",
        }
        if libc:
            arch_entry["libc"] = libc
        assets.append(arch_entry)

    sums_path = out / "SHA256SUMS"
    lines = [f"{sha256_file(p)}  {p.name}\n" for p in sorted(packed, key=lambda x: x.name)]
    sums_path.write_text("".join(lines), encoding="utf-8")

    manifest = {
        "schemaVersion": 1,
        "name": "agent-toolkit",
        "version": version,
        "gitTag": tag,
        "channel": "stable",
        "releasedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "assets": assets,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"packed {len(list(out.iterdir()))} files in {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
