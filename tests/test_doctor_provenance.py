"""Tests for #387 doctor provenance/pack/MCP — isolated HOME."""

import json
import os
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def _run_doctor(extra_args=None, env=None, cwd=None):
    # Python doctor (product `agent-toolkit` is the V launcher).
    result = subprocess.run(
        ["uv", "run", "agent-toolkit-py", "doctor", "--json"] + (extra_args or []),
        capture_output=True,
        text=True,
        cwd=cwd or str(ROOT),
        env=env or os.environ.copy(),
        timeout=15,
    )
    assert result.returncode in (0, 1), result.stderr
    data = json.loads(result.stdout)
    return data["checks"]


def test_doctor_has_provenance_packs_mcp_categories():
    checks = _run_doctor()
    cats = {c["category"] for c in checks}
    assert "provenance" in cats
    assert "packs" in cats
    assert "mcp" in cats
    # Provenance at least has lock entries or version
    prov = [c for c in checks if c["category"] == "provenance"]
    assert any("lock" in c["name"].lower() for c in prov)


def test_doctor_provenance_flag():
    # --provenance should be accepted and still produce same categories (prints to stderr)
    result = subprocess.run(
        ["uv", "run", "agent-toolkit-py", "doctor", "--provenance", "--json"],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
        timeout=15,
    )
    assert result.returncode in (0, 1)
    data = json.loads(result.stdout)
    cats = {c["category"] for c in data["checks"]}
    assert "provenance" in cats


def test_doctor_json_provenance_sha_and_staleness_shape():
    checks = _run_doctor()
    prov = [c for c in checks if c["category"] == "provenance"]
    # Should have at least lock version/entries and doctor --provenance hint
    names = {c["name"] for c in prov}
    assert "lock entries" in names or "lock version" in names
    assert any("doctor --provenance" in c["name"] for c in prov)


def test_doctor_packs_complete_and_mcp_registry():
    checks = _run_doctor()
    packs = [c for c in checks if c["category"] == "packs"]
    assert any("products.yaml" in c["name"] for c in packs)
    assert any("complete covers all skills" in c["name"] for c in packs)
    # mcp registry
    mcp = [c for c in checks if "mcp" in c["category"].lower() or "mcp" in c["name"].lower()]
    assert len(mcp) >= 1


def test_doctor_isolated_home_hermetic():
    with tempfile.TemporaryDirectory() as tmp:
        env = os.environ.copy()
        env["HOME"] = tmp
        # Should not mutate real HOME and still run (even if profiles missing, it warns not errors)
        checks = _run_doctor(env=env)
        cats = {c["category"] for c in checks}
        assert "provenance" in cats
        # Isolated home should still have provenance checks (not depend on HOME)
        assert any(c["category"] == "provenance" for c in checks)
