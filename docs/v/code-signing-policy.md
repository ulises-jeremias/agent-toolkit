# Code signing & OS trust prompts

**Issue:** [#543](https://github.com/ulises-jeremias/agent-toolkit/issues/543)  
**EPIC:** [#474](https://github.com/ulises-jeremias/agent-toolkit/issues/474) (supply-chain)  
Unsigned GitHub Release binaries are the **current** product. Paid Apple/Microsoft certificates are optional later — they are not a #540 gate.

## Policy table

| Control | Class | User-visible effect | Notes |
|---------|-------|---------------------|-------|
| `SHA256SUMS` + `manifest.json` on every stable Release | **MUST** | None until the user verifies | [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530), ADR-018/022. Homebrew/AUR/npm MUST pin these hashes. |
| GitHub artifact attestations | **SHOULD** | None | Prove **build provenance**, not “secure software”. |
| CycloneDX SBOM on the Release | **SHOULD** | None | Same provenance caveat. |
| macOS Gatekeeper (`com.apple.quarantine`) | **MUST document** | First run: “cannot be opened because the developer cannot be verified” | Workaround: `xattr -d com.apple.quarantine ./agent-toolkit` after checksum verify, or install via Homebrew once the Formula ships. |
| Apple Developer ID + notarization + staple | **FUTURE** | Prompt goes away | Requires paid Apple Developer account. Do not block V cutover. |
| Windows SmartScreen / Mark-of-the-Web | **MUST document** | SmartScreen “Windows protected your PC” on `.exe` from the browser | Unblock: Properties → Unblock, or `Unblock-File`. Prefer `winget`/checksum after download. |
| Authenticode (EV or OV) | **FUTURE** | Reputation builds over time | Paid cert; not a #540 gate. |
| Homebrew bottles | **MUST NOT** | — | ADR-023: upstream prebuilt GitHub binary, not bottled Python. |

## MUST NOT

- Claim SBOM/attestations mean the binary is malware-free.
- Merge a Homebrew Formula with all-zero `sha256` (fail-closed until a Release has real hashes).
- Download unsigned blobs at runtime as the product path ([#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)).

## Operator notes

Until notarization exists, docs (`INSTALLATION.md` / `TROUBLESHOOTING.md`) SHOULD mention Gatekeeper and SmartScreen. Checksum verification remains the trust root.
