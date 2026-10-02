import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

const CAPTURE_DIR = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/loops');

test('adds a loop from the Library template, runs it, and reads its typed report', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
    const loops = page.getByRole('region', { name: 'Loops' });
    await expect(loops).toBeVisible();

    await loops.getByRole('button', { name: 'daily-triage' }).click({ timeout: 5_000 });
    await loops.getByRole('button', { name: 'Add to workspace' }).click();
    const add = page.getByRole('dialog', { name: 'Add daily-triage to this workspace' });
    await expect(add.getByText('loops/daily-triage/loop.yaml')).toBeVisible();
    await add.getByRole('button', { name: 'Create loop' }).click();
    await expect(add).toBeHidden();

    await expect(loops).toContainText('Loop report');
    await expect(loops).toContainText('Goal');
    await expect(loops).toContainText('Token budget');
    await expect(loops.getByRole('region', { name: 'daily-triage run history' })).toContainText('No run records yet.');
    if (process.env.ATK_CAPTURE === '1') {
      const receiptDismiss = page.getByRole('button', { name: 'Dismiss' });
      if (await receiptDismiss.isVisible()) await receiptDismiss.click();
      await page.evaluate(() => document.fonts.ready.then(() => undefined));
      await page.setViewportSize({ width: 1024, height: 640 });
      await loops.getByRole('heading', { name: 'daily-triage' }).scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-report-compact.png') });
      await page.setViewportSize({ width: 1920, height: 1080 });
      await loops.getByRole('heading', { name: 'daily-triage' }).scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-report-large.png') });
    }

    await loops.getByRole('button', { name: 'Run once' }).click();
    const run = page.getByRole('dialog', { name: 'Run a loop once' });
    await expect(run).toContainText(/does not create a schedule/i);
    await run.getByRole('button', { name: 'Run loop' }).click();
    await expect(run).toBeHidden();
    await expect(loops.getByRole('region', { name: 'daily-triage run history' })).toContainText(/completed|failed/, {
      timeout: 45_000,
    });
    await expect(loops.getByRole('region', { name: 'daily-triage audit' })).toContainText('Completed');
    await expect(loops.getByRole('region', { name: 'daily-triage cost report' })).toContainText('Unavailable');
    if (process.env.ATK_CAPTURE === '1') {
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-report-after-run.png') });
    }
  } finally {
    await desktop.close();
  }
});
