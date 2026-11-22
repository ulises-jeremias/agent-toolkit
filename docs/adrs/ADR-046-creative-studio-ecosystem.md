# ADR-046: Creative Studio ecosystem ownership

- Status: Accepted
- Date: 2026-11-22
- Scope: `ulises-jeremias/agent-toolkit` (canonical), `HorneroOS/*`,
  `veasel-labs/veasel`, `veasel-labs/agent-toolkit`,
  `ulises-jeremias/agentic-workstation`, `ulises-jeremias/dotfiles`

## Context

Professional creative applications (Kdenlive, Blender, GIMP, Krita, OBS,
REAPER, FFmpeg) are becoming drivable by AI agents through MCP servers and
application scripting. Without an ownership decision, the same capability
would be re-implemented per repository: skills copied into an OS image, MCP
configs embedded in dotfiles, a second job engine inside a desktop plugin,
or creative logic hard-coded into an agent runtime.

## Decision

**Build capabilities once. Distribute them everywhere. Integrate them
natively where appropriate.** HorneroOS Studio is the best environment to
use these capabilities, never the only one.

### Canonical ownership

| Concern | Owner | Notes |
|---------|-------|-------|
| Creative skills and workflows | **Agent Toolkit** (`skills/creative/`) | First-party `SKILL.md` sources; `plugins/` stays generated |
| MCP registry entries and client templates | **Agent Toolkit** (`mcp/registry/`, `mcp/templates/`) | Placeholders only, pinned upstream revisions, no secrets |
| Creative agent definitions | **Agent Toolkit** (`agents/`) | Roles route to skills; they do not duplicate workflows |
| Distribution product | **Agent Toolkit** (`distributions/products.yaml`) | `agent-toolkit-creative-studio`, opt-in, experimental until verified per client |
| Agent execution, tool permissions, sessions | **Agent runtime** (Veasel, Claude Code, Codex, …) | Portable workflows never depend on one runtime |
| Plugin marketplace distribution | **Veasel Agent Toolkit** (`veasel-labs/agent-toolkit`) | By reference (repo + ref + pinned SHA), review-gated; never vendored |
| Application availability, hardware, OS lifecycle | **HorneroOS** (`HorneroOS/hornero` editions catalogue) | Existing Studio catalogue; no second catalogue |
| Desktop experience | **HorneroOS Shell / Plugins** | Typed `horneroctl` contracts only; QML never hosts arbitrary MCP execution; PluginKit capabilities are review metadata, not a sandbox |
| Machine provisioning and diagnostics | **Agentic Workstation** | Optional creative profile; delegates capability install to Agent Toolkit |
| Personal preferences and hardware routing | **Dotfiles / local overrides** | Never promoted into public product defaults |

### Capability status contract

Every creative integration reports one of these states; nothing manufactures
readiness:

`available` · `installed-not-configured` · `configured-unavailable` ·
`unsupported` · `experimental` · `ready-verified` · `failed` · `interrupted`

### Project and artifact rules

- Source media is never modified in place; generated artifacts live apart
  from sources and caches (XDG; configurable project roots).
- Native editable projects (`.kdenlive`, `.blend`, `.xcf`, `.kra`, `.rpp`,
  SVG) are preserved next to exports.
- Every operation records source, tool, result and created artifacts in a
  project manifest so an interrupted session can resume.

### Security rules

- Third-party MCP servers are pinned and reviewed before registry inclusion;
  provenance is recorded next to each entry.
- Capability classes: read-only, bounded-write (allowed roots), high-risk
  execution (e.g. Blender Python) requiring explicit authorization.
- No silent uploads, paid calls, microphone/screen capture, or large model
  downloads. MCP listeners stay on loopback.

## Consequences

- Agent Toolkit gains a `creative/` skill domain, creative MCP entries,
  creative agents and an opt-in product; HorneroOS only extends its
  existing Studio contracts; Veasel consumes the same packages through its
  existing Agent Plugins/MCP contracts.
- Compatibility claims are per-client and evidence-backed (see
  `docs/creative-studio/COMPATIBILITY.md`). Untested means untested.
- Evidence for upstream MCP adoption decisions lives in
  `docs/creative-studio/UPSTREAM_EVALUATION.md`.

## Alternatives rejected

- Creative logic inside HorneroOS Shell/QML (unsandboxed, unportable).
- A new agent runtime, MCP registry, job engine or marketplace (existing
  implementations already cover the requirements).
- Vendoring third-party MCP servers into this repository (pinned external
  dependencies plus registry entries are sufficient and auditable).
