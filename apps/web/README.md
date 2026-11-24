# Agent Toolkit website

The official public entrance to Agent Toolkit, deployed at
[`https://www.agent-toolkit.io`](https://www.agent-toolkit.io). The site lives in this
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
capability search and the mobile menu; there is no client framework runtime.
Current product pages describe portable Toolkit capabilities and link to
Veasel Code for the graphical coding application. Historical Desktop pages
are clearly labeled archives and retain source attribution for their original
screenshots and artwork.

Capability entries are read at build time from generated catalogs, MCP provider
definitions and distribution manifests. Public documentation is rendered from
the canonical Markdown under `docs/`; the navigation intentionally exposes a
curated user-facing subset. The production build also runs Pagefind over the
rendered `/docs/` pages (`dist/pagefind/`), so docs search is full-text with
heading-level result links; the index is a build artifact, never a second copy
of the Markdown, and search simply reports itself unavailable under `astro
dev`. The legacy `/download/` URL is retained as a migration page; it does not
query or advertise retired Electron release assets.

## Deployment

The root `vercel.json` builds the `agent-toolkit-web` workspace package and
publishes `apps/web/dist`. Connect this repository to Vercel with the
repository root as its project root. Pull requests receive previews; `main`
deploys production. The production domain is `www.agent-toolkit.io`; the apex
`agent-toolkit.io` permanently redirects to `www`. Astro's canonical origin
matches that live deployment for production and preview builds.

The `web` GitHub Actions workflow runs formatting, ESLint, Astro type checks,
Vitest, a static-link audit, and Playwright Chromium smoke/accessibility tests.
