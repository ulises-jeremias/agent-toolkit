#!/usr/bin/env python3
"""Python↔V golden CLI parity harness (#548).

Design: docs/compatibility/parity-harness-design.md

Usage:
  PARITY_V_BIN=./build/agent-toolkit-v \\
    python3 tests/parity/run_harness.py

  # or:
  python3 tests/parity/run_harness.py --v-bin ./build/agent-toolkit-v
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
FIXTURES_PATH = Path(__file__).resolve().parent / "fixtures" / "seed.json"


@dataclass
class RunOut:
    exit_code: int
    stdout: str
    stderr: str


def run_argv(argv: list[str], *, cwd: Path | None = None) -> RunOut:
    proc = subprocess.run(
        argv,
        capture_output=True,
        text=True,
        cwd=str(cwd or ROOT),
        check=False,
    )
    return RunOut(proc.returncode, proc.stdout, proc.stderr)


def normalize(text: str) -> str:
    t = text.replace("\r\n", "\n").strip()
    t = re.sub(r"/tmp/[^\s]+", "<TMP>", t)
    return t


def fail(command: str, cls: str, msg: str) -> None:
    raise AssertionError(f"[{command}] {cls}: {msg}")


def python_argv(args: list[str]) -> list[str]:
    return [
        "uv",
        "run",
        "--project",
        str(ROOT / "packages/agent-toolkit-cli"),
        "agent-toolkit",
        *args,
    ]


def check_fixture(fx: dict[str, Any], v_bin: str) -> None:
    command = fx["command"]
    cls = fx["class"]
    args = list(fx.get("args", []))

    py = run_argv(python_argv(args))
    v = run_argv([v_bin, *args])

    if cls == "EXACT":
        expect = fx.get("expect_exit", 0)
        if py.exit_code != expect:
            fail(command, cls, f"python exit {py.exit_code} != {expect}")
        if v.exit_code != expect:
            fail(command, cls, f"v exit {v.exit_code} != {expect}")
        if fx.get("compare") == "exit_only":
            return
        if py.stdout != v.stdout:
            fail(command, cls, f"stdout mismatch {py.stdout!r} vs {v.stdout!r}")
        return

    if cls == "NORMALIZED_EXACT":
        if py.exit_code != v.exit_code:
            fail(command, cls, f"exit {py.exit_code} != {v.exit_code}")
        py_n, v_n = normalize(py.stdout), normalize(v.stdout)
        if rx := fx.get("stdout_regex"):
            if not re.search(rx, py_n):
                fail(command, cls, f"python stdout !~ {rx}")
            if not re.search(rx, v_n):
                fail(command, cls, f"v stdout !~ {rx}")
            return
        if prefix := fx.get("stdout_prefix"):
            if not py_n.startswith(prefix):
                fail(command, cls, f"python missing prefix {prefix}")
            if not v_n.startswith(prefix):
                fail(command, cls, f"v missing prefix {prefix}")
            return
        if py_n != v_n:
            fail(command, cls, f"normalized stdout mismatch")
        return

    if cls == "SEMANTIC":
        if py.exit_code != v.exit_code:
            fail(command, cls, f"exit {py.exit_code} != {v.exit_code}")
        blob_py = py.stdout + py.stderr
        blob_v = v.stdout + v.stderr
        for needle in fx.get("must_contain", []):
            if needle.lower() not in blob_py.lower():
                fail(command, cls, f"python missing {needle!r}")
            if needle.lower() not in blob_v.lower():
                fail(command, cls, f"v missing {needle!r}")
        return

    if cls == "SCHEMA":
        expect_v = fx.get("expect_v_exit", 0)
        if v.exit_code != expect_v:
            fail(command, cls, f"v exit {v.exit_code} != {expect_v}")
        try:
            v_data = json.loads(v.stdout)
        except json.JSONDecodeError as exc:
            fail(command, cls, f"v stdout not JSON: {exc}")
        data = v_data.get("data") if isinstance(v_data.get("data"), dict) else {}
        for key in fx.get("required_keys", []):
            if key not in v_data and key not in data:
                fail(command, cls, f"missing key {key!r}")
        return

    fail(command, cls, f"unsupported class {cls}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--v-bin",
        default=os.environ.get("PARITY_V_BIN", str(ROOT / "build" / "agent-toolkit-v")),
    )
    args = parser.parse_args()
    v_bin = args.v_bin
    if not Path(v_bin).exists():
        print(f"ERROR: V binary not found: {v_bin} (build with `make build-cli`)", file=sys.stderr)
        return 2

    fixtures = json.loads(FIXTURES_PATH.read_text(encoding="utf-8"))["fixtures"]
    failed = 0
    for fx in fixtures:
        try:
            check_fixture(fx, v_bin)
            print(f"PASS {fx['command']} ({fx['class']})")
        except AssertionError as exc:
            failed += 1
            print(f"FAIL {exc}", file=sys.stderr)

    if failed:
        print(f"{failed} fixture(s) failed", file=sys.stderr)
        return 1
    print(f"OK: {len(fixtures)} fixture(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
