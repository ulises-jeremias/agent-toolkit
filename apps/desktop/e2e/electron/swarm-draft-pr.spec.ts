import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

/**
 * Former opt-in GitHub smoke for the retired Toolkit Swarm v1 execution path.
 * Keep this spec even for maintainers with a sandbox `gh` repository: it must
 * never create new provider runs or external PRs from the archived Desktop.
 */
test('archived Desktop does not offer Swarm v1 starts or create external PR state', async () => {
  const desktop = await openDesktop();
  const { page } = desktop;
  try {
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
    await expect(page.getByRole('region', { name: 'Swarms' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Start swarm' })).toHaveCount(0);
    await expect(page.getByRole('dialog', { name: 'Start a swarm' })).toHaveCount(0);

    await page.keyboard.press('Control+k');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByLabel('Filter commands').fill('Start a swarm');
    await expect(palette.getByRole('option')).toHaveCount(0);
  } finally {
    await desktop.close();
  }
});
