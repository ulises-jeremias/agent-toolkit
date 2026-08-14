# MegaLinter Images & Runners — 2026-08-12

**Release:** `v10.0.0` at `15e5b45552097e318c93de385779ce3b1084052c` (2026-08-08, `gh api repos/oxsecurity/megalinter/releases/tags/v10.0.0`)

## npm runner

- Package: `mega-linter-runner@10.0.0`
- Tarball: `https://registry.npmjs.org/mega-linter-runner/-/mega-linter-runner-10.0.0.tgz`
- `npm view mega-linter-runner@10.0.0 version` → `10.0.0`
- `npm view mega-linter-runner dist`:
  ```json
  {
    "shasum": "c9e3977ab8004e66c8417dd6c981198a1897a971",
    "integrity": "sha512-yQOyD8/MTeZ35MveiE6Stoj0/FgIGkV7jok3VriFI+VP30LouWYlohFWVbaUJm+8/gmwT2NxA6pCcSdFsZ7xkA==",
    "unpackedSize": 1538108
  }
  ```
- Usage: `npx mega-linter-runner --install --no-prompt --flavor <flavor> --setup-ci <ci>` / `--upgrade`; version follows `MEGALINTER_VERSION` in `.mega-linter.yml` (`npx mega-linter-runner@beta` only when `MEGALINTER_VERSION: beta`).

## Docker images

- **Registry:** `ghcr.io/oxsecurity/megalinter` (since v9.5.0, Docker Hub `oxsecurity/megalinter` frozen at v9.4.0; `npx mega-linter-runner --upgrade` does NOT rewrite registry prefix — manual migration to `ghcr.io/` required per `megalinter-setup` skill).
- **Tag:** `v10` (flavor-specific: `ghcr.io/oxsecurity/megalinter-python:v10`, `ghcr.io/oxsecurity/megalinter:v10` for `all`, etc.)
- **Manifest (2026-08-12):** `docker manifest inspect ghcr.io/oxsecurity/megalinter:v10` → `mediaType: application/vnd.docker.distribution.manifest.v2+json`, `config.digest: sha256:939058f3ed31803e12583365e7126eacfb356724bf003fd29e96a93948aa2d33`, 66 layers, single-arch v2 manifest as of this date.
- **Multi-arch note:** MegaLinter standalone images `megalinter-only-*` are only multi-arch on `beta` tag until v10; full flavor images are multi-arch via `ghcr.io`. Do **not** pin a platform-specific layer digest (e.g., `linux/amd64` layer sha) — pin the manifest list index digest if pinning digest at all. Per 2026-08-11 review, prefer **tag + verified digest** (`v10` + `sha256:9390...`) for readability + immutability, not digest-only. Test manifest-list handling with `docker buildx imagetools inspect ghcr.io/oxsecurity/megalinter:v10` (shows index vs manifest, platform digests).

**Recommendation for Toolkit consumers:**
- Keep `MEGALINTER_VERSION: v10` in `.mega-linter.yml` (human-readable) and document config digest for verification; do not hardcode digest in CI without testing multi-arch (e.g., `linux/arm64` vs `linux/amd64`).
- For strict pinning, record both: `version: v10.0.0, digest: sha256:939058f3...` (as in this file), but use tag in `docker run` / `uses: oxsecurity/megalinter@v10` (action, not Docker image).

## Configuration

- `.mega-linter.yml` JSON schema: `https://raw.githubusercontent.com/oxsecurity/megalinter/main/megalinter/descriptors/schemas/megalinter-configuration.jsonschema.json`
- This repo's `.mega-linter.yml` (2026-08-12): 6 linters, `VALIDATE_ALL_CODEBASE: false`, `FILTER_REGEX_EXCLUDE` excludes `.git|node_modules|.venv|skills/...data.csv|profiles/...`.
- CI `.github/workflows/mega-linter.yml` (pre-v10): `uses: oxsecurity/megalinter@v9` with `ENABLE_LINTERS: YAML_YAMLLINT, JSON_JSONLINT, MARKDOWN_MARKDOWNLINT, BASH_SHELLCHECK, PYTHON_RUFF, REPOSITORY_SECRETLINT, REPOSITORY_CHECKOV` + `DISABLE_ERRORS` for markdown/ruff/checkov.

