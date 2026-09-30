# ADR-033 — Desktop: Electron + React canonical, V remains core/CLI/backend

- **Status:** Proposed (2026-09-29) — branch `feat/electron-desktop`
- **Deciders:** ulises-jeremias (owner)
- **Supersedes (presentation only):** ADR-032 (native vlang/gui Desktop)
- **Amends:** ADR-027 (server/core boundary), ADR-028 (server security), ADR-030 (binary-first contract)
- **Rollback:** v1.35.0 (native Desktop preserved; see `docs/desktop/ELECTRON_MIGRATION.md`)

## Context

ADR-032 chose a native V GUI for Desktop. In practice the custom renderer keeps
re-fighting web-platform primitives (accessibility, text measurement, focus,
terminal emulation) that Electron + React provide for free, while all Agent
Toolkit domain value lives in V core and `agent-toolkit serve` (ADR-027/030).

## Options

### 1. Keep the native V GUI (ADR-032, status quo)

- Pros: single binary, no Node toolchain, small footprint.
- Cons: custom renderer re-fights accessibility, text measurement, focus
  management, and terminal emulation; slowest path to a daily-usable
  workstation; design convergence stalls on renderer gaps.
- Rejected: the renderer — not the product model — is the bottleneck.

### 2. Tauri / WebView-native hybrid

- Pros: smaller footprint than Electron, system webview.
- Cons: new backend binding layer in Rust, weakest terminal story
  (still needs a PTY transport decision), thinner packaging ecosystem than
  electron-builder, and the team already validated the Vite/React foundation
  via Create Awesome Node App templates.
- Rejected: higher integration risk for no product gain.

### 3. Electron + React over `agent-toolkit serve` (chosen)

- Pros: full Chromium accessibility primitives, xterm.js fidelity, mature
  electron-builder packaging, node-pty ConPTY coverage on Windows, V stays
  the sole domain authority behind a typed OpenAPI contract.
- Cons: larger install footprint; two toolchains (V + Node) with one
  canonical pnpm lockfile; backend binary bundled per platform.

## Decision

From now on:

- **V = core + CLI + server/backend.** `agent-toolkit serve` is the canonical
  programmatic backend. All domain truth (catalog, agents, skills, installs,
  receipts, workspaces, memory, jobs, loops, swarms, approvals, budgets,
  Doctor, Insights, safety) stays in V and is consumed over typed HTTP APIs.
- **Electron + React = Desktop application** (`apps/desktop/`, pnpm, Vite,
  TypeScript strict, TanStack Query for server state, Zustand for client-only
  UI state, xterm.js terminals, Vitest + RTL + Playwright, electron-builder).
- Electron main/preload own **desktop infrastructure only**: lifecycle,
  supervising the bundled `agent-toolkit serve`, native integrations, secure
  IPC, updater, and the node-pty terminal transport adapter.
- React never parses CLI output and hosts no second backend; OpenAPI
  (`docs/surface/openapi.json`, generated client via `pnpm gen:api`) is the
  V↔TypeScript contract.
- Terminal transport is **node-pty in Electron main** (strictly a PTY adapter,
  no domain state), chosen over the V `modules/pty` backend because the V
  module is POSIX-only while node-pty provides ConPTY on Windows.
- The native V GUI is retained as a functional reference until the Electron
  product reaches verified replacement; v1.35.0 remains the rollback release
  (tags are never moved or rewritten).

## Consequences

- Desktop gains real accessibility, terminal fidelity, and iteration speed.
- Cost: Electron footprint + Node toolchain alongside V (one canonical pnpm
  lockfile; V release automation bundles the backend binary as an app resource).
- Backend gaps the Desktop needs (typed domain models beyond generic
  envelopes, read-classified GET subs, job cancellation) are tracked in
  `docs/desktop/ELECTRON_MIGRATION.md` and land in V — never worked around in
  TypeScript string parsing.

## References

- Branch: `feat/electron-desktop` → PR (TBD; links EPIC for Desktop v2.0.0)
- Rollback proof: `docs/desktop/ELECTRON_MIGRATION.md` (v1.35.0 == main tree)
- Template: Create Awesome Node App `react-vite-starter`
  (`projects/cna-templates/templates/react-vite-starter`)
- Capability reference: `docs/desktop/WORKSTATION_REFERENCE_ANALYSIS.md`
  (in-repo; Munder Difflin + Agent Office as capability references only;
  identity not copied). Workspace note
  `agent-toolkit-vs-munder-difflin-analysis.md` is historical.
- Review: owner review required before ACCEPTED (human review gate).
