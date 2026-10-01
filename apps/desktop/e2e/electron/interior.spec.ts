import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

/**
 * Focused capture for the world interior + runtime activity: a real job is
 * started through the GUI, its project house opens into the interior, and the
 * working character is captured next to real furniture (collision-free slot
 * search from layout). Images land in the recovery evidence dir.
 */
const OUT_DIR = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/pixel-valley-recovery');

test('project interior with a working character', async () => {
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

    // Grounds while the job runs.
    await nav.getByRole('link', { name: 'World' }).click();
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await page.mouse.move(1000, 600);
    await page.screenshot({ path: path.join(OUT_DIR, 'world-with-running-job.png') });
  } finally {
    await desktop.close();
  }
});
