"""969 SSOT: cli-contract.yaml is canonical for CLI surfaces."""

import pathlib
import re

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs/compatibility/cli-contract.yaml"


def test_contract_is_ssot_and_check_exists():
    assert CONTRACT.exists()
    data = yaml.safe_load(CONTRACT.read_text())
    assert "commands" in data
    # ensure every command has required ssot fields
    for cmd in data["commands"]:
        assert "name" in cmd
        assert "surface" in cmd
        assert "migration" in cmd
        assert "disposition" in cmd["migration"]
        # api boolean must be present or default true
        # if api false, ensure it's completion or serve
        if not cmd.get("api", True):
            assert cmd["name"] in ("completion", "serve"), f"{cmd['name']} api false unexpected"


def test_cli_surfaces_contains_all_contract_commands():
    data = yaml.safe_load(CONTRACT.read_text())
    names = {c["name"] for c in data["commands"]}
    text = (ROOT / "docs/CLI_SURFACES.md").read_text()
    found = set(re.findall(r"\| `([^`]+)` \|", text))
    missing = names - found
    assert not missing, f"CLI_SURFACES.md missing contract commands: {sorted(missing)}"


def test_generate_surface_check_wired():
    wf = (ROOT / ".github/workflows/validate.yml").read_text()
    assert "check-surface" in wf
    assert "generate_surface.py --check" in wf
    assert "check-surface" in wf.split("required-ci:")[1].split("needs:")[1].split("steps:")[0]


def test_dist_surface_deprecated():
    # dist/surface/cli-help.md should not exist as stale regular file; canonical is docs/surface
    legacy = ROOT / "dist/surface/cli-help.md"
    if legacy.exists() and not legacy.is_symlink():
        # if exists as regular file, must match canonical
        canonical = ROOT / "docs/surface/cli-help.md"
        assert legacy.read_text() == canonical.read_text(), (
            "dist/surface/cli-help.md diverged from docs/surface/cli-help.md"
        )
    # openapi should not be duplicated in dist
    assert (
        not (ROOT / "dist/surface/openapi.json").exists()
        or (ROOT / "dist/surface/openapi.json").is_symlink()
    ), "dist/surface/openapi.json stale"
    # web_nav retired
    assert not (ROOT / "dist/surface/web_nav.json").exists(), "web_nav.json retired per ADR-030"


def test_contract_api_flag():
    data = yaml.safe_load(CONTRACT.read_text())
    for cmd in data["commands"]:
        name = cmd["name"]
        api = cmd.get("api", True)
        # completion and serve are api false per ADR-030
        if name in ("completion", "serve"):
            assert api is False, f"{name} should be api:false"
        # insights should be api true (was re-ported)
        if name == "insights":
            assert api is True
