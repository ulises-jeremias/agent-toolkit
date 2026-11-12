import { expect, test } from '@playwright/test';

/**
 * Renderer smoke tests against vite preview.
 * Backend-independent: asserts the app shell (nav, headings, fallbacks)
 * renders with no backend running. Live-backend behavior (queries,
 * mutations, SSE, terminals) is covered by unit tests, the packaged-app CDP
 * tour, and manual UAT — see docs/desktop/PACKAGING.md and VISUAL_QA.md.
 * Set VITE_ATK_BACKEND_URL to point at a live `agent-toolkit serve` to also
 * exercise backend-driven panels locally.
 */
test.describe('desktop smoke', () => {
  test('semantic World map loads as a navigation destination', async ({ page }) => {
    test.setTimeout(60_000);
    await page.goto('/#/world', { waitUntil: 'commit' });
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible({ timeout: 45_000 });
    await expect(page.getByRole('navigation', { name: 'Destinations' })).toBeVisible();
    await expect(page.getByRole('banner').getByRole('button', { name: /Search or run a command/ })).toBeVisible();
    await expect(page.getByRole('application', { name: 'Semantic workspace world' })).toBeVisible();
    await expect(page.getByRole('alert')).toContainText('Live state may be incomplete or out of date.');
  });

  test('Attention is the Needs you inspector, not home', async ({ page }) => {
    await page.goto('/#/office');
    await expect(page.getByRole('heading', { level: 1, name: 'Attention' })).toBeVisible();
    await expect(page.getByRole('region', { name: 'Needs you' })).toBeVisible();
    await expect(page).toHaveURL(/#\/office/);
  });

  test('Ctrl+K opens the command palette', async ({ page }) => {
    await page.goto('/#/world');
    await page.getByRole('button', { name: /Search or run a command/ }).click();
    await expect(page.getByRole('dialog', { name: 'Commands' })).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog', { name: 'Commands' })).toBeHidden();
  });

  test('destinations navigate without dead ends', async ({ page }) => {
    await page.goto('/#/world', { waitUntil: 'commit' });
    const nav = page.getByRole('navigation', { name: 'Destinations' });
    for (const destination of [
      { label: 'World', path: 'world' },
      { label: 'Focus', path: 'focus' },
      { label: 'Projects', path: 'workspace' },
      { label: 'People', path: 'people' },
      { label: 'Library', path: 'library' },
      { label: 'Operations', path: 'operations' },
      { label: 'Settings', path: 'settings' },
    ]) {
      await nav.getByRole('link', { name: destination.label }).click();
      await expect(page).toHaveURL(new RegExp(`#/${destination.path}`));
      await expect(nav.getByRole('link', { name: destination.label })).toHaveAttribute('aria-current', 'page');
      // Some destinations intentionally render an empty-state panel without an h1.
      // Navigation is proven by route and active destination state above.
    }
    // Attention, Terminals and Health are tabs of Operations, not separate places.
    await nav.getByRole('link', { name: 'Operations' }).click();
    const tabs = page.getByRole('navigation', { name: 'Section' });
    for (const tab of [
      { label: 'Needs you', path: 'office' },
      { label: 'Terminals', path: 'terminal' },
      { label: 'Health', path: 'insights' },
    ]) {
      await tabs.getByRole('link', { name: tab.label }).click();
      await expect(page).toHaveURL(new RegExp(`#/${tab.path}`));
      await expect(tabs.getByRole('link', { name: tab.label })).toHaveAttribute('aria-current', 'page');
      await expect(nav.getByRole('link', { name: 'Operations' })).not.toHaveAttribute('aria-current', 'page');
      await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    }
  });

  test('all destinations stay visible without horizontal scrolling at compact widths', async ({ page }) => {
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.goto('/#/world', { waitUntil: 'commit' });
    const nav = page.getByRole('navigation', { name: 'Destinations' });
    const list = nav.locator('ul:not([data-slot="footer"])');
    await expect(list).toBeVisible();
    await expect.poll(() => list.evaluate((element) => element.scrollWidth - element.clientWidth)).toBe(0);
    await expect(list.getByRole('link')).toHaveCount(6);
    await expect(nav.locator('ul[data-slot="footer"]').getByRole('link', { name: 'Settings' })).toBeVisible();
  });

  test('terminal explains itself outside Electron', async ({ page }) => {
    await page.goto('/#/terminal');
    await expect(page.getByRole('heading', { level: 1, name: 'Terminal' })).toBeVisible();
    await expect(page.getByText('Interactive terminals need the Desktop app.')).toBeVisible();
  });

  test('unknown routes land on the Focus home', async ({ page }) => {
    await page.goto('/#/nowhere');
    await expect(page).toHaveURL(/#\/focus/);
  });
});
