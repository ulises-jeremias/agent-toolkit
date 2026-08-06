"""doctor --fix must propagate install return codes (CLI-005 residual)."""

from __future__ import annotations

from agent_toolkit.cli import doctor as doctor_mod


def _stub_minimal_ok(monkeypatch):
    """Make doctor checks cheap and mostly green except profiles."""
    ok = doctor_mod.CheckResult("system", "python", doctor_mod.CheckResult.STATUS_OK, "ok")
    monkeypatch.setattr(doctor_mod, "_check_python_version", lambda: ok)
    monkeypatch.setattr(
        doctor_mod,
        "_check_command",
        lambda *a, **k: doctor_mod.CheckResult(a[0], a[1], doctor_mod.CheckResult.STATUS_OK, "ok"),
    )
    monkeypatch.setattr(
        doctor_mod,
        "_check_gh_auth",
        lambda: doctor_mod.CheckResult("system", "gh auth", doctor_mod.CheckResult.STATUS_OK, "ok"),
    )
    monkeypatch.setattr(
        doctor_mod,
        "_check_ai_tool",
        lambda *a, **k: doctor_mod.CheckResult(
            "ai_tools", a[0], doctor_mod.CheckResult.STATUS_OK, "ok"
        ),
    )
    monkeypatch.setattr(doctor_mod, "_check_loop_runtime", lambda *_a, **_k: [])
    monkeypatch.setattr(doctor_mod, "_check_llm_providers", lambda: [])
    monkeypatch.setattr(doctor_mod, "_check_mcp", lambda: [])
    monkeypatch.setattr(doctor_mod, "_check_scheduled_loops", lambda: [])


def test_doctor_fix_propagates_install_failure(monkeypatch):
    _stub_minimal_ok(monkeypatch)
    warn = doctor_mod.CheckResult(
        "profiles", "cursor", doctor_mod.CheckResult.STATUS_WARN, "missing"
    )
    monkeypatch.setattr(doctor_mod, "_check_profiles", lambda: [warn])

    called = {"n": 0}

    def fake_install(args):
        called["n"] += 1
        return 3

    monkeypatch.setattr("agent_toolkit.cli.install.cmd_install", fake_install)

    assert doctor_mod.cmd_doctor(["--fix"]) == 3
    assert called["n"] == 1

    called["n"] = 0
    assert doctor_mod.cmd_doctor(["--json", "--fix"]) == 3
    assert called["n"] == 1


def test_doctor_fix_ok_when_install_succeeds(monkeypatch):
    _stub_minimal_ok(monkeypatch)
    warn = doctor_mod.CheckResult(
        "profiles", "cursor", doctor_mod.CheckResult.STATUS_WARN, "missing"
    )
    monkeypatch.setattr(doctor_mod, "_check_profiles", lambda: [warn])
    monkeypatch.setattr("agent_toolkit.cli.install.cmd_install", lambda args: 0)
    assert doctor_mod.cmd_doctor(["--fix"]) == 0
