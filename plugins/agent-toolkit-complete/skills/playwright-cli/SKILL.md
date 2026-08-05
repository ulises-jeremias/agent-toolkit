---
name: playwright-cli
description: Drive a real browser from the terminal using the Playwright CLI (snapshot, click, fill, screenshots, traces). Use when the task is CLI-first browser automation (data extraction, UI debugging, form fills, multi-tab work). For Playwright **test specs**, use `e2e-runner` instead.
---

# Playwright CLI

Drive a real browser from the terminal using `playwright-cli`. The bundled
wrapper script runs the CLI through `npx`, so a global install is not required.

> Treat this skill as **CLI-first automation**. Do NOT pivot to
> `@playwright/test` test files unless the user explicitly asks for them — for
> Playwright tests use [`e2e-runner`](../e2e-runner/SKILL.md).

## When to use

- Quick, one-off browser automation from the shell (snapshot → interact →
  screenshot/trace).
- Reproducing a UI bug step-by-step with persistent sessions.
- Extracting data from a page that requires JS rendering.
- Smoke-checking a deployment without authoring a test suite.

## Prerequisites

- `npx` on `PATH` (provided by Node.js / `volta` from `bootstrap`).
- Optional but recommended: a global install for faster startup —
  `npm install -g @playwright/cli@latest`.
- Outbound HTTPS access to npm and to the target sites.

`skills check playwright-cli` validates `npx` is present.

## Wrapper script (set once per shell)

```bash
export PWCLI="$HOME/.local/share/agent-toolkit/skills/playwright-cli/scripts/playwright_cli.sh"
alias pwcli="$PWCLI"
pwcli --help
```

The wrapper uses `npx --yes --package @playwright/cli playwright-cli`, so even
without a global install the first call will fetch the package and cache it.

If `PLAYWRIGHT_CLI_SESSION` is set, the wrapper passes it as `--session`
automatically — handy to keep separate browser contexts per project.

## Quick start

```bash
pwcli open https://playwright.dev --headed
pwcli snapshot
pwcli click e15
pwcli type "Playwright"
pwcli press Enter
pwcli screenshot
```

## Core workflow

1. `open` the page.
2. `snapshot` to get stable element refs (e.g. `e3`).
3. Interact using refs from the **latest** snapshot.
4. Re-snapshot after navigation or significant DOM changes.
5. Capture artifacts (`screenshot`, `pdf`, `tracing-start`/`tracing-stop`)
   when useful.

Minimal loop:

```bash
pwcli open https://example.com
pwcli snapshot
pwcli click e3
pwcli snapshot
```

## When to snapshot again

After:

- navigation
- clicking elements that change the UI substantially
- opening/closing modals or menus
- tab switches

Refs go stale silently. When a command fails due to a missing ref, snapshot
again — do not bypass with `run-code`/`eval` unless explicitly justified.

## Recommended patterns

### Form fill and submit

```bash
pwcli open https://example.com/form
pwcli snapshot
pwcli fill e1 "user@example.com"
pwcli fill e2 "password123"
pwcli click e3
pwcli snapshot
```

### Debug a UI flow with traces

```bash
pwcli open https://example.com --headed
pwcli tracing-start
# ...interactions...
pwcli tracing-stop
```

### Multi-tab work

```bash
pwcli tab-new https://example.com
pwcli tab-list
pwcli tab-select 0
pwcli snapshot
```

## Sessions

```bash
pwcli --session todo open https://demo.playwright.dev/todomvc
pwcli --session todo snapshot
```

Or set the env var once:

```bash
export PLAYWRIGHT_CLI_SESSION=todo
pwcli open https://demo.playwright.dev/todomvc
```

## Boundaries

- This skill is **read/interact** on real browsers. No test framework, no test
  files. For test suites, hand off to `e2e-runner`.
- When this skill captures artifacts inside a project, write them under
  `output/playwright/` (or whatever the repo defines) — never introduce new
  top-level artifact folders.
- For sandboxed AI tools that block `npx`/network, ask the user to authorize
  outbound network for this skill rather than disabling sandboxing globally.

## References

- [`references/cli.md`](references/cli.md) — CLI command reference.
- [`references/workflows.md`](references/workflows.md) — practical workflows
  and troubleshooting.

## See also

- [`e2e-runner`](../e2e-runner/SKILL.md) — Playwright **test**
  authoring & execution (different mental model than this skill).
