"""Load declarative compile-target registry from schemas/targets-registry.yaml."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

from agent_toolkit._paths import toolkit_root


@dataclass(frozen=True)
class TargetSpec:
    id: str
    adapter_module: str
    adapter_class: str
    aliases: tuple[str, ...]
    build: bool
    diff: bool
    release: bool


def _repo_root() -> Path:
    root = toolkit_root()
    if (root / "schemas" / "targets-registry.yaml").is_file():
        return root
    if (root.parent / "schemas" / "targets-registry.yaml").is_file():
        return root.parent
    return root


def _parse_target(raw: dict[str, Any]) -> TargetSpec:
    commands = raw.get("commands") or {}
    return TargetSpec(
        id=str(raw["id"]),
        adapter_module=str(raw["adapter_module"]),
        adapter_class=str(raw["adapter_class"]),
        aliases=tuple(str(a) for a in (raw.get("aliases") or [])),
        build=bool(commands.get("build", True)),
        diff=bool(commands.get("diff", False)),
        release=bool(commands.get("release", True)),
    )


def load_target_registry(repo_root: Path | None = None) -> list[TargetSpec]:
    root = repo_root or _repo_root()
    path = root / "schemas" / "targets-registry.yaml"
    if not path.is_file():
        raise FileNotFoundError(f"Target registry not found: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return [_parse_target(entry) for entry in data.get("targets") or []]


def resolve_target_id(target_id: str, registry: list[TargetSpec] | None = None) -> str:
    """Map alias (e.g. gemini) to canonical id (gemini-cli)."""
    specs = registry or load_target_registry()
    for spec in specs:
        if target_id == spec.id or target_id in spec.aliases:
            return spec.id
    return target_id


def target_ids_for(command: str, registry: list[TargetSpec] | None = None) -> list[str]:
    specs = registry or load_target_registry()
    attr = {"build": "build", "diff": "diff", "release": "release"}[command]
    return [spec.id for spec in specs if getattr(spec, attr)]


def adapter_import_path(spec: TargetSpec) -> str:
    return f"{spec.adapter_module}.{spec.adapter_class}"


def registry_by_id(registry: list[TargetSpec] | None = None) -> dict[str, TargetSpec]:
    specs = registry or load_target_registry()
    out: dict[str, TargetSpec] = {}
    for spec in specs:
        out[spec.id] = spec
        for alias in spec.aliases:
            out[alias] = spec
    return out
