# ADR-022: Machine-readable GitHub Release manifest

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#488](https://github.com/ulises-jeremias/agent-toolkit/issues/488))

## Context

Wrappers (PyPI wheel build, Homebrew Formula updater, AUR `-bin` PKGBUILD, future npm) must select a GitHub Release asset by `{os, arch, channel, libc}` without scraping HTML. [ADR-018](ADR-018-release-artifacts.md) defined floating names and versioned archives but deferred the JSON document those adapters parse. Checksums and attestations ([#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530)) need a single object to attach hashes to.

GitHub Releases remain the **canonical** artifact source. The manifest is an index of those assets, not a second download channel.

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | One `manifest.json` asset per GitHub Release | Schema-versioned JSON listing every binary and archive for that tag. |
| **B** | Per-platform sidecar (`*.json` next to each binary) | Many small files; wrappers must know names before they can fetch the sidecar. |
| **C** | GitHub Release body / notes as YAML | Human-edited; breaks automation; not checksummable as a first-class asset. |
| **D** | SLSA / in-toto only, no custom JSON | Provenance is complementary; Homebrew/AUR still need a simple os/arch map. |

## Decision

Adopt **A**.

### Filename

Attach exactly one manifest asset named:

```text
manifest.json
```

Do **not** version the filename (`agent-toolkit-1.10.0.manifest.json`). The GitHub Release *tag* already versions the object. Wrappers fetch:

```text
https://github.com/ulises-jeremias/agent-toolkit/releases/download/<tag>/manifest.json
```

Experimental prereleases use the same filename on the prerelease; `channel` inside the document distinguishes `stable` vs `experimental` assets (ADR-018 prefix `agent-toolkit-v-experimental-<os>-<arch>`).

### Document shape

JSON Schema: [`schemas/release-manifest.schema.json`](../../schemas/release-manifest.schema.json). Required top-level keys:

| Field | Type | Meaning |
|-------|------|---------|
| `schemaVersion` | integer (`1`) | Manifest format. Bump only with a new ADR. |
| `name` | string | Always `agent-toolkit`. |
| `version` | string | Semver **without** a leading `v` (matches archive names in ADR-018). |
| `gitTag` | string | GitHub tag including `v` when present (`v1.10.0`). |
| `channel` | `stable` \| `experimental` | Release channel of this GitHub Release. |
| `releasedAt` | string (RFC 3339) | UTC timestamp of publish. |
| `assets` | array | One entry per uploaded file that wrappers may consume. |

Each `assets[]` entry:

| Field | Type | Meaning |
|-------|------|---------|
| `os` | `linux` \| `macos` \| `windows` | ADR-018 tokens (not `darwin`). |
| `arch` | `x86_64` \| `arm64` | ADR-018 tokens (not `amd64`). |
| `libc` | `gnu` \| `musl` \| omit | Linux only. MUST `gnu` for stable glibc ([ADR-019](ADR-019-linux-libc.md)). Omit on macOS/Windows. |
| `channel` | `stable` \| `experimental` | May mix experimental assets onto a prerelease only. |
| `kind` | `binary` \| `archive` \| `sums` \| `sbom` | Floating binary vs versioned archive vs `SHA256SUMS` vs SBOM. |
| `filename` | string | Exact GitHub Release asset name. |
| `sha256` | string | 64 lowercase hex digits of the asset bytes. Empty **forbidden** on `binary`/`archive` once [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) lands; until then CI MAY emit `""` only in experimental spikes. |
| `url` | string | Canonical `https://github.com/ulises-jeremias/agent-toolkit/releases/download/<tag>/<filename>`. |

`kind: sums` is the `SHA256SUMS` file itself (hash of that file, not a nested table). Wrappers MUST prefer `assets[].sha256` over parsing HTML.

### Example

```json
{
  "schemaVersion": 1,
  "name": "agent-toolkit",
  "version": "1.10.0",
  "gitTag": "v1.10.0",
  "channel": "stable",
  "releasedAt": "2026-08-13T00:00:00Z",
  "assets": [
    {
      "os": "linux",
      "arch": "x86_64",
      "libc": "gnu",
      "channel": "stable",
      "kind": "binary",
      "filename": "agent-toolkit-linux-x86_64",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "url": "https://github.com/ulises-jeremias/agent-toolkit/releases/download/v1.10.0/agent-toolkit-linux-x86_64"
    }
  ]
}
```

### Wrapper lookup

Given host `{os, arch, libc}` and desired `channel`:

1. GET `manifest.json` for the chosen tag (or `latest` **only** after verifying the tag matches `gitTag`).
2. Select `kind: archive` when the wrapper unpacks (Homebrew/AUR); select `kind: binary` when the wrapper copies a single file (PyPI wheel bundle).
3. Verify downloaded bytes against `sha256` before install/exec ([#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530), threat model [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)).
4. Do **not** scrape the GitHub HTML releases page as a primary resolver.

### Rejected

- **B** — chicken-and-egg: need the binary name to find its sidecar.
- **C** — release notes are not a schema.
- **D** — attestations do not replace an os/arch index; they complement it in #530.

## Consequences

- **Positive:** Homebrew/AUR/PyPI CI can pin `{tag, filename, sha256}` without HTML; #530 has a place to put hashes; libc variants (#485/ADR-019) are first-class fields.
- **Negative:** Release job must generate and upload this file; a stale/missing manifest is a release defect, not a wrapper bug.
- **Follow-on:** [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) emits `SHA256SUMS` + fills `sha256`; PyPI [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535) / Homebrew [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490) / AUR [#491](https://github.com/ulises-jeremias/agent-toolkit/issues/491) consume it. Runtime download of binaries (ADR-021 option B) stays blocked on [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563).

## Validation plan

- `schemas/release-manifest.schema.json` validates the example in this ADR (`additionalProperties: false`).
- When #530 lands, the release workflow uploads `manifest.json` and a CI step `jsonschema`s it.
- Floating `filename` values MUST match ADR-018 tables.

## References

- Issues [#488](https://github.com/ulises-jeremias/agent-toolkit/issues/488), [#484](https://github.com/ulises-jeremias/agent-toolkit/issues/484), [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530), [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)
- [ADR-018](ADR-018-release-artifacts.md), [ADR-019](ADR-019-linux-libc.md); PyPI wheels [#486](https://github.com/ulises-jeremias/agent-toolkit/issues/486)
