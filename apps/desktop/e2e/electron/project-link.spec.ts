import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';
import { goTo } from './navigation';

/**
 * Linking an existing repository from the GUI. The native folder picker is
 * the only stub; the preload bridge and the HTTP API are real. A folder that
 * does not exist is refused with a message, and a real repository becomes a
 * house in the World.
 */
test('links an existing project from the GUI and places it in the world', async () => {
  const desktop = await openDesktop();
  try {
    const { app, page, home } = desktop;
    await waitForBackend(page);

    const pick = (folder: string) =>
      app.evaluate(({ dialog }, selected) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [selected] });
      }, folder);

    await goTo(page, 'Projects');
    const missing = path.join(home, 'no-such-folder');
    expect(fs.existsSync(missing)).toBe(false);
    await pick(missing);
    await page.getByRole('button', { name: 'Link a repository' }).click();
    await expect(page.getByRole('alert')).toContainText('not found');

    const repo = path.join(home, 'code', 'garden-api');
    fs.mkdirSync(path.join(repo, '.git'), { recursive: true });
    await pick(repo);
    await page.getByRole('button', { name: 'Link a repository' }).click();
    await expect(page.getByRole('button', { name: /^garden-api(?:\s|$)/ })).toBeVisible({ timeout: 30_000 });
    expect(fs.realpathSync(path.join(desktop.workspace, 'projects', 'garden-api'))).toBe(fs.realpathSync(repo));

    await goTo(page, 'World');
    await expect(page.getByRole('button', { name: /^garden-api\s+·\s+Project\b/ })).toBeAttached({ timeout: 30_000 });
  } finally {
    await desktop.close();
  }
});
