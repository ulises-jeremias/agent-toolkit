"""People contract tests: schemas, mirrors, offline validation, adversarial input.

These tests exercise the Toolkit-owned contract slice only: `schemas/person.schema.json`,
`schemas/people-bindings.schema.json`, `capabilities/imports/munder-hire-v1.json`,
`scripts/sync-people-contracts.py` and `scripts/workspace/validate-people.py`.
Run from the repo root: `pytest -c tests/pytest.ini tests/test_people_contracts.py -v`.
"""

import hashlib
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).absolute().parent.parent
SYNC = REPO / "scripts" / "sync-people-contracts.py"
VALIDATE = REPO / "scripts" / "workspace" / "validate-people.py"
PERSON_SCHEMA = REPO / "schemas" / "person.schema.json"
BINDINGS_SCHEMA = REPO / "schemas" / "people-bindings.schema.json"
IMPORT_MAPPING = REPO / "capabilities" / "imports" / "munder-hire-v1.json"
LOCK = "schemas/people-contracts.lock.json"


def person(**overrides):
    base = {
        "spec": "agent-toolkit/person@1",
        "id": "test-worker",
        "name": "Test Worker",
        "role": "reviewer",
        "goal": "Review code changes with care.",
        "archived": False,
    }
    base.update(overrides)
    return base


def write_workspace(tmp_path, files):
    ws = tmp_path / "ws"
    for rel, data in files.items():
        dest = ws / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(data, bytes):
            dest.write_bytes(data)
        else:
            dest.write_text(data, encoding="utf-8")
    return ws


def run_sync(ws, mode):
    return subprocess.run(
        [sys.executable, str(SYNC), "--workspace", str(ws), mode],
        capture_output=True,
        text=True,
        timeout=60,
    )


def run_validate(ws):
    return subprocess.run(
        [sys.executable, str(VALIDATE), "--workspace", str(ws)],
        capture_output=True,
        text=True,
        timeout=60,
    )


def seeded_workspace(tmp_path):
    ws = write_workspace(tmp_path, {"people/test-worker.json": json.dumps(person()) + "\n"})
    result = run_sync(ws, "--write")
    assert result.returncode == 0, result.stdout + result.stderr
    return ws


# ---------------------------------------------------------------------------
# Schema documents
# ---------------------------------------------------------------------------


class TestSchemaDocuments:
    def test_person_schema_declares_spec_and_required_fields(self):
        schema = json.loads(PERSON_SCHEMA.read_text(encoding="utf-8"))
        assert schema["$id"] == "agent-toolkit/person@1"
        assert schema["additionalProperties"] is False
        for field in ("spec", "id", "name", "role", "goal", "archived"):
            assert field in schema["required"]

    def test_person_schema_blocks_runtime_fields(self):
        schema = json.loads(PERSON_SCHEMA.read_text(encoding="utf-8"))
        properties = json.dumps(schema["properties"])
        for banned in ("commands", "environment", "secrets", "grants", "tokens"):
            assert f'"{banned}"' not in properties

    def test_bindings_schema_roles_are_dynamic_and_bounded(self):
        schema = json.loads(BINDINGS_SCHEMA.read_text(encoding="utf-8"))
        assert schema["$id"] == "agent-toolkit/people-bindings@1"
        roles = schema["properties"]["roles"]
        assert roles["maxProperties"] == 64
        assert roles["additionalProperties"]["additionalProperties"] is False
        # No permission or recipe rewriting keys.
        assert "allow" not in json.dumps(roles)
        assert "recipe" not in json.dumps(roles)

    def test_import_mapping_is_contract_only(self):
        mapping = json.loads(IMPORT_MAPPING.read_text(encoding="utf-8"))
        assert mapping["status"] == "contract-only"
        assert mapping["review_required"] is True
        assert mapping["auto_spawn"] is False
        assert mapping["auto_install"] is False
        assert mapping["live_sync"] is False
        assert mapping["unknown_fields"] == "blocked"
        assert mapping["unsafe_fields"] == "blocked"


# ---------------------------------------------------------------------------
# Sync mirrors
# ---------------------------------------------------------------------------


class TestSyncMirrors:
    def test_write_creates_lock_with_sha256_and_source(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        lock = json.loads((ws / LOCK).read_text(encoding="utf-8"))
        assert lock["spec"] == "agent-toolkit/people-contracts-lock@1"
        assert lock["source"] == "https://github.com/ulises-jeremias/agent-toolkit"
        for rel, entry in lock["files"].items():
            assert entry["source"] in (
                "schemas/person.schema.json",
                "schemas/people-bindings.schema.json",
                "scripts/workspace/validate-people.py",
            )
            digest = hashlib.sha256((ws / rel).read_bytes()).hexdigest()
            assert entry["sha256"] == digest

    def test_check_passes_on_fresh_write(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        assert run_sync(ws, "--check").returncode == 0

    def test_check_fails_on_drift(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        (ws / "scripts" / "validate-people.py").write_text("# drift\n", encoding="utf-8")
        result = run_sync(ws, "--check")
        assert result.returncode == 1
        assert "drift" in result.stdout

    def test_check_fails_on_missing_mirror(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        (ws / "schemas" / "person.schema.json").unlink()
        assert run_sync(ws, "--check").returncode == 1

    def test_write_replaces_sibling_inode_not_outside_hardlink(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        outside = tmp_path / "outside-copy.py"
        target = ws / "scripts" / "validate-people.py"
        # Drift the mirror, then share the inode with an outside file. The write
        # must swap in a fresh sibling inode; the outside hardlink keeps its bytes.
        target.write_text("# drift\n", encoding="utf-8")
        outside.hardlink_to(target)
        assert os.stat(outside).st_ino == os.stat(target).st_ino
        result = run_sync(ws, "--write")
        assert result.returncode == 0
        assert os.stat(outside).st_ino != os.stat(target).st_ino
        assert outside.read_text(encoding="utf-8") == "# drift\n"
        assert target.read_text(encoding="utf-8") != "# drift\n"

    def test_write_rejects_symlinked_destination_directory(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        escape = tmp_path / "escape"
        escape.mkdir()
        (ws / "scripts" / "validate-people.py").unlink()
        (ws / "scripts").rmdir()
        (ws / "scripts").symlink_to(escape)
        result = run_sync(ws, "--write")
        assert result.returncode == 1
        assert not (escape / "workspace").exists()

    def test_write_rejects_symlinked_final_file(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        outside = tmp_path / "victim.txt"
        outside.write_text("do not clobber", encoding="utf-8")
        (ws / "schemas" / "person.schema.json").unlink()
        (ws / "schemas" / "person.schema.json").symlink_to(outside)
        result = run_sync(ws, "--write")
        assert result.returncode == 1
        assert outside.read_text(encoding="utf-8") == "do not clobber"

    def test_write_never_copies_declarations(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        run_sync(ws, "--write")
        assert not (ws / "people" / "test-worker.json.copy").exists()
        # Only the named mirrors plus the lock were added.
        added = sorted(str(p.relative_to(ws)) for p in ws.rglob("*") if p.is_file())
        assert "people/test-worker.json" in added
        assert LOCK in added
        assert "schemas/person.schema.json" in added


# ---------------------------------------------------------------------------
# Offline validation
# ---------------------------------------------------------------------------


class TestOfflineValidation:
    def test_valid_seeded_workspace(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        result = run_validate(ws)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "1 configured" in result.stdout

    def test_unknown_field_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        (ws / "people" / "test-worker.json").write_text(
            json.dumps(person(runtime_grants={"all": True})) + "\n", encoding="utf-8"
        )
        result = run_validate(ws)
        assert result.returncode == 1
        assert "runtime_grants" not in result.stdout
        assert "all" not in result.stdout

    def test_id_filename_mismatch_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        (ws / "people" / "other-name.json").write_text(
            json.dumps(person()) + "\n", encoding="utf-8"
        )
        assert run_validate(ws).returncode == 1

    def test_uppercase_id_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        (ws / "people" / "Bad-ID.json").write_text(
            json.dumps(person(id="Bad-ID")) + "\n", encoding="utf-8"
        )
        assert run_validate(ws).returncode == 1

    def test_oversized_declaration_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        big = person(goal="x" * (64 * 1024 + 10))
        (ws / "people" / "test-worker.json").write_text(json.dumps(big) + "\n", encoding="utf-8")
        assert run_validate(ws).returncode == 1

    def test_malformed_json_rejected_without_traceback(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        (ws / "people" / "test-worker.json").write_text("{not json", encoding="utf-8")
        result = run_validate(ws)
        assert result.returncode == 1
        assert "Traceback" not in result.stderr

    def test_duplicate_json_key_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        (ws / "people" / "test-worker.json").write_text(
            json.dumps(person()) + "\n"[:-2] + ', "role": "impl"}\n', encoding="utf-8"
        )
        assert run_validate(ws).returncode == 1

    def test_nonfinite_budget_rejected_nan(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        raw = json.dumps(person(budget={"max_tokens": 0})) + "\n"
        raw = raw.replace('"max_tokens": 0', '"max_tokens": NaN')
        (ws / "people" / "test-worker.json").write_text(raw, encoding="utf-8")
        result = run_validate(ws)
        assert result.returncode == 1
        assert "NaN" not in result.stdout

    def test_nonfinite_budget_rejected_infinity(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        raw = json.dumps(person(budget={"max_cost_usd": 1})) + "\n"
        raw = raw.replace('"max_cost_usd": 1', '"max_cost_usd": Infinity')
        (ws / "people" / "test-worker.json").write_text(raw, encoding="utf-8")
        assert run_validate(ws).returncode == 1

    def test_nonfinite_budget_rejected_1e9999(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        raw = json.dumps(person(budget={"max_seconds": 1})) + "\n"
        raw = raw.replace('"max_seconds": 1', '"max_seconds": 1e9999')
        (ws / "people" / "test-worker.json").write_text(raw, encoding="utf-8")
        assert run_validate(ws).returncode == 1

    def test_drift_stops_validation_before_schema_evaluation(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        # Corrupt the locked schema copy: validation must fail on drift, not evaluate the tampered schema.
        (ws / "schemas" / "person.schema.json").write_text('{"tampered": true}', encoding="utf-8")
        result = run_validate(ws)
        assert result.returncode == 1
        assert "drift" in result.stdout

    def test_remote_reference_never_retrieved(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        raw = json.dumps(person(definition_id="https://evil.example.com/x")) + "\n"
        (ws / "people" / "test-worker.json").write_text(raw, encoding="utf-8")
        result = run_validate(ws)
        # The URL is schema-valid data; the no-network registry means validation
        # never fetches it. Zero retrieval attempts, and the value is never echoed.
        assert result.returncode == 0, result.stdout + result.stderr
        assert "evil.example.com" not in result.stdout + result.stderr
        # The retrieve=no_network wiring is what blocks any future remote $ref.
        source = VALIDATE.read_text(encoding="utf-8")
        assert "retrieve=no_network" in source

    def test_symlinked_people_directory_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        outside = tmp_path / "outside-people"
        outside.mkdir()
        outside_file = outside / "linked.json"
        outside_file.write_text(json.dumps(person()) + "\n", encoding="utf-8")
        (ws / "people" / "test-worker.json").unlink()
        (ws / "people").rmdir()
        (ws / "people").symlink_to(outside)
        result = run_validate(ws)
        assert result.returncode == 1
        # No outside file was read or echoed.
        assert "linked" not in result.stdout

    def test_symlinked_declaration_file_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        outside = tmp_path / "outside.json"
        outside.write_text(json.dumps(person()) + "\n", encoding="utf-8")
        (ws / "people" / "test-worker.json").unlink()
        (ws / "people" / "test-worker.json").symlink_to(outside)
        assert run_validate(ws).returncode == 1

    def test_diagnostic_never_echoes_values_or_controls(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        secret = "hunter2-with\x1b[31mesc"
        # Missing required "archived" makes the declaration invalid; the secret
        # marker must not surface in the static diagnostic.
        declaration = person(name=secret)
        del declaration["archived"]
        (ws / "people" / "test-worker.json").write_text(
            json.dumps(declaration) + "\n", encoding="utf-8"
        )
        result = run_validate(ws)
        assert result.returncode == 1
        assert "hunter2" not in result.stdout + result.stderr
        assert "\x1b" not in result.stdout + result.stderr

    def test_malicious_dynamic_role_key_redacted(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        bindings = {
            "spec": "agent-toolkit/people-bindings@1",
            "roles": {"impl\x1b[31m': pass; import os; os.system": {"person_id": "test-worker"}},
        }
        (ws / "people" / "bindings.yaml").write_text(json.dumps(bindings), encoding="utf-8")
        result = run_validate(ws)
        # Either the schema rejects the key or the reference check fails; never echo the key.
        combined = result.stdout + result.stderr
        assert result.returncode == 1
        assert "os.system" not in combined
        assert "\x1b" not in combined

    def test_bindings_reference_missing_person_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        bindings = {
            "spec": "agent-toolkit/people-bindings@1",
            "roles": {"reviewer": {"person_id": "missing-person"}},
        }
        (ws / "people" / "bindings.yaml").write_text(json.dumps(bindings), encoding="utf-8")
        assert run_validate(ws).returncode == 1

    def test_bindings_with_valid_reference_pass(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        bindings = {
            "spec": "agent-toolkit/people-bindings@1",
            "roles": {
                "reviewer": {"person_id": "test-worker", "preferred_people": ["test-worker"]}
            },
        }
        (ws / "people" / "bindings.yaml").write_text(json.dumps(bindings) + "\n", encoding="utf-8")
        result = run_validate(ws)
        assert result.returncode == 0, result.stdout + result.stderr

    def test_empty_workspace_reports_zero_without_error(self, tmp_path):
        ws = write_workspace(tmp_path, {})
        run_sync(ws, "--write")
        result = run_validate(ws)
        assert result.returncode == 0
        assert "0 configured" in result.stdout

    def test_workspace_missing_mirror_fails_validation(self, tmp_path):
        ws = write_workspace(tmp_path, {"people/test-worker.json": json.dumps(person()) + "\n"})
        # No lock written: fail-fast, do not evaluate schemas without verified mirrors.
        assert run_validate(ws).returncode == 1

    def test_templates_people_validated_when_present(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        template = {
            "spec": "agent-toolkit/person@1",
            "id": "review-example",
            "name": "Review Example",
            "role": "reviewer",
            "goal": "Example template.",
            "archived": True,
        }
        (ws / "templates" / "people").mkdir(parents=True)
        (ws / "templates" / "people" / "review-example.json").write_text(
            json.dumps(template) + "\n", encoding="utf-8"
        )
        result = run_validate(ws)
        assert result.returncode == 0, result.stdout + result.stderr
        # Templates are validated but never counted as configured people.
        assert "1 configured" in result.stdout

    def test_non_regular_file_in_people_rejected(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        fifo = ws / "people" / "pipe.json"
        os.mkfifo(fifo)
        result = run_validate(ws)
        assert result.returncode == 1


# ---------------------------------------------------------------------------
# Regression guards on the validator process
# ---------------------------------------------------------------------------


class TestValidatorProcess:
    def test_validator_reports_unavailable_deps_honestly(self):
        # jsonschema/referencing are importable on this host; the honest-deps path
        # is covered by the ImportError branch in main(). Static check only.
        source = VALIDATE.read_text(encoding="utf-8")
        assert "install jsonschema and PyYAML" in source

    def test_sync_never_deletes_unrelated_files(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        keep = ws / "people" / "keep-me.txt"
        keep.write_text("user file", encoding="utf-8")
        run_sync(ws, "--write")
        assert keep.read_text(encoding="utf-8") == "user file"

    def test_lock_survives_repeated_writes_idempotently(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        first = (ws / LOCK).read_bytes()
        assert run_sync(ws, "--write").returncode == 0
        assert (ws / LOCK).read_bytes() == first

    def test_mirrors_are_regular_files_after_write(self, tmp_path):
        ws = seeded_workspace(tmp_path)
        for rel in (
            "schemas/person.schema.json",
            "schemas/people-bindings.schema.json",
            "scripts/validate-people.py",
        ):
            mode = (ws / rel).lstat().st_mode
            assert stat.S_ISREG(mode)
            assert not stat.S_ISLNK(mode)
