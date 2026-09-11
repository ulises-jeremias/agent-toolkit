# Desktop visual QA

Visual acceptance requires build → run → navigate → capture PNG → open PNG →
critique → fix → capture and inspect again. Golden comparison detects change, not
quality. Never call a screenshot reviewed merely because it exists.

## Matrix

Required viewport sizes: 1024×640, 1280×720, 1280×800, 1440×900, 1600×900,
1920×1080 and 2560×1440. Exercise wide, medium and compact behavior. Test 100%,
125%, 150% and 200% scaling where the backend supports it, including meaningful
HiDPI/multi-monitor checks on supported platforms.

Themes: Paper, Ink, System with both OS appearances. Languages: English, Spanish,
Chinese, Arabic, plus long strings. Arabic requires shaping/bidi review, not simply
reversed characters. Include keyboard-only, visible focus, reduced motion, zoom,
color-independent statuses and readable contrast. Current OS accessibility-tree
support is unverified; do not claim screen-reader or full WCAG conformance.

For each important workflow exercise populated, empty, loading, Engine failure,
configuration failure, partial success, long data, one result and large data.
Include modal/text/terminal shortcut precedence, disabled explanations and Escape.

## Build and capture

The current production build reference is HEAD `711c9f32` (2026-09-10).

> **Honest note (2026-09-10):** the full 7-viewport/theme/language matrix
> below remains unmet as a whole — the only fully opened/inspected captures
> are the 2026-09-05 audit pair plus per-PR screenshots landed since VC0–VC8,
> which are the de-facto visual evidence. Do not read this section as
> claiming matrix completion at HEAD.

The last fully built + captured baseline was `85853de`; build with:

```sh
VJOBS=2 VMODULES="$PWD/modules" v -d gg_text_buff_size=4096 \
  -o build/agent-toolkit-desktop-native cmd/agent-toolkit-desktop
```

`./make.vsh build-desktop` currently runs a headless harness, not this production
build. The visual harnesses are V scripts with workstation isolation built in
(no `pkill`, no user-preference writes — owned Xvfb/display guarded by the
shared acceptance lock, temp HOME/XDG, PID-scoped cleanup; missing evidence
fails loudly). Tests fail when navigation commands fail.

| Harness | Command | What it proves |
|---|---|---|
| `scripts/ui-smoke.vsh` | `./make.vsh ui-smoke` | panel tour + per-state screenshots, app-alive assertions |
| `scripts/golden.vsh` | `./make.vsh golden` (`ATK_GOLDEN_THEME=ink` for ink) | pixel compare vs `tests/golden/` fixtures (default fuzz 8%) |
| `scripts/check-tofu.vsh` | `./scripts/check-tofu.vsh` | bundled-fonts proof from `tests/golden-app.log` + fixture sanity |
| `scripts/check-contrast.vsh` | `./scripts/check-contrast.vsh` | Paper/Ink WCAG 4.5:1 text-on-surface gate from `tokens.v` |
| `scripts/enter-regression.vsh` | `./make.vsh enter-regression` | Return keys never kill/hang/unmap the app under Xvfb |

For clean-machine verification copy the built artifact outside the checkout and
launch from an unrelated directory with temporary HOME, XDG_CONFIG_HOME,
XDG_DATA_HOME and XDG_CACHE_HOME, minimal PATH and no toolkit override variables.
This is distinct from merely launching the checkout binary with a fresh HOME.
Record fonts/catalog/schema/template/migration resolution and real install results.

## Golden policy

Fixtures must be explicit test inputs, isolated from normal runtime. Freeze only
visual nondeterminism, never invent operational state. Review every changed golden
at actual size before accepting it. Keep failed diffs and logs. Record why each
baseline changes. Current golden CI is `continue-on-error: true`; it is not a
blocking release-quality guarantee.

## Initial visual audit, 2026-09-05

Baseline `85853de` built successfully. Native app ran on isolated Xvfb at 1280×800,
from `/tmp/atk-ui-audit` with fresh HOME/XDG directories. Binary remained in the
checkout and resolved checkout fonts, so this is **not packaged verification**.
The reviewer opened `/tmp/atk-ui-audit/first-launch.png` and `office.png`.
The reviewer also opened `skills.png` after navigating to Library → Skills.

- First launch exposes "Harness", revisions, API counts, resource-resolution
  internals and capability totals before explaining the product or workspace choice.
- Very small text and a crowded bottom navigation make the next action difficult
  to find. The inspector consumes space without useful setup context.
- Office gives most space to desks, decoration and stations. It presents working
  agents and operational logs on a clean setup; source audit confirms fabrication.
- Paper content and dark chrome lack a clear hierarchy. Stronger typography and
  reduced visual noise are needed before adding panel detail.
- Skills shows synthetic entries and two receipts in the fresh environment. The
  source fallback is visible in the real application, not just test-only data.

Only this resolution and initial English/default appearance were inspected. No
other matrix cell, terminal lifecycle, assistive technology, soak or packaged
clean-machine pass is claimed. Capture reviewed evidence in PR artifacts and link
it from the workflow ledger; temporary files are not durable release evidence.
