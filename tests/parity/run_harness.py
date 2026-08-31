#!/usr/bin/env python3
"""V CLI contract harness (formerly Python↔V parity, #548).

Python CLI quarantine is removed — fixtures validate the V binary only.

Usage:
  PARITY_V_BIN=./build/agent-toolkit \\
    python3 tests/parity/run_harness.py
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


def check_fixture(fx: dict[str, Any], v_bin: str) -> None:
    command = fx["command"]
    cls = fx["class"]
    args = list(fx.get("args", []))
    v = run_argv([v_bin, *args])
    blob_v = v.stdout + v.stderr
    v_n = normalize(v.stdout)

    if cls in ("EXACT", "NORMALIZED_EXACT", "SEMANTIC", "V_SEMANTIC", "SCHEMA"):
        # Prefer V-specific expect keys; fall back to shared expect_exit.
        if cls == "SCHEMA":
            expect = fx.get("expect_v_exit", 0)
        elif cls == "V_SEMANTIC":
            expect = fx.get("expect_v_exit", fx.get("expect_exit", 0))
        else:
            expect = fx.get("expect_v_exit", fx.get("expect_exit", 0))
        if v.exit_code != expect:
            fail(command, cls, f"v exit {v.exit_code} != {expect}")

        if cls == "EXACT" and fx.get("compare") == "exit_only":
            return

        if cls == "SCHEMA":
            try:
                v_data = json.loads(v.stdout)
            except json.JSONDecodeError as exc:
                fail(command, cls, f"v stdout not JSON: {exc}")
            if isinstance(v_data, list):
                # bare JSON arrays (e.g. `swarm ls --json`) carry no top-level keys
                if fx.get("required_keys"):
                    fail(command, cls, "array payload cannot check required_keys")
                return
            data = v_data.get("data") if isinstance(v_data.get("data"), dict) else {}
            for key in fx.get("required_keys", []):
                if key not in v_data and key not in data:
                    fail(command, cls, f"missing key {key!r}")
            return

        if rx := fx.get("stdout_regex"):
            if not re.search(rx, v_n):
                fail(command, cls, f"v stdout !~ {rx}")
        if prefix := fx.get("stdout_prefix"):
            if not v_n.startswith(prefix):
                fail(command, cls, f"v missing prefix {prefix}")
        for needle in fx.get("must_contain", []):
            if needle.lower() not in blob_v.lower():
                fail(command, cls, f"v missing {needle!r}")
        for needle in fx.get("must_not_contain", []):
            if needle.lower() in blob_v.lower():
                fail(command, cls, f"v unexpectedly contains {needle!r}")
        return

    fail(command, cls, f"unsupported class {cls}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--v-bin",
        default=os.environ.get(
            "PARITY_V_BIN",
            str(ROOT / "build" / "agent-toolkit"),
        ),
    )
    args = parser.parse_args()
    v_bin = args.v_bin
    if not Path(v_bin).exists():
        # Historical default name from dual-engine era
        alt = ROOT / "build" / "agent-toolkit-v"
        if alt.exists():
            v_bin = str(alt)
        else:
            print(
                f"ERROR: V binary not found: {v_bin} (build with `./make.vsh build-cli`)",
                file=sys.stderr,
            )
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
