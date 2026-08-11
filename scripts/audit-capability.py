#!/usr/bin/env python3
"""Static supply-chain audit for capabilities (per #378).

Scans SKILL.md, MCP registry YAML, plugin manifests, and repo files for
shell/network/MCP/hook/env/dangerous permission surface without executing
untrusted code.

Usage:
  python3 scripts/audit-capability.py [path ...]          # default: skills/ mcp/
  python3 scripts/audit-capability.py --json skills/design/
  python3 scripts/audit-capability.py --fail-on high

Exit 0 when no high-severity surface; exit 2 on high findings (for CI gate).
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

TOOLKIT_ROOT = Path(__file__).resolve().parents[1]

# Patterns (static grep, not execution)
PATTERNS: dict[str, tuple[str, str]] = {
    "shell_curl": (r"\bcurl\b", "network: curl"),
    "shell_wget": (r"\bwget\b", "network: wget"),
    "shell_npx": (r"\bnpx\b", "network: npx"),
    "shell_npm": (r"\bnpm\s+(install|exec|run)\b", "shell: npm"),
    "shell_pip": (r"\bpip[3]?\b", "shell: pip"),
    "shell_uv": (r"\buv\s+(pip|run|exec)\b", "shell: uv"),
    "shell_docker": (r"\bdocker\b", "shell: docker"),
    "shell_sh_c": (r"\bsh\s+-c\b|\bbash\s+-c\b", "shell: sh -c"),
    "shell_rm_rf": (r"rm\s+-rf", "destructive: rm -rf"),
    "shell_git_push": (r"git\s+push.*main|push.*default", "destructive: push to default"),
    "network_raw_main": (r"raw\.githubusercontent.*main", "mutable fetch: raw.*main"),
    "network_main_fragment": (r"ref:\s*main\b", "mutable ref: main"),
    "hook": (r"hooks?:", "hook registration"),
    "mcp": (r"mcp/registry|mcp\.json", "MCP reference"),
    "env_secret": (r"(SECRET|TOKEN|KEY|PASSWORD)\s*[:=]", "possible credential"),
    "dangerous_skip": (
        r"skipDangerousMode|dangerouslySkipPermissions",
        "dangerous: skip permission prompt",
    ),
}

SKIP_DIRS = {".git", ".venv", "__pycache__", "node_modules", ".ruff_cache", ".mypy_cache"}
SKIP_EXTS = {".pyc", ".png", ".jpg", ".svg"}


def _should_skip(path: Path) -> bool:
    if any(p in SKIP_DIRS for p in path.parts):
        return True
    if path.suffix in SKIP_EXTS:
        return True
    return False


def audit_path(path: Path) -> list[dict]:
    findings: list[dict] = []
    if path.is_file():
        files = [path]
    elif path.is_dir():
        files = [p for p in path.rglob("*") if p.is_file() and not _should_skip(p)]
    else:
        return findings
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for key, (pat, label) in PATTERNS.items():
            for m in re.finditer(pat, text):
                line_no = text[: m.start()].count("\n") + 1
                findings.append(
                    {
                        "file": str(f.relative_to(TOOLKIT_ROOT)),
                        "line": line_no,
                        "rule": key,
                        "label": label,
                        "match": m.group(0)[:80],
                    }
                )
    return findings


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Static audit for capabilities")
    parser.add_argument("paths", nargs="*", default=["skills", "mcp"], help="paths to audit")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument(
        "--fail-on", choices=["high", "never"], default="never", help="fail CI on high findings"
    )
    args = parser.parse_args(argv)

    all_findings: list[dict] = []
    for p in args.paths:
        path = (TOOLKIT_ROOT / p) if not Path(p).is_absolute() else Path(p)
        if not path.exists():
            path = TOOLKIT_ROOT / p
        if not path.exists():
            print(f"warn: not found {p}", flush=True)
            continue
        all_findings.extend(audit_path(path))

    high_rules = {"shell_rm_rf", "shell_git_push", "network_raw_main", "dangerous_skip"}
    high = [f for f in all_findings if f["rule"] in high_rules]

    if args.json:
        print(json.dumps({"findings": all_findings, "high": high}, indent=2))
    else:
        if not all_findings:
            print(
                "audit-capability: no static findings (checked patterns: shell/curl/MCP/hooks/env)."
            )
        else:
            for f in all_findings:
                print(f"{f['file']}:{f['line']}: [{f['rule']}] {f['label']}: {f['match']}")
            print(f"\n{len(all_findings)} finding(s), {len(high)} high-severity.")
            if high:
                print(
                    "High: raw.*main, rm -rf, push default, skip permission prompt — requires human review before merge."
                )

    if args.fail_on == "high" and high:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
