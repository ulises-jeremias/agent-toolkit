from __future__ import annotations

import io
import json
import hashlib
import zipfile
from pathlib import Path

import pytest

from scripts.recover_release_artifacts import (
    BINARIES,
    SBOM_ARTIFACT,
    extract_checked_zip,
    validate_source_run,
    verify_artifact_digest,
)
from scripts.validate_release_assets import EXPECTED, validate_release_assets
from scripts.verify_pypi_files import verify_pypi_files


REPO = "ulises-jeremias/agent-toolkit"
RUN_ID = 45718501193
VERSION = "1.51.0"
SOURCE_SHA = "ef9e87856502b58f2fd652ada31d82296a929173"


def source_run() -> dict:
    return {
        "id": RUN_ID,
        "repository": {"full_name": REPO},
        "head_repository": {"full_name": REPO},
        "path": ".github/workflows/release.yml",
        "event": "push",
        "status": "completed",
        "conclusion": "failure",  # downstream PyPI/Docker failures are recoverable
        "head_branch": f"v{VERSION}",
        "head_sha": SOURCE_SHA,
    }


def jobs() -> list[dict]:
    names = [f"Build {name}" for name in BINARIES]
    names += ["Generate SBOM", "Attach V binaries, archives, SHA256SUMS, manifest"]
    return [{"name": name, "conclusion": "success"} for name in names]


def artifacts() -> list[dict]:
    names = [*BINARIES, SBOM_ARTIFACT]
    return [
        {"id": i + 1, "name": name, "expired": False, "run_id": RUN_ID,
         "digest": "sha256:" + f"{i + 1:064x}"}
        for i, name in enumerate(names)
    ]


def validate(**changes):
    run = source_run()
    run.update(changes.pop("run", {}))
    return validate_source_run(
        run,
        changes.pop("jobs", jobs()),
        changes.pop("artifacts", artifacts()),
        repository=changes.pop("repository", REPO),
        run_id=changes.pop("run_id", RUN_ID),
        version=changes.pop("version", VERSION),
        source_sha=changes.pop("source_sha", SOURCE_SHA),
    )


def test_recovery_accepts_failed_publication_when_build_artifacts_succeeded():
    selected = validate()
    assert set(selected) == {*BINARIES, SBOM_ARTIFACT}


@pytest.mark.parametrize(
    "changes",
    [
        {"repository": "attacker/other"},
        {"run": {"head_repository": {"full_name": "attacker/other"}}},
        {"run": {"event": "workflow_dispatch"}},
        {"run": {"path": ".github/workflows/other.yml"}},
        {"run": {"head_branch": "v1.50.0"}},
        {"source_sha": "0" * 40},
        {"run": {"status": "in_progress"}},
        {"run": {"id": RUN_ID + 1}},
        {"version": "../../latest"},
        {"artifacts": artifacts()[:-1]},
    ],
)
def test_recovery_rejects_untrusted_or_incomplete_source(changes):
    with pytest.raises(ValueError):
        validate(**changes)


def test_recovery_requires_unexpired_artifact_digests_and_build_jobs():
    expired = artifacts()
    expired[0]["expired"] = True
    with pytest.raises(ValueError, match="expired"):
        validate(artifacts=expired)
    no_digest = artifacts()
    no_digest[0]["digest"] = ""
    with pytest.raises(ValueError, match="digest"):
        validate(artifacts=no_digest)
    failed_jobs = jobs()
    failed_jobs[0]["conclusion"] = "failure"
    with pytest.raises(ValueError, match="successful release jobs"):
        validate(jobs=failed_jobs)


def test_recovery_verifies_downloaded_artifact_zip_digest():
    archive = b"artifact zip bytes"
    digest = "sha256:" + hashlib.sha256(archive).hexdigest()
    verify_artifact_digest(archive, digest, "agent-toolkit-linux-x86_64")
    with pytest.raises(ValueError, match="digest mismatch"):
        verify_artifact_digest(archive + b"tampered", digest, "agent-toolkit-linux-x86_64")


def zip_bytes(*entries: tuple[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, payload in entries:
            archive.writestr(name, payload)
    return buffer.getvalue()


def test_extract_checked_zip_requires_expected_single_member(tmp_path: Path):
    output = tmp_path / "agent-toolkit-linux-x86_64"
    extract_checked_zip(zip_bytes((output.name, b"binary")), output.name, output)
    assert output.read_bytes() == b"binary"

    with pytest.raises(ValueError, match="unexpected member"):
        extract_checked_zip(zip_bytes(("unexpected", b"x")), output.name, output)
    with pytest.raises(ValueError, match="exactly one"):
        extract_checked_zip(
            zip_bytes((output.name, b"one"), ("other", b"two")),
            output.name,
            output,
        )


def test_release_asset_validation_checks_manifest_and_checksums(tmp_path: Path):
    for name in EXPECTED:
        (tmp_path / name).write_bytes(name.encode())
    archive = "agent-toolkit-1.51.0-linux-x86_64.tar.gz"
    (tmp_path / archive).write_bytes(b"archive")
    names = sorted([*EXPECTED, archive])
    checksums = {
        name: hashlib.sha256((tmp_path / name).read_bytes()).hexdigest()
        for name in names
    }
    (tmp_path / "SHA256SUMS").write_text(
        "".join(f"{checksums[name]}  {name}\n" for name in names)
    )
    manifest_assets = [
        {"filename": name, "sha256": checksums[name]} for name in names
    ]
    manifest = {
        "schemaVersion": 1,
        "name": "agent-toolkit",
        "version": VERSION,
        "gitTag": f"v{VERSION}",
        "sourceSha": SOURCE_SHA,
        "assets": manifest_assets,
    }
    (tmp_path / "manifest.json").write_text(json.dumps(manifest))
    validate_release_assets(
        tmp_path, version=VERSION, tag=f"v{VERSION}", source_sha=SOURCE_SHA
    )

    (tmp_path / next(iter(EXPECTED))).write_bytes(b"tampered")
    with pytest.raises(ValueError, match="checksum mismatch"):
        validate_release_assets(
            tmp_path, version=VERSION, tag=f"v{VERSION}", source_sha=SOURCE_SHA
        )


def test_release_workflows_handoff_and_validate_same_run_assets():
    root = Path(__file__).resolve().parents[1]
    release = (root / ".github/workflows/release.yml").read_text()
    docker = (root / ".github/workflows/docker.yml").read_text()
    dockerfile = (root / "Dockerfile").read_text()

    assert "name: release-assets" in release
    assert "name: release-assets" in docker
    assert "validate_release_assets.py release-assets" in release
    assert "validate_release_assets.py release-assets" in docker
    assert "source_run_id" in release
    assert "recover_release_artifacts.py" in release
    assert "needs: [recover-release-assets, recover-pypi, docker-recovery]" in release
    assert "type=bind,target=/mnt/context,readonly" in dockerfile
    assert "/mnt/context/release-assets/" in dockerfile
    assert "sha256sum -c SHA256SUMS --ignore-missing" in dockerfile
    recover_pypi = release.split("  recover-pypi:", 1)[1].split("  docker:", 1)[0]
    assert "::error::PyPI file names/digests" in recover_pypi
    assert "exit 1" in recover_pypi.split("PyPI file names/digests", 1)[1]
    assert "::warning::PyPI verification timed out" not in recover_pypi
    assert "verify_pypi_files.py dist pypi-version.json" in recover_pypi
    assert "packaging==26.4" in recover_pypi
    normal_publish = release.split("  publish-pypi:", 1)[1].split("  build-binaries:", 1)[0]
    assert "Download GitHub Release" not in normal_publish


def test_pypi_file_verification_accepts_exact_filenames_and_digests(tmp_path: Path):
    files = {"agent_toolkit_cli-1.51.0.tar.gz": b"sdist", "agent_toolkit_cli-1.51.0-py3-none-any.whl": b"wheel"}
    for name, payload in files.items():
        (tmp_path / name).write_bytes(payload)
    metadata = {
        "info": {"name": "agent-toolkit-cli", "version": VERSION},
        "urls": [
            {"filename": name, "digests": {"sha256": hashlib.sha256(payload).hexdigest()}}
            for name, payload in files.items()
        ],
    }
    verify_pypi_files(tmp_path, metadata, version=VERSION)


def test_pypi_file_verification_rejects_missing_wrong_digest_and_extra_files(tmp_path: Path):
    payload = b"wheel"
    name = "agent_toolkit_cli-1.51.0-py3-none-any.whl"
    (tmp_path / name).write_bytes(payload)
    exact = {
        "info": {"name": "agent-toolkit-cli", "version": VERSION},
        "urls": [{"filename": name, "digests": {"sha256": hashlib.sha256(payload).hexdigest()}}],
    }
    (tmp_path / "agent_toolkit_cli-1.51.0.tar.gz").write_bytes(b"sdist")
    with pytest.raises(ValueError, match="file set differs"):
        verify_pypi_files(tmp_path, exact, version=VERSION)
    (tmp_path / "agent_toolkit_cli-1.51.0.tar.gz").unlink()
    with pytest.raises(ValueError, match="SHA-256 differs"):
        verify_pypi_files(
            tmp_path,
            {**exact, "urls": [{"filename": name, "digests": {"sha256": "0" * 64}}]},
            version=VERSION,
        )
    extra = {"filename": "extra.whl", "digests": {"sha256": "1" * 64}}
    with pytest.raises(ValueError, match="file set differs"):
        verify_pypi_files(tmp_path, {**exact, "urls": [*exact["urls"], extra]}, version=VERSION)


def test_pypi_file_verification_normalizes_prerelease_versions(tmp_path: Path):
    payload = b"release candidate wheel"
    name = "agent_toolkit_cli-1.51.0rc1-py3-none-any.whl"
    (tmp_path / name).write_bytes(payload)
    metadata = {
        "info": {"name": "agent-toolkit-cli", "version": "1.51.0rc1"},
        "urls": [{"filename": name, "digests": {"sha256": hashlib.sha256(payload).hexdigest()}}],
    }
    verify_pypi_files(tmp_path, metadata, version="1.51.0-rc1")


def test_pypi_file_verification_rejects_malformed_digests_and_wrong_project(tmp_path: Path):
    name = "agent_toolkit_cli-1.51.0-py3-none-any.whl"
    payload = b"wheel"
    (tmp_path / name).write_bytes(payload)
    entry = {"filename": name, "digests": None}
    metadata = {"info": {"name": "agent-toolkit-cli", "version": VERSION}, "urls": [entry]}
    with pytest.raises(ValueError, match="digests"):
        verify_pypi_files(tmp_path, metadata, version=VERSION)
    metadata["info"]["name"] = "other-project"
    with pytest.raises(ValueError, match="project name"):
        verify_pypi_files(tmp_path, metadata, version=VERSION)
