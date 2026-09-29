# Agent Toolkit Desktop

Electron + React workstation over the canonical `agent-toolkit serve` backend.
See [ADR-033](../../docs/adrs/ADR-033-electron-desktop.md) and
[docs/desktop/ELECTRON_MIGRATION.md](../../docs/desktop/ELECTRON_MIGRATION.md).

Foundation: Create Awesome Node App `react-vite-starter` (React 19, Vite 8,
TypeScript 6 strict, ESLint + jsx-a11y + Prettier). All package management
with **pnpm** only — one canonical lockfile at the repo root.

## Architecture

- **V is the backend.** Every destination reads/mutates through the typed
  client in `src/lib/api.ts` (TanStack Query owns server state). No domain
  logic in TypeScript, no CLI-output parsing, no Node backend.
- **`electron/` is infrastructure only**: window lifecycle, supervising the
  bundled `agent-toolkit serve --no-browser` on a dynamic localhost port
  (health-gated, version-checked, crash-detected, clean shutdown), narrow
  typed preload bridge (`contextIsolation`, no `nodeIntegration`), and the
  node-pty terminal transport adapter.
- Destinations: Office, Operations, Workspace, Library, Insights, Terminal,
  Settings — all controls hit real backend endpoints.

## Develop

```bash
pnpm install                    # from repo root (builds electron, node-pty)
pnpm --filter agent-toolkit-desktop dev          # renderer vs any backend
pnpm --filter agent-toolkit-desktop dev:electron # full shell (needs built main)
pnpm --filter agent-toolkit-desktop gen:api      # regenerate from docs/surface/openapi.json
```

Backend for renderer dev: `agent-toolkit serve --no-browser`, or set
`VITE_ATK_BACKEND_URL` (default `http://127.0.0.1:3847`).

## Gates

```bash
pnpm --filter agent-toolkit-desktop lint
pnpm --filter agent-toolkit-desktop type-check
pnpm --filter agent-toolkit-desktop test
pnpm --filter agent-toolkit-desktop build        # renderer
pnpm --filter agent-toolkit-desktop build:all    # renderer + electron main
pnpm --filter agent-toolkit-desktop test:e2e     # Playwright vs live backend
pnpm --filter agent-toolkit-desktop dist:dir     # electron-builder, unpacked (Linux verified)
```

## Decisions that differ from the template (documented, not accidental)

- `tsconfig.json` has no project `references`; renderer and electron/node
  projects type-check independently (`tsc --noEmit && tsc -p tsconfig.node.json --noEmit`).
- ESLint uses `tseslint.configs.recommended` (not type-checked) like the
  template; strict safety comes from `tsc`. import-x uses the node resolver:
  its TypeScript resolver does not support TS 6 yet.
- `vite-plugin-eslint` types come from a local `vite-plugin-eslint.d.ts` shim
  (the package's exports map breaks TS `bundler` resolution).
