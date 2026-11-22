#!/usr/bin/env python3
"""Creative project scaffold, manifest log and environment doctor.

Implements the portable project/artifact model used by the creative
skills: sources are referenced (never copied or modified), generated
artifacts live in dedicated directories, and every operation is appended
to project.json with tool provenance so an interrupted session can resume.

Usage:
  creative_project.py init <dir> [--name NAME]
  creative_project.py add-source <dir> <media-path>
  creative_project.py log-op <dir> --tool TOOL --action TEXT [--artifact PATH]...
  creative_project.py status <dir>
  creative_project.py doctor
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = 1
DIRS = ("sources", "analysis", "edit", "assets", "preview", "export", "qa")
TOOLS = {
    "kdenlive": ("kdenlive", ["--version"]),
    "melt": ("melt", ["--version"]),
    "ffmpeg": ("ffmpeg", ["-version"]),
    "ffprobe": ("ffprobe", ["-version"]),
    "blender": ("blender", ["--version"]),
    "gimp": ("gimp", ["--version"]),
    "krita": ("krita", ["--version"]),
    "inkscape": ("inkscape", ["--version"]),
    "obs": ("obs", ["--version"]),
    "reaper": ("reaper", ["-h"]),
    "kdenlive-mcp": ("kdenlive-mcp", ["--version"]),
}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def manifest_path(root: Path) -> Path:
    return root / "project.json"


def load(root: Path) -> dict:
    p = manifest_path(root)
    if not p.is_file():
        raise SystemExit(f"no creative project at {root} (run init first)")
    return json.loads(p.read_text())


def save(root: Path, data: dict) -> None:
    tmp = root / ".project.json.tmp"
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    os.replace(tmp, manifest_path(root))


def contained(root: Path, target: Path) -> Path:
    """Resolve symlinks and refuse paths escaping the project root."""
    resolved = target.resolve()
    if resolved != root.resolve() and root.resolve() not in resolved.parents:
        raise SystemExit(f"path escapes project root: {target}")
    return resolved


def sha256_head(path: Path, limit: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        h.update(f.read(limit))
    return h.hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def cmd_init(args: argparse.Namespace) -> None:
    root = Path(args.dir).resolve()
    if manifest_path(root).exists():
        raise SystemExit(f"project already exists at {root}")
    for d in DIRS:
        (root / d).mkdir(parents=True, exist_ok=True)
    data = {
        "schema": SCHEMA,
        "name": args.name or root.name,
        "created": now(),
        "updated": now(),
        "sources": [],
        "operations": [],
        "artifacts": [],
    }
    save(root, data)
    print(f"created creative project at {root}")


def cmd_add_source(args: argparse.Namespace) -> None:
    root = Path(args.dir).resolve()
    data = load(root)
    media = Path(args.media).resolve()
    if not media.is_file():
        raise SystemExit(f"source does not exist: {media}")
    st = media.stat()
    entry = {
        "path": str(media),
        "size": st.st_size,
        "mtime_ns": st.st_mtime_ns,
        "sha256": sha256_file(media),
        "added": now(),
        "note": "referenced only; never modified in place",
    }
    data["sources"].append(entry)
    data["updated"] = now()
    save(root, data)
    print(f"added source {media} ({st.st_size} bytes)")


def cmd_log_op(args: argparse.Namespace) -> None:
    root = Path(args.dir).resolve()
    data = load(root)
    artifacts = []
    for a in args.artifact or []:
        p = Path(a)
        if not p.is_absolute():
            p = root / p
        artifacts.append(str(contained(root, p)))
    op = {
        "at": now(),
        "tool": args.tool,
        "action": args.action,
        "status": args.status,
        "artifacts": artifacts,
    }
    data["operations"].append(op)
    data["artifacts"].extend(artifacts)
    data["updated"] = now()
    save(root, data)
    print(f"logged: {args.tool} — {args.action} ({args.status})")


def verify_sources(data: dict) -> tuple[list[str], list[str]]:
    problems = []
    warnings = []
    for s in data["sources"]:
        p = Path(s["path"])
        if not p.is_file():
            problems.append(f"source missing: {p}")
            continue
        st = p.stat()
        if st.st_size != s["size"] or st.st_mtime_ns != s["mtime_ns"]:
            problems.append(f"source changed since add: {p}")
            continue
        expected_hash = s.get("sha256")
        if expected_hash and sha256_file(p) != expected_hash:
            problems.append(f"source content changed since add: {p}")
            continue
        legacy_hash = s.get("sha256_head_1mb")
        if legacy_hash:
            if sha256_head(p) != legacy_hash:
                problems.append(f"source content changed since add: {p}")
                continue
            warnings.append(f"source has only a first-MiB digest: {p}")
        elif not expected_hash:
            warnings.append(f"source has no content digest: {p}")
    return problems, warnings
    return problems


def cmd_status(args: argparse.Namespace) -> None:
    root = Path(args.dir).resolve()
    data = load(root)
    print(f"project: {data['name']}  updated: {data['updated']}")
    print(
        f"sources: {len(data['sources'])}  operations: {len(data['operations'])}  "
        f"artifacts: {len(data['artifacts'])}"
    )
    problems, warnings = verify_sources(data)
    for warning in warnings:
        print(f"WARN {warning}")
    if problems:
        for p in problems:
            print(f"FAIL {p}")
        raise SystemExit(1)
    if warnings:
        print(
            f"source metadata verified; {len(warnings)} source digest(s) need stronger verification"
        )
    else:
        print("source content verified: OK")


def probe_tool(name: str, cmd: str, ver_args: list[str]) -> dict:
    exe = shutil.which(cmd)
    if not exe:
        return {"tool": name, "status": "unsupported", "detail": "not on PATH"}
    try:
        out = subprocess.run([exe, *ver_args], capture_output=True, text=True, timeout=15)
        output = (out.stdout or out.stderr).strip()
        if out.returncode != 0:
            detail = output.splitlines()[0][:80] if output else "no version output"
            return {
                "tool": name,
                "status": "configured-unavailable",
                "detail": f"version command exited {out.returncode}: {detail}",
            }
        if not output:
            return {
                "tool": name,
                "status": "configured-unavailable",
                "detail": "version command returned no output",
            }
        version = output.splitlines()[0][:80]
    except Exception as exc:  # noqa: BLE001 - report, never crash the doctor
        return {"tool": name, "status": "configured-unavailable", "detail": str(exc)}
    return {"tool": name, "status": "available", "detail": f"{version} [{exe}]"}


def cmd_doctor(args: argparse.Namespace) -> None:
    rows = [probe_tool(n, c, a) for n, (c, a) in TOOLS.items()]
    core = {"kdenlive", "melt", "ffmpeg", "ffprobe"}
    missing = [r["tool"] for r in rows if r["tool"] in core and r["status"] != "available"]
    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        for r in rows:
            print(f"{r['tool']:<14} {r['status']:<26} {r['detail']}")
    if missing:
        if not args.json:
            print(f"core tools missing: {', '.join(missing)}")
        raise SystemExit(1)
    if not args.json:
        print("core media tools available (MCP servers still need per-tool diagnose)")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(required=True)
    i = sub.add_parser("init")
    i.add_argument("dir")
    i.add_argument("--name")
    i.set_defaults(fn=cmd_init)
    a = sub.add_parser("add-source")
    a.add_argument("dir")
    a.add_argument("media")
    a.set_defaults(fn=cmd_add_source)
    log_parser = sub.add_parser("log-op")
    log_parser.add_argument("dir")
    log_parser.add_argument("--tool", required=True)
    log_parser.add_argument("--action", required=True)
    log_parser.add_argument("--status", default="succeeded")
    log_parser.add_argument("--artifact", action="append")
    log_parser.set_defaults(fn=cmd_log_op)
    s = sub.add_parser("status")
    s.add_argument("dir")
    s.set_defaults(fn=cmd_status)
    d = sub.add_parser("doctor")
    d.add_argument("--json", action="store_true")
    d.set_defaults(fn=cmd_doctor)
    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
