#!/usr/bin/env python3
"""Render the weekly upstream-sync PR body from apply summary JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _load_summary(paths: list[Path]) -> dict:
    for cand in paths:
        if cand.exists():
            try:
                return json.loads(cand.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
    return {}


def render(summary: dict) -> str:
    applied = summary.get("applied") or []
    lines = [
        "## Summary",
        "",
        "Automated upstream sync via `scripts/provenance.py updates --apply`.",
        "Vendored `SKILL.md` bodies are byte-identical to upstream; only Toolkit",
        "frontmatter overlay differs. **Do not auto-merge.**",
        "",
        "## Updates",
        "",
    ]
    if not applied:
        lines.append("_See workflow logs for details._")
    for item in applied:
        lines.append(
            f"- `{item.get('capability')}` / `{item.get('source')}`: "
            f"`{str(item.get('old_commit', ''))[:7]}` → "
            f"`{str(item.get('new_commit', ''))[:7]}` "
            f"(body `{str(item.get('body_checksum', ''))[:23]}…`)"
        )
    lines += [
        "",
        "## Reviewer checklist",
        "",
        "- [ ] Diff shows only expected upstream body/sibling changes + pin bumps",
        "- [ ] License SPDX unchanged (or intentional license change reviewed)",
        "- [ ] `security.*` surface still accurate (shell/network/mcp/hooks)",
        "- [ ] Set `trust.tier: reviewed` and `trust.reviewed_provenance` to the new",
        "      `provenance_digest` in each updated `SKILL.md` after audit",
        "- [ ] `python3 scripts/provenance.py check` passes",
        "",
        "## Notes",
        "",
        "- Bot leaves `trust.tier: experimental` and drops `reviewed_provenance`.",
        "- Offline CI (`validate-upstream`) must stay green without network.",
        "",
    ]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Write upstream-sync PR body markdown")
    p.add_argument(
        "--summary",
        action="append",
        default=[],
        help="JSON summary path (repeatable; first readable wins)",
    )
    p.add_argument("-o", "--output", help="Write markdown here (default stdout)")
    args = p.parse_args(argv)
    paths = [Path(s) for s in args.summary] or [
        Path("/tmp/upstream-apply-summary.json"),
        Path("/tmp/apply.json"),
    ]
    text = render(_load_summary(paths))
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
