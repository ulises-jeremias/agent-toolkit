import { writeFileSync } from 'node:fs';
import { expect, test, type ElectronApplication, type Locator, type Page } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

async function setZoom(app: ElectronApplication, factor: number) {
  await app.evaluate(async ({ BrowserWindow }, zoom) => {
    const [window] = BrowserWindow.getAllWindows();
    if (!window) throw new Error('Desktop window is unavailable.');
    window.webContents.setZoomFactor(zoom);
    await new Promise((resolve) => setTimeout(resolve, 250));
  }, factor);
}

async function captureElectronWindow(app: ElectronApplication, path: string) {
  const dataUrl = await app.evaluate(async ({ BrowserWindow }) => {
    const [window] = BrowserWindow.getAllWindows();
    if (!window) throw new Error('Desktop window is unavailable.');
    await new Promise((resolve) => setTimeout(resolve, 200));
    return (await window.webContents.capturePage()).toDataURL();
  });
  writeFileSync(path, Buffer.from(dataUrl.slice(dataUrl.indexOf(',') + 1), 'base64'));
}

async function expectNoHorizontalOverflow(page: Page, label: string) {
  const metrics = await page.evaluate(() => ({
    width: document.documentElement.scrollWidth,
    viewport: document.documentElement.clientWidth,
  }));
  expect(metrics.width, `${label} must reflow without document-level horizontal scrolling`).toBeLessThanOrEqual(
    metrics.viewport + 1,
  );
  return metrics;
}

async function expectFitsViewport(locator: Locator, page: Page, label: string) {
  await expect(locator, label).toBeVisible();
  const bounds = await locator.boundingBox();
  expect(bounds, `${label} must have a visible box`).not.toBeNull();
  const viewport = await page.evaluate(() => ({ width: innerWidth, height: innerHeight }));
  expect(bounds!.x, `${label} must not be clipped on the left`).toBeGreaterThanOrEqual(0);
  expect(bounds!.x + bounds!.width, `${label} must fit the viewport width`).toBeLessThanOrEqual(viewport.width + 1);
  return bounds!;
}

test('Packaged Desktop reflows at 200% and 320 CSS px, including keyboard-scrollable data tables', async () => {
  const desktop = await openDesktop();
  try {
    const { app, page } = desktop;
    await waitForBackend(page);
    await setViewport(app, 1024, 640);

    for (const factor of [2, 3.2]) {
      const expectedWidth = Math.round(1024 / factor);
      await setZoom(app, factor);
      await expect.poll(() => page.evaluate(() => Math.round(innerWidth))).toBe(expectedWidth);
      const prefix = `zoom ${Math.round(factor * 100)}%`;

      await expect(page.getByRole('heading', { name: 'What should we work on?' })).toBeVisible();
      await expectNoHorizontalOverflow(page, `${prefix}, Focus`);
      await expectFitsViewport(page.getByRole('textbox', { name: 'Task' }), page, `${prefix}, task editor`);
      await expectFitsViewport(page.getByRole('button', { name: 'Start session' }), page, `${prefix}, Start session`);

      const sessionsToggle = page.getByRole('button', { name: 'Sessions' });
      await expect(sessionsToggle).toBeVisible();
      await sessionsToggle.click();
      const sessions = page.getByRole('navigation', { name: 'Sessions' });
      await expect(sessions).toBeVisible();
      const closeSessions = sessions.getByRole('button', { name: 'Close' });
      await expect(closeSessions).toBeFocused();
      await page.keyboard.press('Escape');
      await expect(sessions).toBeHidden();
      await expect(sessionsToggle).toBeFocused();
      await sessionsToggle.click();
      await expect(closeSessions).toBeFocused();
      await sessions.getByRole('button', { name: 'New session' }).click();
      await expect(sessionsToggle).toHaveAttribute('aria-expanded', 'false');
      await expect(sessions).toBeHidden();
      await captureElectronWindow(
        app,
        `/home/ulisesjcf/.ai-workspace/.audit-private/zoom-reflow-focus-${expectedWidth}.png`,
      );

      const destinations = page.getByRole('navigation', { name: 'Destinations' });
      await destinations.getByRole('link', { name: 'People' }).click();
      await expectFitsViewport(page.getByRole('button', { name: 'Create Person' }), page, `${prefix}, People action`);
      await expectNoHorizontalOverflow(page, `${prefix}, People`);
      await captureElectronWindow(
        app,
        `/home/ulisesjcf/.ai-workspace/.audit-private/zoom-reflow-people-${expectedWidth}.png`,
      );

      await destinations.getByRole('link', { name: 'Library' }).click();
      await expect(page.getByRole('heading', { level: 1, name: 'Library board' })).toBeVisible();
      await expectNoHorizontalOverflow(page, `${prefix}, Library`);
      const table = page.getByRole('region', { name: 'Scrollable data table' }).first();
      await expect(table).toBeVisible();
      const tableBounds = await table.boundingBox();
      expect(tableBounds!.width).toBeLessThanOrEqual(expectedWidth + 1);
      await expect.poll(() => table.evaluate((element) => element.scrollWidth > element.clientWidth)).toBe(true);
      await page.evaluate(() => {
        document.body.tabIndex = -1;
        document.body.focus();
      });
      let reachedByTab = false;
      for (let index = 0; index < 100; index += 1) {
        await page.keyboard.press('Tab');
        reachedByTab = await table.evaluate((element) => document.activeElement === element);
        if (reachedByTab) break;
      }
      expect(reachedByTab, `${prefix}, wide data table is reachable by Tab`).toBe(true);
      const before = await table.evaluate((element) => element.scrollLeft);
      await page.keyboard.press('ArrowRight');
      await expect.poll(() => table.evaluate((element) => element.scrollLeft)).toBeGreaterThan(before);
      await table.evaluate((element) => element.scrollTo({ left: 0 }));
      await captureElectronWindow(
        app,
        `/home/ulisesjcf/.ai-workspace/.audit-private/zoom-reflow-library-${expectedWidth}.png`,
      );

      await destinations.getByRole('link', { name: 'Focus' }).click();
    }
  } finally {
    await desktop.close();
  }
});
