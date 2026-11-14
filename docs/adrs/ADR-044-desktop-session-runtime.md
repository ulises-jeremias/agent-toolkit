# ADR-044: Desktop session runtime in the Electron main process; new frontend over the V services

- Status: Accepted (owner decision under mission #1775; supersedes the "runtime in V" part of ADR-043)
- Date: 2026-11-12
- Related: #1667, #1669, #1670, #1671, #1775, ADR-027, ADR-033, ADR-037, ADR-038, ADR-043

## Context

The packaged Desktop was run end to end on 2026-11-12 ([RESCUE.md](../desktop/RESCUE.md)). It has no
coding conversation: a session is a raw PTY running a provider TUI, so turns, tool calls, approvals,
diffs and history are invisible to the product. ADR-043 proposed building one provider adapter in V.
Three things changed the picture:

1. Every provider's structured transport is a long-lived, bidirectional stdio or HTTP protocol with
   server-initiated requests (approvals). Measured on this host with real signed-in CLIs:
   - Claude Code 2.1.322: `claude -p --input-format stream-json --output-format stream-json
     --include-partial-messages --permission-prompt-tool stdio` streams text and tool events, sends
     `can_use_tool` control requests, honours `interrupt`, and continues a conversation with
     `--resume <session id>`. One fixture fix: 78 frames, edit applied, 12.5 s.
   - Codex 0.167.2 exposes `codex app-server` (JSON-RPC over stdio) and OpenCode 2.2.7 exposes
     `opencode serve` (HTTP + events). Source inspection of T3 Code (`ddc4f576`, MIT) confirms both
     carry approvals, interrupt and resume.
2. V has no maintained JSON-RPC/NDJSON process-supervision stack. Writing one would be the largest
   new V surface in the repository and would still need a second implementation of the provider
   quirks that Electron already has to know for the PTY path.
3. The mission issue states that a V-only runtime is not required and that the Desktop must be a
   truthful projection of session state.

Reference projects were inspected at source (not adopted): T3 Code (MIT) is a complete competing
server and client; Agent Office (MIT, 3D), Munder Difflin (MIT code, non-redistributable LimeZu
tilesets) and Pixel Agents (MIT code, art provenance unverified) observe sessions through hooks or
transcript tailing rather than driving them. No art from any of them is reused.

## Decision

1. **Session runtime in TypeScript, in the Electron main process** (`apps/desktop/electron/focus/`).
   One `ProviderSession` adapter per provider speaks that provider's own structured protocol to the
   user's installed, signed-in CLI. No API keys, no bundled provider SDKs.
2. **One canonical model**: thread → turn → event (`apps/desktop/src/types/focus.d.ts`). Adapters
   normalise native frames into `user`, `assistant`, `reasoning`, `tool.started`, `tool.finished`,
   `approval.requested`, `approval.resolved`, `turn.started`, `turn.finished`, `notice`.
3. **The journal is the only history**: thread metadata plus append-only `events.jsonl`. Streaming
   deltas are live-only. A turn that was running when the app exited is closed in the journal as
   `interrupted`; nothing is shown as running without a live process. ADR-045 supersedes this ADR's
   original workspace-local storage path with private app storage and a nondestructive migration.
4. **Provider readiness comes from the provider**: `claude auth status --json`, `codex login status`,
   `opencode auth list`. A binary on PATH is "installed", never "ready". Account identifiers are
   dropped in the main process.
5. **V keeps the domain**: projects, Git, skills and catalog, memory, people, loops, swarms, install.
   The renderer keeps using the typed HTTP client for those.
6. **New frontend over those services**: the shell, onboarding, Focus and World are rebuilt; People,
   Library and Operations are re-homed and restyled rather than rewritten from zero.
7. Adding a provider means adding one adapter and one row in the provider probe. The renderer reads
   capabilities; it has no provider-name branches.

## Consequences

- `apps/desktop/README.md` and `AGENTS.md` no longer say "no domain logic in TypeScript": provider
  session orchestration is the one domain that lives in `electron/`. Everything else stays in V.
- Sessions end with the app. Detached survival (as the PTY host does, ADR-037) is deliberately not
  attempted for structured sessions; resume covers continuity where the provider supports it.
- The CLI cannot list or continue Focus threads yet. The journal format is plain JSONL so V can
  project it later without a migration.
- We own provider protocol drift. Each adapter ignores frames it does not understand and is covered
  by a scripted stand-in plus a recorded real-provider run.
- The interactive PTY path (People → Start, Terminal) keeps working unchanged.

## Implementation correction — 2026-11-14

Focus permission mode `ask` now maps to Claude Code's `manual` mode instead of `default`.
The installed Claude Code 2.1.325 accepts `manual`; `default` can approve some tools using
CLI heuristics or user settings, which does not meet Focus's explicit approval promise. A
source-build Electron run with a disposable repository showed a pending file-edit approval
before the change and applied the file only after `Allow once`. Older Claude Code versions
have not been checked for `manual` support; provider discovery does not yet detect this mode
capability, so an older CLI may report a start failure rather than being blocked in advance.

Git and file review invalidation now lives in the always-mounted Focus view and responds to
`tool.finished` and `turn.finished`, including when the optional inspector was closed during
the edit. Real Git API responses showed the new file as untracked. The full live-provider
journey through panel rendering, terminal input, restart and World routing still needs a
completed acceptance run; no conclusion is drawn from the partial run.

## Alternatives rejected

- **Adapter in V (ADR-043)**: correct ownership, wrong cost; see Context 2.
- **Fork or sidecar T3 Code**: a second state authority and a second product to track.
- **`@anthropic-ai/claude-agent-sdk`**: convenient, but adds a proprietary-licensed dependency and a
  bundled CLI when the user's own CLI already speaks the protocol.
- **ACP for everything**: needs extra adapter binaries installed per provider; kept as an option for
  providers that only speak ACP.
