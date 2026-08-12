"""AI-assisted comment attribution for loop-gh-gate."""

from __future__ import annotations

from pathlib import Path

from agent_toolkit.loop import gh_gate
from agent_toolkit.loop.runner import _parse_attribution_config


def test_format_attribution_prefix_includes_login_and_loop() -> None:
    text = gh_gate.format_attribution_prefix(login="ulises-jeremias", loop_name="oss-triage")
    assert text.startswith("> 🤖 AI-assisted")
    assert "`@ulises-jeremias`" in text
    assert "(`oss-triage`)" in text
    assert "https://github.com/ulises-jeremias/agent-toolkit" in text


def test_apply_attribution_is_idempotent() -> None:
    prefix = gh_gate.format_attribution_prefix(login="me", loop_name="x")
    once = gh_gate.apply_attribution_to_body("Hello world", prefix)
    twice = gh_gate.apply_attribution_to_body(once, prefix)
    assert once == twice
    assert once.startswith("> 🤖 AI-assisted")
    assert "Hello world" in once


def test_inject_attribution_rewrites_body_flag() -> None:
    prefix = gh_gate.format_attribution_prefix(login="me", loop_name="oss-triage")
    argv = ["issue", "comment", "12", "--repo", "o/r", "--body", "Thanks"]
    out, injected = gh_gate.inject_attribution_argv(argv, prefix=prefix)
    assert injected is True
    assert out[out.index("--body") + 1].startswith("> 🤖 AI-assisted")
    assert "Thanks" in out[out.index("--body") + 1]


def test_inject_attribution_rewrites_body_file(tmp_path: Path) -> None:
    prefix = gh_gate.format_attribution_prefix(login="me", loop_name="oss-triage")
    body_file = tmp_path / "body.md"
    body_file.write_text("Please rebase.\n", encoding="utf-8")
    run_dir = tmp_path / "run"
    run_dir.mkdir()
    argv = ["pr", "comment", "3", "--body-file", str(body_file)]
    out, injected = gh_gate.inject_attribution_argv(argv, prefix=prefix, run_dir=run_dir)
    assert injected is True
    new_path = Path(out[out.index("--body-file") + 1])
    assert new_path.exists()
    text = new_path.read_text(encoding="utf-8")
    assert text.startswith("> 🤖 AI-assisted")
    assert "Please rebase." in text


def test_inject_attribution_rewrites_field_body() -> None:
    prefix = gh_gate.format_attribution_prefix(login="me", loop_name="oss-triage")
    argv = ["api", "-X", "POST", "repos/o/r/issues/1/comments", "-f", "body=hi"]
    out, injected = gh_gate.inject_attribution_argv(argv, prefix=prefix)
    assert injected is True
    assert any(a.startswith("body=") and "> 🤖 AI-assisted" in a for a in out)


def test_parse_attribution_config_defaults_and_opt_out() -> None:
    assert _parse_attribution_config({}) == {"enabled": True, "template": ""}
    assert _parse_attribution_config({"attribution": False})["enabled"] is False
    assert _parse_attribution_config({"attribution": {"enabled": False}})["enabled"] is False
    cfg = _parse_attribution_config(
        {"attribution": {"enabled": True, "template": "> custom `{login}`"}}
    )
    assert cfg["enabled"] is True
    assert "custom" in cfg["template"]


def test_install_gh_shim_sets_attribution_env(tmp_path: Path, monkeypatch) -> None:
    fake_gh = tmp_path / "real-gh"
    fake_gh.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    fake_gh.chmod(0o755)
    monkeypatch.setattr(gh_gate, "resolve_github_login", lambda _real=None: "tester")
    env = gh_gate.install_gh_shim(
        tmp_path / "run",
        tier="L2",
        allowlist=["comment"],
        deny=["merge"],
        real_gh=str(fake_gh),
        attribution_enabled=True,
        loop_name="oss-triage",
        github_login="tester",
    )
    assert env["LOOP_GATE_ATTRIBUTION"] == "1"
    assert env["LOOP_GATE_LOOP_NAME"] == "oss-triage"
    assert env["LOOP_GATE_GITHUB_LOGIN"] == "tester"

    env_off = gh_gate.install_gh_shim(
        tmp_path / "run2",
        tier="L2",
        allowlist=["comment"],
        deny=[],
        real_gh=str(fake_gh),
        attribution_enabled=False,
        loop_name="oss-triage",
    )
    assert env_off["LOOP_GATE_ATTRIBUTION"] == "0"
