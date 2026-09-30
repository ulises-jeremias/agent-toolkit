import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';

const CAPTURE = process.env.ATK_CAPTURE === '1';
const OUT_DIR =
  process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/onboarding');

async function capture(page: Desktop['page'], name: string): Promise<void> {
  if (!CAPTURE) return;
  fs.mkdirSync(OUT_DIR, { recursive: true });
  await page.screenshot({ path: path.join(OUT_DIR, `${name}.png`) });
}

async function enterWorld(page: Desktop['page'], prefix: string): Promise<void> {
  await page.getByRole('button', { name: 'Enter the world' }).click();
  await waitForBackend(page);
  await expect(page).toHaveURL(/#\/world/);
  await expect(
    page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }),
  ).toHaveAttribute('aria-current', 'page');
  await expect(page.getByRole('application', { name: 'Semantic workspace world' })).toBeVisible();
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await expect(page.getByText('INSTALLED')).toHaveCount(0);
  await capture(page, `${prefix}03-world`);
}

test.describe('first-run happy path', () => {
  let desktop: Desktop;

  test.beforeAll(async () => {
    desktop = await openDesktop({ skipOnboarding: false });
  });

  test.afterAll(async () => {
    await desktop?.close();
  });

  test('existing ~/.ai-workspace: confirm harness then enter the world', async () => {
    const { page, workspace } = desktop;
    await expect(page.getByRole('heading', { level: 1, name: 'A world for coding agents' })).toBeVisible();
    await expect(page.getByText('ready', { exact: true })).toBeVisible({ timeout: 30_000 });
    await capture(page, '01-ready');

    await page.getByRole('button', { name: 'Continue' }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Where should work live?' })).toBeVisible();
    await expect(page.getByText(workspace, { exact: false }).first()).toBeVisible();
    await expect(page.getByText('This folder already exists.')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Create harness' })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Choose folder' })).toBeVisible();
    await capture(page, '02-harness-existing');

    await enterWorld(page, '');
  });
});

test.describe('first-run missing harness', () => {
  let desktop: Desktop;

  test.beforeAll(async () => {
    desktop = await openDesktop({ initWorkspace: false, skipOnboarding: false });
  });

  test.afterAll(async () => {
    await desktop?.close();
  });

  test('confirms before creating ~/.ai-workspace then enters the world', async () => {
    const { page, workspace } = desktop;
    expect(fs.existsSync(workspace)).toBe(false);
    await expect(page.getByRole('heading', { level: 1, name: 'A world for coding agents' })).toBeVisible();
    await expect(page.getByText('ready', { exact: true })).toBeVisible({ timeout: 30_000 });

    await page.getByRole('button', { name: 'Continue' }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Where should work live?' })).toBeVisible();
    await expect(page.getByText(/No harness folder is present/)).toBeVisible();
    await expect(page.getByRole('button', { name: 'Choose folder' })).toBeVisible();
    await capture(page, 'fallback-01-missing');

    await page.getByRole('button', { name: 'Create harness' }).click();
    const confirm = page.getByRole('dialog', { name: 'Create the default harness?' });
    await expect(confirm).toBeVisible();
    await expect(confirm.getByText(workspace, { exact: false })).toBeVisible();
    await capture(page, 'fallback-02-confirm');
    await confirm.getByRole('button', { name: 'Create harness' }).click();
    await expect(confirm).toBeHidden();
    await expect(page.getByRole('button', { name: 'Enter the world' })).toBeEnabled({ timeout: 45_000 });
    expect(fs.existsSync(workspace)).toBe(true);
    await capture(page, 'fallback-03-created');

    await enterWorld(page, 'fallback-');
  });
});
