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
  await page.getByRole('button', { name: 'Open Agent Toolkit' }).click();
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

  test('existing ~/.ai-workspace: link a repository, see the agents, open the app', async () => {
    const { app, page, workspace, home } = desktop;
    await expect(page.getByRole('heading', { level: 1, name: 'Set up Agent Toolkit' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Destinations' })).toHaveCount(0);
    await expect(page.getByText(/agent-toolkit workspace init/)).toHaveCount(0);

    // Step 1 states the workspace that already exists; nothing asks to create it.
    const steps = page.getByRole('listitem');
    await expect(steps.filter({ hasText: 'Workspace folder' })).toContainText(workspace, { timeout: 30_000 });
    await expect(page.getByRole('button', { name: /^Create / })).toHaveCount(0);
    await capture(page, '01-setup');

    // Step 2 links an existing repository in one action. Only the OS picker is stubbed.
    const repo = path.join(home, 'code', 'garden-api');
    fs.mkdirSync(path.join(repo, '.git'), { recursive: true });
    await app.evaluate(({ dialog }, folder) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
    }, repo);
    await page.getByRole('button', { name: 'Choose a repository folder' }).click();
    const repository = steps.filter({ hasText: 'A repository to work on' });
    await expect(repository).toContainText('garden-api', { timeout: 30_000 });
    await expect(repository).toContainText(repo);
    expect(fs.realpathSync(path.join(workspace, 'projects', 'garden-api'))).toBe(fs.realpathSync(repo));

    // Step 3 reports what each agent CLI says about itself; this isolated HOME has no signed-in agent.
    const agents = steps.filter({ hasText: 'A coding agent' });
    await expect(agents).toContainText('Claude Code', { timeout: 60_000 });
    await expect(agents).not.toContainText('Signed in');

    await setViewport(app, 1024, 640);
    await expect(page.getByRole('button', { name: 'Open Agent Toolkit' })).toBeVisible();
    await capture(page, '01-setup-compact');
    await setViewport(app, 1440, 900);

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

  test('creates ~/.ai-workspace only when asked, then opens the app', async () => {
    const { page, workspace } = desktop;
    expect(fs.existsSync(workspace)).toBe(false);
    await expect(page.getByRole('heading', { level: 1, name: 'Set up Agent Toolkit' })).toBeVisible();
    await expect(page.getByText(/agent-toolkit workspace init/)).toHaveCount(0);

    const create = page.getByRole('button', { name: `Create ${workspace}` });
    await expect(create).toBeEnabled({ timeout: 30_000 });
    await expect(page.getByRole('button', { name: 'Use an existing folder' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Open Agent Toolkit' })).toBeDisabled();
    await expect(page.getByRole('button', { name: 'Choose a repository folder' })).toBeDisabled();
    expect(fs.existsSync(workspace)).toBe(false);
    await capture(page, 'fallback-01-missing');

    await create.click();
    await expect(page.getByRole('button', { name: 'Open Agent Toolkit' })).toBeEnabled({ timeout: 45_000 });
    expect(fs.existsSync(workspace)).toBe(true);
    await expect(page.getByRole('listitem').filter({ hasText: 'Workspace folder' })).toContainText(workspace);
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

  test('restarts a crashed local service from the setup screen', async () => {
    const { app, page } = desktop;
    await expect(page.getByRole('heading', { level: 1, name: 'Set up Agent Toolkit' })).toBeVisible();
    const open = page.getByRole('button', { name: 'Open Agent Toolkit' });
    await expect(open).toBeEnabled({ timeout: 30_000 });
    killBackend(desktop);
    const restart = page.getByRole('button', { name: 'Restart the local service' });
    await expect(restart).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('Nothing in your folders was changed.')).toBeVisible();
    await expect(open).toBeDisabled();
    await setViewport(app, 1024, 768);
    await capture(page, 'recovery-backend-failed-compact');

    await setViewport(app, 1440, 960);
    await capture(page, 'recovery-backend-failed-large');
    await setViewport(app, 1024, 768);
    await restart.click();
    await expect(restart).toHaveCount(0, { timeout: 30_000 });
    await expect(open).toBeEnabled({ timeout: 30_000 });
  });
});
