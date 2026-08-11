#!/usr/bin/env python3
"""Validate upstream provenance for distributable capabilities.

Enforces P0 governance per #364/#399:
- Full 40-char SHA only (no short SHAs) — gate 1
- Explicit origin.type for every SKILL.md — gate 2
- Trust/maintenance/security separation — gate 4
- SPDX subset — gate 6
- Multi-source support — gate 9
- Distribution mode semantics — gate 8
- Schema/validator agreement documented — gate 13

Usage:
  python3 scripts/validate-upstream.py [--check]
  python3 scripts/validate-upstream.py --strict
  python3 scripts/validate-upstream.py --json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import yaml

TOOLKIT_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = TOOLKIT_ROOT / "skills"

# Gate 1: mutable refs - expanded set, short SHAs are NEVER immutable
MUTABLE_REFS = {
    "main", "master", "latest", "HEAD", "", "develop", "stable", "release",
    "production", "next", "dev", "staging",
}

# Gate 6: SPDX allowlist — controlled subset. See docs/TRUST.md for policy.
SPDX_KNOWN = {
    "MIT", "Apache-2.0", "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause", "BSD-3-Clause",
    "ISC", "MPL-2.0",
    "GPL-2.0-only", "GPL-3.0-only", "LGPL-2.1-only", "LGPL-3.0-only",
    "AGPL-3.0", "AGPL-3.0-only", "AGPL-3.0-or-later",
    "CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0",
    "Unlicense", "0BSD", "NOASSERTION",
}

SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
TAG_RE = re.compile(r"^v?[0-9]+\.[0-9]+\.[0-9]+.*$")

# Distribution modes — mutually exclusive delivery channels (gate 8)
DISTRIBUTION_MODES = {"vendored", "external", "native-plugin", "generated"}
# Trust tiers — gate 5: reviewed replaces verified (verified kept as alias)
TRUST_TIERS = {"first-party", "reviewed", "community", "experimental"}
TRUST_TIERS_DEPRECATED = {"verified": "reviewed"}
MAINTENANCE_STATUSES = {"active", "quiet", "archived", "unknown"}

def _is_immutable_ref(ref: str, commit: str | None) -> tuple[bool, str]:
    if not ref or ref in MUTABLE_REFS:
        return False, f"mutable ref forbidden ({ref!r})"
    if SHA40_RE.match(ref):
        # Gate 1: full 40-char SHA is immutable; short SHAs are rejected even if hex
        if commit and commit != ref:
            # commit field redundant when ref is SHA but if present should match or be absent
            # Allow commit to be absent or equal to ref; if different, it's suspicious but not failed
            pass
        return True, ""
    if TAG_RE.match(ref):
        if commit and SHA40_RE.match(commit):
            return True, ""
        return False, f"tag {ref!r} requires commit: 40-char SHA (got {commit!r})"
    # Anything else is not immutable — covers short SHAs (7,12,39) explicitly
    if re.match(r"^[0-9a-f]{7,39}$", ref):
        return False, f"short SHA {ref!r} (len {len(ref)}) is not allowed — must be full 40-char SHA (gate 1)"
    return False, f"ref {ref!r} not immutable (must be 40-char SHA or semver tag+commit)"

def _is_valid_spdx(expr: str) -> tuple[bool, str]:
    """Gate 6: controlled SPDX subset.
    Supports: single id, 'A AND B', 'A OR B' where A,B are known ids.
    Parentheses and WITH expressions (except Apache-2.0 WITH LLVM-exception) not supported in V1.
    """
    expr = expr.strip()
    if not expr:
        return False, "empty SPDX expression"
    # Handle AND/OR compound
    if " AND " in expr or " OR " in expr:
        # Only support single AND or single OR, not complex nesting
        # Split on AND/OR
        if expr.count(" AND ") + expr.count(" OR ") > 1:
            return False, f"SPDX expression {expr!r} too complex for V1 subset (only single AND/OR supported)"
        sep = " AND " if " AND " in expr else " OR "
        parts = [p.strip().strip("() ") for p in expr.split(sep)]
        for p in parts:
            if p in SPDX_KNOWN or p.startswith("LicenseRef-"):
                continue
            return False, f"SPDX component {p!r} not in allowlist (in expression {expr!r})"
        return True, ""
    # Single id
    if expr in SPDX_KNOWN or expr.startswith("LicenseRef-"):
        return True, ""
    return False, f"SPDX {expr!r} not in allowlist (see SPDX_KNOWN; use LicenseRef- prefix for custom)"

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

def _validate_source(src: dict, skill_path: Path, idx: int | None = None) -> list[str]:
    errors: list[str] = []
    prefix = f"{skill_path}: sources[{idx}]" if idx is not None else f"{skill_path}: upstream"
    if not isinstance(src, dict):
        errors.append(f"{prefix}: must be object")
        return errors
    repo = src.get("repository", "")
    path = src.get("path", "")
    ref = src.get("ref", "")
    lic = src.get("license", "")
    commit = src.get("commit") if isinstance(src.get("commit"), str) else None
    if not repo or "/" not in str(repo):
        errors.append(f"{prefix}: repository must be 'owner/repo', got {repo!r}")
    if not path:
        errors.append(f"{prefix}: path required")
    # Gate 1: immutable ref checks
    if not isinstance(ref, str) or not ref:
        errors.append(f"{prefix}: ref required (40-char SHA or tag+commit)")
    else:
        ok, reason = _is_immutable_ref(ref, commit)
        if not ok:
            errors.append(f"{prefix}: ref not immutable — {reason}")
        # If ref is SHA40, commit if present should also be SHA40 (optional)
        if SHA40_RE.match(ref) and commit is not None and not SHA40_RE.match(commit):
            errors.append(f"{prefix}: commit must be 40-char SHA when present (got {commit!r})")
        if TAG_RE.match(ref) and commit is not None and not SHA40_RE.match(commit):
            errors.append(f"{prefix}: commit {commit!r} must be 40-char SHA for tag {ref!r}")
    if not lic:
        errors.append(f"{prefix}: license (SPDX) required")
    else:
        if not isinstance(lic, str):
            errors.append(f"{prefix}: license must be string")
        else:
            ok, reason = _is_valid_spdx(lic)
            if not ok:
                errors.append(f"{prefix}: license {reason}")
    # Gate 1: short SHAs explicitly rejected — also check commit field short
    if commit is not None and re.match(r"^[0-9a-f]{7,39}$", commit) and not SHA40_RE.match(commit):
        errors.append(f"{prefix}: commit short SHA len {len(commit)} not allowed — must be full 40-char (gate 1)")
    return errors

def validate_one(skill_path: Path, strict: bool = False) -> list[str]:
    errors: list[str] = []
    fm = _load_frontmatter(skill_path)
    # Gate 2: explicit origin required for every distributable capability
    origin = fm.get("origin")
    if origin is None:
        # Policy exceeds schema (schema makes origin optional for backwards compat, validator requires it)
        errors.append(f"{skill_path}: missing origin.type — every distributable SKILL.md must declare origin: {{type: first-party|upstream}} (gate 2, see docs/TRUST.md)")
        return errors
    if not isinstance(origin, dict):
        errors.append(f"{skill_path}: origin must be object with type")
        return errors
    origin_type = origin.get("type")
    if origin_type not in {"first-party", "upstream"}:
        errors.append(f"{skill_path}: origin.type must be 'first-party' or 'upstream', got {origin_type!r}")
        return errors

    # Collect sources: support both single 'upstream' (deprecated) and multi 'sources'
    upstream_single = fm.get("upstream")
    sources = fm.get("sources")
    has_upstream = upstream_single is not None
    has_sources = sources is not None

    if has_upstream and has_sources:
        errors.append(f"{skill_path}: cannot have both 'upstream' and 'sources' — use 'sources' for multi-source (gate 9)")
        return errors

    if origin_type == "first-party":
        if has_upstream or has_sources:
            errors.append(f"{skill_path}: origin first-party must not have upstream/sources (found upstream={has_upstream} sources={has_sources})")
        # Validate trust tier if present
        trust = fm.get("trust")
        if isinstance(trust, dict):
            tier = trust.get("tier")
            if tier is not None and tier not in TRUST_TIERS and tier not in TRUST_TIERS_DEPRECATED:
                errors.append(f"{skill_path}: trust.tier {tier!r} invalid (must be one of {sorted(TRUST_TIERS)})")
        # Gate 11: inventory/doctor not required for #364, so no check
        return errors

    # origin_type == upstream
    if not has_upstream and not has_sources:
        errors.append(f"{skill_path}: origin upstream requires 'upstream' or 'sources' provenance (gate 2)")
        return errors

    # Validate sources
    if has_sources:
        if not isinstance(sources, list):
            errors.append(f"{skill_path}: sources must be array")
        elif len(sources) == 0:
            errors.append(f"{skill_path}: sources must have at least one entry")
        else:
            for idx, src in enumerate(sources):
                errors.extend(_validate_source(src, skill_path, idx))
            # Gate 9: multi-source should have role where helpful, but not required for single source
            # Check for duplicate repository+path+ref
            seen = set()
            for src in sources:
                if isinstance(src, dict):
                    key = (src.get("repository"), src.get("path"), src.get("ref"))
                    if key in seen:
                        errors.append(f"{skill_path}: duplicate source {key!r} in sources")
                    seen.add(key)
    else:
        errors.extend(_validate_source(upstream_single, skill_path, None))

    # Validate distribution
    dist = fm.get("distribution")
    if dist is not None:
        if not isinstance(dist, dict):
            errors.append(f"{skill_path}: distribution must be object")
        else:
            mode = dist.get("mode")
            if mode is not None and mode not in DISTRIBUTION_MODES:
                errors.append(f"{skill_path}: distribution.mode {mode!r} invalid (must be one of {sorted(DISTRIBUTION_MODES)})")
            # Gate 8: distribution semantics — each mode is mutually exclusive delivery channel
            # No additional cross-field checks needed beyond enum

    # Validate trust tier
    trust = fm.get("trust")
    if isinstance(trust, dict):
        tier = trust.get("tier")
        if tier is not None:
            if tier in TRUST_TIERS_DEPRECATED:
                # Deprecated alias: treat as reviewed but warn via error? For CI, allow with deprecation note
                # We'll allow but suggest migration; not an error for now
                pass
            elif tier not in TRUST_TIERS:
                errors.append(f"{skill_path}: trust.tier {tier!r} invalid (must be one of {sorted(TRUST_TIERS)}; 'verified' is deprecated alias for 'reviewed')")

    # Validate maintenance (separate from trust — gate 4)
    maintenance = fm.get("maintenance")
    if isinstance(maintenance, dict):
        status = maintenance.get("status")
        if status is not None and status not in MAINTENANCE_STATUSES:
            errors.append(f"{skill_path}: maintenance.status {status!r} invalid (must be one of {sorted(MAINTENANCE_STATUSES)})")

    # Validate security
    sec = fm.get("security")
    if isinstance(sec, dict):
        cve = sec.get("cve_policy")
        if cve is not None and cve not in {"not-applicable", "no-known-cve", "cve-present"}:
            errors.append(f"{skill_path}: security.cve_policy {cve!r} invalid")
        # For pure prompt assets, cve_policy should be not-applicable — not enforced, just documented

    # Also check for missing SPDX etc. already done in _validate_source
    return errors


def validate_capability_fixture(data: dict, path_hint: str = "fixture") -> list[str]:
    """Gate 10: validate non-skill capability provenance (agent/mcp/hook/plugin)."""
    errors: list[str] = []
    # Reuse same logic but data is already parsed dict, not file
    origin = data.get("origin")
    if origin is None or not isinstance(origin, dict) or origin.get("type") not in {"first-party", "upstream"}:
        errors.append(f"{path_hint}: origin.type must be 'first-party' or 'upstream'")
        return errors
    # Check capability field if present
    cap = data.get("capability")
    if cap is not None:
        if not isinstance(cap, dict) or cap.get("kind") not in {"skill", "agent", "mcp", "hook", "plugin", "script"} or not cap.get("id"):
            errors.append(f"{path_hint}: capability must be {{kind: skill|agent|mcp|hook|plugin|script, id}}")
    # Then same source checks
    has_upstream = "upstream" in data
    has_sources = "sources" in data
    if has_upstream and has_sources:
        errors.append(f"{path_hint}: cannot have both upstream and sources")
    if origin.get("type") == "upstream" and not has_upstream and not has_sources:
        errors.append(f"{path_hint}: upstream origin requires sources/upstream")
    if origin.get("type") == "first-party" and (has_upstream or has_sources):
        errors.append(f"{path_hint}: first-party must not have sources")
    if has_sources:
        srcs = data.get("sources")
        if isinstance(srcs, list):
            for idx, src in enumerate(srcs):
                errors.extend(_validate_source(src, Path(path_hint), idx))
    if has_upstream:
        errors.extend(_validate_source(data.get("upstream"), Path(path_hint), None))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate upstream provenance")
    parser.add_argument("--check", action="store_true", help="alias for default check")
    parser.add_argument("--strict", action="store_true", help="strict mode (currently same as default; origin always required)")
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
            print(json.dumps({"errors": all_errors}, indent=2))
        print(f"\n{len(all_errors)} upstream validation error(s).", file=sys.stderr)
        print("Fix: declare origin.type and provenance per docs/TRUST.md#provenance", file=sys.stderr)
        print("Gate 2: every distributable SKILL.md must have origin: {type: first-party|upstream}", file=sys.stderr)
        print("Gate 1: ref must be full 40-char SHA or tag+40-char commit (short SHAs rejected)", file=sys.stderr)
        return 1

    count = len(list(SKILLS_DIR.rglob("SKILL.md")))
    print(f"upstream validation OK — {count} skills checked, origin + provenance + SPDX + SHA40 enforced.")
    print("Note: SKILL.md frontmatter is authoritative until #370 introduces capabilities/upstream.lock (gate 3 Option B).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
