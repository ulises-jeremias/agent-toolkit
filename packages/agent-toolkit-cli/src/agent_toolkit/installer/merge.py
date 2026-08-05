"""Non-destructive JSON config merge for profile installs."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def merge_json_objects(
    base: dict[str, Any],
    overlay: dict[str, Any],
    *,
    prefix: str = "",
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Merge overlay into base without overwriting existing keys.

    Returns the merged dict and a list of ownership patches (JSON-pointer-like paths).
    """
    merged = dict(base)
    patches: list[dict[str, Any]] = []

    for key, value in overlay.items():
        path = f"{prefix}/{key}" if prefix else f"/{key}"
        if key not in merged:
            merged[key] = value
            patches.append({"op": "add", "path": path, "value": value})
            continue
        if isinstance(merged[key], dict) and isinstance(value, dict):
            nested, nested_patches = merge_json_objects(merged[key], value, prefix=path)
            if nested != merged[key]:
                merged[key] = nested
                patches.extend(nested_patches)

    return merged, patches


def merge_json_file(
    src: Path,
    dst: Path,
    *,
    force: bool = False,
) -> tuple[dict[str, Any] | None, list[dict[str, Any]], str]:
    """Merge src JSON into dst when dst exists; otherwise return src content.

    Returns (result_dict, patches, ownership) where ownership is ``created`` or ``merged``.
    """
    overlay = json.loads(src.read_text(encoding="utf-8"))
    if not dst.is_file() or force:
        return overlay, [], "created"

    base = json.loads(dst.read_text(encoding="utf-8"))
    if not isinstance(base, dict) or not isinstance(overlay, dict):
        return None, [], "skipped"

    merged, patches = merge_json_objects(base, overlay)
    if merged == base:
        return merged, [], "unchanged"
    return merged, patches, "merged"
