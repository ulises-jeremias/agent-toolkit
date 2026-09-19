# Desktop visual QA

Status: **CURRENT GUIDE** — re-confirmed 2026-09-13 at `ecc4d67c`.

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

The last reviewed production build reference is `ecc4d67c` (2026-09-13;
previous `711c9f32`, 2026-09-10). HEAD has moved on since (v1.31.0 release
prep); no full-matrix capture is claimed past `ecc4d67c`, and re-baselining
the reference against a release-build SHA is pending — see Golden policy
below. Record the exact build SHA with every new capture.

> **Honest note (2026-09-13):** the full 7-viewport/theme/language matrix
> below remains unmet as a whole — the only fully opened/inspected captures
> are the 2026-09-05 audit pair plus per-PR screenshots landed since VC0–VC8
> and the Engine-persistence / spike-retirement refactors (#1205/#1206,
> no visual change claimed), which are the de-facto visual evidence. Do not
> read this section as claiming matrix completion at HEAD.

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

## Display map (reproducible captures)

Every visual harness owns a FIXED virtual display because tour coordinates and
the captured window id are display-bound. To reproduce a run locally, free the
display (or point the override at a free one), build the desktop binary, and run
the matching `make.vsh` target with `VJOBS=2`:

| Harness | Target | Display | Override | Lock |
|---|---|---|---|---|
| `scripts/golden.vsh` | `./make.vsh golden` | `:77` | `GOLDEN_DISPLAY` | `atk-golden-X77.lock` |
| `scripts/ui-smoke.vsh` | `./make.vsh ui-smoke` | `:99` | `SMOKE_DISPLAY` | `atk-uismoke-X99.lockd` |
| `scripts/enter-regression.vsh` | `./make.vsh enter-regression` | `:97` | `ATK_ENTER_DISPLAY` | shared `atk-acceptance-X97.lock` |
| `scripts/clean-machine.vsh` | `./make.vsh clean-machine` | `:98` | fixed | none — fails loudly if `:98` is busy |

Rules: never run two harnesses on the same display at once — golden, ui-smoke
and enter-regression take a PID-scoped lock each, and a second run on a locked
display fails loudly instead of colliding. Stale locks (owner pid dead) are
stolen with a warning. clean-machine takes no lock, so check `:98` is free
first. The app
always runs under a temp HOME/XDG, so real user preferences are never read or
written. `SMOKE_BIN` overrides the binary under test (default
`build/agent-toolkit-desktop-native`); CI sets it explicitly on every step.
`ATK_GOLDEN_THEME=ink` selects the Ink fixture set. Missing evidence
(Xvfb/xdotool/compare, no window, dead app) fails loudly — a missing tool is
never a pass.

## Golden policy

Fixtures must be explicit test inputs, isolated from normal runtime. Freeze only
visual nondeterminism, never invent operational state. Review every changed golden
at actual size before accepting it. Keep failed diffs and logs. Record why each
baseline changes. Current golden CI is `continue-on-error: true`; it is not a
blocking release-quality guarantee.

Promotion to a blocking golden gate requires ALL of:

1. 20 consecutive green `golden-ui` runs on main with no fixture churn.
2. Every RMSE failure in that window triaged to a real visual change — no
   Xvfb/xdotool/`compare` infra flakes.
3. Paper + Ink fixture sets re-captured from a release-build SHA and recorded
   in the Build-and-capture reference above.
4. The `golden-mismatch` artifact bundle reviewed end-to-end at least once
   (failed diffs + `tests/golden-app.log` resolve to an understood cause).

Until all four hold, golden comparison remains advisory change-detection, and
only opened-and-inspected captures count as reviewed evidence.

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
