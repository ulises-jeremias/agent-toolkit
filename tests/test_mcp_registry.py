"""Tests for the canonical MCP provider registry."""
from pathlib import Path
import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.mcp_registry import load_registry, McpProvider

REPO_ROOT = Path(__file__).parent.parent
REGISTRY_DIR = REPO_ROOT / "mcp" / "registry"


def test_registry_dir_exists():
    assert REGISTRY_DIR.is_dir(), f"mcp/registry/ not found at {REGISTRY_DIR}"


def test_registry_loads_all_providers():
    providers = load_registry(REGISTRY_DIR)
    assert len(providers) >= 6, f"Expected at least 6 providers, got {len(providers)}"


def test_all_required_providers_present():
    providers = load_registry(REGISTRY_DIR)
    required = {"github", "slack", "notion", "linear", "figma", "clickup"}
    missing = required - set(providers.keys())
    assert not missing, f"Missing providers: {missing}"


def test_github_provider_fields():
    providers = load_registry(REGISTRY_DIR)
    gh = providers["github"]
    assert gh.id == "github"
    assert gh.display_name == "GitHub"
    assert gh.provenance == "official"
    assert "GITHUB_TOKEN" in gh.env_vars
    assert len(gh.read_tools) > 0
    assert len(gh.write_tools) > 0


def test_no_secrets_in_registry():
    """Registry files must contain only env var names, never values."""
    for yaml_file in REGISTRY_DIR.glob("*.yaml"):
        text = yaml_file.read_text()
        # These patterns suggest actual secret values
        import re
        assert not re.search(r"ghp_[A-Za-z0-9]{36}", text), f"Token in {yaml_file}"
        assert not re.search(r"xoxb-[A-Za-z0-9-]+", text), f"Slack token in {yaml_file}"
        assert "api_key:" not in text.lower() or "${" in text, f"Possible hardcoded key in {yaml_file}"


def test_provider_platform_support():
    providers = load_registry(REGISTRY_DIR)
    gh = providers["github"]
    assert gh.is_supported_for("claude-code")
    assert gh.is_supported_for("cursor")


def test_registry_no_private_hostnames():
    for yaml_file in REGISTRY_DIR.glob("*.yaml"):
        text = yaml_file.read_text()
        assert ".local" not in text, f"Private hostname in {yaml_file}"
        assert "192.168." not in text, f"Private IP in {yaml_file}"


def test_load_registry_graceful_on_missing_dir(tmp_path):
    providers = load_registry(tmp_path / "nonexistent")
    assert providers == {}
