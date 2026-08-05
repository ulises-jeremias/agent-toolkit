"""Tests for canonical hook registry."""
from pathlib import Path
import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.hook_registry import load_hooks, HookDefinition, generate_parity_document

REPO_ROOT = Path(__file__).parent.parent
HOOKS_DIR = REPO_ROOT / "capabilities" / "hooks"


def test_hooks_dir_exists():
    assert HOOKS_DIR.is_dir()


def test_registry_loads_hooks():
    hooks, _errs = load_hooks(HOOKS_DIR)
    assert len(hooks) >= 2


def test_hooks_have_required_fields():
    hooks, _errs = load_hooks(HOOKS_DIR)
    for hook in hooks.values():
        assert hook.id
        assert hook.event
        assert hook.handler_type in ("command", "http", "mcp_tool", "prompt", "agent_verifier")


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
