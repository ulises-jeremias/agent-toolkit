import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

test('uses the project workbench to review and open a real terminal session', async () => {
  const desktop = await openDesktop();
  try {
    const { app, page, home } = desktop;
    await waitForBackend(page);
    const projectPath = path.join(home, '.ai-workspace', 'repos', 'local', 'garden-api');
    fs.mkdirSync(projectPath, { recursive: true });
    fs.writeFileSync(path.join(projectPath, 'README.md'), '# Garden API\n');

    await app.evaluate(({ dialog }, folder) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
    }, projectPath);

    const nav = page.getByRole('navigation', { name: 'Destinations' });
    await nav.getByRole('link', { name: 'World' }).click();
    await page.getByRole('button', { name: /Add project/ }).click();
    await page.getByRole('button', { name: 'Link existing folder' }).click();
    const projectReview = page.getByRole('dialog', { name: 'Review project link' });
    await projectReview.getByRole('button', { name: 'Link garden-api' }).click();
    await expect(projectReview).toBeHidden();
    await nav.getByRole('link', { name: 'World' }).click();

    await page.getByRole('button', { name: /garden-api · Project/ }).click();
    const interior = page.getByRole('application', { name: 'Interior of garden-api' });
    await expect(interior).toBeVisible();
    await interior.getByRole('button', { name: 'Explore by walking' }).click();
    const nearby = interior.getByRole('status');
    await page.keyboard.down('ArrowDown');
    await expect(nearby).toContainText('Terminal', { timeout: 4000 });
    await page.keyboard.up('ArrowDown');
    await page.keyboard.press('E');

    const terminalReview = page.getByRole('dialog', { name: 'New terminal session' });
    await expect(terminalReview).toBeVisible();
    const cwd = terminalReview.getByRole('textbox', { name: 'Working folder' });
    await expect(cwd).toHaveValue(projectPath);
    await expect(terminalReview).toContainText('Starts a process in a pseudo-terminal on this machine.');
    await expect(page.getByRole('tablist', { name: 'Sessions' }).getByRole('tab')).toHaveCount(0);
    await terminalReview.getByRole('button', { name: 'Open session' }).click();
    await expect(terminalReview).toBeHidden();
    await expect(page.getByRole('tablist', { name: 'Sessions' }).getByRole('tab')).toHaveCount(1);
    await expect(page.getByRole('tab', { name: /garden-api.*running/i })).toBeVisible();
  } finally {
    await desktop.close();
  }
});
