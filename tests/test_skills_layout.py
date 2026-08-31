"""Validate catalogs/skills-layout.json matches skill-catalog.yaml and disk."""

import json
import pathlib

import yaml

REPO = pathlib.Path(__file__).resolve().parent.parent
LAYOUT = REPO / "catalogs" / "skills-layout.json"
CATALOG = REPO / "catalogs" / "skill-catalog.yaml"


def test_layout_equals_catalog_and_disk():
    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    catalog = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))

    layout_ids = {s["id"] for s in layout["skills"]}
    catalog_ids = {s["id"] for s in catalog["skills"]}
    disk_ids = {
        f"{p.parent.parent.name}/{p.parent.name}" for p in (REPO / "skills").rglob("SKILL.md")
    }

    # layout must equal catalog and disk
    assert layout_ids == catalog_ids, (
        f"layout vs catalog diff: layout - catalog {layout_ids - catalog_ids}, catalog - layout {catalog_ids - layout_ids}"
    )
    assert layout_ids == disk_ids, (
        f"layout vs disk diff: {layout_ids - disk_ids} vs {disk_ids - layout_ids}"
    )

    # no ghost
    assert "design/ui-ux-pro-max" not in layout_ids

    # groups must cover all domains
    assert set(layout["groups"].keys()) >= {
        "accessibility",
        "agentic-security",
        "architecture",
        "cloud",
    }

    # every skill in groups must match flat list
    grouped = {f"{g}/{s}" for g, lst in layout["groups"].items() for s in lst}
    assert grouped == layout_ids, f"groups vs flat mismatch {grouped ^ layout_ids}"
