# Desktop Rescue record

Mission [#1775](https://github.com/ulises-jeremias/agent-toolkit/issues/1775), parent
[#1667](https://github.com/ulises-jeremias/agent-toolkit/issues/1667). This file is the evidence
record: what was recovered, what was measured, and what is still unverified. The decision is in
[ADR-044](../adrs/ADR-044-desktop-session-runtime.md).

## 1. Forensics: Muse Code session `01a1c6ee-e6b9-7aa2-bcbd-07fb9e2b3822`

Recovered on 2026-11-12 with the supported exporter (`muse export --session <id> --redacted`) from
local session storage. The export decoded 72,985 durable records with no unparseable lines; 4,780
live-only tool-delta records are omitted by the exporter by design.

| Fact | Value |
|---|---|
| Span | 2026-11-10 19:28Z to 2026-11-12 05:45Z, 20 runs |
| Model / mode | `muse-wonder-1.0`, approvals and sandbox disabled (`--yolo`) |
| Subagents | 22 accepted spawns (19 workflow agents, 3 art agents), 3 workflow scripts |
| Abnormal ends | one inferred process loss at 2026-11-12 02:58Z (cause not established from the retained session evidence); final run cancelled by the owner mid-step |

What the session did, re-checked against GitHub on 2026-11-12:

| Workstream | Session claim | Verified state |
|---|---|---|
| PXL Renaissance, mission #1741 | #1742, #1743, #1744, #1750, #1746 merged; #1745 replaced | all merged; #1745 closed unmerged; #1741 closed |
| Governance | PXL skill left `experimental`, lifecycle documented (#1753) | `tier: experimental` on main; no human review recorded |
| Release | v1.49.0 published, CI fix #1756, #1655 merged | release exists with 20 assets |
| Website portal, mission #1759 | #1762, #1763, #1764, #1767 merged; ImgBot #1766 closed | all as claimed; #1759 closed |
| Daily driver gates 0 and 1 | #1758, #1760, #1761 (ADR-043), #1765, #1768, #1769, #1772 merged | all merged |
| Unfinished at cancellation | #1773 (server rejects linking a repo outside the workspace) and #1774 (first-run journey) open, CI running | both reviewed and merged under this mission |

Work the session left behind:

- **No structured coding session.** Every "genuine traversal" drove a provider TUI inside xterm. The
  session's own ledger records D04 as "Raw PTY stream only".
- Gate 0 stays `unverified` overall in `daily-driver-evidence.json`; OpenCode runs were blocked by a
  provider quota.
- ADR-043 was written but none of it was implemented.
- ImgBot #1771 is open and fails `gates` because it rewrites deterministic generated sprites.
- Human-only items it correctly did not fabricate: PXL trust review, screen-reader pass, art sign-off.
- 16 local worktrees and their branches remain on the owner's machine; every one maps to a merged PR.

Not recoverable: reasoning content is encrypted in the export, and tool deltas are live-only. The
analysis uses committed messages, tool calls, subagent results and run boundaries.

## 2. Baseline: the packaged app, actually run

Packaged build of `main` + #1773 (`electron-builder --dir`, Electron 44.11), real backend binary,
headless ozone, Linux x86_64, 2026-11-12. Every destination was opened at 1440×900, six of them also
at 1024×640 and 1920×1080.

Ranked defects:

1. **There is no Focus.** No destination shows a conversation. A session is a terminal tab
   ([capture](assets/rescue/baseline-session-terminal-1024.png)); tool calls, approvals and diffs do
   not exist as product state.
2. **Navigation is nine internal nouns** in a pixel font under three stacked bars. "Attention" lives
   at `/office`; "Terminal" is both a page and a dock; Doctor appears in two places.
3. **Copy defends the implementation instead of helping**:
   [Library](assets/rescue/baseline-library-1440.png) ("Catalog membership and receipt-backed
   installs stay distinct. Memory is not this room"),
   [Operations](assets/rescue/baseline-operations-1440.png) ("The board lists only what serve
   returned", "GET /api/v1/swarms").
4. **Providers are "available" when a binary exists.** Nothing checks sign-in.
5. **A slow machine breaks startup for good.** The backend `--version` probe timed out at 5 s (the
   cold binary took 25 s under memory pressure) and every screen stayed on "Loading…"
   ([capture](assets/rescue/baseline-backend-down-1440.png)). Fixed here by a 45 s probe budget.
6. **The World is flat and crowded** ([capture](assets/rescue/baseline-world-1440.png)): front-facing
   boxes on a top-down lawn, no light direction, half the map is undifferentiated forest, labels are
   6 px pixel text.
7. **Split truth**: workspace in a URL parameter and in the harness; session liveness reconciled only
   in the renderer; `workflows.yaml` says 18/18 ok while `daily-driver-evidence.json` says unverified.

## 3. Protocol measurements behind ADR-044

Real CLI, real subscription, disposable Git repository with one failing function.

| Check | Result |
|---|---|
| Structured turn | `claude` 2.1.322 emitted `system/init`, partial `stream_event`s, `assistant` blocks, `user` tool results and a `result` with usage |
| Approval | an `Edit` arrived as a `can_use_tool` control request with a session-scope suggestion; answering `allow` applied the edit (`a - b` → `a + b`) |
| Interrupt | a control `interrupt` during streaming returned success and the turn ended with `error_during_execution` |
| Resume | a new process with `--resume <session id>` answered a question about the earlier edit correctly |
| Models and account | the `initialize` response lists selectable models; `claude auth status --json` reports `loggedIn` and the plan |
| Through the new runtime | `FocusService` drove the same fix: 14 journaled events, two approvals, edit applied, then a second turn interrupted with its partial answer kept |

Provider status on this host at measurement time: Claude Code signed in (subscription), Codex signed
in (ChatGPT), OpenCode installed with no model provider connected.

## 4. Unverified

- Windows and macOS: nothing in this mission has been run there.
- Screen readers: not run. Keyboard and automated checks are not a WCAG conformance claim.
- Codex and OpenCode structured sessions until their adapters land and are run for real.
