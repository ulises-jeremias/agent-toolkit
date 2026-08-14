> **Superseded 2026-08-14:** MegaLinter skills are now **vendored** (literal copies). See `docs/megalinter/AGPL-VENDING.md`.

# MegaLinter License Analysis — 2026-08-12

**Upstream:** `oxsecurity/megalinter` — `LICENSE` at repo root is **GNU Affero General Public License v3.0 (AGPL-3.0)**, 34523 bytes, SHA `be3f7b28e564e7dd05eaf59d64adba1a4065ac0e` (`gh api repos/oxsecurity/megalinter --jq .license.spdx_id` → `AGPL-3.0`).

**Assets in scope:**
- `skills/megalinter/SKILL.md`, `skills/megalinter-setup/SKILL.md`, `skills/megalinter-check/SKILL.md`, `skills/megalinter-fix/SKILL.md` — markdown instruction files, each frontmatter `licence: MegaLinter by OX Security, Copyright 2026 - https://megalinter.io/` (not SPDX, but file is part of AGPL repo, so copyrighted work under AGPL unless explicitly exempted — no exemption found; `skills/*/LICENSE` 404 as of 2026-08-12).
- `skills/megalinter-setup/agents/megalinter-watcher.md`, `megalinter-runner.md`, `megalinter-fixer.md` — same repo, same copyright, same AGPL.
- `megalinter/linters/*.md` fix guides — generated partially from descriptors via `.automation/build.py` + hand-maintained, also AGPL.
- `mega-linter-runner` npm package (`mega-linter-runner@10.0.0`, `https://registry.npmjs.org/mega-linter-runner/-/mega-linter-runner-10.0.0.tgz`, integrity `sha512-yQOyD8/...`, shasum `c9e3977ab8004e66c8417dd6c981198a1897a971`) — same AGPL repo, but distributed as npm tarball (still AGPL).
- Docker images `ghcr.io/oxsecurity/megalinter:v10` (config digest `sha256:939058f3ed31803e12583365e7126eacfb356724bf003fd29e96a93948aa2d33`, manifest v2+json, 66 layers) — built from AGPL repo, image layers are AGPL-derived; using the image as a runtime container (docker run) does not create a derivative of the image in the consumer repo.

## What would vendoring mean?

If Agent Toolkit copied the 4 SKILL.md + 3 agent MD files verbatim into `skills/quality/megalinter/` (vendored):
- Those specific files would be **redistributed** AGPL-licensed copyrighted works inside an MIT-licensed repository.
- Obligations for those files: preserve copyright notice (`MegaLinter by OX Security`), preserve AGPL license text (include `LICENSE` or notice), offer source (GitHub already does), and the AGPL would apply to those files themselves. The MIT license of the rest of the repo would not automatically become AGPL — this is **aggregation**, not a combined derivative, if the files remain separate and are not compiled/linked into a single program. The MIT files remain MIT.
- However, the AGPL's "network use is distribution" clause is not triggered by merely storing markdown docs in a repo; it is triggered by running the AGPL program as a network service. The linter Docker image, when run, is a separate AGPL program executed via Docker — not linked into Toolkit code. Using it via `docker run` or `npx mega-linter-runner` is **mere use**, not redistribution of its code inside Toolkit.
- Still, vendoring would mix licenses in one repo, require per-file license headers, and create maintenance burden (chasing upstream updates). Reviewers must verify each vendored file's license, and CI would need to enforce that the vendored bytes match the locked commit's checksum.

## What does external reference mean?

External (chosen):
- Toolkit does **not** copy upstream SKILL.md bytes into `skills/quality/megalinter/`. The single `skills/quality/megalinter/SKILL.md` in Toolkit is **first-party adapter** (MIT) that *references* the upstream skills via `sources` metadata and documents `npx skills add oxsecurity/megalinter/skills -s '*' -a <agent> -y` as the install step.
- At install time, the *user's* machine fetches the upstream skills directly from `oxsecurity/megalinter` at the pinned commit `15e5b45` / tag `v10.0.0` via the `skills` CLI. The Toolkit repository itself never contains the AGPL markdown bytes, so it never redistributes them. The user who runs `npx skills add` obtains the AGPL files directly from the AGPL licensor (OX Security) — compliance is between user and OX Security, not mediated by Toolkit.
- `capabilities/upstream.lock` still records the **resolved commit** (`15e5b45552097e318c93de385779ce3b1084052c`), **per-source content checksums** (`sha256:ffd79b...`, `b1cba...`, `bb8e4...`, `fff520...`) computed from the upstream raw bytes at that commit, and **observed license** `AGPL-3.0`. This provides governance without redistribution.
- Docker image and npm runner are likewise **referenced**, not vendored: `ghcr.io/oxsecurity/megalinter:v10` is pulled at runtime via Docker, `mega-linter-runner@10.0.0` via npm. No image layers are committed to Toolkit.

**Why external is cleanest (avoiding imprecise 'infect' language):**
- AGPL does not automatically "infect" MIT files in the same repo when they are separate works (aggregation). The imprecise phrase overstates the obligation.
- The real reason to keep external is **operational simplicity + legal uncertainty avoidance**: (1) no need to ship AGPL `LICENSE` alongside each vendored file and audit each update, (2) no question whether a vendored markdown doc is a "derivative" of the AGPL program, (3) the official `oxsecurity/megalinter` skills remain the maintained source of truth — Toolkit avoids drift from manual copy, and updates are via `npx skills update` + provenance lock bump, not manual file sync.
- Therefore: `distribution: mode: external, redistribution_allowed: false` in the Toolkit adapter, with provenance lock for governance.

## Evidence

- `gh api repos/oxsecurity/megalinter --jq .license.spdx_id` → `AGPL-3.0` (2026-08-12)
- `curl -sL https://raw.githubusercontent.com/oxsecurity/megalinter/main/LICENSE | head -5` → `GNU AFFERO GENERAL PUBLIC LICENSE`
- `gh api repos/oxsecurity/megalinter/contents/skills/megalinter --jq .[].name` → `SKILL.md` only, no LICENSE
- `curl -sL https://raw.githubusercontent.com/oxsecurity/megalinter/15e5b45552097e318c93de385779ce3b1084052c/skills/megalinter/SKILL.md | head -1` → `licence: MegaLinter by OX Security...` (not SPDX)
- Checksums (2026-08-12): `ffd79b1c...` (orchestrator), `b1cba393...` (setup), `bb8e4759...` (check), `fff5202a...` (fix) — `sha256:` prefixed in lock.
- Docker: `docker manifest inspect ghcr.io/oxsecurity/megalinter:v10 --verbose` shows config digest `sha256:939058f3ed31803e12583365e7126eacfb356724bf003fd29e96a93948aa2d33` (single-arch v2 manifest as of 2026-08-12; for multi-arch, use `docker buildx imagetools inspect ghcr.io/oxsecurity/megalinter:v10` to see manifest list index digest — prefer retaining `version: v10` tag + digest when pinning, not digest-only, per 2026-08-11 review).
- npm: `npm view mega-linter-runner@10.0.0 dist.integrity` → `sha512-yQOyD8...`
