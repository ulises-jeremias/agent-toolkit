import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

interface FocusStop {
  tag: string;
  label: string;
  outlineStyle: string;
  outlineWidth: string;
}

async function focusedStop(page: import('@playwright/test').Page): Promise<FocusStop> {
  return page.evaluate(() => {
    const el = document.activeElement as HTMLElement | null;
    if (!el) return { tag: 'NONE', label: '', outlineStyle: '', outlineWidth: '' };
    const style = getComputedStyle(el);
    return {
      tag: el.tagName,
      label: (el.getAttribute('aria-label') ?? el.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 60),
      outlineStyle: style.outlineStyle,
      outlineWidth: style.outlineWidth,
    };
  });
}

test('Keyboard-only: skip link, visible focus ring, and every destination reachable by Tab', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    const destinations = page.getByRole('navigation', { name: 'Destinations' });
    await expect(destinations).toBeVisible();
    await expect(destinations.getByRole('link').nth(0)).toHaveAccessibleName('Focus');
    await expect(destinations.getByRole('link').nth(1)).toHaveAccessibleName('World');

    // Focus home intentionally places the caret in its task composer. Move the
    // sequential-focus starting point to the document so this checks the shell
    // tab order rather than continuing after that autofocus target.
    await page.evaluate(() => {
      document.body.tabIndex = -1;
      document.body.focus();
    });

    const stops: FocusStop[] = [];
    for (let i = 0; i < 30; i += 1) {
      await page.keyboard.press('Tab');
      stops.push(await focusedStop(page));
    }

    // First stop is the skip link, and it is visibly ringed for keyboard users.
    expect(stops[0]?.label).toContain('Skip to content');
    expect(stops[0]?.outlineStyle).not.toBe('none');
    expect(stops[0]?.outlineWidth).not.toBe('0px');

    // No stop falls back to <body> (a focus trap / lost focus), and the
    // primary destinations are reachable within the bounded traversal.
    expect(stops.every((stop) => stop.tag !== 'BODY')).toBe(true);
    const labels = stops.map((stop) => stop.label);
    for (const destination of ['World', 'People', 'Operations', 'Library']) {
      expect(
        labels.some((label) => label.includes(destination)),
        `Tab should reach ${destination}`,
      ).toBe(true);
    }
    // Interactive stops reached by keyboard show the focus ring.
    const ringed = stops.filter((stop) => stop.outlineStyle !== 'none' && stop.outlineWidth !== '0px');
    expect(ringed.length).toBeGreaterThanOrEqual(5);

    // The skip link moves focus into the main landmark when activated from
    // the keyboard. (Tab-reachability is proven by the stops above; focusing
    // here avoids depending on the browser's sequential-focus restart point
    // after a long traversal.)
    await page.getByRole('link', { name: 'Skip to content' }).focus();
    await page.keyboard.press('Enter');
    await expect.poll(() => page.evaluate(() => document.activeElement?.id ?? '')).toBe('main');

    // Keyboard activation of a destination link navigates without a mouse.
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).focus();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('button', { name: 'Create Person' })).toBeVisible();
  } finally {
    await desktop.close();
  }
});

test('Keyboard-only: reduced-motion preference is honored by the shell', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    const probe = await page.evaluate(() => {
      const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      let animated = 0;
      let checked = 0;
      for (const el of Array.from(document.querySelectorAll('*'))) {
        const style = getComputedStyle(el);
        if (style.animationName !== 'none') {
          checked += 1;
          if (Number.parseFloat(style.animationDuration) > 0.05) animated += 1;
        }
      }
      return { reduced, animated, checked };
    });
    expect(probe.reduced).toBe(true);
    // The global reduced-motion rule collapses CSS animation durations;
    // nothing on screen may keep a long-running animation under the pref.
    expect(probe.animated).toBe(0);
  } finally {
    await desktop.close();
  }
});

test('Keyboard: shortcut map lists shell and world bindings; Esc closes only the innermost layer', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await page.evaluate(() => (document.activeElement as HTMLElement | null)?.blur());

    // '?' opens the audited shortcut map.
    await page.keyboard.press('?');
    const map = page.getByRole('dialog', { name: 'Keyboard shortcuts' });
    await expect(map).toBeVisible();
    await expect(map).toContainText(/command palette/i);
    await expect(map).toContainText(/in the World/i);
    await expect(map).toContainText(/Interact with the nearest place/i);

    // Esc closes the map — and nothing else: the app stays on World.
    await page.keyboard.press('Escape');
    await expect(map).toBeHidden();
    await expect(page.getByRole('navigation', { name: 'Destinations' })).toBeVisible();
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();

    // A focused child can consume bubbling keyboard events (e.g. terminal or
    // embedded widget). The global palette shortcut must still be available.
    const worldLink = page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' });
    await worldLink.focus();
    await worldLink.evaluate((element) => {
      element.addEventListener('keydown', (event) => {
        if (event instanceof KeyboardEvent && event.ctrlKey && event.key.toLowerCase() === 'k') {
          event.stopPropagation();
        }
      });
    });

    // Regression: editable controls retain keyboard precedence even though
    // the global palette listener runs in capture phase.
    // This is a hermetic keyboard-boundary test, NOT a real PTY acceptance test.
    const editor = page.locator('[data-testid="palette-keyboard-probe"]');
    await page.evaluate(() => {
      const input = document.createElement('input');
      input.dataset.testid = 'palette-keyboard-probe';
      input.setAttribute('aria-label', 'Keyboard probe');
      input.addEventListener('keydown', (event) => {
        if (event.ctrlKey && event.key.toLowerCase() === 'k') {
          input.dataset.receivedPaletteChord = 'true';
          event.stopPropagation();
        }
      });
      document.body.appendChild(input);
    });
    await editor.focus();

    // Ctrl+K belongs to the focused editable control, not the palette.
    await page.keyboard.press('Control+k');
    await expect(editor).toHaveAttribute('data-received-palette-chord', 'true');
    await expect(page.getByLabel('Filter commands').first()).toBeHidden();

    // Non-editable focus still opens the palette despite a bubbling consumer.
    await worldLink.focus();
    await page.keyboard.press('Control+k');
    await expect(page.getByLabel('Filter commands').first()).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByLabel('Filter commands').first()).toBeHidden();
    await expect(page.getByRole('navigation', { name: 'Destinations' })).toBeVisible();
  } finally {
    await desktop.close();
  }
});
