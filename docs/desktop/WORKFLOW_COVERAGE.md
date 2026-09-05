# Desktop workflow coverage

Baseline: `85853decda84b9af70cee48889d00c22c543f79d`, fetched 2026-09-05.
This ledger is intentionally conservative. A control or method is not proof of a
working journey. `scripts/gui-coverage.py` remains a command-affordance check only.

Legend: **P** source path exists but partial/unverified; **B** known blocking defect;
**?** not exercised; **N/A** stage does not apply; **✓** exercised successfully with
linked evidence. No workflow currently earns end-to-end completion from this audit.

| Workflow | Discover | Configure | Preview | Execute | Observe | Recover | Undo |
|---|---|---|---|---|---|---|---|
| Clean onboarding | P | P | ? | B | B | ? | ? |
| Existing environment adoption | P | P | ? | B | ? | ? | ? |
| Capability discovery | B | P | N/A | N/A | B | ? | N/A |
| Install skills/agents | P | P | P | B | B | ? | B |
| Coding tools/targets | B | P | P | B | B | ? | B |
| MCP setup/probe | P | P | P | ? | ? | ? | ? |
| Jobs | P | P | ? | B | B | ? | N/A |
| Loops | P | P | ? | B | ? | ? | ? |
| Swarms | P | P | ? | ? | B | ? | ? |
| Doctor repair | P | P | P | ? | ? | ? | ? |
| Terminal lifecycle | P | P | N/A | P | B | ? | N/A |
| Workspace create/switch | P | P | ? | B | B | ? | ? |
| Workspace files/Git | P | P | ? | B | B | ? | ? |
| Insights | P | P | N/A | N/A | B | ? | N/A |
| Universal search/actions | P | B | B | B | ? | ? | ? |
| Installed app/launcher | ? | ? | N/A | ? | ? | ? | ? |
| Check/apply product update | P | ? | ? | ? | ? | ? | ? |

## Evidence and release blockers

The synthetic-state blocker is resolved for the current production paths. The
historical source locations below remain useful audit references, but the
required proof is now represented by Engine catalog/receipt tests and neutral
empty-state implementations. Visual and end-to-end workflow evidence is still
incomplete, so this ledger must not be treated as release-complete.

Source paths below refer to the baseline SHA; line numbers will move as fixes land.

| Blocker | Evidence | Required proof |
|---|---|---|
| Synthetic catalog and receipts | `modules/desktop_engine/skills_service.v:122`, `agents_service.v:109`, `receipts_service.v:115`; `product_truth_test.v:35` enforces padding | Real resources only, empty/error cases and no synthetic production fallback |
| Install reports success without deploying | `skills_service.v:383`, `agents_service.v:444`, `targets_service.v:171`, `onboarding_service.v:232` | Preview/apply real files, verify receipt, partial failure and rollback |
| Fabricated running state and telemetry | `cmd/agent-toolkit-desktop/main.v:1754`, `:1859`, `:4463`, `:5155`, `:5311`, `:5359`, `:5420`, `:6970` | Clean setup remains empty; real events and processes produce matching UI |
| False process success | `modules/desktop_engine/jobs_service.v:263` | Failed spawn reports failure, no running record |
| Workspace safety and invented state | `onboarding_service.v:138`, `workspace_service.v:160`, `:271`, `:727` | Containment, no-overwrite, partial failure, actual Git and memory state |
| Dead/split action discovery | `main.v:7908`; `modules/desktop/palette/palette.v:468` | Typed registry, retained entity identity, functional dispatch/forms/results |
| Domain duplication | CLI `dispatch.v` imports core; Desktop install services duplicate logic; `loops_service.v:480` invokes own CLI | Shared typed domain execution with GUI/CLI parity tests |
| Native capability misreporting | `modules/desktop/backend/backend.v:139`, `:164`, `:193` | Actual clipboard/dialog operation or explicit unsupported result |
| Terminal exit and identity | `modules/pty/pty.v:197`; `modules/ghostty/ghostty.v:5` | Reaped child/closed fd, no unexpected restart, honest VT compatibility |
| Accessibility and Arabic | `main.v:1253`, `:1366`; no OS accessibility bridge identified | Shaping/bidi and assistive-tech evidence or explicit limitation |
| Packaging/docs drift | `make.vsh:201`, `docs/desktop/PACKAGING.md`, ADR-032 | Packaged binary outside checkout and reconciled architecture docs |

## Updating coverage

Each accepted workflow needs the build SHA, persona/fixture, entry point, actions,
expected and observed result, failure/recovery case, screenshot links where relevant
and reviewer. Record real filesystem/process postconditions for mutations. Mark
unsupported stages explicitly; never award a checkmark for a palette string, fake
receipt, source-only test or unviewed golden. Add regression tests around actual
outcomes, including empty, loading, Engine/config error, partial success, long data,
one result and large datasets.

Delivery order follows dependencies: establish truth and safe operations; converge
shared action/focus/geometry contracts; improve shell and onboarding; then Office,
inspector and domain workflows; finish native packaging, localization, performance
and full product consistency. The master tracker remains open until blockers pass.

Update acceptance must verify the downloaded artifact, checksum/provenance, actual
installed version and failure recovery. Respect package-manager ownership and
rollback limits; a state-only version change is not an update. Audit
`modules/desktop_engine/update_service.v` and channel policy before enabling apply.
