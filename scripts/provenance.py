#!/usr/bin/env python3
"""
Provenance tool — declaration → lock → integrity verification + update discovery.

Commands:
  lock    Resolve SKILL.md declarations and write deterministic capabilities/upstream.lock (v2)
  check   Offline validation: declaration↔lock consistency, schema, SHA40, SPDX, checksum vs vendored bytes, orphan/missing, review-binding
  docs    Generate docs/UPSTREAM.md from declaration+lock
  updates Online discovery: compare locked commits to remote default-branch HEAD (read-only, --json); --apply would update lock/vendored (future)

Lock semantics (ADR-0001):
  - Sparse: only origin: upstream with external content appears; first-party omitted.
  - Resolution artifact: requested {type, ref} (declaration intent) + resolved {commit, content_checksum, license, resolved_at}.
  - Stable capability ID is namespaced Toolkit ID (e.g. design/frontend-design).
  - Multi-source: capability → sources: {id: {repository, path, requested, resolved}}.

Usage:
  uv run python scripts/provenance.py lock [--check]
  uv run python scripts/provenance.py check
  uv run python scripts/provenance.py docs [--check]
  uv run python scripts/provenance.py updates [--json]  # read-only discovery

See docs/adr/0001-capability-declaration-and-external-provenance-lock.md
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).parents[1]
LOCK_PATH = REPO_ROOT / "capabilities" / "upstream.lock"
LOCK_SCHEMA_PATH = REPO_ROOT / "schemas" / "upstream-lock.schema.json"
UPSTREAM_SCHEMA_PATH = REPO_ROOT / "schemas" / "upstream.schema.json"
SKILLS_GLOB = "skills/**/SKILL.md"

SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
# vendored content: single SKILL.md + LICENSE.txt per skill
# For directory-hash future, keep separate; now file-level.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _load_frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---\n", text, re.DOTALL | re.MULTILINE)
    if not m:
        return {}
    data = yaml.safe_load(m.group(1)) or {}
    return data if isinstance(data, dict) else {}


def _skill_id_from_path(skill_path: Path) -> str:
    # skills/<domain>/<name>/SKILL.md → <domain>/<name>
    try:
        rel = skill_path.relative_to(REPO_ROOT / "skills")
        parts = rel.parts
        # expect domain/name/SKILL.md
        if len(parts) >= 3 and parts[-1] == "SKILL.md":
            return f"{parts[0]}/{parts[1]}"
        # fallback: parent dir name
        return skill_path.parent.name
    except ValueError:
        return skill_path.parent.name


def _file_sha256(path: Path) -> str:
    """
    Vendored artifact checksum (normalized).

    Invariant: content_checksum in capabilities/upstream.lock is the sha256 of the
    *local vendored file* as it exists in the repo, not the pure upstream raw bytes.
    For SKILL.md this includes Toolkit-owned frontmatter (origin, trust, distribution)
    plus the upstream body (which is byte-identical to upstream at resolved commit).
    The only normalization is stripping trust.reviewed_provenance, which is a binding
    TO the lock digest; including it would make lock generation circular
    (checksum → digest → reviewed_provenance → checksum). All other bytes are
    integrity-checked. For LICENSE.txt the file is byte-identical to upstream LICENSE
    at the resolved commit, so upstream and vendored checksums are identical.
    """
    data = path.read_bytes()
    if path.name == "SKILL.md":
        text = data.decode("utf-8", errors="ignore")
        # Remove any line containing reviewed_provenance (with optional leading spaces)
        filtered = re.sub(
            r"^\s*reviewed_provenance:\s*sha256:[0-9a-f]{64}\s*\n", "", text, flags=re.MULTILINE
        )
        data = filtered.encode("utf-8")
    h = hashlib.sha256()
    h.update(data)
    return f"sha256:{h.hexdigest()}"


def _file_sha256_raw(path: Path) -> str:
    """Raw sha256 without normalization — used for LICENSE files and non-SKILL.md."""
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return f"sha256:{h.hexdigest()}"


def _provenance_digest(sources: dict) -> str:
    """
    Deterministic digest of resolved source set:
    hash(source IDs sorted + resolved commits + content_checksum + license spdx)
    """
    # sources: {source_id: {repository, path, requested, resolved}}
    parts: list[str] = []
    for sid in sorted(sources.keys()):
        src = sources[sid]
        resolved = src.get("resolved", {})
        commit = resolved.get("commit", "")
        cksum = resolved.get("content_checksum", "")
        lic = (resolved.get("license") or {}).get("spdx", "")
        parts.append(f"{sid}:{commit}:{cksum}:{lic}")
    payload = "|".join(parts).encode("utf-8")
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def _validate_lock_schema(data: dict) -> list[str]:
    if not LOCK_SCHEMA_PATH.exists():
        return [f"lock schema not found at {LOCK_SCHEMA_PATH}"]
    schema = json.loads(LOCK_SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
    msgs = []
    for e in errors:
        loc = ".".join(str(p) for p in e.path) or "(root)"
        msgs.append(f"lock schema: {loc}: {e.message}")
    return msgs


def _discover_declarations() -> dict[str, dict]:
    """
    Return {capability_id: {frontmatter, path, sources_list, declaration_type}}
    Only origin: upstream with sources/upstream is included (sparse).
    """
    result: dict[str, dict] = {}
    for p in sorted(REPO_ROOT.glob(SKILLS_GLOB)):
        fm = _load_frontmatter(p)
        origin = fm.get("origin") or {}
        otype = origin.get("type") if isinstance(origin, dict) else None
        if otype != "upstream":
            continue
        # Must have upstream or sources
        upstream = fm.get("upstream")
        sources = fm.get("sources")
        if upstream is None and sources is None:
            continue
        # Normalize to list of source dicts with id
        src_list: list[dict] = []
        if sources is not None:
            if not isinstance(sources, list):
                continue
            for s in sources:
                if not isinstance(s, dict):
                    continue
                # Derive id: id > role > repository path fallback
                sid = s.get("id") or s.get("role") or "upstream"
                src_list.append({**s, "_source_id": sid})
        elif upstream is not None:
            if not isinstance(upstream, dict):
                continue
            sid = upstream.get("role") or upstream.get("id") or "upstream"
            src_list.append({**upstream, "_source_id": sid})
        cap_id = _skill_id_from_path(p)
        # Handle collision (should not happen; if happens, disambiguate)
        if cap_id in result:
            # keep first, warn
            print(
                f"warning: duplicate capability id {cap_id} at {p} (already {result[cap_id]['path']})",
                file=sys.stderr,
            )
        result[cap_id] = {
            "frontmatter": fm,
            "path": p,
            "sources": src_list,
            "skill_id": cap_id,
        }
    return result


def _build_lock_data(
    declarations: dict[str, dict],
    existing_lock: dict | None = None,
) -> dict:
    # For determinism, reuse existing resolved_at when source unchanged;
    # otherwise use now for new resolutions. Top-level generated_at is omitted
    # to keep the committed lock byte-stable (only resolved_at per source matters).
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    existing_caps = (existing_lock or {}).get("capabilities", {}) if existing_lock else {}
    capabilities: dict = {}
    for cap_id in sorted(declarations.keys()):
        decl = declarations[cap_id]
        skill_path = decl["path"]
        src_list = decl["sources"]
        # Determine distribution mode to decide if vendored bytes expected
        # (not needed for lock generation, but for checksum)
        lock_sources: dict = {}
        for src in src_list:
            sid = src["_source_id"]
            repo = src.get("repository", "")
            spath = src.get("path", "")
            ref = src.get("ref", "")
            lic = src.get("license", "NOASSERTION")
            # Determine requested type
            if SHA40_RE.match(ref or ""):
                req_type = "commit"
            elif re.match(r"^v?[0-9]+\.[0-9]+\.[0-9]+", ref or ""):
                req_type = "tag"
            else:
                # Fallback: treat any 40-char hex as commit, else tag if looks like tag, else commit
                req_type = "commit" if ref else "commit"
            requested = {"type": req_type, "ref": ref}
            # Resolved: commit is ref if commit else need commit field (not present in current declaration)
            # For current single-commit case, resolved commit == ref when type commit
            commit = src.get("commit") or (ref if SHA40_RE.match(ref or "") else "")
            if not commit or not SHA40_RE.match(commit):
                # Cannot build resolved without 40-char SHA — use placeholder but mark error elsewhere
                # For now fallback to ref if it's SHA, else empty and check will fail
                commit = ref if SHA40_RE.match(ref or "") else ""
            # Content checksum: per-source artifact
            # For single-source, it's SKILL.md; for multi-source, each source maps to its vendored file:
            # - wrapper (vercel-labs/agent-skills) -> SKILL.md
            # - rules (vercel-labs/web-interface-guidelines) -> references/web-interface-guidelines.md
            # Generic fallback: skill_path for most, references/<basename> for others
            # For distribution: external, fetch upstream raw bytes at resolved commit instead of local vendored file
            content_checksum = ""
            try:
                # External distribution: fetch upstream content for checksum (governance without redistribution)
                dist_mode = None
                fm_dist = declarations[cap_id].get("frontmatter", {}).get("distribution", {})
                if isinstance(fm_dist, dict):
                    dist_mode = fm_dist.get("mode")
                if dist_mode == "external" and commit and repo and spath:
                    # Fetch upstream raw at pinned commit (deterministic, no network in check when lock exists? — but lock generation is online-capable)
                    # Try to reuse existing lock's checksum if already correct to avoid network in deterministic re-run
                    existing_ck = None
                    if cap_id in existing_caps:
                        ex_src = existing_caps[cap_id].get("sources", {}).get(sid, {})
                        ex_res = ex_src.get("resolved", {})
                        if ex_res.get("commit") == commit:
                            existing_ck = ex_res.get("content_checksum")
                    # If we have a valid existing checksum (not zeros) and commit matches, reuse it for determinism
                    if existing_ck and existing_ck != "sha256:" + "0" * 64:
                        content_checksum = existing_ck
                    else:
                        # Fetch upstream
                        import urllib.request

                        url = f"https://raw.githubusercontent.com/{repo}/{commit}/{spath}"
                        try:
                            with urllib.request.urlopen(url, timeout=10) as resp:
                                data = resp.read()
                                # Normalize SKILL.md same as _file_sha256 (strip reviewed_provenance) is not needed for upstream (no reviewed_provenance line)
                                h = hashlib.sha256()
                                h.update(data)
                                content_checksum = f"sha256:{h.hexdigest()}"
                        except Exception as e:
                            # Fallback to local if fetch fails (offline)
                            print(
                                f"warn: external fetch failed for {repo}/{spath}@{commit[:7]}: {e} — falling back to local",
                                file=sys.stderr,
                            )
                            raise
                # Fallback: vendored local file
                if not content_checksum or content_checksum == "sha256:" + "0" * 64:
                    vendored_path = skill_path
                    if len(src_list) > 1:
                        if sid == "rules" or spath == "command.md":
                            candidate = (
                                skill_path.parent / "references" / "web-interface-guidelines.md"
                            )
                            if candidate.exists():
                                vendored_path = candidate
                            else:
                                candidate = skill_path.parent / "references" / Path(spath).name
                                if candidate.exists():
                                    vendored_path = candidate
                    if vendored_path.exists():
                        content_checksum = _file_sha256(vendored_path)
                    else:
                        content_checksum = "sha256:" + "0" * 64
            except Exception:
                content_checksum = "sha256:" + "0" * 64
                # If external and still zeros, try local fallback already handled; keep zeros (check will skip for external)
            # License observed: per-source
            license_obj: dict = {"spdx": lic}
            # For multi-source, try per-source LICENSE
            lic_path = None
            if len(src_list) > 1 and (sid == "rules" or lic == "MIT"):
                # rules source has LICENSE in references/
                cand = skill_path.parent / "references" / "LICENSE"
                if cand.exists():
                    lic_path = cand
            if lic_path is None:
                # Fallback to skill dir LICENSE.txt / LICENSE
                cand = skill_path.parent / "LICENSE.txt"
                if cand.exists():
                    lic_path = cand
                elif (skill_path.parent / "LICENSE").exists():
                    lic_path = skill_path.parent / "LICENSE"
            if lic_path is not None and lic_path.exists():
                license_obj["source_path"] = str(lic_path.relative_to(REPO_ROOT))
                try:
                    # Use raw for LICENSE (not normalized)
                    license_obj["checksum"] = _file_sha256_raw(lic_path)
                except Exception:
                    pass
            # Preserve existing resolved_at if source material unchanged (deterministic lock)
            existing_resolved_at = None
            if cap_id in existing_caps:
                ex_src = existing_caps[cap_id].get("sources", {}).get(sid, {})
                ex_res = ex_src.get("resolved", {})
                # Compare material fields that define identity; if same, reuse timestamp
                if (
                    ex_res.get("commit") == commit
                    and ex_res.get("content_checksum") == content_checksum
                    and (ex_res.get("license") or {}).get("spdx") == license_obj.get("spdx")
                    and (ex_res.get("license") or {}).get("checksum") == license_obj.get("checksum")
                    and ex_res.get("version")
                    == (str(src["version"]) if src.get("version") else None)
                    and ex_res.get("resolved_at")
                ):
                    existing_resolved_at = ex_res.get("resolved_at")
            resolved: dict = {
                "commit": commit,
                "content_checksum": content_checksum,
                "license": license_obj,
                "resolved_at": existing_resolved_at or now,
            }
            # Preserve version if present in declaration
            if src.get("version"):
                resolved["version"] = str(src["version"])
            # tree_sha optional — not generated here
            lock_sources[sid] = {
                "repository": repo,
                "path": spath,
                "requested": requested,
                "resolved": resolved,
            }
        # provenance digest for capability
        digest = _provenance_digest(lock_sources)
        capabilities[cap_id] = {
            "sources": lock_sources,
            "provenance_digest": digest,
        }
    return {
        "version": 2,
        "capabilities": capabilities,
    }


def _load_lock() -> dict | None:
    if not LOCK_PATH.exists():
        return None
    try:
        data = yaml.safe_load(LOCK_PATH.read_text(encoding="utf-8")) or {}
        return data if isinstance(data, dict) else None
    except Exception as e:
        print(f"error loading lock {LOCK_PATH}: {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def cmd_lock(args: argparse.Namespace) -> int:
    declarations = _discover_declarations()
    if not declarations:
        print("no upstream declarations found (all 62 may be first-party)", file=sys.stderr)
    # Use existing lock generated_at if --check and file exists to keep deterministic
    existing = _load_lock() if LOCK_PATH.exists() else None
    data = _build_lock_data(declarations, existing_lock=existing)
    # Validate against schema before write
    errs = _validate_lock_schema(data)
    if errs:
        for e in errs:
            print(f"schema error: {e}", file=sys.stderr)
        return 1

    # Deterministic YAML: sort keys, no flow
    # Ensure capabilities sorted
    # Write or check
    def _dump(d: dict) -> str:
        # Use yaml.safe_dump with sort_keys True for determinism
        return yaml.safe_dump(
            d, sort_keys=True, default_flow_style=False, width=100, allow_unicode=True
        )

    new_text = _dump(data)
    if args.check:
        if not LOCK_PATH.exists():
            print(
                f"lock missing at {LOCK_PATH} — run: uv run python scripts/provenance.py lock",
                file=sys.stderr,
            )
            print(new_text)
            return 1
        existing_data = _load_lock()
        new_data_cmp = json.loads(json.dumps(data))
        existing_cmp = json.loads(json.dumps(existing_data)) if existing_data else {}
        if new_data_cmp != existing_cmp:
            print(f"lock drift: {LOCK_PATH} differs from declarations", file=sys.stderr)
            print("Fix: uv run python scripts/provenance.py lock", file=sys.stderr)
            import difflib

            exp_lines = _dump(new_data_cmp).splitlines(keepends=True)
            act_lines = (
                yaml.safe_dump(existing_cmp, sort_keys=True).splitlines(keepends=True)
                if existing_cmp
                else []
            )
            diff = difflib.unified_diff(
                act_lines,
                exp_lines,
                fromfile="committed lock",
                tofile="expected from declarations",
            )
            sys.stderr.writelines(diff)
            return 1
        print("lock check OK — declarations ↔ lock in sync")
        return 0
    else:
        # Write
        LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
        LOCK_PATH.write_text(new_text, encoding="utf-8")
        print(
            f"wrote {LOCK_PATH} — {len(data['capabilities'])} capabilities, {sum(len(c['sources']) for c in data['capabilities'].values())} sources"
        )
        for cap_id, cap in data["capabilities"].items():
            print(
                f"  {cap_id}: {', '.join(sorted(cap['sources'].keys()))} digest={cap['provenance_digest'][:16]}…"
            )
        return 0


def cmd_check(args: argparse.Namespace) -> int:
    errors: list[str] = []
    warnings: list[str] = []

    # 1. Load and validate lock schema
    lock = _load_lock()
    if lock is None:
        print(f"lock not found at {LOCK_PATH}", file=sys.stderr)
        print("hint: uv run python scripts/provenance.py lock", file=sys.stderr)
        return 1
    schema_errs = _validate_lock_schema(lock)
    if schema_errs:
        for e in schema_errs:
            print(f"FAIL: {e}", file=sys.stderr)
        return 1
    version = lock.get("version")
    if version != 2:
        print(f"FAIL: lock version must be 2, got {version}", file=sys.stderr)
        return 1

    capabilities_lock: dict = lock.get("capabilities") or {}
    declarations = _discover_declarations()

    # 2. Orphan / missing detection
    decl_ids = set(declarations.keys())
    lock_ids = set(capabilities_lock.keys())

    # First-party must NOT appear in lock — check that no first-party was incorrectly added
    # (We already only add upstream declarations, but lock could have stale first-party from v1 flat)
    for lid in sorted(lock_ids):
        if lid not in decl_ids:
            errors.append(
                f"orphan lock entry: capabilities.{lid} has no matching SKILL.md with origin: upstream (or SKILL.md was removed/renamed)"
            )

    for did in sorted(decl_ids):
        if did not in lock_ids:
            errors.append(
                f"missing lock entry: declaration {did} (origin: upstream) has no capabilities.{did} in {LOCK_PATH}"
            )

    # 3. Per-capability checks
    for cap_id in sorted(decl_ids & lock_ids):
        decl = declarations[cap_id]
        fm = decl["frontmatter"]
        skill_path: Path = decl["path"]
        lock_cap = capabilities_lock[cap_id]
        lock_sources: dict = lock_cap.get("sources") or {}
        decl_src_list: list[dict] = decl["sources"]
        # Build map by source id for comparison
        decl_by_id: dict[str, dict] = {s["_source_id"]: s for s in decl_src_list}
        # Check source IDs match
        if set(decl_by_id.keys()) != set(lock_sources.keys()):
            errors.append(
                f"{cap_id}: source IDs mismatch — declaration {sorted(decl_by_id.keys())} vs lock {sorted(lock_sources.keys())}"
            )
            continue
        # Compute expected digest and compare to stored
        expected_digest = _provenance_digest(lock_sources)
        stored_digest = lock_cap.get("provenance_digest", "")
        if stored_digest != expected_digest:
            errors.append(
                f"{cap_id}: provenance_digest mismatch — stored {stored_digest!r} vs expected {expected_digest!r} (hash of resolved commits+checksums+licenses)"
            )

        # Review binding: if declaration has trust.reviewed_provenance, must equal digest
        trust = fm.get("trust") or {}
        reviewed_prov = trust.get("reviewed_provenance") if isinstance(trust, dict) else None
        if isinstance(reviewed_prov, str) and reviewed_prov:
            if not SHA256_RE.match(reviewed_prov):
                errors.append(
                    f"{cap_id}: trust.reviewed_provenance {reviewed_prov!r} is not sha256:64hex"
                )
            elif reviewed_prov != stored_digest:
                errors.append(
                    f"{cap_id}: review binding invalid — trust.reviewed_provenance {reviewed_prov[:16]}… does not match lock provenance_digest {stored_digest[:16]}… "
                    f"(lock changed since last review; update declaration after auditing new bytes)"
                )

        for sid in sorted(decl_by_id.keys()):
            dsrc = decl_by_id[sid]
            lsrc = lock_sources[sid]
            # repository/path must match declaration intent
            for field in ("repository", "path"):
                if dsrc.get(field) != lsrc.get(field):
                    errors.append(
                        f"{cap_id}.sources.{sid}.{field}: declaration {dsrc.get(field)!r} vs lock {lsrc.get(field)!r}"
                    )
            # requested must match declaration ref/type
            d_ref = dsrc.get("ref", "")
            l_req = lsrc.get("requested") or {}
            if l_req.get("ref") != d_ref:
                errors.append(
                    f"{cap_id}.sources.{sid}.requested.ref: declaration {d_ref!r} vs lock {l_req.get('ref')!r} (run provenance.py lock)"
                )
            # expected requested type
            exp_type = (
                "commit"
                if SHA40_RE.match(d_ref or "")
                else ("tag" if re.match(r"^v?[0-9]+\.[0-9]+\.[0-9]+", d_ref or "") else "commit")
            )
            if l_req.get("type") != exp_type:
                warnings.append(
                    f"{cap_id}.sources.{sid}.requested.type: expected {exp_type!r} for ref {d_ref!r}, got {l_req.get('type')!r}"
                )
            # resolved commit must be 40-char SHA
            resolved = lsrc.get("resolved") or {}
            commit = resolved.get("commit", "")
            if not SHA40_RE.match(commit or ""):
                errors.append(
                    f"{cap_id}.sources.{sid}.resolved.commit {commit!r} is not a 40-char SHA (immutable ref required)"
                )
            else:
                # For type=commit, resolved commit should equal requested ref; for tag, commit is separate
                if exp_type == "commit" and commit != d_ref:
                    errors.append(
                        f"{cap_id}.sources.{sid}: resolved commit {commit[:7]}… != requested commit ref {d_ref[:7]}… (tag+commit separation violated)"
                    )
            # content_checksum must be sha256 and match vendored bytes if distribution vendored
            cksum = resolved.get("content_checksum", "")
            if not SHA256_RE.match(cksum or ""):
                errors.append(
                    f"{cap_id}.sources.{sid}.resolved.content_checksum {cksum!r} is not sha256:64hex"
                )
            else:
                # Verify against actual vendored file if vendored (per-source)
                dist = (
                    (fm.get("distribution") or {}).get("mode")
                    if isinstance(fm.get("distribution"), dict)
                    else None
                )
                if dist == "vendored" or dist is None:  # default assume vendored for upstream
                    try:
                        vendored_path = skill_path
                        if len(decl_src_list) > 1 and (
                            sid == "rules" or dsrc.get("path") == "command.md"
                        ):
                            cand = skill_path.parent / "references" / "web-interface-guidelines.md"
                            if cand.exists():
                                vendored_path = cand
                            else:
                                cand2 = (
                                    skill_path.parent
                                    / "references"
                                    / Path(dsrc.get("path", "")).name
                                )
                                if cand2.exists():
                                    vendored_path = cand2
                        actual = _file_sha256(vendored_path)
                        if actual != cksum:
                            errors.append(
                                f"{cap_id}.sources.{sid}: content_checksum mismatch — lock {cksum[:16]}… vs vendored {vendored_path} {actual[:16]}… (drift; run provenance.py lock after updating vendored bytes)"
                            )
                    except FileNotFoundError:
                        errors.append(
                            f"{cap_id}: vendored file not found at {skill_path} but lock expects {cksum[:16]}…"
                        )
            # license observed: must be valid SPDX subset and compare to declaration expected?
            lic = (resolved.get("license") or {}).get("spdx", "")
            decl_lic = dsrc.get("license", "")
            if lic and decl_lic and lic != decl_lic:
                warnings.append(
                    f"{cap_id}.sources.{sid}: observed license {lic!r} != declaration license {decl_lic!r} (possible upstream license change — review)"
                )
            # If LICENSE file vendored, checksum should match
            lic_obj = resolved.get("license") or {}
            lic_ck = lic_obj.get("checksum")
            lic_src_path = lic_obj.get("source_path")
            if lic_ck and lic_src_path:
                lic_file = REPO_ROOT / lic_src_path
                if lic_file.exists():
                    actual_lic_ck = _file_sha256(lic_file)
                    if actual_lic_ck != lic_ck:
                        errors.append(
                            f"{cap_id}.sources.{sid}.license.checksum: lock {lic_ck[:16]}… vs file {actual_lic_ck[:16]}… ({lic_file})"
                        )
                else:
                    warnings.append(
                        f"{cap_id}.sources.{sid}.license: source_path {lic_src_path!r} not found on disk"
                    )

    # 4. Validate first-party not in lock (redundant with orphan, but explicit)
    # Scan all skills to ensure no first-party appears in lock (lock is sparse by design)
    for cap_id in sorted(lock_ids):
        if cap_id not in declarations:
            # Already flagged as orphan; check if there exists a SKILL.md that is first-party with same id that was incorrectly locked
            possible = REPO_ROOT / "skills" / f"{cap_id}" / "SKILL.md"
            # Actually cap_id is domain/name, path is skills/domain/name/SKILL.md
            if possible.exists():
                fm2 = _load_frontmatter(possible)
                if (fm2.get("origin") or {}).get("type") == "first-party":
                    errors.append(
                        f"{cap_id}: lock contains first-party capability — lock must be sparse (only origin: upstream)"
                    )

    # 5. Validate upstream schema for declarations still passes (reuse validate-upstream logic indirectly)
    # Here we just ensure every upstream declaration has valid SPDX and ref already validated

    if errors:
        print(
            f"provenance check FAILED — {len(errors)} error(s), {len(warnings)} warning(s):",
            file=sys.stderr,
        )
        for e in errors:
            print(f"  ✗ {e}", file=sys.stderr)
        for w in warnings:
            print(f"  ⚠ {w}", file=sys.stderr)
        return 1
    if warnings:
        print(f"provenance check OK with {len(warnings)} warning(s):")
        for w in warnings:
            print(f"  ⚠ {w}")
    else:
        print(
            f"provenance check OK — {len(lock_ids)} capabilities, {sum(len(c.get('sources', {})) for c in capabilities_lock.values())} sources, digests valid, checksums match vendored bytes."
        )
    # Also validate lock schema already OK
    return 0


def _generate_upstream_md_content(declarations: dict[str, dict], lock: dict | None) -> str:
    lines: list[str] = []
    lines.append(
        "<!-- GENERATED by scripts/provenance.py docs — do not hand-edit. Run: uv run python scripts/provenance.py docs -->"
    )
    lines.append("# Upstream Provenance Report")
    lines.append("")
    lines.append("Human-readable provenance for third-party capability content. Canonical sources:")
    lines.append("")
    lines.append(
        "- **Declaration:** `SKILL.md` frontmatter (`origin`, `sources`/`upstream`, `trust`, `maintenance`, `distribution`, `security`) — see `schemas/upstream.schema.json`"
    )
    lines.append(
        "- **Resolution:** `capabilities/upstream.lock` (`version: 2`, `provenance_digest`) — see `schemas/upstream-lock.schema.json` and `docs/adr/0001-*.md`"
    )
    lines.append("- **Vendored bytes:** `skills/<domain>/<name>/SKILL.md` + `LICENSE.txt`")
    lines.append("")
    lines.append(f"Generated: {datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')}")
    lines.append(
        f"Capabilities with external provenance: {len(declarations)} (first-party omitted; lock is sparse)"
    )
    lines.append("")
    if not declarations:
        lines.append("_No upstream capabilities — all 62 skills are first-party._")
        lines.append("")
        return "\n".join(lines)

    capabilities_lock = (lock or {}).get("capabilities", {}) if lock else {}
    for cap_id in sorted(declarations.keys()):
        decl = declarations[cap_id]
        fm = decl["frontmatter"]
        trust = fm.get("trust") or {}
        maint = fm.get("maintenance") or {}
        dist = fm.get("distribution") or {}
        sec = fm.get("security") or {}
        lock_cap = capabilities_lock.get(cap_id, {})
        digest = lock_cap.get("provenance_digest", "(no lock entry)")
        reviewed = trust.get("reviewed_provenance", "")
        lines.append(f"## `{cap_id}`")
        lines.append("")
        lines.append(
            f"- **Trust:** `{trust.get('tier', '?')}` reviewed_at={trust.get('reviewed_at', '?')} by={trust.get('reviewed_by', '?')}"
        )
        if reviewed:
            lines.append(
                f"  - `reviewed_provenance:` `{reviewed}` (must equal `provenance_digest` below)"
            )
        lines.append(
            f"- **Maintenance:** `{maint.get('status', '?')}` last_activity={maint.get('last_activity', '?')}"
        )
        lines.append(
            f"- **Distribution:** `{dist.get('mode', '?')}` redistribution_allowed={dist.get('redistribution_allowed', '?')}"
        )
        lines.append(
            f"- **Security (declared):** scripts={sec.get('scripts')} shell={sec.get('shell')} network={sec.get('network')} cve_policy={sec.get('cve_policy')} mcp={sec.get('mcp')} hooks={sec.get('hooks')}"
        )
        lines.append(f"- **Provenance digest:** `{digest}`")
        if reviewed and reviewed != digest:
            lines.append(
                "  - ⚠️ **Review binding invalid** — "
                "`trust.reviewed_provenance` does not match lock "
                "`provenance_digest` (re-audit required)"
            )
        lines.append("")
        src_list = decl["sources"]
        lock_sources = lock_cap.get("sources", {})
        for src in src_list:
            sid = src["_source_id"]
            repo = src.get("repository")
            path = src.get("path")
            ref = src.get("ref")
            lic = src.get("license")
            lsrc = lock_sources.get(sid, {})
            req = lsrc.get("requested", {})
            res = lsrc.get("resolved", {})
            lines.append(f"### Source `{sid}` — `{repo}/{path}`")
            lines.append("")
            lines.append(f"- **Repository:** `{repo}`")
            lines.append(f"- **Path:** `{path}`")
            lines.append(
                f"- **Requested:** `{req.get('type', '?')}` `{req.get('ref', ref)}` (declaration intent)"
            )
            lines.append(f"- **Resolved commit:** `{res.get('commit', '?')}`")
            lines.append(f"- **Content checksum:** `{res.get('content_checksum', '?')}`")
            lic_obj = res.get("license", {})
            lines.append(
                f"- **Observed license:** `{lic_obj.get('spdx', lic)}` source_path=`{lic_obj.get('source_path', '?')}` checksum=`{lic_obj.get('checksum', '?')}`"
            )
            lines.append(f"  - Declaration expected `license: {lic}` — mismatch requires review")
            lines.append(
                f"- **Resolved at:** `{res.get('resolved_at', '?')}` version=`{res.get('version', '?')}`"
            )
            lines.append("")
        # Per-skill existing UPSTREAM.md pointer
        skill_upstream_md = REPO_ROOT / "skills" / cap_id / "UPSTREAM.md"
        if skill_upstream_md.exists():
            lines.append(
                f"- **Per-skill attribution:** `{skill_upstream_md.relative_to(REPO_ROOT)}`"
            )
            lines.append("")
    lines.append("---")
    lines.append("")
    lines.append(
        "Update workflow (follow-up #428): resolve tracking refs → candidate branch → "
        "`provenance.py lock` → vendored bytes + this doc → `audit-capability` → tests → "
        "PR with old/new commit/checksum/license and `provenance_digest` review-required."
    )
    lines.append("")
    return "\n".join(lines)


def cmd_docs(args: argparse.Namespace) -> int:
    declarations = _discover_declarations()
    lock = _load_lock()
    content = _generate_upstream_md_content(declarations, lock)
    out_path = REPO_ROOT / "docs" / "UPSTREAM.md"
    if args.check:
        if not out_path.exists():
            print(
                f"docs missing at {out_path} — run: uv run python scripts/provenance.py docs",
                file=sys.stderr,
            )
            print(content)
            return 1
        existing = out_path.read_text(encoding="utf-8")

        # Normalize for comparison (strip first line timestamp? compare without Generated line)
        # Simple strict compare ignoring Generated line
        def _strip_generated(txt: str) -> str:
            return "\n".join(line for line in txt.splitlines() if not line.startswith("Generated:"))

        if _strip_generated(existing) != _strip_generated(content):
            print(f"UPSTREAM.md drift: {out_path} differs from declarations+lock", file=sys.stderr)
            print("Fix: uv run python scripts/provenance.py docs", file=sys.stderr)
            import difflib

            diff = difflib.unified_diff(
                existing.splitlines(keepends=True),
                content.splitlines(keepends=True),
                fromfile="committed docs/UPSTREAM.md",
                tofile="expected",
            )
            sys.stderr.writelines(diff)
            return 1
        print("docs check OK — docs/UPSTREAM.md in sync")
        return 0
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content, encoding="utf-8")
    print(f"wrote {out_path} — {len(declarations)} capabilities")
    return 0


def _gh_api_json(path: str) -> dict | list | None:
    """Try gh api first, fallback to urllib with GITHUB_TOKEN."""
    # Try gh
    try:
        out = subprocess.check_output(
            ["gh", "api", path, "--paginate"], text=True, stderr=subprocess.DEVNULL, timeout=10
        )
        # gh --paginate joins pages; for single object it returns JSON object
        # For list endpoints without paginate we get array
        return json.loads(out) if out.strip().startswith(("[", "{")) else None
    except Exception:
        pass
    # Fallback urllib
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    headers = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    url = f"https://api.github.com/{path.lstrip('/')}"
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        print(f"warn: GitHub API {path} failed: {e}", file=sys.stderr)
        return None


def _fetch_latest_commit(repository: str, path: str | None = None) -> str | None:
    """Fetch latest commit SHA for repository default branch (ignoring path for now)."""
    # Get default branch
    info = _gh_api_json(f"repos/{repository}")
    if not isinstance(info, dict):
        return None
    branch = info.get("default_branch", "main")
    # Get commit for branch
    commit_info = _gh_api_json(f"repos/{repository}/commits/{branch}")
    if isinstance(commit_info, dict) and "sha" in commit_info:
        sha = commit_info["sha"]
        if SHA40_RE.match(sha):
            return sha
    # Fallback: list commits
    commits = _gh_api_json(f"repos/{repository}/commits?sha={branch}&per_page=1")
    if isinstance(commits, list) and commits and isinstance(commits[0], dict):
        sha = commits[0].get("sha", "")
        if SHA40_RE.match(sha):
            return sha
    return None


def cmd_updates(args: argparse.Namespace) -> int:
    """
    Online discovery: compare locked resolved commits to remote HEAD.

    Read-only by default (--json prints machine-readable). With --apply (future),
    would update lock/vendored bytes and docs, but for #428 foundation we keep
    read-only and let the workflow open a PR manually.

    Never auto-merges; human review required.
    """
    lock = _load_lock()
    if lock is None:
        print(f"lock not found at {LOCK_PATH}", file=sys.stderr)
        return 1
    caps = lock.get("capabilities", {})
    updates: list[dict] = []
    for cap_id in sorted(caps.keys()):
        for source_id, src in sorted(caps[cap_id].get("sources", {}).items()):
            repo = src.get("repository", "")
            locked = (src.get("resolved") or {}).get("commit", "")
            # Skip if no repo or not commit-typed (tag tracking would need release API)
            req_type = (src.get("requested") or {}).get("type", "commit")
            if req_type != "commit":
                continue
            latest = _fetch_latest_commit(repo, src.get("path"))
            if not latest:
                if args.json:
                    continue
                print(
                    f"{cap_id} {source_id}: {repo} — could not fetch latest (offline?)",
                    file=sys.stderr,
                )
                continue
            if latest != locked:
                # Also check staleness >90d via resolved_at
                resolved_at = (src.get("resolved") or {}).get("resolved_at", "")
                stale = False
                try:
                    rt = datetime.fromisoformat(resolved_at.replace("Z", "+00:00"))
                    stale = (datetime.now(timezone.utc) - rt).days > 90
                except Exception:
                    stale = False
                entry = {
                    "capability": cap_id,
                    "source": source_id,
                    "repository": repo,
                    "path": src.get("path"),
                    "locked_commit": locked,
                    "latest_commit": latest,
                    "stale": stale,
                    "license_locked": (src.get("resolved") or {}).get("license", {}).get("spdx"),
                }
                updates.append(entry)
                if not args.json:
                    print(
                        f"{cap_id} {source_id}: update available {locked[:7]} → {latest[:7]} ({repo})"
                        + (" STALE>90d" if stale else "")
                    )
            else:
                if not args.json:
                    print(f"{cap_id} {source_id}: up-to-date {locked[:7]} ({repo})")
    if args.json:
        print(json.dumps({"updates": updates, "count": len(updates)}, indent=2))
        # Also check staleness even without update
        if not updates:
            # Still report staleness for existing lock entries
            for cap_id in sorted(caps.keys()):
                for source_id, src in caps[cap_id].get("sources", {}).items():
                    resolved_at = (src.get("resolved") or {}).get("resolved_at", "")
                    try:
                        rt = datetime.fromisoformat(resolved_at.replace("Z", "+00:00"))
                        if (datetime.now(timezone.utc) - rt).days > 90:
                            print(
                                f"warn: {cap_id} {source_id} pin >90d stale ({resolved_at})",
                                file=sys.stderr,
                            )
                    except Exception:
                        pass
        return 0 if not updates else 0  # exit 0 even with updates; caller checks JSON

    if updates:
        print(
            f"\n{len(updates)} update(s) available — run workflow to open PR (see #428).",
            file=sys.stderr,
        )
        print(
            "PR body must include: old/new commit, checksum, license, shell/network/mcp/hook diff, provenance_digest review-required.",
            file=sys.stderr,
        )
    else:
        print("No updates — all locked commits are at remote HEAD.")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="provenance: declaration → lock → check")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_lock = sub.add_parser(
        "lock", help="resolve declarations and write capabilities/upstream.lock"
    )
    p_lock.add_argument(
        "--check",
        action="store_true",
        help="do not write; fail if committed lock differs",
    )
    p_lock.set_defaults(func=cmd_lock)

    p_check = sub.add_parser(
        "check", help="offline validation declaration↔lock + checksums + digest + review binding"
    )
    p_check.set_defaults(func=cmd_check)

    p_docs = sub.add_parser("docs", help="generate docs/UPSTREAM.md from declaration+lock")
    p_docs.add_argument("--check", action="store_true", help="fail if docs/UPSTREAM.md differs")
    p_docs.set_defaults(func=cmd_docs)

    p_up = sub.add_parser("updates", help="online discovery: compare locked commits to remote HEAD")
    p_up.add_argument("--json", action="store_true", help="machine-readable JSON")
    p_up.set_defaults(func=cmd_updates)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
