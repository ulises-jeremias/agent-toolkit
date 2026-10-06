import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';

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

function killBackend(desktop: Desktop): void {
  const procDir = '/proc';
  if (!fs.existsSync(procDir)) throw new Error('Backend failure recovery test requires /proc.');
  const rootPid = desktop.app.process().pid;
  if (rootPid === undefined) throw new Error('Electron process PID is unavailable for the crash probe.');
  const descendants = new Set([rootPid]);
  let foundDescendant = true;
  while (foundDescendant) {
    foundDescendant = false;
    for (const entry of fs.readdirSync(procDir)) {
      if (!/^\d+$/.test(entry) || descendants.has(Number(entry))) continue;
      try {
        const stat = fs.readFileSync(path.join(procDir, entry, 'stat')).toString();
        const fields = stat.slice(stat.lastIndexOf(')') + 2).split(/\s+/);
        if (descendants.has(Number(fields[1]))) {
          descendants.add(Number(entry));
          foundDescendant = true;
        }
      } catch {
        // The process exited or is owned by another user.
      }
    }
  }

  let killed = 0;
  for (const pid of descendants) {
    if (pid === rootPid) continue;
    try {
      const args = fs
        .readFileSync(path.join(procDir, String(pid), 'cmdline'))
        .toString()
        .split('\0')
        .filter(Boolean);
      const argv0 = args[0] ?? '';
      if (
        (argv0 !== desktop.backendBin && path.basename(argv0) !== path.basename(desktop.backendBin)) ||
        !args.includes('serve') ||
        !args.includes('--no-browser')
      )
        continue;
      process.kill(pid, 'SIGKILL');
      killed += 1;
    } catch {
      // The process exited or is owned by another user.
    }
  }
  if (!killed) throw new Error(`No supervised backend process found for ${desktop.backendBin}`);
}

test.describe('first-run backend recovery', () => {
  test.skip(process.platform !== 'linux', 'The isolated crash probe uses Linux /proc.');
  let desktop: Desktop;

  test.beforeAll(async () => {
    desktop = await openDesktop({ skipOnboarding: false });
  });

  test.afterAll(async () => {
    await desktop?.close();
  });

  test('restarts a crashed backend from the welcome screen', async () => {
    const { app, page } = desktop;
    await expect(page.getByRole('heading', { level: 1, name: 'A world for coding agents' })).toBeVisible();
    await expect(page.getByRole('region', { name: 'Backend' })).toContainText('ready', { timeout: 30_000 });
    killBackend(desktop);
    await expect(page.getByRole('button', { name: 'Restart backend' })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByRole('button', { name: 'Continue' })).toBeDisabled();
    await capture(page, 'recovery-backend-failed-compact');

    await setViewport(app, 1440, 960);
    await capture(page, 'recovery-backend-failed-large');
    await setViewport(app, 1024, 768);
    await page.getByRole('button', { name: 'Restart backend' }).click();
    await expect(page.getByRole('region', { name: 'Backend' })).toContainText('ready', { timeout: 30_000 });
    await expect(page.getByRole('button', { name: 'Restart backend' })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Continue' })).toBeEnabled();
    await page.getByRole('button', { name: 'Continue' }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Where should work live?' })).toBeVisible();
  });
});
