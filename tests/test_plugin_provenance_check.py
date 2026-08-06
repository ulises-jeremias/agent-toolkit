"""Plugin check verifies .provenance.json digest drift when present."""

from __future__ import annotations

from pathlib import Path

from agent_toolkit.cli.plugin import _run_gen_surfaces
from agent_toolkit.compiler.provenance import (
    ArtifactRecord,
    ProvenanceManifest,
    file_digest,
)


def _write_minimal_toolkit(tmp_path: Path) -> Path:
    """Minimal toolkit layout with all agent-toolkit-core surfaces in sync."""
    core_surfaces = [
        ("agents/code-reviewer", "agents/code-reviewer"),
        ("skills/core/assistant", "skills/assistant"),
        ("skills/core/dev-companion", "skills/dev-companion"),
        ("skills/core/output-handshake", "skills/output-handshake"),
        ("skills/core/pr-fallback", "skills/pr-fallback"),
        ("skills/core/workspace-knowledge-sync", "skills/workspace-knowledge-sync"),
        ("skills/core/onboarding", "skills/onboarding"),
    ]

    for src_rel, dst_rel in core_surfaces:
        src = tmp_path / src_rel
        src.mkdir(parents=True, exist_ok=True)
        filename = "AGENT.md" if src_rel.startswith("agents/") else "SKILL.md"
        body = f"# {src_rel}\n"
        (src / filename).write_text(body, encoding="utf-8")

        dst = tmp_path / "plugins" / "agent-toolkit-core" / dst_rel
        dst.mkdir(parents=True, exist_ok=True)
        (dst / filename).write_text(body, encoding="utf-8")

    return tmp_path


def test_plugin_check_fails_on_provenance_digest_drift(tmp_path, capsys):
    """Digest drift on compiler-only artifacts is detected after surface sync passes."""
    toolkit = _write_minimal_toolkit(tmp_path)
    plugins_dir = toolkit / "plugins"
    plugin_dir = plugins_dir / "agent-toolkit-core"

    manifest_path = plugin_dir / ".claude-plugin" / "plugin.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text('{"name": "agent-toolkit-core"}\n', encoding="utf-8")
    digest = file_digest(manifest_path)

    provenance = ProvenanceManifest(
        generator_version="1.0.0",
        product="agent-toolkit-core",
        target="claude-code",
        artifacts=[
            ArtifactRecord(
                path="agent-toolkit-core/.claude-plugin/plugin.json",
                source_file="generated",
                source_digest="n/a",
                generated_digest=digest,
            )
        ],
    )
    (plugin_dir / ".provenance.json").write_text(provenance.to_json(), encoding="utf-8")

    manifest_path.write_text('{"name": "agent-toolkit-core", "tampered": true}\n', encoding="utf-8")

    rc = _run_gen_surfaces(toolkit, check=True)
    out = capsys.readouterr().out

    assert rc == 1
    assert "digest drift" in out


def test_plugin_check_passes_when_provenance_matches(tmp_path, capsys):
    toolkit = _write_minimal_toolkit(tmp_path)
    plugins_dir = toolkit / "plugins"
    plugin_dir = plugins_dir / "agent-toolkit-core"

    manifest_path = plugin_dir / ".claude-plugin" / "plugin.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text('{"name": "agent-toolkit-core"}\n', encoding="utf-8")
    digest = file_digest(manifest_path)

    provenance = ProvenanceManifest(
        generator_version="1.0.0",
        product="agent-toolkit-core",
        target="claude-code",
        artifacts=[
            ArtifactRecord(
                path="agent-toolkit-core/.claude-plugin/plugin.json",
                source_file="generated",
                source_digest="n/a",
                generated_digest=digest,
            )
        ],
    )
    (plugin_dir / ".provenance.json").write_text(provenance.to_json(), encoding="utf-8")

    rc = _run_gen_surfaces(toolkit, check=True)
    out = capsys.readouterr().out

    assert rc == 0
    assert "digest drift" not in out
