"""Pack YAML loading and loop override application for `loop run --pack`."""

from __future__ import annotations

from pathlib import Path
from typing import Any


def resolve_pack_path(pack_arg: str | Path, workspace: Path) -> Path | None:
    """Resolve a pack file path relative to workspace or as absolute."""
    candidate = Path(pack_arg).expanduser()
    if candidate.is_absolute():
        return candidate if candidate.is_file() else None
    for rel in (str(pack_arg), f"packs/{pack_arg}", f"packs/{pack_arg}.yaml"):
        path = workspace / rel
        if path.is_file():
            return path
    return None


def load_pack(pack_path: Path) -> dict[str, Any]:
    """Load pack YAML (PyYAML when available, else minimal parser)."""
    from agent_toolkit.loop.runner import _parse_simple_yaml

    text = pack_path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore

        loaded = yaml.safe_load(text)
        return loaded if isinstance(loaded, dict) else {}
    except ImportError:
        return _parse_simple_yaml(text)


def loop_pack_entry(pack_data: dict[str, Any], loop_name: str) -> dict[str, Any]:
    """Return the pack config block for a loop name, or empty dict."""
    loops = pack_data.get("loops")
    if not isinstance(loops, dict):
        return {}
    entry = loops.get(loop_name)
    return entry if isinstance(entry, dict) else {}


def apply_loop_pack_overrides(
    meta: dict[str, Any], pack_data: dict[str, Any], loop_name: str
) -> dict[str, Any]:
    """Merge pack loop settings (enabled, cadence, budget, tier, …) into loop meta."""
    entry = loop_pack_entry(pack_data, loop_name)
    if not entry:
        return dict(meta)

    merged = dict(meta)
    for key in ("enabled", "cadence", "tier", "verifier", "goal"):
        if key in entry and entry[key] is not None:
            merged[key] = entry[key]

    if "budget" in entry and isinstance(entry["budget"], dict):
        base_budget = dict(merged.get("budget") or {})
        base_budget.update(entry["budget"])
        merged["budget"] = base_budget

    if entry.get("enabled") is False:
        merged["enabled"] = False

    return merged
