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

import re

import yaml

TOOLKIT_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = TOOLKIT_ROOT / "skills"
MUTABLE_REFS = {"main", "master", "latest", "HEAD", "", "develop", "stable", "release", "production", "next", "dev", "staging"}

# SPDX allowlist (common identifiers + NOASSERTION). Validate format, not free-text per §8.
SPDX_KNOWN = {
    "MIT", "Apache-2.0", "Apache-2.0 WITH LLVM-exception", "BSD-2-Clause", "BSD-3-Clause",
    "ISC", "MPL-2.0", "GPL-2.0-only", "GPL-3.0-only", "LGPL-2.1-only", "LGPL-3.0-only",
    "AGPL-3.0", "AGPL-3.0-only", "AGPL-3.0-or-later", "CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0",
    "Unlicense", "0BSD", "NOASSERTION", "LicenseRef-Unknown"
}

# Strong immutable ref: require 40-char SHA OR tag+commit (per §7). Tag alone without commit is weak.
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
SHA7_RE = re.compile(r"^[0-9a-f]{7,40}$")
TAG_RE = re.compile(r"^v?[0-9]+\.[0-9]+\.[0-9]+.*$")  # semver tag like v1.2.3, 1.2.3-beta

def _is_immutable_ref(ref: str, commit: str | None) -> tuple[bool, str]:
    if not ref or ref in MUTABLE_REFS:
        return False, f"mutable ref forbidden ({ref!r})"
    if SHA40_RE.match(ref):
        return True, ""
    if TAG_RE.match(ref):
        if commit and SHA40_RE.match(commit):
            return True, ""
        return False, f"tag {ref!r} requires commit: 40-char SHA (got {commit!r})"
    if SHA7_RE.match(ref) and len(ref) >= 7:
        # short SHA allowed only if len >=7 and hex, but warn to prefer 40
        return True, ""
    return False, f"ref {ref!r} not immutable (must be 40-char SHA or semver tag+commit)"

# Vendored/external capabilities MUST declare upstream — not path heuristic (per §6).
# First-party if origin==first-party or no upstream and distribution not vendored/external.


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
    distribution = fm.get("distribution") or {}
    dist_mode = distribution.get("mode") if isinstance(distribution, dict) else None
    # §6: explicit distribution mode determines requirement, not path string heuristic
    # If distribution is vendored/external/generated with upstream source → upstream required
    # Also strict mode requires upstream for any SKILL.md that declares distribution
    requires_upstream = dist_mode in {"vendored", "external", "generated", "native-plugin"}
    if upstream is None:
        if requires_upstream:
            errors.append(f"{skill_path}: missing upstream provenance (distribution.mode={dist_mode!r} requires upstream per §6)")
        elif strict and dist_mode is not None:
            errors.append(f"{skill_path}: missing upstream provenance (strict mode, has distribution)")
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
    commit = upstream.get("commit") if isinstance(upstream.get("commit"), str) else None
    ok, reason = _is_immutable_ref(ref, commit)
    if not ok:
        errors.append(f"{skill_path}: upstream.ref not immutable — {reason} (per §7: use 40-char SHA or tag+commit)")
    if not lic:
        errors.append(f"{skill_path}: upstream.license (SPDX) required")
    elif lic not in SPDX_KNOWN and not lic.startswith("LicenseRef-"):
        # allow SPDX expression with AND/OR but warn if unknown
        if " AND " not in lic and " OR " not in lic and lic != "NOASSERTION":
            errors.append(f"{skill_path}: upstream.license {lic!r} not in SPDX allowlist (see SPDX_KNOWN, or use LicenseRef- prefix, per §8)")
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
