---
name: chrome-devtools
description: Use Chrome DevTools MCP to control and inspect a live Chrome instance for network, console, performance, rendering, and Deep debugging. Pairs with playwright-cli (deterministic interaction/E2E) — complements, not duplicates.
origin:
  type: first-party
---

# Chrome DevTools

Control and inspect a **live Chrome** browser via the official `ChromeDevTools/chrome-devtools-mcp` (`chrome-devtools-mcp`, Apache-2.0) MCP server. Gives your coding agent the full power of Chrome DevTools for **runtime debugging, network inspection, performance analysis, and rendering diagnostics** — while `playwright-cli` remains the primary tool for deterministic interaction and E2E validation.

> **Complementarity:** `playwright-cli` → deterministic `locator/snapshot/assert` workflows, multi-tab, traces, screenshots. `chrome-devtools` → network + console + performance traces + rendering diagnostics + Puppeteer-based reliable automation via DevTools. **Do not** re-implement Playwright flows via DevTools JSON-RPC; pick the right provider per capability (see decision table).

## When to use which provider

| Need | Use `playwright-cli` | Use `chrome-devtools` | Either |
|------|----------------------|-----------------------|--------|
| Click / fill / navigate deterministically | ✅ locators, `snapshot` → stable `eN` refs, fixtures | — |  |
| Take screenshot of rendered state (verification required before declaring UI good) | ✅ `screenshot` + trace | ✅ `take_screenshot` + rendering inspection | ✅ |
| Assert E2E condition / generate test | ✅ assertions, `e2e-runner` specs | — |  |
| Inspect DOM / accessibility tree / computed styles | `snapshot` (a11y-aware) limited | ✅ DOM, a11y tree, style inspection |  |
| Network requests / console messages / runtime debugging | limited | ✅ `list_network_requests`, console, source-mapped stack traces |  |
| Performance trace / CrUX field data / insights | — | ✅ `performance_*` tools + CrUX |  |
| Reliable automation that auto-waits | — | ✅ Puppeteer-based `click/type/navigate` via DevTools |  |
| Extract JS-rendered data quickly | ✅ snapshot + CLI loop |  |  |

**Rule for design workflows:** `design-improvement` and `design-assessment` use `playwright-cli` for `implement → run → capture` (primary capture + interaction); pull in `chrome-devtools` when `browser.network / browser.console / browser.performance / browser.runtime-debug` is required. Either MCP alone suffices for degraded mode; together they cover `implement → render → capture → inspect → compare → iterate`.

## Prerequisites

- **Node.js LTS** + **npm** + **current stable Chrome** (or Chrome for Testing). Latest Chrome via [Extended Stable](https://chromiumdash.appspot.com/schedule).
- MCP host: Claude Code / Cursor / Gemini / OpenCode (native `mcpServers`), or bridged via `mcp-remote` — see `mcp/registry/chrome-devtools.yaml` `platforms`.
- No secrets — DevTools MCP runs a local browser; avoid sharing sensitive page content with the LLM. Prefer `FIGMA_TOKEN`-style isolation: do not commit real URLs with secrets.

Check availability:

```bash
agent-toolkit doctor 2>&1 | grep -i chrome
npx -y chrome-devtools-mcp@latest --help
```

## Installation (MCP)

**Claude Code (MCP-only, no plugin):**

```bash
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

**Claude Code (plugin + skills, recommended):**

```bash
/plugin marketplace add ChromeDevTools/chrome-devtools-mcp
/plugin install chrome-devtools-mcp@chrome-devtools-plugin
```

Then restart Claude Code and check `/mcp` or `/skills`.

**Other hosts (Cline, Gemini, Codex, Copilot):** Use the same `npx -y chrome-devtools-mcp@latest` entry:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    }
  }
}
```

Add flags as needed:

- `--slim` — reduced tool count for smaller context
- `--headless` — run headless (default headed for visual review)
- `--browser-url=http://127.0.0.1:9222` — attach to an existing Chrome (e.g., Antigravity)
- `--isolated` — per-session Chrome instance
- `--no-performance-crux` — disable CrUX field fetch
- `--no-usage-statistics` — opt out of Google usage stats (or set `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`)

See `docs/tool-reference.md` for full flag table and `mcp/templates/chrome-devtools/README.md` for host-specific wiring.

## Core workflows

### 1. Open → interact → inspect → trace

```bash
# via MCP tool (agent calls tool): navigate, click, take_snapshot, etc.
# equivalent CLI (no MCP) also available:
npx -y chrome-devtools-mcp@latest --help
```

Typical MCP tool sequence:

1. `navigate_page` → open URL
2. `take_snapshot` or `take_screenshot` → capture rendered evidence (required before declaring UI good)
3. `click` / `fill` / `drag` (Puppeteer-backed, auto-waits)
4. `list_console_messages` / `list_network_requests` → runtime diagnostics
5. `performance_start_trace` → `performance_stop_trace` → `performance_analyze_insight` → actionable insights + CrUX
6. `take_screenshot` at breakpoints/themes (mobile/tablet/desktop, light/dark) for `design-improvement` re-review loop

### 2. Performance debugging

Use `performance_start_trace --auto` (optionally `reload`, `metric: webVital`), then `performance_stop_trace`, then `performance_analyze_insight`. Tools send trace CrUX to Google's CrUX API for field vs lab comparison — disable with `--no-performance-crux` if offline-sensitive.

### 3. Network / console triage

`list_network_requests` + `get_network_request` (HAR-like), `list_console_messages` with source-mapped stacks. Prefer over `curl` when JS rendering or auth is involved.

## Security boundaries

- DevTools MCP exposes **all browser content** to the MCP client — avoid loading pages with secrets, personal data, or internal admin surfaces without explicit scoping; the README warning applies.
- Treat tool arguments (`url`, `selector`, `script`) as executable-ish — validate inputs, no SSRF via `navigate_page` to internal hosts without approval.
- Usage stats are enabled by default (Google collects tool success/latency/env). Opt out with `--no-usage-statistics` or env `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`; CI sets `CI=1` automatically disables them. Update checks ping npm registry — disable with `CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1`.
- Chrome support is limited to Google Chrome / Chrome for Testing — other Chromium forks may misbehave.
- Respect `security.classification` in skill frontmatter where applicable; DevTools MCP is `read-write` (can modify page) — not `read-only` like Figma.

## Delegation — browser capabilities conceptually

Request capabilities, not brands, where practical:

| Capability | `playwright-cli` / `e2e-runner` | `chrome-devtools` |
|------------|-------------------------------|-------------------|
| `browser.interact` | ✅ deterministic locators/assertions | ✅ Puppeteer-backed (auto-wait) |
| `browser.capture` | ✅ screenshot/trace/pdf/snapshot | ✅ screenshot + trace |
| `browser.dom` / `browser.accessibility` | snapshot (a11y) | ✅ DOM + a11y tree + computed styles |
| `browser.network` / `browser.console` / `browser.performance` | limited | ✅ full |
| `browser.trace` / `browser.visual-compare` | trace | trace + rendering inspection |
| `browser.runtime-debug` | — | ✅ DevTools protocol |

**Delegation mapping for Toolkit:**

- `design-assessment` (A11Y/Responsive/Perf) → requests `browser.capture` + `browser.accessibility` + `browser.performance`
- `design-improvement` (run → capture → review → fix → re-review) → requests `browser.interact` + `browser.capture` + `browser.visual-compare`
- `e2e-runner` → requests `browser.assert` (Playwright spec)

Either provider alone is valid degraded mode; together they cover the full lifecycle.

## References

- `mcp/registry/chrome-devtools.yaml` — provenance (ChromeDevTools/chrome-devtools-mcp, Apache-2.0, npm `chrome-devtools-mcp`), transport `stdio` via `npx`, platforms matrix, security notes
- `mcp/templates/chrome-devtools/config.template.json` + `README.md` — host wiring
- `docs/MCP.md` — MCP overview and provider table
- `tooling/playwright-cli` — deterministic browser automation (complement)
- `Chrome DevTools MCP docs`: [GitHub ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp), [tool-reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md), [npm chrome-devtools-mcp](https://www.npmjs.com/package/chrome-devtools-mcp)

