"""Tests for workspace persona, load, validate, and context-budget commands (#204/#205/#206/#335)."""

from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli import workspace as ws
from agent_toolkit.cli.context_budget import analyze_workspace


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


def test_budget_workspace(workspace: Path) -> None:
    assert ws._cmd_budget([]) == 0


def test_budget_pack(workspace: Path) -> None:
    assert ws._cmd_budget(["--pack", "acme"]) == 0


def test_budget_nonexistent_pack(workspace: Path) -> None:
    result = analyze_workspace(workspace, pack_ref="nope")
    assert result.warnings


def test_budget_json_output(workspace: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert ws._cmd_budget(["--json"]) == 0
    out = capsys.readouterr().out
    assert "estimated_tokens" in out
    assert "risk" in out


def test_budget_risk_levels() -> None:
    from agent_toolkit.cli.context_budget import _risk_level

    assert _risk_level(10_000) == "LOW"
    assert _risk_level(25_000) == "MEDIUM"
    assert _risk_level(50_000) == "HIGH"


def test_budget_large_section_detected(workspace: Path) -> None:
    big_text = "x" * 6000
    (workspace / "packs" / "big.yaml").write_text(
        f"name: big\ndescription: Test pack\nnotes: |\n  {big_text}\n",
        encoding="utf-8",
    )
    result = analyze_workspace(workspace, pack_ref="big")
    large = [w for w in result.warnings if "Large section" in w]
    assert len(large) >= 1


def test_budget_profile_references_pack(workspace: Path) -> None:
    result = analyze_workspace(workspace, profile_ref="oss-contributor")
    pack_labels = [s.label for s in result.sections]
    assert any("pack:" in lbl for lbl in pack_labels)
    assert any("persona:" in lbl for lbl in pack_labels)
