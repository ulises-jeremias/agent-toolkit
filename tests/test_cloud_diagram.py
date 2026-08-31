"""Tests for #384 cloud + #385 diagram — research + 4 first-party skills."""

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]


def test_cloud_research_384_exists_and_decisions():
    txt = (ROOT / "docs/cloud/research-384-candidates.md").read_text()
    assert "Purpose:" in txt and "Evidence-based" in txt
    assert "Findings" in txt
    assert "AWS Well-Architected" in txt and "6 pillars" in txt
    assert "awslabs/mcp" in txt and "mcp-proxy-for-aws" in txt
    for cand, verdict in [
        ("cloud-design-patterns", "ADOPT"),
        ("aws-well-architected-review", "ADOPT"),
        ("Terraform / K8s / Helm", "REJECT"),
    ]:
        assert cand in txt and verdict in txt
    # Pack semantics: architecture vendor-neutral vs cloud-architecture optional
    assert "vendor-neutral" in txt.lower()
    assert "cloud-architecture" in txt.lower() and "optional" in txt.lower()
    assert "ADR-0003" in txt or "ADR-0004" in txt


def test_diagram_research_385_exists():
    txt = (ROOT / "docs/architecture/research-385-diagram.md").read_text()
    assert "Purpose:" in txt and "Mermaid is portable baseline" in txt
    assert "Findings" in txt
    assert "mermaid-js/mermaid" in txt and "MIT" in txt
    assert "C4 model" in txt
    # Must mention PlantUML/Structurizr/Excalidraw with REJECT or optional
    assert "Structurizr" in txt
    assert "PlantUML" in txt
    assert "Excalidraw" in txt and "REJECT" in txt


def test_cloud_skills_exist_first_party():
    for skill in [
        "skills/cloud/cloud-design-patterns/SKILL.md",
        "skills/cloud/aws-well-architected-review/SKILL.md",
    ]:
        p = ROOT / skill
        assert p.exists(), skill
        txt = p.read_text()
        assert "origin:" in txt and "first-party" in txt
        assert "WHAT" in txt
    # cloud-design-patterns must reference 6 pillars mapping, not Azure dump
    assert "6 pillars" in (ROOT / "skills/cloud/aws-well-architected-review/SKILL.md").read_text()
    assert (
        "AWS Well-Architected" in (ROOT / "skills/cloud/cloud-design-patterns/SKILL.md").read_text()
    )


def test_diagram_skills_exist():
    for skill in [
        "skills/tooling/mermaid/SKILL.md",
        "skills/architecture/c4-model/SKILL.md",
    ]:
        p = ROOT / skill
        assert p.exists(), skill
        txt = p.read_text()
        assert "first-party" in txt
    # mermaid primary, c4 via mermaid
    assert "mermaid-js/mermaid" in (ROOT / "skills/tooling/mermaid/SKILL.md").read_text()
    assert "via Mermaid" in (ROOT / "skills/architecture/c4-model/SKILL.md").read_text()


def test_mermaid_c4_collaboration_not_duplicate():
    m = (ROOT / "skills/tooling/mermaid/SKILL.md").read_text()
    c = (ROOT / "skills/architecture/c4-model/SKILL.md").read_text()
    # c4 must say methodology not renderer, mermaid is renderer
    assert "Methodology not renderer" in c or "methodology" in c.lower()
    assert "Mermaid" in c
    # No 5 interchangeable skills — only 2 adopted
    assert (
        "Excalidraw" not in m
        or "REJECT" in (ROOT / "docs/architecture/research-385-diagram.md").read_text()
    )


def test_skills_validate():
    # Ensure frontmatter parseable (light check)
    import re

    import yaml

    for skill in [
        "skills/cloud/cloud-design-patterns/SKILL.md",
        "skills/cloud/aws-well-architected-review/SKILL.md",
        "skills/tooling/mermaid/SKILL.md",
        "skills/architecture/c4-model/SKILL.md",
    ]:
        text = (ROOT / skill).read_text()
        m = re.search(r"^---\n(.*?)\n---\n", text, re.DOTALL | re.MULTILINE)
        assert m, f"no frontmatter {skill}"
        data = yaml.safe_load(m.group(1))
        assert data["name"] in skill
        assert data["origin"]["type"] == "first-party"
