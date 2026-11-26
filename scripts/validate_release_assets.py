#!/usr/bin/env python3
"""Validate a packed release asset directory before package publication."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

EXPECTED = {
    "agent-toolkit-linux-x86_64",
    "agent-toolkit-linux-arm64",
    "agent-toolkit-macos-arm64",
    "agent-toolkit-macos-x86_64",
    "agent-toolkit-windows-x86_64.exe",
}


def validate_release_assets(directory: Path, *, version: str, tag: str, source_sha: str) -> None:
    manifest_path = directory / "manifest.json"
    sums_path = directory / "SHA256SUMS"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid release manifest: {error}") from error
    if manifest.get("version") != version or manifest.get("gitTag") != tag:
        raise ValueError("release manifest version/tag mismatch")
    if manifest.get("sourceSha") != source_sha:
        raise ValueError("release manifest source commit mismatch")
    if manifest.get("name") != "agent-toolkit" or manifest.get("schemaVersion") != 1:
        raise ValueError("unexpected release manifest identity")

    checksums: dict[str, str] = {}
    try:
        lines = sums_path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ValueError(f"cannot read SHA256SUMS: {error}") from error
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9._-]+)", line)
        if not match:
            raise ValueError(f"invalid checksum line: {line!r}")
        digest, name = match.groups()
        if name in checksums:
            raise ValueError(f"duplicate checksum entry: {name}")
        checksums[name] = digest

    if not EXPECTED.issubset(checksums):
        raise ValueError("SHA256SUMS does not cover every platform binary")
    for name, expected_digest in checksums.items():
        path = directory / name
        if not path.is_file():
            raise ValueError(f"release asset is missing: {name}")
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected_digest:
            raise ValueError(f"release asset checksum mismatch: {name}")

    manifest_assets = manifest.get("assets")
    if not isinstance(manifest_assets, list):
        raise ValueError("manifest assets must be an array")
    by_name = {entry.get("filename"): entry for entry in manifest_assets if isinstance(entry, dict)}
    if len(by_name) != len(manifest_assets) or set(by_name) != set(checksums):
        raise ValueError("manifest and SHA256SUMS asset sets differ")
    if not EXPECTED.issubset(by_name):
        raise ValueError("manifest does not describe every platform binary")
    for name, entry in by_name.items():
        if entry.get("sha256") != checksums[name]:
            raise ValueError(f"manifest checksum disagrees for {name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    validate_release_assets(
        args.directory,
        version=args.version,
        tag=args.tag,
        source_sha=args.source_sha,
    )
    print(f"Verified release assets for {args.tag} at {args.source_sha}")


if __name__ == "__main__":
    main()
