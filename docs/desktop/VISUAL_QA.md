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

The current production build, verified at `85853de`, is:

```sh
VJOBS=2 VMODULES="$PWD/modules" v -d gg_text_buff_size=4096 \
  -o build/agent-toolkit-desktop-native cmd/agent-toolkit-desktop
```

`./make.vsh build-desktop` currently runs a headless harness, not this production
build. `scripts/ui-smoke.sh` and `scripts/golden.sh` need isolation repairs before
use on a shared workstation: they kill unrelated processes and remove saved user
preferences; ui-smoke also references missing `/tmp/opencode` tools. Use an owned
Xvfb process/display, preserve other processes and preferences, and clean up only
owned resources. Tests must fail when navigation commands fail.

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
