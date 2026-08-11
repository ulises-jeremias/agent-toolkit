"""Tests for quality/codeql first-party workflow — #383."""

import re
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILL_PATH = REPO_ROOT / "skills/quality/codeql/SKILL.md"


def _fm(path):
    text = path.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---\n", text, re.DOTALL | re.MULTILINE)
    return yaml.safe_load(m.group(1)), text


def test_frontmatter_first_party():
    fm, _ = _fm(SKILL_PATH)
    assert fm["origin"]["type"] == "first-party"
    assert fm["name"] == "codeql"


def test_workflow_modes():
    t = SKILL_PATH.read_text()
    for mode in [
        "SETUP / CONFIG REVIEW",
        "FINDING TRIAGE",
        "REMEDIATION",
        "WORKFLOW TROUBLESHOOTING",
        "CUSTOM QUERY",
    ]:
        assert mode in t, f"missing mode {mode}"
    # Should not be split into separate skills
    assert "Do not split into separate skills" in t


def test_evidence_discipline():
    t = SKILL_PATH.read_text()
    for field in ["ruleId", "source → sink", "code evidence", "confidence", "severity"]:
        assert field in t, f"missing evidence field {field}"
    assert "Needs investigation" in t
    # Table columns
    assert "ruleId | location" in t or "ruleId" in t


def test_megalinter_distinction():
    t = SKILL_PATH.read_text()
    assert "MegaLinter" in t
    assert "broad linting" in t.lower() or "Broad linting" in t
    assert "semantic security" in t.lower()
    assert "Neither replaces the other" in t


def test_operational_loop():
    t = SKILL_PATH.read_text()
    assert "DISCOVER existing CodeQL setup" in t
    assert "RUN or INSPECT scan" in t
    assert "TRIAGE findings" in t
    assert "RE-VALIDATE" in t


def test_safety():
    t = SKILL_PATH.read_text()
    assert "Never auto-suppress" in t
    assert "Never push to `main`" in t or "Never push to" in t


def test_references():
    assert (REPO_ROOT / "skills/quality/codeql/references/codeql-queries.md").exists()
    txt = (REPO_ROOT / "skills/quality/codeql/references/codeql-queries.md").read_text()
    assert "security-and-quality" in txt
    assert "github/codeql" in txt
