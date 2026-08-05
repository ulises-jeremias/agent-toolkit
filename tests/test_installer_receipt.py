"""Tests for installation receipts."""
import json
from pathlib import Path
import pytest
from agent_toolkit.installer.receipt import InstallReceipt, ArtifactEntry


def test_receipt_create():
    r = InstallReceipt.create("agent-toolkit-core", "cursor", "project", "1.1.0", "abc123")
    assert r.product == "agent-toolkit-core"
    assert r.target == "cursor"
    assert r.schema_version == 1


def test_receipt_no_secrets():
    r = InstallReceipt.create("agent-toolkit-core", "cursor", "project", "1.1.0", "abc123")
    d = r.to_dict()
    assert d["secrets"] == []


def test_receipt_save_load(tmp_path):
    r = InstallReceipt.create("agent-toolkit-core", "cursor", "project", "1.1.0", "abc123")
    r.artifacts.append(ArtifactEntry(".cursor/rules/assistant.mdc", "def456", "created"))
    saved = r.save(tmp_path)
    assert saved.exists()

    loaded = InstallReceipt.load("cursor", "agent-toolkit-core", tmp_path)
    assert loaded is not None
    assert loaded.product == "agent-toolkit-core"
    assert len(loaded.artifacts) == 1


def test_receipt_valid_json(tmp_path):
    r = InstallReceipt.create("agent-toolkit-core", "cursor", "project", "1.0.0", "abc")
    saved = r.save(tmp_path)
    data = json.loads(saved.read_text())
    assert "schemaVersion" in data
    assert data["secrets"] == []


def test_receipt_missing_returns_none(tmp_path):
    result = InstallReceipt.load("nonexistent", "product", tmp_path)
    assert result is None


def test_receipt_config_patches_round_trip(tmp_path):
    r = InstallReceipt.create("agent-toolkit-core", "claude-code", "project", "1.1.0", "abc123")
    r.config_patches.append({"path": "~/.claude/settings.json", "op": "merge", "keys": ["agents"]})
    r.save(tmp_path)
    loaded = InstallReceipt.load("claude-code", "agent-toolkit-core", tmp_path)
    assert loaded is not None
    assert len(loaded.config_patches) == 1
    assert loaded.config_patches[0]["op"] == "merge"
