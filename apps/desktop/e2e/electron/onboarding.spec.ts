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

async function walkSharedSteps(page: Desktop['page'], prefix: string): Promise<void> {
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'What is on this machine?' })).toBeVisible();
  await expect(page.getByText('CLI detection is not available as a typed list.')).toBeVisible();
  await page.getByRole('button', { name: 'Open Doctor report' }).click();
  await expect(page.getByRole('region', { name: 'Doctor' })).toBeVisible();
  await expect(page.getByText(/Running doctor/)).toHaveCount(0, { timeout: 30_000 });
  await capture(page, `${prefix}03-tools-unavailable`);

  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'First agent' })).toBeVisible();
  await expect(page.getByText('No typed agent, provider or model API.')).toBeVisible();
  await capture(page, `${prefix}04-agent-unavailable`);

  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Run something real' })).toBeVisible();
  await page.getByRole('button', { name: 'Start version job' }).click();
  const output = page.getByLabel('Live output');
  await expect(output.getByText('completed')).toBeVisible({ timeout: 30_000 });
  await expect(output.getByText(/Loading log/)).toHaveCount(0, { timeout: 20_000 });
  await expect(output).toContainText(/\d+\.\d+|agent-toolkit/, { timeout: 20_000 });
  await capture(page, `${prefix}05-first-work-live`);

  await page.getByRole('button', { name: 'Finish and open Office' }).click();
  await waitForBackend(page);
  await expect(page.getByRole('heading', { level: 1, name: 'What needs you' })).toBeVisible();
  await capture(page, `${prefix}06-office`);
}

test.describe('first-run happy path', () => {
  let desktop: Desktop;

  test.beforeAll(async () => {
    desktop = await openDesktop({ skipOnboarding: false });
  });

  test.afterAll(async () => {
    await desktop?.close();
  });

  test('existing ~/.ai-workspace: choose harness, honest gaps, live version job', async () => {
    const { page, workspace } = desktop;
    await expect(page.getByRole('heading', { level: 1, name: 'A workstation for coding agents' })).toBeVisible();
    await expect(page.getByText('ready', { exact: true })).toBeVisible({ timeout: 30_000 });
    await capture(page, '01-ready');

    await page.getByRole('button', { name: 'Continue' }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Where should work live?' })).toBeVisible();
    await expect(page.getByText(workspace, { exact: false }).first()).toBeVisible();
    await expect(page.getByText(/already exists/i)).toBeVisible();
    await expect(page.getByRole('button', { name: 'Create harness' })).toHaveCount(0);
    await capture(page, '02-harness-existing');

    await walkSharedSteps(page, '');
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

  test('confirms before creating ~/.ai-workspace then reaches live output', async () => {
    const { page, workspace } = desktop;
    expect(fs.existsSync(workspace)).toBe(false);
    await expect(page.getByRole('heading', { level: 1, name: 'A workstation for coding agents' })).toBeVisible();
    await expect(page.getByText('ready', { exact: true })).toBeVisible({ timeout: 30_000 });

    await page.getByRole('button', { name: 'Continue' }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Where should work live?' })).toBeVisible();
    await expect(page.getByText(/No harness folder is present/)).toBeVisible();
    await capture(page, 'fallback-01-missing');

    await page.getByRole('button', { name: 'Create harness' }).click();
    const confirm = page.getByRole('dialog', { name: 'Create the default harness?' });
    await expect(confirm).toBeVisible();
    await expect(confirm.getByText(workspace, { exact: false })).toBeVisible();
    await capture(page, 'fallback-02-confirm');
    await confirm.getByRole('button', { name: 'Create harness' }).click();
    await expect(confirm).toBeHidden();
    await expect(page.getByRole('button', { name: 'Continue' })).toBeEnabled({ timeout: 45_000 });
    expect(fs.existsSync(workspace)).toBe(true);
    await capture(page, 'fallback-03-created');

    await walkSharedSteps(page, 'fallback-');
  });
});
