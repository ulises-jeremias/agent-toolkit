"""Guard the retired Swarm v1 public documentation boundary."""

from __future__ import annotations

import pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent


def test_current_consumer_docs_do_not_advertise_swarm_start_examples():
    paths = [
        REPO / "README.md",
        REPO / "docs" / "INSTALLATION.md",
        REPO / "docs" / "TROUBLESHOOTING.md",
        REPO / "docs" / "SWARMS.md",
        REPO / "docs" / "CLI_SURFACES.md",
    ]
    for path in paths:
        text = path.read_text(encoding="utf-8")
        assert "agent-toolkit swarm start --" not in text, path
        assert "agent-toolkit swarm init --" not in text, path


def test_retirement_docs_state_the_data_boundary_and_veasel_owner():
    disposition = (REPO / "docs" / "SWARM_V1_DISPOSITION.md").read_text(encoding="utf-8")
    assert "reject Swarm v1 `start` and `init`" in disposition
    assert "No general Swarm-to-Veasel importer exists" in disposition
    assert "user-owned" in disposition
    assert "github.com/veasel-labs/veasel" in disposition


def test_old_swarm_guides_are_archived_not_actionable():
    paths = list((REPO / "docs").glob("SWARM_*.md")) + [
        REPO / "docs" / "HOW_TO_CREATE_SWARM_RECIPE.md",
        REPO / "docs" / "v" / "swarm.md",
        REPO / "docs" / "v" / "swarm-visual-testing.md",
    ]
    for path in paths:
        if path.name == "SWARM_V1_DISPOSITION.md":
            continue
        text = path.read_text(encoding="utf-8")
        assert "(archived)" in text, path
        assert "retirement and data boundary" in text, path
        assert "agent-toolkit swarm start --" not in text, path
