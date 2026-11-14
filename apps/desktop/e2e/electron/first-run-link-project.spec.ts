import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop } from './fixtures';

test('first-run creates a workspace and links an external Git repository through the UI', async () => {
  const desktop = await openDesktop({ initWorkspace: false, skipOnboarding: false });
  try {
    const { app, page, home, workspace } = desktop;
    await expect(page.getByRole('heading', { name: 'Set up Agent Toolkit' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Create workspace folder' })).toBeEnabled({ timeout: 30_000 });
    expect(fs.existsSync(workspace)).toBe(false);

    const repository = path.join(home, 'code', 'garden-api');
    fs.mkdirSync(repository, { recursive: true });
    execFileSync('git', ['init', '--initial-branch=main', repository]);
    execFileSync('git', ['-C', repository, 'config', 'user.name', 'Desktop Acceptance']);
    execFileSync('git', ['-C', repository, 'config', 'user.email', 'desktop-acceptance@example.invalid']);
    fs.writeFileSync(path.join(repository, 'README.md'), '# Disposable acceptance repository\n');
    execFileSync('git', ['-C', repository, 'add', 'README.md']);
    execFileSync('git', ['-C', repository, 'commit', '-m', 'Initial acceptance repository']);

    await page.getByRole('button', { name: 'Create workspace folder' }).click();
    await expect(page.getByRole('listitem').filter({ hasText: 'Workspace folder' })).toContainText(workspace, {
      timeout: 45_000,
    });

    // The OS picker is the only stub. Keep renderer, preload IPC, backend
    // validation, external-path handling, and symlink creation real.
    await app.evaluate(({ dialog }, folder) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
    }, repository);
    await page.getByRole('button', { name: 'Choose a repository folder' }).click();
    await expect(page.getByRole('listitem').filter({ hasText: 'A repository to work on' })).toContainText(repository, {
      timeout: 45_000,
    });
    expect(fs.realpathSync(path.join(workspace, 'projects', 'garden-api'))).toBe(fs.realpathSync(repository));

    await expect(page.getByRole('button', { name: 'Open Agent Toolkit' })).toBeEnabled();
    await page.getByRole('button', { name: 'Open Agent Toolkit' }).click();
    await expect(page).toHaveURL(/#\/focus/, { timeout: 45_000 });
    await expect(page.getByRole('heading', { name: 'What should we work on?' })).toBeVisible();
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    await expect(page).toHaveURL(/#\/world/);
    await expect(page.getByRole('button', { name: /^garden-api\s+·\s+Project\b/ })).toBeAttached({ timeout: 30_000 });
    await expect(page.getByText('Checking live workspace details...')).toHaveCount(0, { timeout: 30_000 });
  } finally {
    await desktop.close();
  }
});
