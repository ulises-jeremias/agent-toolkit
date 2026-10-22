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

test('Operations: a running job streams live output in the inspector and can be canceled there', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
    await expect(page.getByText('No jobs on the backend.')).toBeVisible();

    // `serve` is the fixture long-running command: it prints its
    // listening line and then runs until killed, so the job stays
    // active deterministically. The uncommon port avoids colliding
    // with the backend under test. Every step under test — live
    // streaming, cancel, persisted log — is the real backend path.
    const port = 39173;
    await page.getByRole('button', { name: 'Start job' }).click();
    const dialog = page.getByRole('dialog', { name: 'Start a job' });
    await expect(dialog).toBeVisible();
    await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('serve');
    await dialog.getByRole('textbox', { name: 'Arguments' }).fill(`--port ${port} --no-browser`);
    await expect(dialog.getByText(/agent-toolkit serve/)).toBeVisible();
    await dialog.getByRole('button', { name: 'Start job' }).click();
    await expect(dialog).toBeHidden();

    const row = page.getByRole('button', { name: /agent-toolkit serve/ });
    await expect(row).toBeVisible();

    // Follow mode: output streams into the inspector's Live output
    // section without leaving Operations (the #1103 live acceptance).
    const liveSection = page.locator('section[aria-label="Live output"]');
    await expect(liveSection).toBeVisible({ timeout: 30_000 });
    await expect(liveSection).toContainText(`listening on http://127.0.0.1:${port}/`, { timeout: 30_000 });
    await expect(page.getByRole('button', { name: 'Cancel job' })).toBeVisible();

    // Cancel from the same inspector; the job lands in its terminal
    // canceled state and the persisted Log replaces the live stream,
    // keeping the lines written before the kill plus the marker.
    await page.getByRole('button', { name: 'Cancel job' }).click();
    const logSection = page.locator('section[aria-label="Log"]');
    await expect(logSection).toBeVisible({ timeout: 30_000 });
    await expect(logSection).toContainText(`listening on http://127.0.0.1:${port}/`);
    await expect(logSection).toContainText('[canceled]');
    await expect(page.getByText('canceled', { exact: true }).first()).toBeVisible();

    // Cleanup: delete the canceled job back to the empty board.
    await page.getByRole('button', { name: 'Delete' }).click();
    const confirm = page.getByRole('dialog');
    await confirm.getByRole('button', { name: 'Delete job' }).click();
    await expect(page.getByText('No jobs on the backend.')).toBeVisible({ timeout: 30_000 });
  } finally {
    await desktop.close();
  }
});
