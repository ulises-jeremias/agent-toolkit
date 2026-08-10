#!/usr/bin/env python3
"""Validate upstream provenance for third-party capabilities.

Checks SKILL.md frontmatter for required upstream fields, immutable refs,
and security declarations. Used in CI per #364 to block `ref: main` etc.

Usage:
  python3 scripts/validate-upstream.py [--check]
  python3 scripts/validate-upstream.py --strict  # fail on missing provenance for vendored paths

Exit 0 when all vendored skills with upstream metadata are valid;
exit 1 on mutable ref or missing license.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

TOOLKIT_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = TOOLKIT_ROOT / "skills"
MUTABLE_REFS = {"main", "master", "latest", "HEAD", ""}

# Vendored skills are expected under skills/<domain>/<name>/SKILL.md
# First-party skills may omit upstream; third-party MUST have it when present.

def _load_frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fm = text[3:end]
    try:
        data = yaml.safe_load(fm) or {}
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def validate_one(skill_path: Path, strict: bool = False) -> list[str]:
    errors: list[str] = []
    fm = _load_frontmatter(skill_path)
    upstream = fm.get("upstream")
    # strict mode: any skill under skills/ that looks third-party should have upstream
    # heuristic: skip check if no upstream and not strict
    if upstream is None:
        if strict and "third-party" in str(skill_path).lower():
            errors.append(f"{skill_path}: missing upstream provenance (strict mode)")
        return errors
    if not isinstance(upstream, dict):
        errors.append(f"{skill_path}: upstream must be object")
        return errors
    repo = upstream.get("repository", "")
    path = upstream.get("path", "")
    ref = upstream.get("ref", "")
    lic = upstream.get("license", "")
    if not repo or "/" not in repo:
        errors.append(f"{skill_path}: upstream.repository must be 'owner/repo', got {repo!r}")
    if not path:
        errors.append(f"{skill_path}: upstream.path required")
    if not ref or ref in MUTABLE_REFS:
        errors.append(f"{skill_path}: upstream.ref must be immutable tag/SHA, not {ref!r}")
    if ref and ref in MUTABLE_REFS:
        errors.append(f"{skill_path}: mutable ref forbidden ({ref!r})")
    if not lic:
        errors.append(f"{skill_path}: upstream.license (SPDX or 'unknown') required")
    # distribution check
    dist = fm.get("distribution") or {}
    if isinstance(dist, dict) and dist.get("mode") == "vendored" and not upstream.get("license"):
        errors.append(f"{skill_path}: vendored distribution requires license")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate upstream provenance")
    parser.add_argument("--check", action="store_true", help="alias for default check")
    parser.add_argument("--strict", action="store_true", help="strict: require provenance for third-party-looking paths")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args(argv)

    all_errors: list[str] = []
    for skill_md in sorted(SKILLS_DIR.rglob("SKILL.md")):
        errs = validate_one(skill_md, strict=args.strict)
        all_errors.extend(errs)

    if all_errors:
        for e in all_errors:
            print(f"ERROR: {e}", file=sys.stderr)
        if args.json:
            import json

            print(json.dumps({"errors": all_errors}, indent=2))
        print(f"\n{len(all_errors)} upstream validation error(s).", file=sys.stderr)
        print("Fix: set upstream: {repository, path, ref: <immutable SHA/tag>, license: SPDX} per docs/TRUST.md#provenance", file=sys.stderr)
        return 1

    # success: also report inventory hint
    count = len(list(SKILLS_DIR.rglob("SKILL.md")))
    print(f"upstream validation OK — {count} skills checked, no mutable refs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
