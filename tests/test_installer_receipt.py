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
