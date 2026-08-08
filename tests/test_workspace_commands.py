"""Tests for workspace persona, load, and validate commands (#204/#205/#206)."""

from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli import workspace as ws


def _scaffold_workspace(tmp_path: Path) -> Path:
    ws.cmd_init(["--dir", str(tmp_path), "--name", "ws"])
    root = tmp_path / "ws"
    (root / "packs" / "acme.yaml").write_text(
        "name: acme\ndescription: Acme client\nnotes: |\n  Key contact: Alice\n",
        encoding="utf-8",
    )
    (root / "profiles").mkdir(exist_ok=True)
    (root / "profiles" / "oss-contributor.yaml").write_text(
        "name: oss-contributor\ndescription: OSS mode\npack: acme\npersona: implementer\n",
        encoding="utf-8",
    )
    (root / "profiles" / "full-stack.yaml").write_text(
        "name: full-stack\ndescription: Full stack profile with skills and loops\n"
        "pack: acme\npersona: reviewer\n"
        "skills:\n  - delivery/gh-address-comments\n  - core/memory\n"
        "loops:\n  - daily-triage\n  - weekly-report\n",
        encoding="utf-8",
    )
    (root / "templates" / "jobs").mkdir(parents=True, exist_ok=True)
    (root / "templates" / "jobs" / "code-review.yaml").write_text(
        "name: code-review\nrequest: Review the code\n",
        encoding="utf-8",
    )
    (root / "knowledge" / "processes").mkdir(exist_ok=True)
    return root


@pytest.fixture
def workspace(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = _scaffold_workspace(tmp_path)
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(root))
    monkeypatch.chdir(root)
    return root


def test_use_persona_and_history(workspace: Path) -> None:
    assert ws.cmd_use_persona(["implementer"]) == 0
    assert (workspace / ".active-persona").read_text(encoding="utf-8").strip() == "implementer"
    assert ws.cmd_use_persona(["reviewer"]) == 0
    assert ws.cmd_history(["5"]) == 0
    history = (workspace / ".persona-history").read_text(encoding="utf-8")
    assert "implementer → reviewer" in history


def test_handoff_valid_and_invalid(workspace: Path) -> None:
    ws.cmd_use_persona(["implementer"])
    assert ws.cmd_handoff(["reviewer"]) == 0
    assert (workspace / ".active-persona").read_text(encoding="utf-8").strip() == "reviewer"
    # researcher is not in reviewer's handoff targets
    assert ws.cmd_handoff(["researcher"]) == 1


def test_personas_list(workspace: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert ws.cmd_personas([]) == 0
    out = capsys.readouterr().out
    assert "implementer" in out
    assert "write_files" in out


def test_load_pack(workspace: Path) -> None:
    assert ws.cmd_load(["packs/acme.yaml"]) == 0
    assert (workspace / ".active-pack").read_text(encoding="utf-8").strip() == "packs/acme.yaml"


def test_load_profile(workspace: Path) -> None:
    assert ws.cmd_load(["--profile", "oss-contributor"]) == 0
    assert (workspace / ".active-profile").read_text(encoding="utf-8").strip() == "oss-contributor"
    assert (workspace / ".active-pack").read_text(encoding="utf-8").strip() == "packs/acme.yaml"
    assert (workspace / ".active-persona").read_text(encoding="utf-8").strip() == "implementer"


def test_profiles_list(workspace: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert ws.cmd_profiles([]) == 0
    out = capsys.readouterr().out
    assert "oss-contributor" in out
    assert "pack=acme" in out


def test_context_includes_persona_constraints(
    workspace: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    ws.cmd_use_persona(["implementer"])
    ws.cmd_load(["packs/acme.yaml"])
    assert ws.cmd_context([]) == 0
    out = capsys.readouterr().out
    assert "<persona-constraints>" in out
    assert "persona: implementer" in out
    assert "Active Pack" in out
    assert "Key contact: Alice" in out


def test_validate_all_passes(workspace: Path) -> None:
    assert ws.cmd_validate([]) == 0


def test_validate_packs_missing_field(workspace: Path) -> None:
    (workspace / "packs" / "bad.yaml").write_text("name: bad\n", encoding="utf-8")
    assert ws.cmd_validate(["packs"]) == 1


def test_validate_knowledge_missing_dir(workspace: Path) -> None:
    import shutil

    shutil.rmtree(workspace / "knowledge" / "processes")
    assert ws.cmd_validate(["knowledge"]) == 1


def test_validate_unknown_surface(workspace: Path) -> None:
    assert ws.cmd_validate(["nope"]) == 1


def test_load_profile_stores_skills_and_loops(workspace: Path) -> None:
    assert ws.cmd_load(["--profile", "full-stack"]) == 0
    assert (workspace / ".active-profile").read_text(encoding="utf-8").strip() == "full-stack"
    skills = (workspace / ".active-skills").read_text(encoding="utf-8").strip()
    assert "delivery/gh-address-comments" in skills
    assert "core/memory" in skills
    loops = (workspace / ".active-loops").read_text(encoding="utf-8").strip()
    assert "daily-triage" in loops
    assert "weekly-report" in loops


def test_context_shows_skills_and_loops(
    workspace: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    ws.cmd_load(["--profile", "full-stack"])
    assert ws.cmd_context([]) == 0
    out = capsys.readouterr().out
    assert "Active Skills" in out
    assert "delivery/gh-address-comments" in out
    assert "core/memory" in out
    assert "Active Loops" in out
    assert "daily-triage" in out
    assert "weekly-report" in out


def test_profiles_list_shows_skills_and_loops(
    workspace: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    assert ws.cmd_profiles([]) == 0
    out = capsys.readouterr().out
    assert "full-stack" in out
    assert "delivery/gh-address-comments" in out
    assert "daily-triage" in out


def test_validate_profile_bad_skills(workspace: Path) -> None:
    (workspace / "profiles" / "bad-skills.yaml").write_text(
        "name: bad-skills\ndescription: Bad skills field\n"
        "skills:\n  - ''\n  - 42\n",
        encoding="utf-8",
    )
    assert ws.cmd_validate(["profiles"]) == 1


def test_validate_profile_bad_loops(workspace: Path) -> None:
    (workspace / "profiles" / "bad-loops.yaml").write_text(
        "name: bad-loops\ndescription: Bad loops field\n"
        "loops: not-a-list\n",
        encoding="utf-8",
    )
    assert ws.cmd_validate(["profiles"]) == 1
