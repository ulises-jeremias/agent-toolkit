import { expect, test } from '@playwright/test';

/**
 * Renderer smoke tests against vite dev.
 * Backend-independent: asserts the app shell (nav, headings, fallbacks)
 * renders with no backend running. Live-backend behavior (queries,
 * mutations, SSE, terminals) is covered by unit tests, the packaged-app CDP
 * tour, and manual UAT — see docs/desktop/ELECTRON_MIGRATION.md.
 * Set VITE_ATK_BACKEND_URL to point at a live `agent-toolkit serve` to also
 * exercise backend-driven panels locally.
 */
test.describe('desktop smoke', () => {
  test('office shell loads', async ({ page }) => {
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
