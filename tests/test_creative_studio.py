"""Creative Studio: project helper, registry, product and MCP contracts.

Unit tests always run. The integration tests at the bottom exercise real
ffmpeg/ffprobe behaviour and are skipped when the tools are absent; the
Kdenlive MCP end-to-end flow is documented (with host evidence) in
docs/creative-studio/COMPATIBILITY.md and is not faked here.
"""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

REPO_ROOT = Path(__file__).parent.parent
HELPER_PATH = (
    REPO_ROOT / "skills" / "creative" / "creative-studio" / "scripts" / "creative_project.py"
)
REGISTRY_PATH = REPO_ROOT / "capabilities" / "skills" / "registry.yaml"
PRODUCTS_PATH = REPO_ROOT / "distributions" / "products.yaml"
MCP_DIR = REPO_ROOT / "mcp" / "registry"

CREATIVE_SKILLS = [
    "creative/audio-production",
    "creative/content-production",
    "creative/creative-studio",
    "creative/image-editing",
    "creative/media-qa",
    "creative/motion-graphics",
    "creative/video-analysis",
    "creative/video-editing",
]
CREATIVE_AGENTS = [
    "audio-engineer",
    "creative-director",
    "media-qa-reviewer",
    "motion-designer",
    "video-editor",
    "visual-designer",
]


def _helper():
    spec = importlib.util.spec_from_file_location("creative_project", HELPER_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _run_helper(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(HELPER_PATH), *args],
        capture_output=True,
        text=True,
        timeout=60,
    )


def test_helper_init_status_and_source_preservation(tmp_path: Path) -> None:
    proj = tmp_path / "proj"
    media = tmp_path / "clip.bin"
    media.write_bytes(b"x" * (2 << 20))

    assert _run_helper("init", str(proj), "--name", "unit").returncode == 0
    data = json.loads((proj / "project.json").read_text())
    assert data["name"] == "unit"
    for d in ("sources", "analysis", "edit", "assets", "preview", "export", "qa"):
        assert (proj / d).is_dir()

    assert _run_helper("add-source", str(proj), str(media)).returncode == 0
    assert _run_helper("status", str(proj)).returncode == 0

    # Full-file hash verification catches a same-size tail edit with restored mtime.
    added_stat = media.stat()
    media.write_bytes(b"x" * ((2 << 20) - 1) + b"y")
    os.utime(media, ns=(added_stat.st_atime_ns, added_stat.st_mtime_ns))
    result = _run_helper("status", str(proj))
    assert result.returncode != 0
    assert "source content changed since add" in result.stdout


def test_doctor_rejects_core_tool_that_exits_nonzero(tmp_path: Path, monkeypatch) -> None:
    helper = _helper()
    broken_tool = tmp_path / "ffmpeg"
    broken_tool.write_text("#!/bin/sh\necho 'ffmpeg 9.0'\nexit 1\n")
    broken_tool.chmod(0o755)
    monkeypatch.setattr(helper.shutil, "which", lambda _command: str(broken_tool))

    result = helper.probe_tool("ffmpeg", "ffmpeg", ["-version"])

    assert result["status"] == "configured-unavailable"
    assert "exited 1" in result["detail"]


def test_status_labels_legacy_partial_digest_as_sampled(tmp_path: Path) -> None:
    proj = tmp_path / "proj"
    media = tmp_path / "clip.bin"
    media.write_bytes(b"x" * 2048)
    assert _run_helper("init", str(proj)).returncode == 0
    assert _run_helper("add-source", str(proj), str(media)).returncode == 0

    manifest = json.loads((proj / "project.json").read_text())
    source = manifest["sources"][0]
    source["sha256_head_1mb"] = source.pop("sha256")
    (proj / "project.json").write_text(json.dumps(manifest))

    result = _run_helper("status", str(proj))

    assert result.returncode == 0
    assert "first-MiB digest" in result.stdout
    assert "need stronger verification" in result.stdout


def test_status_warns_when_legacy_source_has_no_digest(tmp_path: Path) -> None:
    proj = tmp_path / "proj"
    media = tmp_path / "clip.bin"
    media.write_bytes(b"x" * 2048)
    assert _run_helper("init", str(proj)).returncode == 0
    assert _run_helper("add-source", str(proj), str(media)).returncode == 0

    manifest = json.loads((proj / "project.json").read_text())
    manifest["sources"][0].pop("sha256")
    (proj / "project.json").write_text(json.dumps(manifest))

    result = _run_helper("status", str(proj))

    assert result.returncode == 0
    assert "source has no content digest" in result.stdout


def test_helper_rejects_path_traversal(tmp_path: Path) -> None:
    proj = tmp_path / "proj"
    assert _run_helper("init", str(proj)).returncode == 0
    result = _run_helper(
        "log-op",
        str(proj),
        "--tool",
        "x",
        "--action",
        "bad",
        "--artifact",
        "/etc/passwd",
    )
    assert result.returncode != 0
    assert "escapes" in (result.stdout + result.stderr)


def test_helper_doctor_reports_core_tools(tmp_path: Path) -> None:
    empty_path = tmp_path / "empty-path"
    empty_path.mkdir(exist_ok=True)
    result = subprocess.run(
        [sys.executable, str(HELPER_PATH), "doctor", "--json"],
        capture_output=True,
        text=True,
        timeout=60,
        env={**os.environ, "PATH": str(empty_path)},
    )
    rows = {r["tool"]: r["status"] for r in json.loads(result.stdout)}
    for core in ("kdenlive", "melt", "ffmpeg", "ffprobe"):
        assert rows[core] == "unsupported"
    assert result.returncode == 1


def test_registry_owns_creative_skills() -> None:
    data = yaml.safe_load(REGISTRY_PATH.read_text())
    by_id = {s["id"]: s for s in data["skills"]}
    assert data["count"] == len(data["skills"])
    for skill_id in CREATIVE_SKILLS:
        assert skill_id in by_id, skill_id
        assert by_id[skill_id]["holistic_owner"] == "designer"
        assert by_id[skill_id]["origin"] == "first-party"
    # Every cross-reference must resolve.
    for skill_id in CREATIVE_SKILLS:
        entry = by_id[skill_id]
        for key in ("overlap", "complementary", "prerequisites", "follow_ups"):
            for ref in entry[key] or []:
                assert ref in by_id, f"{skill_id} -> {ref}"


def test_creative_product_is_opt_in() -> None:
    data = yaml.safe_load(PRODUCTS_PATH.read_text())
    products = {p["id"]: p for p in data["products"]}
    studio = products["agent-toolkit-creative-studio"]
    assert studio["security"]["default_enabled"] is False
    assert studio["security"]["approval_required"] is True
    for skill_id in CREATIVE_SKILLS:
        assert skill_id in studio["includes"]["skills"]
    for agent in CREATIVE_AGENTS:
        assert agent in studio["includes"]["agents"]
    # Complete catalog covers the creative surface too.
    complete = products["agent-toolkit-complete"]["includes"]
    for skill_id in CREATIVE_SKILLS:
        assert skill_id in complete["skills"]


def test_mcp_entries_have_pinned_provenance_and_safety() -> None:
    for mcp_id in ("kdenlive", "blender", "gimp", "krita", "inkscape", "obs", "reaper", "comfyui"):
        data = yaml.safe_load((MCP_DIR / f"{mcp_id}.yaml").read_text())
        assert data["id"] == mcp_id
        policy = data["implementation"]["version_policy"]
        assert "pin" in policy, mcp_id
        assert data["security"]["notes"], mcp_id
    blender = yaml.safe_load((MCP_DIR / "blender.yaml").read_text())
    assert blender["approval"]["default"] == "explicit"
    obs = yaml.safe_load((MCP_DIR / "obs.yaml").read_text())
    assert obs["approval"]["default"] == "explicit"
    assert obs["security"]["network_hosts"] == ["127.0.0.1"]


def test_skill_files_exist_for_every_registered_creative_skill() -> None:
    for skill_id in CREATIVE_SKILLS:
        domain, name = skill_id.split("/")
        assert (REPO_ROOT / "skills" / domain / name / "SKILL.md").is_file(), skill_id
    for agent in CREATIVE_AGENTS:
        assert (REPO_ROOT / "agents" / agent / "AGENT.md").is_file(), agent


@pytest.mark.skipif(
    shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None,
    reason="ffmpeg/ffprobe not installed",
)
def test_audio_loudnorm_roundtrip_preserves_source(tmp_path: Path) -> None:
    """Acceptance scenario 3 (audio): measure, process, verify, keep source."""
    src = tmp_path / "tone.wav"
    out = tmp_path / "tone_norm.wav"
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=1000:duration=2",
            "-c:a",
            "pcm_s16le",
            str(src),
        ],
        check=True,
        timeout=60,
    )
    before = src.read_bytes()

    def lufs(path: Path) -> float:
        proc = subprocess.run(
            [
                "ffmpeg",
                "-hide_banner",
                "-i",
                str(path),
                "-af",
                "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json",
                "-f",
                "null",
                "-",
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )
        start, end = proc.stderr.rindex("{"), proc.stderr.rindex("}") + 1
        return float(json.loads(proc.stderr[start:end])["input_i"])

    input_i = lufs(src)
    assert not out.exists()
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(src),
            "-af",
            "loudnorm=I=-16:TP=-1.5:LRA=11",
            "-c:a",
            "pcm_s16le",
            str(out),
        ],
        check=True,
        timeout=60,
    )
    output_i = lufs(out)
    assert abs(output_i - (-16.0)) < 1.0, (input_i, output_i)
    assert src.read_bytes() == before
