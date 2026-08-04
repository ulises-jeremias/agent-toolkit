"""Contract tests for the Pi Coding Agent adapter.

Pi uses npm packages with a ``pi`` field in package.json — NOT a plugin marketplace.
The adapter generates static companion assets (pi-package.json, skills/, agents/)
without any TypeScript runtime code.

Verifies:
- pi-package.json created with ``pi`` field declaring skills and agents
- No private hostnames in generated output
- Skills placed in skills/<name>/SKILL.md (not .pi/ or any platform-specific path)
- No skill.json generated
- Unsupported capabilities (TypeScript features) explicitly reported
- package_type is not 'plugin' (Pi has no plugin marketplace)
- check mode leaves filesystem unchanged
- All products compile cleanly (parametrized)
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.pi import PiAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def adapter(tmp_path):
    return PiAdapter(tmp_path / "pi-output", REPO_ROOT)


# ── pi-package.json ───────────────────────────────────────────────────────────


def test_pi_package_json_created(adapter, graph):
    """pi-package.json must be created at the product root."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    pkg = adapter.output_root / "agent-toolkit-core" / "pi-package.json"
    assert pkg.exists(), "pi-package.json not created"
    assert "pi-package-json" in result.emitted


def test_pi_package_json_valid(adapter, graph):
    """pi-package.json must be valid JSON."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    pkg = adapter.output_root / "agent-toolkit-core" / "pi-package.json"
    data = json.loads(pkg.read_text())
    assert isinstance(data, dict)


def test_pi_package_json_has_pi_field(adapter, graph):
    """pi-package.json must include the ``pi`` field that Pi uses for discovery."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    pkg = adapter.output_root / "agent-toolkit-core" / "pi-package.json"
    data = json.loads(pkg.read_text())

    assert "pi" in data, "pi-package.json missing 'pi' field"
    assert isinstance(data["pi"], dict), "'pi' field must be a dict"


def test_pi_package_json_pi_field_has_skills(adapter, graph):
    """pi.skills in pi-package.json must list the compiled skill paths."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    pkg = adapter.output_root / "agent-toolkit-core" / "pi-package.json"
    data = json.loads(pkg.read_text())

    pi_field = data.get("pi", {})
    assert "skills" in pi_field, "pi field missing 'skills' array"
    assert isinstance(pi_field["skills"], list), "pi.skills must be a list"


def test_pi_package_json_no_private_hostnames(adapter, graph):
    """pi-package.json must not contain private hostnames or IPs."""
    for product in graph.products.values():
        adapter.compile(graph, product)
        pkg_path = adapter.output_root / product.id / "pi-package.json"
        if pkg_path.exists():
            text = pkg_path.read_text()
            assert ".local" not in text, f"Private .local hostname in {pkg_path}"
            assert "192.168." not in text, f"Private IP in {pkg_path}"
            assert "colibri" not in text.lower(), f"Private host 'colibri' in {pkg_path}"


def test_pi_package_json_has_required_fields(adapter, graph):
    """pi-package.json must contain standard npm package fields."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    pkg = adapter.output_root / "agent-toolkit-core" / "pi-package.json"
    data = json.loads(pkg.read_text())

    for field in ("name", "version", "description", "license"):
        assert field in data, f"pi-package.json missing required field '{field}'"


# ── skills ────────────────────────────────────────────────────────────────────


def test_skills_in_skills_directory(adapter, graph):
    """Pi discovers skills at skills/<name>/SKILL.md — not a platform-specific path."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skills_dir = adapter.output_root / "agent-toolkit-core" / "skills"
    assert skills_dir.is_dir(), "skills/ directory not created"

    skill_mds = list(skills_dir.rglob("SKILL.md"))
    assert len(skill_mds) > 0, "No SKILL.md files found in skills/"


def test_no_skill_json(adapter, graph):
    """skill.json must not be generated (removed in v1.0.4)."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    skill_jsons = list((adapter.output_root / "agent-toolkit-core").rglob("skill.json"))
    assert skill_jsons == [], f"skill.json generated: {skill_jsons}"


def test_no_absolute_paths_in_skills(adapter, graph):
    """Generated SKILL.md must not contain absolute machine paths."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    for skill_md in (adapter.output_root / "agent-toolkit-core").rglob("SKILL.md"):
        text = skill_md.read_text()
        assert "/home/" not in text, f"Absolute /home/ path in {skill_md}"
        assert str(Path.home()) not in text, f"Home dir path in {skill_md}"


def test_skills_emitted_in_result(adapter, graph):
    """CompilationResult must record each emitted skill."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    emitted_skills = [e for e in result.emitted if e.startswith("skill:")]
    assert len(emitted_skills) > 0, "No skills recorded in result.emitted"


# ── unsupported capabilities ──────────────────────────────────────────────────


def test_typescript_features_reported_as_unsupported(adapter, graph):
    """TypeScript-only features must be explicitly reported — never silently dropped."""
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)

    unsupported_text = " ".join(result.unsupported).lower()
    assert "hook" in unsupported_text, "Lifecycle hooks not reported as unsupported"
    assert "tool" in unsupported_text, "Custom tools not reported as unsupported"
    assert "mcp" in unsupported_text, "MCP not reported as unsupported"


def test_package_type_not_plugin(adapter):
    """Pi has no plugin marketplace — package_type must NOT be 'plugin'."""
    assert adapter.package_type != "plugin", (
        "Pi Coding Agent does not have a plugin marketplace. "
        "package_type must not be 'plugin' — use 'companion-assets'."
    )


def test_package_type_is_companion_assets(adapter):
    """package_type should accurately reflect companion-assets (not plugin)."""
    assert adapter.package_type == "companion-assets", (
        f"Expected package_type='companion-assets', got '{adapter.package_type}'"
    )


# ── check mode ────────────────────────────────────────────────────────────────


def test_check_mode_no_files_written(adapter, graph, tmp_path):
    """check mode must not write any files to the filesystem."""
    product = graph.products["agent-toolkit-core"]
    before = set(tmp_path.rglob("*"))
    result = adapter.check(graph, product)
    after = set(tmp_path.rglob("*"))
    assert after == before, f"check mode wrote files: {after - before}"
    assert result.artifacts == []
    assert result.is_valid


# ── validate_pi_package_json ──────────────────────────────────────────────────


def test_validate_detects_private_ip():
    errors = PiAdapter.validate_pi_package_json({
        "name": "test",
        "registry": "http://192.168.1.100:4873"
    })
    assert len(errors) > 0, "Should detect private 192.168.x.x IP"


def test_validate_detects_private_hostname():
    errors = PiAdapter.validate_pi_package_json({
        "name": "test",
        "publishConfig": {"registry": "http://colibri.local/npm"}
    })
    assert len(errors) > 0, "Should detect private .local hostname"


def test_validate_accepts_safe_config():
    errors = PiAdapter.validate_pi_package_json({
        "name": "@agent-toolkit/core",
        "version": "1.0.0",
        "description": "Agent Toolkit for Pi",
        "license": "MIT",
        "pi": {"skills": ["skills/assistant/SKILL.md"]},
    })
    assert errors == [], f"Safe config wrongly rejected: {errors}"


# ── parity notes ──────────────────────────────────────────────────────────────


def test_parity_notes_documented():
    notes = PiAdapter.parity_notes()
    assert "typescript" in notes.lower(), "Parity notes must mention TypeScript"
    assert "npm" in notes.lower(), "Parity notes must explain npm distribution"
    assert "marketplace" in notes.lower(), "Parity notes must explain no marketplace"


# ── all products ──────────────────────────────────────────────────────────────


@pytest.mark.parametrize("product_id", [
    "agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"
])
def test_all_products_compile(adapter, graph, product_id):
    """All defined products must compile without errors."""
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = adapter.compile(graph, graph.products[product_id])
    assert result.errors == [], f"Errors for {product_id}: {result.errors}"
