"""doctor --swarm reports tmux, herdr, and offline plan health."""

from __future__ import annotations

from agent_toolkit.cli import doctor as doctor_mod


def _stub_ok_result(category: str, name: str) -> doctor_mod.CheckResult:
    return doctor_mod.CheckResult(category, name, doctor_mod.CheckResult.STATUS_OK, "ok")


def _make_doctor_green(monkeypatch):
    monkeypatch.setattr(
        doctor_mod, "_check_python_version", lambda: _stub_ok_result("system", "python")
    )
    monkeypatch.setattr(
        doctor_mod,
        "_check_command",
        lambda *a, **k: doctor_mod.CheckResult(a[0], a[1], doctor_mod.CheckResult.STATUS_OK, "ok"),
    )
    monkeypatch.setattr(
        doctor_mod,
        "_check_gh_auth",
        lambda: _stub_ok_result("system", "gh auth"),
    )
    monkeypatch.setattr(
        doctor_mod,
        "_check_ai_tool",
        lambda *a, **k: doctor_mod.CheckResult(a[0], a[1], doctor_mod.CheckResult.STATUS_OK, "ok"),
    )
    monkeypatch.setattr(doctor_mod, "_check_profiles", lambda: [])
    monkeypatch.setattr(doctor_mod, "_check_loop_runtime", lambda *_a, **_k: [])
    monkeypatch.setattr(doctor_mod, "_check_llm_providers", lambda: [])
    monkeypatch.setattr(doctor_mod, "_check_mcp", lambda: [])
    monkeypatch.setattr(doctor_mod, "_check_scheduled_loops", lambda: [])


def test_swarm_section_present_when_tmux_and_herdr_available(monkeypatch):
    _make_doctor_green(monkeypatch)

    called_which = {"calls": []}
    _orig_which = doctor_mod.shutil.which

    def _fake_which(cmd):
        called_which["calls"].append(cmd)
        if cmd in ("tmux", "herdr"):
            return f"/usr/local/bin/{cmd}"
        return _orig_which(cmd)

    monkeypatch.setattr(doctor_mod.shutil, "which", _fake_which)
    monkeypatch.setattr(
        doctor_mod.subprocess,
        "run",
        lambda args, **kwargs: _fake_run(args, kwargs.get("timeout", 5)),
    )

    monkeypatch.setattr(
        doctor_mod,
        "_check_swarm",
        lambda: [
            doctor_mod.CheckResult("swarm", "tmux", doctor_mod.CheckResult.STATUS_OK, "tmux 3.4"),
            doctor_mod.CheckResult("swarm", "herdr", doctor_mod.CheckResult.STATUS_OK, "herdr 1.0"),
            doctor_mod.CheckResult(
                "swarm",
                "swarm plan (offline)",
                doctor_mod.CheckResult.STATUS_OK,
                "skeleton runner plan succeeded",
            ),
        ],
    )

    rc = doctor_mod.cmd_doctor([])
    assert rc == 0


def test_swarm_warns_when_deps_missing(monkeypatch):
    _make_doctor_green(monkeypatch)

    monkeypatch.setattr(
        doctor_mod,
        "_check_swarm",
        lambda: [
            doctor_mod.CheckResult(
                "swarm",
                "tmux",
                doctor_mod.CheckResult.STATUS_WARN,
                "not found — install with: brew install tmux / apt install tmux",
            ),
            doctor_mod.CheckResult(
                "swarm",
                "herdr",
                doctor_mod.CheckResult.STATUS_WARN,
                "not found — install from https://herdr.dev/docs/install/",
            ),
            doctor_mod.CheckResult(
                "swarm",
                "swarm plan (offline)",
                doctor_mod.CheckResult.STATUS_WARN,
                "could not run plan: [Errno 2] No such file or directory",
            ),
        ],
    )

    rc = doctor_mod.cmd_doctor([])
    assert rc == 0


def test_swarm_json_includes_swarm_category(monkeypatch, capsys):
    _make_doctor_green(monkeypatch)

    monkeypatch.setattr(
        doctor_mod,
        "_check_swarm",
        lambda: [
            doctor_mod.CheckResult("swarm", "tmux", doctor_mod.CheckResult.STATUS_OK, "tmux 3.4"),
            doctor_mod.CheckResult(
                "swarm",
                "herdr",
                doctor_mod.CheckResult.STATUS_WARN,
                "not found — install from https://herdr.dev/docs/install/",
            ),
        ],
    )

    rc = doctor_mod.cmd_doctor(["--json"])
    assert rc == 0
    captured = capsys.readouterr()
    assert '"category": "swarm"' in captured.out
    assert "tmux" in captured.out
    assert "herdr" in captured.out


def _fake_run(args, timeout):
    import subprocess

    if args[0] == "tmux" and "-V" in args:
        return subprocess.CompletedProcess(args, 0, stdout="tmux 3.4\n", stderr="")
    if args[0] == "herdr" and "--version" in args:
        return subprocess.CompletedProcess(args, 0, stdout="herdr 1.0.0\n", stderr="")
    return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
