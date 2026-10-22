import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

test('Operations: a job started from the GUI streams/persists its log in the inspector and can be deleted', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();

    // Empty board is the honest starting state.
    await expect(page.getByText('No jobs on the backend.')).toBeVisible();

    // Start a real backend job entirely from the GUI.
    await page.getByRole('button', { name: 'Start job' }).click();
    const dialog = page.getByRole('dialog', { name: 'Start a job' });
    await expect(dialog).toBeVisible();
    await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('version');
    await expect(dialog.getByText(/agent-toolkit version/)).toBeVisible();
    await dialog.getByRole('button', { name: 'Start job' }).click();
    await expect(dialog).toBeHidden();

    // The inspector follows the created job; the board lists it.
    const row = page.getByRole('button', { name: /agent-toolkit version/ });
    await expect(row).toBeVisible();

    // The job finishes and its persisted log is readable without leaving
    // Operations (the #1103 acceptance in the current Electron product).
    const logSection = page.locator('section[aria-label="Log"]');
    await expect(logSection).toBeVisible({ timeout: 30_000 });
    await expect(logSection).toContainText(/agent-toolkit \d+\.\d+\.\d+/);
    await expect(page.getByText('completed', { exact: false }).first()).toBeVisible();

    // Recovery/cleanup: delete the job from the same inspector.
    await page.getByRole('button', { name: 'Delete' }).click();
    const confirm = page.getByRole('dialog');
    await confirm.getByRole('button', { name: 'Delete job' }).click();
    await expect(page.getByText('No jobs on the backend.')).toBeVisible({ timeout: 30_000 });
  } finally {
    await desktop.close();
  }
});
