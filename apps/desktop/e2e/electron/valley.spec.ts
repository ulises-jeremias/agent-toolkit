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

  test('shows the village, a place panel with real actions, and no characters without sessions', async () => {
    const { page } = desktop;
    await waitForBackend(page);
    await goTo(page, 'World');

    const village = page.getByRole('group', { name: 'Workspace village' });
    await expect(village).toBeVisible();
    await expect(page.getByRole('button', { name: /Library:/ })).toBeVisible();
    await expect(page.getByRole('button', { name: /Workshop:/ })).toBeAttached();
    // With no live session there is no character to click.
    await expect(page.getByRole('button', { name: /working|needs your answer/ })).toHaveCount(0);

    const panel = page.getByRole('region', { name: 'Selected place' });
    await expect(panel).toContainText('Choose a place');

    await page.getByRole('button', { name: /Library:/ }).click();
    await expect(panel.getByRole('heading', { name: 'Library' })).toBeVisible();
    await expect(panel.getByRole('button', { name: 'Open Library' })).toBeVisible();
    await panel.getByRole('button', { name: 'Open Library' }).click();
    await expect(page).toHaveURL(/#\/library/);
  });

  test('a linked project is a house whose New session action opens Focus in that project', async () => {
    const { page } = desktop;
    await goTo(page, 'World');
    await page.getByRole('button', { name: /^garden-api:/ }).click();
    const panel = page.getByRole('region', { name: 'Selected place' });
    await panel.getByRole('button', { name: 'New session' }).click();
    await expect(page).toHaveURL(/#\/focus/);
  });
});
