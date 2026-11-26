#!/usr/bin/env python3
"""Recover tag-run binaries and SBOM after a downstream publication failure.

The source run must be a completed push of the exact version tag from this
repository. Artifact ZIP digests are checked against the Actions API before any
member is extracted.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any


BINARIES = (
    "agent-toolkit-linux-x86_64",
    "agent-toolkit-linux-arm64",
    "agent-toolkit-macos-arm64",
    "agent-toolkit-macos-x86_64",
    "agent-toolkit-windows-x86_64.exe",
)
SBOM_ARTIFACT = "sbom"
SBOM_FILE = "sbom.cyclonedx.json"
WORKFLOW_PATH = ".github/workflows/release.yml"


def fail(message: str) -> None:
    raise ValueError(message)


def validate_source_run(
    run: dict[str, Any], jobs: list[dict[str, Any]], artifacts: list[dict[str, Any]],
    *, repository: str, run_id: int, version: str, source_sha: str,
) -> dict[str, dict[str, Any]]:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        fail("invalid repository identifier")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.-]+)?", version):
        fail("invalid version")
    tag = f"v{version}"
    if run.get("id") != run_id:
        fail("source run ID does not match requested run")
    if run.get("repository", {}).get("full_name", "").lower() != repository.lower():
        fail("source run belongs to a different repository")
    if run.get("head_repository", {}).get("full_name", "").lower() != repository.lower():
        fail("source run head repository is not the requested repository")
    if run.get("path") != WORKFLOW_PATH or run.get("event") != "push":
        fail("source run is not a tag-push release workflow run")
    if run.get("status") != "completed":
        fail("source run has not completed")
    if run.get("head_branch") != tag or run.get("head_sha") != source_sha:
        fail("source run tag or commit does not match the requested release")

    successful_jobs = {job.get("name") for job in jobs if job.get("conclusion") == "success"}
    required_jobs = {
        *(f"Build {name}" for name in BINARIES),
        "Generate SBOM",
        "Attach V binaries, archives, SHA256SUMS, manifest",
    }
    missing_jobs = required_jobs - successful_jobs
    if missing_jobs:
        fail(f"source run lacks successful release jobs: {', '.join(sorted(missing_jobs))}")

    by_name: dict[str, dict[str, Any]] = {}
    for artifact in artifacts:
        name = artifact.get("name")
        if name in {*BINARIES, SBOM_ARTIFACT}:
            if name in by_name:
                fail(f"duplicate source artifact: {name}")
            if artifact.get("expired") or artifact.get("run_id", run_id) != run_id:
                fail(f"source artifact is expired or belongs to another run: {name}")
            digest = artifact.get("digest", "")
            if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
                fail(f"source artifact has no valid SHA-256 digest: {name}")
            by_name[name] = artifact
    missing_artifacts = {*BINARIES, SBOM_ARTIFACT} - by_name.keys()
    if missing_artifacts:
        fail(f"source run lacks artifacts: {', '.join(sorted(missing_artifacts))}")
    return by_name


def gh_api_bytes(endpoint: str) -> bytes:
    result = subprocess.run(
        ["gh", "api", "-H", "Accept: application/vnd.github+json", endpoint],
        check=True,
        stdout=subprocess.PIPE,
    )
    return result.stdout


def verify_artifact_digest(archive: bytes, digest: str, name: str) -> None:
    expected = digest.removeprefix("sha256:")
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        fail(f"source artifact has no valid SHA-256 digest: {name}")
    if hashlib.sha256(archive).hexdigest() != expected:
        fail(f"Actions artifact digest mismatch: {name}")


def extract_checked_zip(archive: bytes, expected_name: str, destination: Path) -> None:
    with zipfile.ZipFile(__import__("io").BytesIO(archive)) as bundle:
        files = [info for info in bundle.infolist() if not info.is_dir()]
        if len(files) != 1:
            fail(f"artifact {expected_name} must contain exactly one file")
        info = files[0]
        member = PurePosixPath(info.filename)
        if member.name != expected_name or member.is_absolute() or ".." in member.parts:
            fail(f"artifact contains unexpected member for {expected_name}")
        if info.file_size > 500 * 1024 * 1024:
            fail(f"artifact is too large: {expected_name}")
        # Reject Unix symlinks and other non-regular file types.
        mode = (info.external_attr >> 16) & 0o170000
        if mode not in (0, 0o100000):
            fail(f"artifact member is not a regular file: {expected_name}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        with bundle.open(info) as source, destination.open("wb") as target:
            shutil.copyfileobj(source, target)


def recover(
    repository: str, run_id: int, version: str, source_sha: str, output: Path,
) -> None:
    if output.exists() or output.is_symlink():
        fail("recovery output path already exists")
    run = json.loads(gh_api_bytes(f"repos/{repository}/actions/runs/{run_id}"))
    jobs_payload = json.loads(gh_api_bytes(f"repos/{repository}/actions/runs/{run_id}/jobs?per_page=100"))
    artifacts_payload = json.loads(gh_api_bytes(f"repos/{repository}/actions/runs/{run_id}/artifacts?per_page=100"))
    artifacts = validate_source_run(
        run, jobs_payload.get("jobs", []), artifacts_payload.get("artifacts", []),
        repository=repository, run_id=run_id, version=version, source_sha=source_sha,
    )

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="atk-recovery-", dir=output.parent) as temporary:
        staged_output = Path(temporary) / "output"
        binaries_dir = staged_output / "binaries"
        binaries_dir.mkdir(parents=True)
        for name in (*BINARIES, SBOM_ARTIFACT):
            artifact = artifacts[name]
            archive = gh_api_bytes(f"repos/{repository}/actions/artifacts/{artifact['id']}/zip")
            verify_artifact_digest(archive, artifact["digest"], name)
            filename = SBOM_FILE if name == SBOM_ARTIFACT else name
            path = Path(temporary) / filename
            extract_checked_zip(archive, filename, path)
            if name == SBOM_ARTIFACT:
                try:
                    json.loads(path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as error:
                    fail(f"invalid SBOM artifact: {error}")
                shutil.copy2(path, staged_output / SBOM_FILE)
            else:
                shutil.copy2(path, binaries_dir / name)
        # Publish the recovered directory only after every artifact has passed
        # run, digest, archive-member, and SBOM validation.
        os.replace(staged_output, output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--run-id", required=True, type=int)
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not os.environ.get("GH_TOKEN"):
        parser.error("GH_TOKEN must be set for read-only Actions API access")
    recover(args.repository, args.run_id, args.version, args.source_sha, args.output)
    print(f"Recovered verified artifacts from run {args.run_id} for v{args.version}")


if __name__ == "__main__":
    main()
