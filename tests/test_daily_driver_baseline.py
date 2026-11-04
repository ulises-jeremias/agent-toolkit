"""No scripted preflight can masquerade as a passing real-provider acceptance."""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPT = (
    Path(__file__).resolve().parents[1]
    / "apps"
    / "desktop"
    / "scripts"
    / "daily-driver-baseline.mjs"
)
pytestmark = pytest.mark.skipif(
    not shutil.which("node") or not shutil.which("git"),
    reason="node and git required for controlled baseline fixture",
)


def run_preflight(*args):
    return subprocess.run(
        ["node", str(SCRIPT), *args],
        check=False,
        capture_output=True,
        text=True,
        timeout=45,
    )


def test_creates_failing_fixture_without_faking_provider_evidence(tmp_path):
    output = tmp_path / "baseline"
    run = run_preflight("--output-dir", str(output))
    assert run.returncode == 0, run.stderr
    data = json.loads((output / "baseline.json").read_text(encoding="utf8"))
    assert data["schema"] == "agent-toolkit/daily-driver-preflight@1"
    assert len(data["journeys"]) == 10
    assert all(x["evidence_level"] == "U" for x in data["journeys"])
    assert all(x["outcome"] == "unverified" for x in data["journeys"])
    assert all(x["authenticated"] == "not_checked" for x in data["providers"])
    assert data["fixture"]["failing_test_confirmed"] is True
    assert (output / "fixture" / ".git").is_dir()
    check = subprocess.run(
        ["node", "--test"],
        cwd=output / "fixture",
        check=False,
        capture_output=True,
        text=True,
        timeout=20,
    )
    assert check.returncode == 1
    assert "not ok" in check.stdout
    report = (output / "README.md").read_text(encoding="utf8")
    assert "No real provider session" in report
    assert "unverified" in report


def test_never_overwrites_existing_output(tmp_path):
    dest = tmp_path / "output"
    dest.mkdir()
    file = dest / "user.txt"
    file.write_text("KEEP", encoding="utf8")
    run = run_preflight("--output-dir", str(dest))
    assert run.returncode != 0
    assert "must be empty" in run.stderr
    assert file.read_text(encoding="utf8") == "KEEP"


def test_refuses_symlink_outdir(tmp_path):
    target = tmp_path / "target"
    target.mkdir()
    link = tmp_path / "link"
    link.symlink_to(target, target_is_directory=True)
    run = run_preflight("--output-dir", str(link))
    assert run.returncode != 0
    assert "symlink" in run.stderr
    assert list(target.iterdir()) == []


def test_installed_app_presence_is_not_a_usable_app_claim(tmp_path):
    output = tmp_path / "baseline"
    run = run_preflight("--output-dir", str(output), "--app", str(tmp_path / "missing"))
    assert run.returncode == 0, run.stderr
    data = json.loads((output / "baseline.json").read_text(encoding="utf8"))
    assert data["installed_app"] == {"supplied": True, "executable_exists": False}
    assert data["journeys"][0]["outcome"] == "unverified"


def test_explicit_outdir_required():
    run = run_preflight()
    assert run.returncode != 0
    assert "--output-dir is required" in run.stderr


def test_refuses_symlink_ancestor_outdir(tmp_path):
    target = tmp_path / "target"
    target.mkdir()
    link = tmp_path / "link"
    link.symlink_to(target, target_is_directory=True)
    run = run_preflight("--output-dir", str(link / "nested"))
    assert run.returncode != 0
    assert "symlink" in run.stderr
    assert list(target.iterdir()) == []
