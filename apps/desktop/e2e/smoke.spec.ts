import { expect, test } from '@playwright/test';

/**
 * Renderer smoke tests against vite dev + a live `agent-toolkit serve`.
 * Requires the V backend on VITE_ATK_BACKEND_URL (default 127.0.0.1:3847).
 * Full Electron packaged-app UAT is tracked in docs/desktop/ELECTRON_MIGRATION.md.
 */
test.describe('desktop smoke', () => {
  test('office loads with backend-backed attention', async ({ page }) => {
    await page.goto('/#/office');
    await expect(page.getByRole('heading', { name: 'Office' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Destinations' })).toBeVisible();
  });

  test('destinations navigate without dead ends', async ({ page }) => {
    for (const destination of ['Operations', 'Workspace', 'Library', 'Insights', 'Terminal', 'Settings']) {
      await page.goto('/#/office');
      await page.getByRole('link', { name: destination, exact: true }).click();
      await expect(page.getByRole('heading', { name: destination, exact: true })).toBeVisible();
    }
  });

  test('terminal explains itself outside Electron', async ({ page }) => {
    await page.goto('/#/terminal');
    await expect(page.getByRole('heading', { name: 'Terminal' })).toBeVisible();
  });
});
