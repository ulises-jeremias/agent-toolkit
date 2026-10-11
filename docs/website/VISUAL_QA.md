# Website visual QA

This records browser-reviewed evidence for the official static site at
`https://agent-toolkit.io`. The site shares Agent Toolkit's cozy pixel-world
identity while keeping ordinary links, reading order, and copy available as
the primary web interface.

## Scroll journey — 2026-10-11

The homepage now pairs its story with a sticky scene panel that moves through
real product captures for the workspace, project interior, People, Operations,
and Library. Scrolling chooses the nearest story stop; the route beneath the
panel jumps directly to a stop. Each stop links to its focused product page.
The first valley capture is in the server-rendered HTML; later screenshots are
loaded on demand, then retained so revisiting a place is immediate.

The story and route remain ordinary HTML when JavaScript is disabled; only the
scene changes are progressively enhanced. Reduced-motion settings remove the
image, progress, and ambient transitions. The scroll is never captured or
intercepted, and product links remain conventional navigation.

I ran the built Astro site in Chromium and opened these captures:

- [Desktop Operations stop, 1440×900](assets/journey-operations-desktop.png)
- [Mobile People stop, 390×844](assets/journey-people-mobile.png)

The first review showed screenshots cropped by the stage aspect ratio, so the
stage now preserves the original 16:9 capture and places its label below the
frame. The next review confirmed the full Operations inspector remains visible
and the mobile People roster is still legible. These are real UI captures, not
mockups; session details visible in them belong to the screenshot's test data,
not live website state.

## Validation

From `apps/web/`:

```sh
pnpm check
pnpm lint
pnpm test
pnpm build
pnpm format:check
ATK_WEB_CAPTURE=1 ATK_WEB_CAPTURE_DIR=output/playwright/review pnpm test:visual
```

The browser suite passed 11 tests across the product-story journey, no-script
fallback, reduced motion, 390px mobile, 768px tablet, 1280px laptop, 1440px
desktop, route navigation, catalog search, download fallback, and serious/critical
axe findings on primary routes. The capture and animation checks run against
the built preview site rather than the development server.

This journey uses static first-party screenshots rather than a video chain or
external rendering service. It does not claim the embedded captures are live
workspace state.
