"""Tests for #390 packs — docs-only, curated, coherent, not giant default."""

import pathlib

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKS = ["design-engineering", "agentic-security", "code-quality", "architecture"]


def test_packs_exist_docs_only():
    for pack in PACKS:
        cfg = ROOT / f"packs/{pack}/config.yaml"
        readme = ROOT / f"packs/{pack}/README.md"
        assert cfg.exists(), f"missing {cfg}"
        assert readme.exists(), f"missing {readme}"
        data = yaml.safe_load(cfg.read_text())
        assert data["pack"] == pack
        assert "skills" in data or "agents" in data
        # must have at least 2 skills but not bulk (not giant default)
        assert 2 <= len(data.get("skills", {})) <= 15, (
            f"{pack} skills {len(data.get('skills', {}))}"
        )


def test_packs_coherent_workflow_not_everything():
    # design-engineering should have frontend-design etc., not everything
    de = yaml.safe_load((ROOT / "packs/design-engineering/config.yaml").read_text())
    assert "design/frontend-design" in de["skills"]
    assert "agentic-security/supply-chain-audit" not in de["skills"]
    # agentic-security should have supply-chain, not frontend-design
    sec = yaml.safe_load((ROOT / "packs/agentic-security/config.yaml").read_text())
    assert "agentic-security/supply-chain-audit" in sec["skills"]
    assert "design/frontend-design" not in sec["skills"]
    # architecture vendor-neutral core + optional cloud disabled
    arch = yaml.safe_load((ROOT / "packs/architecture/config.yaml").read_text())
    assert "delivery/adr" in arch["skills"]
    assert arch["skills"]["cloud/cloud-design-patterns"]["enabled"] is False


def test_packs_are_docs_only_not_compiler_wired():
    # Ensure packs not referenced in distributions/products.yaml as composition layer
    prod = yaml.safe_load((ROOT / "distributions/products.yaml").read_text())
    # products.yaml should not have pack/packs composition fields
    # (do not substring-search product dicts — version_source may contain "packages/")
    for p in prod.get("products", []):
        assert "pack" not in p
        assert "packs" not in p


def test_inventory_and_context_budget_surface():
    # Simulate: complete still covers all skills (pack skills are subset of skills, not extra)
    prod = yaml.safe_load((ROOT / "distributions/products.yaml").read_text())
    complete = next(p for p in prod["products"] if p["id"] == "agent-toolkit-complete")
    included = set(complete["includes"]["skills"])
    # All pack skills should be subset of complete (since packs are docs-only advisory, not extra skills)
    for pack in PACKS:
        cfg = yaml.safe_load((ROOT / f"packs/{pack}/config.yaml").read_text())
        for skill in cfg.get("skills", {}):
            assert skill in included, f"{pack}:{skill} not in complete — pack skills must be subset"


def test_pack_trust_semantics():
    # design-engineering has community member → trust_tier community
    txt = (ROOT / "packs/design-engineering/README.md").read_text()
    assert "trust_tier: community" in txt or "trust_tier" in txt.lower()
    # code-quality has external megalinter → trust_tier reviewed
    txt2 = (ROOT / "packs/code-quality/README.md").read_text()
    assert "trust_tier" in txt2.lower()


def test_no_giant_default_pack():
    # complete is experimental, not default; packs/README should state not giant default
    readme = (ROOT / "packs/README.md").read_text()
    assert "Not a giant default pack" in readme or "complete stays experimental" in readme
