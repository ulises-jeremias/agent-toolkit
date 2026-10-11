# Agent Toolkit website

The official public entrance to Agent Toolkit, deployed at
[`https://agent-toolkit.io`](https://agent-toolkit.io). The site lives in this
monorepo so product, screenshots, catalogs and documentation remain close to
their canonical sources.

## Develop

Use the repository-pinned Node and pnpm versions from the root:

```sh
pnpm install
pnpm --filter agent-toolkit-web dev
pnpm --filter agent-toolkit-web check
pnpm --filter agent-toolkit-web lint
pnpm --filter agent-toolkit-web test
pnpm --filter agent-toolkit-web build
pnpm --filter agent-toolkit-web test:visual
```

The site is static Astro output. Browser code is progressive enhancement for
capability search, release discovery and the mobile menu; there is no client
framework runtime. The website uses Toolkit's own fonts and original Desktop
sprites, and shows the real screenshots under the root `static/screenshots/`
and `docs/desktop/assets/electron/` paths.

Capability entries are read at build time from generated catalogs, MCP provider
definitions and distribution manifests. Public documentation is rendered from
the canonical Markdown under `docs/`; the navigation intentionally exposes a
curated user-facing subset. Release downloads are queried from the actual
latest GitHub Release, with a link to the canonical release page when the API
is unavailable.

## Deployment

The root `vercel.json` builds the `agent-toolkit-web` workspace package and
publishes `apps/web/dist`. Connect this repository to Vercel with the
repository root as its project root. Pull requests receive previews; `main`
deploys production. Configure `agent-toolkit.io` as the primary production
domain and `www.agent-toolkit.io` as an alias that permanently redirects to the
apex domain. Astro's canonical origin remains fixed to
`https://agent-toolkit.io` for production and preview builds.

The `web` GitHub Actions workflow runs formatting, ESLint, Astro type checks,
Vitest, a static-link audit, and Playwright Chromium smoke/accessibility tests.
