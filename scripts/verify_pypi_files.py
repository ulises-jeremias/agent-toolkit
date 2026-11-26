#!/usr/bin/env python3
"""Compare a local PyPI dist directory with the complete published file set."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from packaging.version import InvalidVersion, Version


def expected_files(directory: Path) -> dict[str, str]:
    if not directory.is_dir():
        raise ValueError(f"distribution directory does not exist: {directory}")
    files = sorted(path for path in directory.iterdir() if path.is_file())
    if not files:
        raise ValueError("distribution directory is empty")
    return {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in files}


def verify_pypi_files(directory: Path, metadata: dict[str, Any], *, version: str) -> None:
    info = metadata.get("info")
    if not isinstance(info, dict) or info.get("name") != "agent-toolkit-cli":
        raise ValueError("PyPI metadata project name does not match agent-toolkit-cli")
    try:
        published_version = Version(info.get("version", ""))
        requested_version = Version(version)
    except InvalidVersion as error:
        raise ValueError("PyPI metadata version is invalid") from error
    if published_version != requested_version:
        raise ValueError("PyPI metadata version does not match the requested version")
    urls = metadata.get("urls")
    if not isinstance(urls, list) or not urls:
        raise ValueError("PyPI metadata contains no distribution files")

    published: dict[str, str] = {}
    for entry in urls:
        if not isinstance(entry, dict):
            raise ValueError("invalid PyPI file entry")
        filename = entry.get("filename")
        digests = entry.get("digests")
        if not isinstance(digests, dict):
            raise ValueError(f"missing or invalid PyPI digests for {entry.get('filename', 'unknown file')}")
        digest = digests.get("sha256")
        if not isinstance(filename, str) or not re.fullmatch(r"[A-Za-z0-9_.+-]+", filename):
            raise ValueError("invalid PyPI filename")
        if filename in published:
            raise ValueError(f"duplicate PyPI file: {filename}")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError(f"missing or invalid PyPI SHA-256 for {filename}")
        published[filename] = digest

    local = expected_files(directory)
    if set(published) != set(local):
        missing = sorted(set(local) - set(published))
        extra = sorted(set(published) - set(local))
        raise ValueError(f"PyPI file set differs (missing={missing}, extra={extra})")
    mismatched = sorted(name for name in local if local[name] != published[name])
    if mismatched:
        raise ValueError(f"PyPI SHA-256 differs for: {mismatched}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dist", type=Path)
    parser.add_argument("metadata", type=Path)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    try:
        metadata = json.loads(args.metadata.read_text(encoding="utf-8"))
        verify_pypi_files(args.dist, metadata, version=args.version)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        parser.error(str(error))
    print(f"Verified PyPI files and SHA-256 digests for {args.version}")


if __name__ == "__main__":
    main()
