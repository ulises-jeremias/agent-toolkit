"""Load declarative compile-target registry from capabilities/targets/registry.yaml."""
from __future__ import annotations

import importlib
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

from agent_toolkit._paths import toolkit_root


@dataclass(frozen=True)
class TargetSpec:
    id: str
    adapter: str
    aliases: tuple[str, ...]
    build: bool
    diff: bool
    release: bool


_REGISTRY_REL_PATHS = (
    Path("capabilities/targets/registry.yaml"),
    Path("schemas/targets-registry.yaml"),
)


def _repo_root(repo_root: Path | None = None) -> Path:
    if repo_root is not None:
        return repo_root
    root = toolkit_root()
    for rel in _REGISTRY_REL_PATHS:
        if (root / rel).is_file():
            return root
        if (root.parent / rel).is_file():
            return root.parent
    return root


def _registry_path(repo_root: Path) -> Path:
    for rel in _REGISTRY_REL_PATHS:
        path = repo_root / rel
        if path.is_file():
            return path
    raise FileNotFoundError(
        "Target registry not found. Expected one of: "
        + ", ".join(str(p) for p in _REGISTRY_REL_PATHS)
    )


def _parse_target(raw: dict[str, Any]) -> TargetSpec:
    commands = raw.get("commands") or {}
    adapter = raw.get("adapter")
    if not adapter and raw.get("adapter_module") and raw.get("adapter_class"):
        adapter = f"{raw['adapter_module']}.{raw['adapter_class']}"
    if not adapter:
        raise ValueError(f"Target {raw.get('id')!r} missing adapter path")
    return TargetSpec(
        id=str(raw["id"]),
        adapter=str(adapter),
        aliases=tuple(str(a) for a in (raw.get("aliases") or [])),
        build=bool(commands.get("build", True)),
        diff=bool(commands.get("diff", False)),
        release=bool(commands.get("release", True)),
    )


def load_target_registry(repo_root: Path | None = None) -> list[TargetSpec]:
    root = _repo_root(repo_root)
    data = yaml.safe_load(_registry_path(root).read_text(encoding="utf-8")) or {}
    return [_parse_target(entry) for entry in data.get("targets") or []]


def registry_by_id(registry: list[TargetSpec] | None = None) -> dict[str, TargetSpec]:
    specs = registry or load_target_registry()
    out: dict[str, TargetSpec] = {}
    for spec in specs:
        out[spec.id] = spec
        for alias in spec.aliases:
            out[alias] = spec
    return out


def resolve_target_id(target_id: str, registry: list[TargetSpec] | None = None) -> str:
    by_id = registry_by_id(registry)
    spec = by_id.get(target_id)
    return spec.id if spec else target_id


def target_ids_for(command: str, registry: list[TargetSpec] | None = None) -> list[str]:
    specs = registry or load_target_registry()
    attr = {"build": "build", "diff": "diff", "release": "release"}[command]
    return [spec.id for spec in specs if getattr(spec, attr)]


def available_target_ids(
    repo_root: Path | None = None,
    *,
    command: str = "build",
) -> list[str]:
    return target_ids_for(command, load_target_registry(repo_root))


def adapter_import_path(spec: TargetSpec) -> str:
    return spec.adapter


def resolve_adapter_class(target_id: str, repo_root: Path | None = None):
    """Import and return adapter class for target id or alias."""
    by_id = registry_by_id(load_target_registry(repo_root))
    spec = by_id.get(target_id)
    if spec is None:
        return None
    module_path, cls_name = spec.adapter.rsplit(".", 1)
    try:
        mod = importlib.import_module(module_path)
        return getattr(mod, cls_name)
    except (ImportError, AttributeError):
        return None
