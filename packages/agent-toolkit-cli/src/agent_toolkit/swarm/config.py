"""Swarm config — precedence CLI > project > workspace > user > defaults."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

MODEL_PROFILE_NAMES = ("economy", "balanced", "quality", "private")
TASK_CLASSES = ("planning", "coding", "review", "architecture", "hardening", "qa")


def find_repo_root(start: Path | None = None) -> Path:
    cur = (start or Path.cwd()).resolve()
    for p in [cur] + list(cur.parents):
        if (p / ".git").exists():
            return p
    return cur


def load_yaml_file(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(text)
        return data if isinstance(data, dict) else {}
    except ImportError:
        import json
        try:
            return json.loads(text)
        except Exception:
            return {}
    except Exception:
        return {}


def resolve_config(repo_root: Path, cli_overrides: dict[str, Any] | None = None) -> dict[str, Any]:
    # Precedence: CLI > project-local > workspace > user > defaults
    defaults = {
        "recipe": "pair",
        "ui": "auto",
        "runner": "opencode",
        "model_profile": "balanced",
        "budget": {},
        "model_profiles": {},
    }
    # User config
    user_cfg_path = Path.home() / ".config" / "agent-toolkit" / "swarm.yaml"
    user_cfg = load_yaml_file(user_cfg_path)
    # Workspace: repo/.agent-toolkit/swarm.yaml OR swarm.yaml
    ws_cfg = {}
    for p in [repo_root / ".agent-toolkit" / "swarm.yaml", repo_root / "swarm.yaml", repo_root / ".agent-toolkit" / "swarm" / "config.yaml"]:
        if p.is_file():
            ws_cfg = load_yaml_file(p)
            break
    # Project-local is same as workspace for now (repo root)
    merged = dict(defaults)
    for src in (user_cfg, ws_cfg):
        if src:
            for k, v in src.items():
                if v is not None:
                    if isinstance(v, dict) and isinstance(merged.get(k), dict):
                        merged[k] = {**merged[k], **v}
                    else:
                        merged[k] = v
    if cli_overrides:
        for k, v in cli_overrides.items():
            if v is not None:
                merged[k] = v
    # Env overrides for runtime paths (not primary config)
    if os.environ.get("AGENT_TOOLKIT_SWARM_RUNS_DIR"):
        merged["runs_dir"] = os.environ["AGENT_TOOLKIT_SWARM_RUNS_DIR"]
    return merged
