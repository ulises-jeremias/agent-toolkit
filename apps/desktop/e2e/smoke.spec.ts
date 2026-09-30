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
  test('world shell loads as home', async ({ page }) => {
    await page.goto('/#/world');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Destinations' })).toBeVisible();
    await expect(page.getByRole('form', { name: 'Session context' })).toBeVisible();
    await expect(page.getByRole('application', { name: 'Semantic workspace world' })).toBeVisible();
  });

  test('Office is the Needs you inspector, not home', async ({ page }) => {
    await page.goto('/#/office');
    await expect(page.getByRole('heading', { level: 1, name: 'What is happening' })).toBeVisible();
    await expect(page.getByRole('region', { name: 'Needs you' })).toBeVisible();
    await expect(page).not.toHaveURL(/#\/$/);
  });

  test('Ctrl+K opens the command palette', async ({ page }) => {
    await page.goto('/#/world');
    await page.getByRole('button', { name: 'Commands' }).click();
    await expect(page.getByRole('dialog', { name: 'Commands' })).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog', { name: 'Commands' })).toBeHidden();
  });

  test('destinations navigate without dead ends', async ({ page }) => {
    const nav = page.getByRole('navigation', { name: 'Destinations' });
    for (const destination of [
      'World',
      'Office',
      'Operations',
      'Workspace',
      'Library',
      'Insights',
      'Terminal',
      'Settings',
    ]) {
      await page.goto('/#/world');
      await nav.getByRole('link', { name: destination }).click();
      await expect(page).toHaveURL(new RegExp(`#/${destination.toLowerCase()}`));
      await expect(nav.getByRole('link', { name: destination })).toHaveAttribute('aria-current', 'page');
      await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    }
  });

  test('terminal explains itself outside Electron', async ({ page }) => {
    await page.goto('/#/terminal');
    await expect(page.getByRole('heading', { level: 1, name: 'Terminal' })).toBeVisible();
    await expect(page.getByText('Interactive terminals need the Desktop app.')).toBeVisible();
  });

  test('unknown routes land on World', async ({ page }) => {
    await page.goto('/#/nowhere');
    await expect(page).toHaveURL(/#\/world/);
  });
});
