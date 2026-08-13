# Migration risk register

**Issue:** [#478](https://github.com/ulises-jeremias/agent-toolkit/issues/478)  
**Parent:** [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)  
Living register. Likelihood (L) / Impact (I): H/M/L. Update when an ADR closes a row.

| Risk | L | I | Mitigation | Detection | Fallback | Status |
|------|---|---|------------|-----------|----------|--------|
| V pre-1.0 breaking changes | H | H | Pin `.v-version` (0.5.2); `import json` not json2; upgrade PRs + parity | CI on pin bump | Stay on pin | **Open** — pin in tree |
| YAML ecosystem gaps | M | H | Constrained schemas; prefer vlib yaml | Parser fixtures | JSON IR internally | Open |
| JSON Schema validation gap | M | H | Python `jsonschema` remains in harness until V validator exists | Schema tests | Keep Python validator | Open |
| Cross-platform FS/symlinks | H | H | Filesystem service; no assume POSIX symlink | Win/mac parity jobs | Per-OS quarantine | Open |
| macOS cross-compile unsupported | H | H | Native `macos-latest` + `macos-15-intel` in `release.yml` | Release matrix | N/A | **Mitigated** [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529) |
| PyInstaller→native cutover gaps | M | H | V assets on GitHub Release since `v1.11.0` ([#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530)); Python wheel still publishes as launcher | Release smoke | Keep wheel + `agent-toolkit-py` | **Mitigated** `v1.11.0` |
| Dual-engine drift | H | H | Golden `tests/parity/`; short dual period; ADR-012 | Parity CI | Product path is V-only; `agent-toolkit-py` quarantined | **Mitigated** [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) |
| PyPI wheel tag complexity | M | M | ADR-021 A; `py3-none-{plat}` hatch tag | Install smoke | Do not default to download-B ([#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)) | **Mitigated** ADR-021/#535 |
| npm optionalDeps failures | M | M | Exit 127 + message; glibc-only (ADR-019) | Matrix smoke | GitHub binary / `AGENT_TOOLKIT_BIN` | **Mitigated** ADR-025/#536 |
| Homebrew/AUR empty sha256 | H | H | Fail-closed until Release assets exist; do not merge Formula with all-zero sha256 | Tap CI / brew fetch | GitHub binary / uv launcher | **Mitigated** `v1.11.0` (Homebrew Formula + AUR `agent-toolkit-bin`) |
| Unsigned macOS/Windows prompts | H | M | Checksums MUST; notarization/Authenticode FUTURE | Manual UX | Document Gatekeeper steps | See [#543](https://github.com/ulises-jeremias/agent-toolkit/issues/543) |
| Runtime download of binaries | M | H | Reject as product default ([#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)) | Threat model review | Bundle-at-build | **Mitigated** |
| Attestations ≠ secure software | L | M | SBOM/attestations SHOULD prove provenance only | Docs | Checksums MUST | **Mitigated** [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) |
| Package manager `update` clobber | M | H | ADR-017: `update` is capability-only | Doctor / tests | Reinstall via brew/AUR/npm/uv | **Mitigated** ADR-017 |
| Bobatea / TUI unknown API | L | L | Do not invent APIs; [#542](https://github.com/ulises-jeremias/agent-toolkit/issues/542) spike only | — | Skip TUI | **Accepted** (P3) |

## Signing (EPIC 17)

Checksums are MUST. GitHub artifact attestations and SBOM are SHOULD. Paid Apple notarization and Authenticode are FUTURE ([#543](https://github.com/ulises-jeremias/agent-toolkit/issues/543), [#474](https://github.com/ulises-jeremias/agent-toolkit/issues/474)).
