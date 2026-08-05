"""Tests for canonical hook registry — fail CI on incomplete or unloadable hooks."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import pytest
import yaml


from agent_toolkit.compiler.hook_registry import (
    HookDefinition,
    generate_parity_document,
    load_hooks,
)

REPO_ROOT = Path(__file__).parent.parent
HOOKS_DIR = REPO_ROOT / "capabilities" / "hooks"
HOOK_SCHEMA_PATH = REPO_ROOT / "schemas" / "hook.schema.yaml"

VALID_EVENTS = {
    "session.start",
    "session.end",
    "tool.before",
    "tool.after",
    "tool.error",
    "prompt.before_submit",
    "prompt.after_submit",
    "permission.request",
    "permission.denied",
    "agent.start",
    "agent.stop",
    "file.changed",
    "config.changed",
}
VALID_HANDLER_TYPES = {"command", "http", "mcp_tool", "prompt", "agent_verifier"}
VALID_CLASSIFICATIONS = {"safe", "elevated", "destructive"}
VALID_FAILURE_POLICIES = {"abort", "continue", "retry"}
PLACEHOLDER_PATTERN = re.compile(r"placeholder|TODO|FIXME|TBD|not\s+implemented", re.I)


def _hook_yaml_files() -> list[Path]:
    return sorted(HOOKS_DIR.glob("*.yaml"))


def _load_hook_yaml(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path.name}: expected mapping, got {type(data).__name__}")
    return data


def _validate_hook_schema(data: dict[str, Any], path: Path) -> None:
    """Validate hook dict against schemas/hook.schema.yaml required fields and enums."""
    missing = [field for field in ("id", "event", "handler", "blocking", "failure_policy", "security") if field not in data]
    if missing:
        raise ValueError(f"{path.name}: missing required field(s): {', '.join(missing)}")

    if data["event"] not in VALID_EVENTS:
        raise ValueError(f"{path.name}: invalid event {data['event']!r}")

    if data["failure_policy"] not in VALID_FAILURE_POLICIES:
        raise ValueError(f"{path.name}: invalid failure_policy {data['failure_policy']!r}")

    handler = data["handler"]
    if not isinstance(handler, dict):
        raise ValueError(f"{path.name}: handler must be a mapping")
    handler_type = handler.get("type")
    if handler_type not in VALID_HANDLER_TYPES:
        raise ValueError(f"{path.name}: invalid handler.type {handler_type!r}")

    if handler_type == "command":
        command = handler.get("command")
        if not command or not isinstance(command, list) or not all(isinstance(c, str) for c in command):
            raise ValueError(f"{path.name}: command handler requires non-empty command: list[str]")

    timeout_ms = handler.get("timeout_ms", 5000)
    if not isinstance(timeout_ms, int) or not (100 <= timeout_ms <= 60000):
        raise ValueError(f"{path.name}: timeout_ms {timeout_ms!r} out of bounds [100, 60000]")

    security = data["security"]
    if not isinstance(security, dict):
        raise ValueError(f"{path.name}: security must be a mapping")
    sec_missing = [f for f in ("classification", "default_enabled") if f not in security]
    if sec_missing:
        raise ValueError(f"{path.name}: security missing {', '.join(sec_missing)}")
    if security["classification"] not in VALID_CLASSIFICATIONS:
        raise ValueError(f"{path.name}: invalid security.classification")
    if not isinstance(security["default_enabled"], bool):
        raise ValueError(f"{path.name}: security.default_enabled must be boolean")


def _command_text(hook: HookDefinition) -> str:
    return " ".join(hook.command)


def test_hooks_dir_exists():
    assert HOOKS_DIR.is_dir()


def test_hook_schema_file_exists():
    assert HOOK_SCHEMA_PATH.is_file()


def test_all_hook_yaml_files_parse():
    """Broken YAML must not pass silently — every file must parse to a mapping."""
    files = _hook_yaml_files()
    assert files, "capabilities/hooks/ has no *.yaml definitions"
    for path in files:
        _load_hook_yaml(path)


def test_all_hooks_validate_against_schema():
    """Each hook YAML must satisfy required fields and enums from hook.schema.yaml."""
    for path in _hook_yaml_files():
        data = _load_hook_yaml(path)
        _validate_hook_schema(data, path)


def test_registry_loads_all_hook_files():
    """load_hooks must not silently skip broken definitions."""
    yaml_files = _hook_yaml_files()
    hooks, errors = load_hooks(HOOKS_DIR)
    assert len(hooks) == len(yaml_files), (
        f"Expected {len(yaml_files)} hooks loaded, got {len(hooks)} — "
        "check for silent parse failures in hook_registry.load_hooks"
    )
    assert errors == []


def test_registry_loads_hooks():
    hooks, _errs = load_hooks(HOOKS_DIR)
    assert len(hooks) >= 2


def test_hooks_have_required_fields():
    hooks, _errs = load_hooks(HOOKS_DIR)
    for hook in hooks.values():
        assert hook.id
        assert hook.event
        assert hook.handler_type in VALID_HANDLER_TYPES


def test_no_placeholder_handlers_in_default_enabled_hooks():
    """Production hooks (default_enabled) must not use stub/placeholder commands."""
    hooks, _errs = load_hooks(HOOKS_DIR)
    for hook in hooks.values():
        if not hook.default_enabled:
            continue
        if hook.handler_type != "command":
            continue
        command_text = _command_text(hook)
        if PLACEHOLDER_PATTERN.search(command_text):
            pytest.fail(
                f"Hook '{hook.id}' is default_enabled but command looks like a placeholder: "
                f"{hook.command!r}"
            )


def test_opt_in_hooks_with_placeholders_are_documented():
    """Opt-in hooks may stub handlers but must stay disabled by default."""
    hooks, _errs = load_hooks(HOOKS_DIR)
    for hook in hooks.values():
        if hook.default_enabled:
            continue
        if hook.handler_type != "command":
            continue
        command_text = _command_text(hook)
        if PLACEHOLDER_PATTERN.search(command_text):
            assert hook.security_classification == "safe"
            assert hook.failure_policy in VALID_FAILURE_POLICIES


def test_destructive_hooks_disabled_by_default():
    """Write/destructive hooks must be opt-in (default_enabled=False)."""
    hooks, _errs = load_hooks(HOOKS_DIR)
    for hook in hooks.values():
        if hook.security_classification == "destructive":
            assert not hook.default_enabled, (
                f"Destructive hook '{hook.id}' must have default_enabled: false"
            )


def test_all_hooks_have_bounded_timeout():
    hooks, _errs = load_hooks(HOOKS_DIR)
    for hook in hooks.values():
        assert 100 <= hook.timeout_ms <= 60000, (
            f"Hook '{hook.id}' timeout {hook.timeout_ms}ms out of bounds [100, 60000]"
        )


def test_parity_document_generated():
    hooks, _errs = load_hooks(HOOKS_DIR)
    doc = generate_parity_document(hooks)
    assert "| Hook |" in doc
    assert "claude-code" in doc


def test_load_graceful_missing_dir(tmp_path):
    hooks, _errs = load_hooks(tmp_path / "nonexistent")
    assert hooks == {}


def test_malformed_hook_yaml_is_detected_by_validation(tmp_path):
    """Validation layer must catch unloadable hook definitions (not rely on silent skip)."""
    bad_file = tmp_path / "broken-hook.yaml"
    bad_file.write_text("id: [unclosed\n", encoding="utf-8")
    with pytest.raises(yaml.YAMLError):
        _load_hook_yaml(bad_file)

    incomplete = tmp_path / "incomplete-hook.yaml"
    incomplete.write_text("id: incomplete-only\n", encoding="utf-8")
    with pytest.raises(ValueError, match="missing required field"):
        _validate_hook_schema(_load_hook_yaml(incomplete), incomplete)


def test_broken_canonical_hook_would_fail_file_count_check(tmp_path):
    """Document fail-closed behavior: broken files reduce loaded hook count."""
    good = HOOKS_DIR / "session-start-context.yaml"
    bad = tmp_path / "bad-hook.yaml"
    bad.write_text("{ not: valid yaml: [", encoding="utf-8")
    (tmp_path / "good-hook.yaml").write_text(good.read_text(encoding="utf-8"), encoding="utf-8")

    yaml_files = sorted(tmp_path.glob("*.yaml"))
    hooks, errors = load_hooks(tmp_path)
    assert len(hooks) < len(yaml_files), "Broken hook YAML must not load silently without detection"
    assert errors, "Broken hook YAML must be reported in errors"
