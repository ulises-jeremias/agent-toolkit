# Threat model: distribution wrappers & binary bootstrap

**Issue:** [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)  
**Related:** [#486](https://github.com/ulises-jeremias/agent-toolkit/issues/486) / ADR-021, [#487](https://github.com/ulises-jeremias/agent-toolkit/issues/487), [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530), [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535), [#543](https://github.com/ulises-jeremias/agent-toolkit/issues/543)

This document is the accepted threat model for **how users obtain a native `agent-toolkit` binary** through adapters (PyPI, future npm, Homebrew/AUR contracts). It does **not** claim attestations or checksums prove “secure software.”

## Trust boundaries

```text
V SOURCE (this repo)
        │
        ▼
Trusted GitHub Actions (pinned actions + release workflow)
        │
        ▼
GitHub Release  ← CANONICAL artifact source (ADR-018)
        │
        ├── PyPI platform wheel  (bundle at *build* time — ADR-021 A)
        ├── Homebrew Formula     (contract in distribution/homebrew/)
        ├── AUR -bin PKGBUILD    (contract in distribution/aur/)
        └── npm (future; ADR pending #487, still gated here)
```

**In scope:** wheel-embedded native binary + thin launcher; install-time or first-run GitHub download+verify (option B); local caches; checksum/provenance; TOCTOU; interaction with Gatekeeper/SmartScreen (#543).

**Out of scope:** Bobatea / TUI (#542); HTTP `serve` (#541); code-signing certificate purchase (#543 is FUTURE policy, not this model’s control set).

## Actors

| Actor | Trust |
|-------|--------|
| Maintainer with `contents: write` on this repo | Trusted to cut tags; compromise is catastrophic |
| GitHub Actions `GITHUB_TOKEN` / OIDC | Trusted for the job that built that tag |
| PyPI project `agent-toolkit-cli` | Trusted publisher (OIDC) once configured; otherwise token = same blast radius as a malicious wheel |
| End user / `uv tool install` | Untrusted network; trusted only for choosing install source |
| `AGENT_TOOLKIT_BIN` operator | **Trusted local override** — equivalent to putting a binary on `PATH` |

## Assets

- Native V binary bytes (the product).
- Thin launcher that `exec`s those bytes (PyPI).
- SHA256 / `manifest.json` / SBOM / attestations (#488 / #530).
- User machine after install (`PATH`, shell profile).

## Strategy A (accepted default) — bundle at wheel-build

CI copies a GitHub Release (or just-built) binary into the wheel at **publish** time. The user’s `pip`/`uv` fetch is a platform wheel from PyPI. Runtime does **not** talk to GitHub.

| Threat | Severity | Control | Residual |
|--------|----------|---------|----------|
| Compromised release CI uploads a backdoored binary | Critical | Pin Actions SHAs; required reviews; #530 checksums+attestations as *evidence*, not proof | Attacker with release rights still wins |
| Malicious PyPI wheel (account/token theft, dependency confusion) | Critical | Keep dist name `agent-toolkit-cli`; Trusted Publishing; users pin version+hash when they can | PyPI is still a second host of the bytes |
| Wheel tag mismatch (macOS installs a Linux binary) | High | Platform tags (`infer_tag`); hatch `pure_python=False` when a native bin is present; missing/wrong bin → exit 127, **no** Python CLI fallback | sdist has no binary — must not silently become the product |
| `AGENT_TOOLKIT_BIN` / writable `agent_toolkit/bin/` TOCTOU | Medium | Document as trusted-operator; do not search `PATH` for a random `agent-toolkit` | Local privilege already implies PATH hijack |
| Launcher reimplements CLI in Python | High | Product scripts call launcher only; `agent-toolkit-py` is explicit fallback (#535) | Until #540, Python still ships in the same dist |
| Offline install | Info | A is **offline-capable** after the wheel is fetched | — |

**npm/Homebrew/AUR** using A-equivalent (Formula/PKGBUILD copies Release bytes at *package build* or install-from-URL with checksum) inherit the same row for “compromised Release.”

## Strategy B (rejected as default) — runtime GitHub download

First run or install script detects OS/arch, downloads a Release asset, verifies, execs. **Blocked** as the PyPI/npm default until this model is accepted **and** #530 checksums exist.

| Threat | Severity | Why B is worse than A |
|--------|----------|------------------------|
| MITM / rogue CDN between user and GitHub | High | User’s first run is a live network fetch; TLS to GitHub helps, pinning `sha256` from `manifest.json` is **MUST** before exec |
| TOCTOU on cache (`~/.cache/agent-toolkit/bin`) | High | Replace binary between verify and exec; A has no user-writable cache in the happy path |
| Infinite re-download / availability | Medium | GitHub outage = CLI gone; A already has bytes in site-packages |
| Supply-chain “latest” float | High | Fetching `latest` without pinning `gitTag`+`sha256` is forbidden |
| Gatekeeper/SmartScreen (#543) | Medium | Freshly downloaded unsigned blobs trigger more OS prompts than a wheel built on CI |

**Decision:** B remains available as a *documented recovery* path (manual `curl` of a Release asset + `sha256sum -c`) and for package managers that already download upstream URLs (Homebrew/AUR). It is **not** the PyPI entrypoint.

## Controls mapped to ADRs / issues

| Control | Where |
|---------|--------|
| GitHub Release is canonical; adapters do not compile a second implementation | ADR-017, ADR-018 |
| glibc Linux MUST; musl not a PyPI MUST | ADR-019 |
| PyPI = platform wheels + thin `exec` launcher; no runtime download default | ADR-021 A, #535 |
| `manifest.json` os/arch/libc index | #488 / ADR-022 |
| `SHA256SUMS`, attestations, SBOM attach | #530 (MUST checksums; attestations/SBOM SHOULD; do not overclaim) |
| No silent Python fallback on the product command | #535 (exit 127) |
| macOS notarization / Authenticode | #543 FUTURE — not a current MUST |
| npm topology | #487 — still blocked on this model + #530 |

## Explicit non-claims

- GitHub artifact attestations show **which workflow** produced an asset. They do not prove the V compiler, pinned Actions, or dependency graph are free of bugs.
- An SBOM lists ingredients. It is not a vulnerability scan.
- Shipping a thin Python process (launcher) is not “Python remains canonical.” The **product** is the V binary.

## Acceptance

- Strategy **A** is the only approved PyPI/npm *default* bootstrap.
- Strategy **B** (runtime download) MUST NOT ship in `agent-toolkit` / `agent-toolkit-cli` console scripts.
- Wrapper implementation (#535, future #536) may proceed under A. Homebrew/AUR install-from-Release-URL is B-shaped and MUST verify `sha256` from `manifest.json` / `SHA256SUMS` once #530 exists.
