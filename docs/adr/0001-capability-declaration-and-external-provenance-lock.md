# ADR-0001: Capability Declaration and External Provenance Lock

**Status:** Accepted (2026-08-11) — implements #370, supersedes gate 3 Option B interim (SKILL.md-only authority)

**Deciders:** ulises-jeremias (owner) + toolkit maintainers

**Related:** #364 (governance foundation), #370 (immutable pinning + lock), #371/#400 (frontend-design vendoring), #378/#402 (supply-chain audit), #387 (inventory/doctor — deferred), PR #403

---

## Context

Agent Toolkit is evolving into a cross-agent capability platform (Claude, Cursor, Copilot, OpenCode, Windsurf, Pi, Muse). Every vendored design/security/quality capability amplifies supply-chain risk without explicit provenance, immutable pinning, and update policy.

#399 established **declaration authority** in `SKILL.md` frontmatter (`origin`, `upstream`/`sources`, `trust`/`maintenance`/`distribution`/`security` validated by `scripts/validate-upstream.py` + `schemas/upstream.schema.json`). Single skill is vendored today: `design/frontend-design` (`anthropics/skills` `f17010c9bb483898c1d9c9f42dde2b3a98889434`, `Apache-2.0`). 61 skills are `origin: first-party`.

#370 required an **immutable external provenance lock** (`capabilities/upstream.lock`) with weekly update PRs. PR #403 v1 implemented `version: 1` / `upstreams: [{repository, path, ref, license, trust_tier, distribution, checksum}]` — a flat, hand-maintained duplicate of declaration fields that mixed semantics and resolution, lacked `origin`/`capability` identity, multi-source roles, `commit` for tags, per-source checksums, `trust`/`maintenance`/`security` split, and had no generator (`generate-upstream-lock.py` header but no script). Architecture review (2026-08-11) demonstrated it would become a second capability catalog and create bidirectional sync.

Forces:

- **Supply-chain integrity:** Vendored bytes must be reproducible from immutable Git SHAs + content checksums; mutable `main` must never be runtime truth.
- **Separation of concerns:** Policy (trust, security declaration, distribution mode, maintenance) vs. resolution state (which commit was resolved, what checksum, what license was observed).
- **Minimal churn:** 61 first-party skills must not acquire provenance manifests; lock must be sparse.
- **Multi-source first-class:** `design/web-design-guidelines` (Vercel wrapper + `web-interface-guidelines` rules) is one logical capability from two independent upstreams.
- **Reviewability:** Updating the lock must invalidate prior human review; PRs must show old/new commit, checksum, license, and detected security surface.
- **Offline CI:** Normal validation must be deterministic without live GitHub calls; network only in explicit update.

## Options Considered

### Option A: Lock as full canonical capability registry (REJECTED — the PR #403 v1 direction)

Store in `upstream.lock`:

```
capability identity, origin, sources, trust, maintenance, security, distribution, updates, ref, checksum
```

**Pros:**
- Single file lists every capability.
- Appears conceptually “clean”.

**Cons:**
- Duplicates every semantic field already in `SKILL.md` (`trust`/`maintenance`/`security`/`distribution`/`origin`/`sources`) — becomes second `skill-catalog.yaml`.
- Forces first-party entries into lock (nothing external to resolve) or leaves them inconsistently absent.
- Mixes policy and resolution; copying `trust: reviewed` into new lock forever hides that review applied to old bytes.
- Requires bidirectional sync: `lock generates SKILL.md` vs `SKILL.md generates lock` — circular.
- Cannot cleanly represent `distribution: native-plugin` without provenance vs `external` pin semantics.
- Validator must reconcile two full catalogs; drift detection is whole-file diff, not resolution diff.

### Option B: Lock as minimal external resolution artifact (SELECTED)

Separation:

```
CAPABILITY DECLARATION  — “What is this capability and what external sources does it intend to use?”  (SKILL.md frontmatter; future agent/mcp/hook manifests)
        ↓ resolution
EXTERNAL PROVENANCE LOCK — “What exact immutable external artifacts were resolved?”            (capabilities/upstream.lock — sparse, per-capability, per-source)
        ↓ integrity verification
VENDORED / EXTERNAL STATE — “What bytes/package/plugin actually correspond?”                  (skills/design/frontend-design/SKILL.md + LICENSE.txt)
        ↓ generation
TARGET SURFACES          — “How Claude/Cursor/Copilot consume the capability”               (plugins/*, catalogs/*, docs/UPSTREAM.md)
```

Lock owns only **resolution**: `capability ID → source ID → {repository, path, requested {type, ref}, resolved {commit, content_checksum, license{spdx, source_path, checksum}, resolved_at, tree_sha?}, provenance_digest}`. Declaration owns semantics/policy. Neither duplicates the other’s responsibility.

**Pros:**
- Sparse: only capabilities with `origin: upstream` and external content appear; `first-party` stays out (61 skills omit lock entries).
- Minimal, auditable: lock diff is exactly `commit` + `checksum` + observed license — review invalidation is obvious.
- Multi-source natural: `capability → sources: {wrapper, rules}` each with independent `resolved` state; atomic capability update.
- One-directional authority: declaration → lock → generated docs (no circular generation).
- Separate schemas: `upstream.schema.json` (declaration) vs `upstream-lock.schema.json` (resolution) share only `$defs/sha40`/`spdx`/`repository`.
- Review binding via `trust.reviewed_provenance` digest cleanly separates lock resolution from human trust state.

**Cons:**
- Two files to inspect for a full picture (declaration + lock) — mitigated by generated `UPSTREAM.md` and `provenance.py check`.
- Requires digest + review-binding discipline; otherwise reviewers might miss that lock changed.
- Needs new `schemas/upstream-lock.schema.json` and `scripts/provenance.py` tooling rather than reusing stub.

## Decision

Adopt **Option B**.

- **Capability declarations own semantics and policy** — `SKILL.md` frontmatter remains canonical for skills (`origin`, `sources`/`upstream`, `trust`, `maintenance`, `distribution`, `security`, plus `requires`). Non-skill kinds later get the smallest equivalent manifest per surface (agent/mcp/hook/plugin), not forced `SKILL.md`.
- **`capabilities/upstream.lock` owns resolved immutable external state** — deterministic `version: 2` mapping `design/frontend-design → sources.{id}` with `requested`/`resolved` separation, `commit` (40-char SHA), `content_checksum` (`sha256:`), observed `license`, `resolved_at`, and `provenance_digest`. Validated by dedicated `schemas/upstream-lock.schema.json`.
- **Generated surfaces own neither** — `catalogs/*`, `plugins/*`, `docs/UPSTREAM.md` are derived; `UPSTREAM.md` is generated from declaration + lock and never hand-edited.
- **First-party capabilities do not appear in lock**; runtime package resolution (`uv.lock`, `pnpm-lock.yaml`, Docker digest) stays in ecosystem locks, not `upstream.lock`.
- Deterministic `scripts/provenance.py` provides `lock` (resolve declarations → write lock) and `check` (offline: declaration↔lock consistency, schema, SHA40, SPDX, checksum vs vendored bytes, orphan/missing, review-binding validity). `updates` (online discovery + PR) is split to follow-up issue to keep #403 focused.
- `trust.reviewed_provenance` binds human review to the lock’s `provenance_digest`; any source `commit`/`checksum`/`license` change alters the digest and invalidates prior review until declaration is updated.

Stable capability identity uses existing Toolkit-namespaced IDs (`design/frontend-design`, not bare `frontend-design`); lock key is that ID, globally unique across kinds (no redundant `capability: {kind, id}` per entry unless future collision forces qualification).

## Consequences

**Positive:**
- Supply-chain reproducibility: `uv run python scripts/provenance.py check` offline validates SKILL.md intent, lock resolution, vendored bytes, and license without network.
- Security-reviewable updates: lock digest change → PR shows old/new commit, checksum, license, and `scripts/audit-capability.vsh` detected `shell`/`network`/`mcp`/`hooks` diff.
- No 62-file churn; migration vertical slice is exactly `design/frontend-design` (real SHA `f17010c9...`, real checksums `sha256:7e906c...` + `0d542e...`, `Apache-2.0`).
- Vercel multi-source fixture validated; update of one source atomically bumps capability digest.
- AGPL/missing-license risk visible: observed `spdx` snapshot detects `GPL` drift vs expected.

**Negative / Costs:**
- Tooling must stay offline-deterministic; flaky network must not gate PR CI.
- Review binding requires discipline: reviewers must update `trust.reviewed_provenance` after auditing new bytes; tooling enforces but adds step.
- Two-schema maintenance (`upstream` vs `upstream-lock`) — reuse shared `$defs` mitigates drift.

**Follow-up split:** Automated weekly `main`/`stable` tracking → resolve → candidate branch → `lock` + vendored files + `UPSTREAM.md` → supply-chain audit → tests → open PR is intentionally moved to a new issue PR after #403. #403 foundation remains: declaration/resolution split, V2 schema, generator, integrity validator, frontend-design migration, human provenance doc, CI lock validation, multi-source + non-skill fixtures, tests, TRUST.md update.

## References

- PR #399 (15 P0 gates, provenance schema + validator, L1/L1.5 separation)
- Issue #370 (immutable pinning + update PR automation — to be split)
- PR #403 (this ADR target; v1 rejected)
- `schemas/upstream.schema.json` / `schemas/upstream-lock.schema.json` (new)
- `schemas/skill-md-frontmatter.schema.json` (`$ref` single-source)
- `docs/TRUST.md` § Supply chain → Provenance & third-party capabilities (updated)
- `scripts/provenance.py` (`lock`/`check`)
- `capabilities/upstream.lock` v2 (`design/frontend-design` real slice)
- `docs/UPSTREAM.md` (generated)
