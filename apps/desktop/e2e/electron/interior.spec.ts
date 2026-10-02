import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

/**
 * A short real job must not leave a decorative worker in the world after its
 * process ends. Capture only on explicit request and only after the world and
 * its live job projection have settled.
 */
const OUT_DIR =
  process.env['ATK_CAPTURE_DIR'] ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/world');

test('the world removes a worker after a short real job completes', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);

    // A real project house needs a real repo the workspace knows. The e2e
    // fixture workspace has no repos, so we land on the grounds and start a
    // real job through Operations to capture a working character on the map.
    const nav = page.getByRole('navigation', { name: 'Destinations' });
    await nav.getByRole('link', { name: 'Operations' }).click();
    await page.getByRole('button', { name: 'Start job' }).click();
    const dialog = page.getByRole('dialog', { name: 'Start a job' });
    await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('version');
    await dialog.getByRole('button', { name: 'Start job' }).click();
    await expect(dialog).toBeHidden();

    // The command is intentionally short; once the canonical job is terminal,
    // the World must not retain its runtime character.
    await nav.getByRole('link', { name: 'World' }).click();
    const world = page.getByRole('application', { name: 'Semantic workspace world' });
    await expect(world).toBeVisible();
    await expect(
      page.getByText('Reading workspace, projects, memory, tools, jobs, and active People sessions...'),
    ).toBeHidden();
    await expect(world.locator('[data-entity-id^="character:job:"]')).toHaveCount(0, { timeout: 20_000 });
    const receiptDismiss = page.getByRole('button', { name: 'Dismiss: Job started' });
    if (await receiptDismiss.isVisible()) await receiptDismiss.click();
    if (process.env['ATK_CAPTURE'] === '1') {
      await setViewport(desktop.app, 1920, 1080);
      await page.screenshot({ path: path.join(OUT_DIR, 'world-job-completed-large.png') });
    }
  } finally {
    await desktop.close();
  }
});
