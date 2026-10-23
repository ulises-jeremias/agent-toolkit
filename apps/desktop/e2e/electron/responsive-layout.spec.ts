import { expect, test, type Page } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

// The Electron window itself declares minWidth 1024 / minHeight 640
// (electron/main.ts), so the supported matrix bottoms out there instead
// of resizing below what a user can actually produce.
const SIZES = [
  { width: 1280, height: 800, key: 'baseline' },
  { width: 1024, height: 768, key: 'minimum' },
  { width: 1024, height: 640, key: 'narrow' },
] as const;

async function expectNoHorizontalOverflow(page: Page, size: { width: number }, label: string) {
  const overflow = await page.evaluate(() => {
    const root = document.documentElement;
    return { scrollWidth: root.scrollWidth, innerWidth: window.innerWidth };
  });
  expect(overflow.scrollWidth, `${label} must not overflow horizontally`).toBeLessThanOrEqual(overflow.innerWidth + 1);
  expect(overflow.innerWidth).toBe(size.width);
}

async function expectWithinViewport(
  locator: import('@playwright/test').Locator,
  size: { width: number; height: number },
  label: string,
) {
  await expect(locator, label).toBeVisible();
  const box = await locator.boundingBox();
  expect(box, `${label} has a bounding box`).not.toBeNull();
  expect(box!.x, `${label} starts inside the viewport`).toBeGreaterThanOrEqual(0);
  expect(box!.x + box!.width, `${label} ends inside the viewport`).toBeLessThanOrEqual(size.width + 1);
  expect(box!.y + box!.height, `${label} is not clipped at the bottom`).toBeLessThanOrEqual(size.height + 1);
}

test('Responsive matrix: shell and primary actions stay usable at baseline, minimum, and narrow sizes', async () => {
  const desktop = await openDesktop();
  try {
    const { app, page } = desktop;
    await waitForBackend(page);

    for (const size of SIZES) {
      // Only the Electron window is resized: page.setViewportSize would pin
      // CDP device-metric emulation and innerWidth would stop tracking the
      // real window. setViewport already waits for the real size to apply.
      await setViewport(app, size.width, size.height);

      // Shell chrome (destinations) remains visible and inside the window.
      await expectWithinViewport(
        page.getByRole('navigation', { name: 'Destinations' }),
        size,
        `${size.key}: destinations navigation`,
      );
      await expectNoHorizontalOverflow(page, size, `${size.key} (world)`);

      // A dense destination keeps its primary action reachable.
      await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
      await expectWithinViewport(
        page.getByRole('button', { name: 'Create Person' }),
        size,
        `${size.key}: Create Person`,
      );
      await expectNoHorizontalOverflow(page, size, `${size.key} (people)`);

      // The command palette opens, fits, and dismisses safely at this size.
      await page.keyboard.press('Control+k');
      const paletteInput = page.getByLabel('Filter commands');
      await expectWithinViewport(paletteInput.first(), size, `${size.key}: command palette input`);
      await page.keyboard.press('Escape');
      await expect(paletteInput.first()).toBeHidden();

      // A dense destination (Library board) also fits without overflow.
      await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Library' }).click();
      await expect(page.getByRole('heading', { level: 1, name: 'Library board' })).toBeVisible();
      await expectNoHorizontalOverflow(page, size, `${size.key} (library)`);

      // Back to World; the terminal dock bar stays inside the window.
      await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
      await expectWithinViewport(
        page.getByRole('complementary', { name: 'Terminal dock' }),
        size,
        `${size.key}: terminal dock`,
      );
      await page.screenshot({ path: `test-results/review/responsive-${size.key}.png`, fullPage: true });
    }

    // The second theme at the minimum size: switch via the command palette,
    // then re-check chrome fit and overflow.
    const minimum = SIZES[1];
    await setViewport(app, minimum.width, minimum.height);
    await page.keyboard.press('Control+k');
    await page.getByLabel('Filter commands').first().fill('Use Dusk theme');
    await page.getByRole('option', { name: 'Use Dusk theme' }).click();
    await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe('dusk');
    await expectWithinViewport(
      page.getByRole('navigation', { name: 'Destinations' }),
      minimum,
      'minimum (dusk): destinations navigation',
    );
    await expectNoHorizontalOverflow(page, minimum, 'minimum (dusk)');
    await page.screenshot({ path: 'test-results/review/responsive-minimum-dusk.png', fullPage: true });
  } finally {
    await desktop.close();
  }
});

test('HiDPI: shell stays usable at device scale factor 2', async () => {
  const desktop = await openDesktop({ launchArgs: ['--force-device-scale-factor=2'] });
  try {
    const { app, page } = desktop;
    await waitForBackend(page);
    await expect.poll(() => page.evaluate(() => window.devicePixelRatio)).toBe(2);
    const size = { width: 1024, height: 768 };
    await setViewport(app, size.width, size.height);
    await expectWithinViewport(
      page.getByRole('navigation', { name: 'Destinations' }),
      size,
      'hidpi: destinations navigation',
    );
    await expectNoHorizontalOverflow(page, size, 'hidpi (world)');
    await page.screenshot({ path: 'test-results/review/responsive-hidpi.png', fullPage: true });
  } finally {
    await desktop.close();
  }
});
