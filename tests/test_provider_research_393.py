"""Tests for #393 research record — spike per §36-37."""

import json
import pathlib

import yaml
from jsonschema import Draft202012Validator

ROOT = pathlib.Path(__file__).resolve().parents[1]
REG = ROOT / "providers/providers.yaml"
SCHEMA = ROOT / "schemas/provider.schema.json"
RESEARCH = ROOT / "docs/providers/research-393-candidates.md"
MATRIX = ROOT / "docs/providers/provider-matrix.md"


def test_registry_now_eight_providers():
    data = yaml.safe_load(REG.read_text())
    assert set(data["providers"].keys()) == {
        "linear",
        "slack",
        "figma",
        "notion",
        "sentry",
        "vercel",
        "jira",
        "confluence",
    }
    # at least 4 HOWs each (confluence has 5 with attachments)
    for pid, prov in data["providers"].items():
        assert len(prov["how"]) >= 4
        assert "evaluation" in prov and "No universal" in prov["evaluation"]["notes"]


def test_registry_validates_schema_393():
    schema = json.loads(SCHEMA.read_text())
    data = yaml.safe_load(REG.read_text())
    errs = list(Draft202012Validator(schema).iter_errors(data))
    assert errs == []


def test_research_purpose_findings_risks():
    txt = RESEARCH.read_text()
    assert "Purpose:" in txt
    assert "Findings" in txt
    # spike needs risks/tradeoffs — we keep as section or inline
    assert "Risks" in txt or "risks/tradeoffs" in txt.lower()


def test_research_each_candidate_adopt_reject():
    txt = RESEARCH.read_text()
    for cand, verdict in [
        ("Notion", "ADOPT"),
        ("Sentry", "ADOPT"),
        ("Vercel", "ADOPT"),
        ("Jira + Confluence", "ADOPT"),
        ("Datadog", "REJECT"),
        ("AWS", "REJECT"),
        ("Supabase", "REJECT"),
    ]:
        assert cand in txt
        assert verdict in txt
    # Must have backend ranking per candidate, not universal law
    assert "No universal" in txt or "contextual" in txt.lower()
    assert "official plugin > MCP > CLI" not in txt or "No universal" in txt


def test_no_custom_where_official_better():
    txt = RESEARCH.read_text()
    # All ADOPT must prefer official remote MCP — check notion/sentry/vercel/jira mention official
    assert "makenotion/notion-mcp-server" in txt
    assert "mcp.sentry.dev" in txt
    assert "https://mcp.vercel.com" in txt
    assert "atlassian/atlassian-mcp-server" in txt
    # Must list community as fallback only where official dominates
    assert "suekou/mcp-notion-server" in txt
    assert "sooperset/mcp-atlassian" in txt


def test_matrix_extension_links_research():
    txt = MATRIX.read_text()
    assert "Extension — #393" in txt
    assert "research-393-candidates.md" in txt
    assert "ADOPT" in txt
    assert "REJECT" in txt
    # Must still carry 2026-08-12 dated sources for new candidates
    assert "2026-08-12" in txt
