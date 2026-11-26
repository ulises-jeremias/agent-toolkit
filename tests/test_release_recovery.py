from __future__ import annotations

import hashlib
import io
import json
import zipfile
from pathlib import Path

import pytest

from scripts import recover_release_artifacts
from scripts.recover_release_artifacts import (
    BINARIES,
    SBOM_ARTIFACT,
    SBOM_FILE,
    extract_checked_zip,
    recover,
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


def recovery_api_fixture() -> tuple[dict[str, bytes], list[dict]]:
    endpoints: dict[str, bytes] = {
        f"repos/{REPO}/actions/runs/{RUN_ID}": json.dumps(source_run()).encode(),
        f"repos/{REPO}/actions/runs/{RUN_ID}/jobs?per_page=100": json.dumps(
            {"jobs": jobs()}
        ).encode(),
    }
    artifacts_payload = []
    for artifact_id, name in enumerate((*BINARIES, SBOM_ARTIFACT), start=1):
        filename = SBOM_FILE if name == SBOM_ARTIFACT else name
        payload = (
            json.dumps({"bomFormat": "CycloneDX", "specVersion": "1.6"}).encode()
            if name == SBOM_ARTIFACT
            else f"verified binary {name}".encode()
        )
        archive = zip_bytes((filename, payload))
        endpoints[f"repos/{REPO}/actions/artifacts/{artifact_id}/zip"] = archive
        artifacts_payload.append(
            {
                "id": artifact_id,
                "name": name,
                "expired": False,
                "run_id": RUN_ID,
                "digest": "sha256:" + hashlib.sha256(archive).hexdigest(),
            }
        )
    endpoints[f"repos/{REPO}/actions/runs/{RUN_ID}/artifacts?per_page=100"] = json.dumps(
        {"artifacts": artifacts_payload}
    ).encode()
    return endpoints, artifacts_payload


def patch_recovery_api(monkeypatch, endpoints: dict[str, bytes], calls: list[str]) -> None:
    def fake_api(endpoint: str) -> bytes:
        calls.append(endpoint)
        return endpoints[endpoint]

    monkeypatch.setattr(recover_release_artifacts, "gh_api_bytes", fake_api)


def test_recover_downloads_by_artifact_id_and_publishes_complete_verified_set(
    tmp_path: Path, monkeypatch,
):
    endpoints, _ = recovery_api_fixture()
    calls: list[str] = []
    patch_recovery_api(monkeypatch, endpoints, calls)
    output = tmp_path / "recovered"

    recover(REPO, RUN_ID, VERSION, SOURCE_SHA, output)

    metadata_calls = [
        f"repos/{REPO}/actions/runs/{RUN_ID}",
        f"repos/{REPO}/actions/runs/{RUN_ID}/jobs?per_page=100",
        f"repos/{REPO}/actions/runs/{RUN_ID}/artifacts?per_page=100",
    ]
    archive_calls = [
        f"repos/{REPO}/actions/artifacts/{artifact_id}/zip"
        for artifact_id in range(1, len(BINARIES) + 2)
    ]
    assert calls == [*metadata_calls, *archive_calls]
    assert {path.name for path in (output / "binaries").iterdir()} == set(BINARIES)
    assert {path.name for path in output.iterdir()} == {"binaries", SBOM_FILE}
    for name in BINARIES:
        assert (output / "binaries" / name).read_bytes() == f"verified binary {name}".encode()
    assert json.loads((output / SBOM_FILE).read_text()) == {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
    }


def test_recover_digest_mismatch_leaves_no_partial_output(tmp_path: Path, monkeypatch):
    endpoints, artifact_rows = recovery_api_fixture()
    # Fail after two artifacts have already been fetched and staged.
    artifact_rows[2]["digest"] = "sha256:" + "0" * 64
    artifacts_endpoint = f"repos/{REPO}/actions/runs/{RUN_ID}/artifacts?per_page=100"
    endpoints[artifacts_endpoint] = json.dumps({"artifacts": artifact_rows}).encode()
    calls: list[str] = []
    patch_recovery_api(monkeypatch, endpoints, calls)
    output = tmp_path / "recovered"

    with pytest.raises(ValueError, match="digest mismatch"):
        recover(REPO, RUN_ID, VERSION, SOURCE_SHA, output)

    assert calls[-1] == f"repos/{REPO}/actions/artifacts/3/zip"
    assert not output.exists()


def test_recover_invalid_sbom_leaves_no_partial_output(tmp_path: Path, monkeypatch):
    endpoints, artifact_rows = recovery_api_fixture()
    sbom_artifact_id = len(BINARIES) + 1
    sbom_endpoint = f"repos/{REPO}/actions/artifacts/{sbom_artifact_id}/zip"
    invalid_sbom = zip_bytes((SBOM_FILE, b"not JSON"))
    endpoints[sbom_endpoint] = invalid_sbom
    artifact_rows[-1]["digest"] = "sha256:" + hashlib.sha256(invalid_sbom).hexdigest()
    artifacts_endpoint = f"repos/{REPO}/actions/runs/{RUN_ID}/artifacts?per_page=100"
    endpoints[artifacts_endpoint] = json.dumps({"artifacts": artifact_rows}).encode()
    calls: list[str] = []
    patch_recovery_api(monkeypatch, endpoints, calls)
    output = tmp_path / "recovered"

    with pytest.raises(ValueError, match="invalid SBOM artifact"):
        recover(REPO, RUN_ID, VERSION, SOURCE_SHA, output)

    assert calls[-1] == sbom_endpoint
    assert not output.exists()


def test_recover_refuses_existing_output_without_api_calls(tmp_path: Path, monkeypatch):
    output = tmp_path / "recovered"
    output.mkdir()
    marker = output / "preserve.txt"
    marker.write_text("existing data")

    def unexpected_api(endpoint: str) -> bytes:
        pytest.fail(f"API must not be queried for existing output: {endpoint}")

    monkeypatch.setattr(recover_release_artifacts, "gh_api_bytes", unexpected_api)
    with pytest.raises(ValueError, match="output path already exists"):
        recover(REPO, RUN_ID, VERSION, SOURCE_SHA, output)

    assert marker.read_text() == "existing data"


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
