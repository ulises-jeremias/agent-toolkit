import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';
import { goTo } from './navigation';

/**
 * The World is one village built from real workspace state. Every place is a
 * real button with its actions, so the whole World works without walking.
 */
test.describe('World village', () => {
  let desktop: Desktop;

  test.beforeAll(async () => {
    desktop = await openDesktop();
    // A real folder with a git repository, linked the way a user links it.
    const repo = path.join(desktop.home, 'code', 'garden-api');
    fs.mkdirSync(repo, { recursive: true });
    execFileSync('git', ['init', '-q'], { cwd: repo });
    execFileSync(desktop.backendBin, ['project', 'add', repo, '--workspace', desktop.workspace], { stdio: 'pipe' });
  });

  test.afterAll(async () => {
    await desktop?.close();
  });

  test('shows the semantic workspace and only real session activity', async () => {
    const { page } = desktop;
    await waitForBackend(page);
    await goTo(page, 'World');

    const village = page.getByRole('application', { name: 'Semantic workspace world' });
    await expect(village).toBeVisible();
    await expect(page.getByRole('button', { name: /^Library ·/ })).toBeVisible();
    await expect(page.getByRole('button', { name: /^Workshop ·/ })).toBeAttached();
    // With no live provider session, the World has no agent activity markers.
    await expect(village.getByRole('button', { name: /working|needs your answer/ })).toHaveCount(0);
    await page.getByRole('button', { name: /^Library ·/ }).click();
    await expect(page).toHaveURL(/#\/library/);
  });

  test('a linked project house opens its interior and stays selectable in Focus', async () => {
    const { page } = desktop;
    await goTo(page, 'World');
    await page.getByRole('button', { name: /^garden-api\s+·\s+Project\b/ }).click();
    await expect(page).toHaveURL(/#\/world\?.*project=garden-api/);
    await expect(page.getByRole('application', { name: 'Interior of garden-api' })).toBeVisible();
    if (process.env['ATK_CAPTURE'] === '1' && process.env['ATK_CAPTURE_DIR']) {
      fs.mkdirSync(process.env['ATK_CAPTURE_DIR'], { recursive: true });
      await page.screenshot({ path: path.join(process.env['ATK_CAPTURE_DIR'], 'project-interior.png') });
    }
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Focus' }).click();
    await expect(page).toHaveURL(/#\/focus/);
    await expect(page.getByRole('combobox', { name: 'Project', exact: true })).toHaveValue('garden-api');
  });
});
