import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';

const CAPTURE = process.env['ATK_CAPTURE'] === '1';
const CAPTURE_DIR = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/swarms');
const PALETTE_CAPTURE_DIR = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/palette');
const LIBRARY_CAPTURE_DIR = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/library');

/**
 * Kill the supervised `agent-toolkit serve` child. After ADR-034 the renderer
 * sees `backend.url` as the loopback static+proxy server, not serve — SIGKILL
 * on that port takes down the UI and hangs Playwright instead of crashing the
 * backend.
 */
function killSupervisedServe(binaryPath: string): void {
  const basename = path.basename(binaryPath);
  const procDir = '/proc';
  if (!fs.existsSync(procDir)) {
    throw new Error('crash probe requires /proc to find the serve child');
  }
  let killed = 0;
  for (const entry of fs.readdirSync(procDir)) {
    if (!/^\d+$/.test(entry)) continue;
    try {
      const args = fs
        .readFileSync(path.join(procDir, entry, 'cmdline'))
        .toString()
        .split('\0')
        .filter(Boolean);
      const argv0 = args[0] ?? '';
      const isBinary = argv0 === binaryPath || path.basename(argv0) === basename;
      if (!isBinary || !args.includes('serve') || !args.includes('--no-browser')) continue;
      process.kill(Number(entry), 'SIGKILL');
      killed += 1;
    } catch {
      // vanished, or not readable
    }
  }
  if (killed === 0) {
    throw new Error(`no supervised serve process for ${binaryPath}`);
  }
}

function runSwarmCli(desktop: Desktop, args: string[]): string {
  const packagedApp = process.env['ATK_E2E_APP_PATH'];
  const candidates = [
    process.env['ATK_E2E_BACKEND_BIN'],
    packagedApp ? path.join(path.dirname(packagedApp), 'resources', 'bin', 'agent-toolkit') : undefined,
    path.resolve(__dirname, '../../../../dist/agent-toolkit'),
    path.resolve(__dirname, '../../../../build/agent-toolkit'),
  ].filter((candidate): candidate is string => Boolean(candidate));
  const binary = candidates.find((candidate) => fs.existsSync(candidate));
  if (!binary) throw new Error('The E2E backend binary is unavailable for external swarm-state changes');
  return execFileSync(binary, ['swarm', ...args, '--workspace', desktop.workspace], {
    env: {
      ...process.env,
      HOME: desktop.home,
      XDG_CONFIG_HOME: path.join(desktop.home, '.config'),
      XDG_DATA_HOME: path.join(desktop.home, '.local', 'share'),
      AGENT_TOOLKIT_WORKSPACE: desktop.workspace,
    },
    encoding: 'utf8',
    stdio: 'pipe',
  });
}

function initializeTestRepository(workspace: string): void {
  execFileSync('git', ['init', '--quiet', workspace]);
  execFileSync(
    'git',
    [
      '-C',
      workspace,
      '-c',
      'user.name=Agent Toolkit E2E',
      '-c',
      'user.email=e2e@agent-toolkit.invalid',
      'commit',
      '--allow-empty',
      '-m',
      'Initialize isolated E2E workspace',
    ],
    { stdio: 'pipe' },
  );
}

const DESTINATIONS: ReadonlyArray<{ link: string; path: string }> = [
  { link: 'World', path: '/world' },
  { link: 'Office', path: '/office' },
  { link: 'Operations', path: '/operations' },
  { link: 'Workspace', path: '/workspace' },
  { link: 'Library', path: '/library' },
  { link: 'Insights', path: '/insights' },
  { link: 'Terminal', path: '/terminal' },
  { link: 'Settings', path: '/settings' },
];

test.describe.configure({ mode: 'serial' });

let desktop: Desktop;

test.beforeAll(async () => {
  desktop = await openDesktop();
});

test.afterAll(async () => {
  if (!desktop) return;
  const child = desktop.app.process();
  const watchdog = setTimeout(() => {
    try {
      child.kill('SIGKILL');
    } catch {
      // already gone
    }
  }, 20_000);
  try {
    await desktop.close();
  } finally {
    clearTimeout(watchdog);
  }
});

test('supervisor starts the real backend and the shell connects', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await expect(page.getByRole('application', { name: 'Semantic workspace world' })).toBeVisible();
  await expect(page.getByRole('alert')).toHaveCount(0);
});

test('the context bar shows the default ~/.ai-workspace harness', async () => {
  const { page, workspace } = desktop;
  const bar = page.getByRole('form', { name: 'Session context' });
  await expect(bar.getByLabel('Workspace')).toHaveValue(workspace);
  await expect(bar).toContainText('default');
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
  await expect(page.getByRole('region', { name: 'Backend' })).toContainText(`${workspace} (default)`);
  await expect(page.getByText('Harness notice')).toHaveCount(0);
});

test('Ctrl+K opens the command palette and keeps session context', async () => {
  const { page, workspace } = desktop;
  await page.keyboard.press('Control+k');
  const dialog = page.getByRole('dialog', { name: 'Commands' });
  await expect(dialog).toBeVisible();
  await dialog.getByLabel('Filter commands').fill('settings');
  await page.keyboard.press('Enter');
  await expect(dialog).toBeHidden();
  await expect(page).toHaveURL(/#\/settings/);
  await expect(page).toHaveURL(new RegExp(`workspace=${encodeURIComponent(workspace)}`));
});

test('palette actions open the same reviewed terminal, job, loop, and swarm workflows', async () => {
  const { page } = desktop;
  const openAction = async (search: string, pattern: string | RegExp) => {
    await page.keyboard.press('Control+k');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByLabel('Filter commands').fill(search);
    const option = palette.getByRole('option').first();
    await expect(option).toHaveAttribute('aria-selected', 'true');
    await expect(option).toContainText(search);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('dialog', { name: pattern })).toBeVisible();
  };

  await openAction('Start a swarm', 'Start a swarm');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'Start a swarm' })).toBeHidden();

  await openAction('Run a loop as a job', 'Run a loop once');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'Run a loop once' })).toBeHidden();

  await openAction('Start a job', 'Start a job');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'Start a job' })).toBeHidden();

  await openAction('New terminal session', 'New terminal session');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'New terminal session' })).toBeHidden();
});

test('palette reaches Person creation and Munder import review without saving or spawning', async () => {
  const { page } = desktop;
  await page.keyboard.press('Control+k');
  let palette = page.getByRole('dialog', { name: 'Commands' });
  await palette.getByLabel('Filter commands').fill('Create Person');
  await expect(palette.getByRole('option', { name: /Create Person/ })).toBeVisible();
  await page.keyboard.press('Enter');
  const create = page.getByRole('dialog', { name: 'Create Person' });
  await expect(create).toBeVisible();
  await expect(create).toContainText('Saving this form does not start a process');
  if (CAPTURE) {
    fs.mkdirSync(PALETTE_CAPTURE_DIR, { recursive: true });
    for (const size of [
      { width: 1024, height: 768, key: 'compact' },
      { width: 1440, height: 900, key: 'large' },
    ]) {
      await setViewport(desktop.app, size.width, size.height);
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({ path: path.join(PALETTE_CAPTURE_DIR, `people-create-${size.key}.png`), fullPage: true });
    }
    await setViewport(desktop.app, 1280, 800);
    await page.setViewportSize({ width: 1280, height: 800 });
  }
  await create.getByRole('button', { name: 'Cancel' }).click();
  await expect(create).toBeHidden();

  await page.keyboard.press('Control+k');
  palette = page.getByRole('dialog', { name: 'Commands' });
  await palette.getByLabel('Filter commands').fill('Import Person from Munder Difflin');
  await expect(palette.getByRole('option', { name: /Import Person from Munder Difflin/ })).toBeVisible();
  await page.keyboard.press('Enter');
  const importPrompt = page.getByRole('dialog', { name: 'Import a Munder Difflin hire' });
  await expect(importPrompt).toBeVisible();
  await expect(importPrompt).toContainText('Import never starts a session');
  const chooser = page.waitForEvent('filechooser');
  await importPrompt.getByRole('button', { name: 'Choose hire file' }).click();
  await (
    await chooser
  ).setFiles({
    name: 'lina.json',
    mimeType: 'application/json',
    buffer: Buffer.from(
      JSON.stringify({
        spec: 'munder-difflin/hire@1',
        name: 'Lina',
        role: 'Senior Reviewer',
        goal: 'Review changes',
        command: 'unsafe content is ignored',
      }),
    ),
  });
  const review = page.getByRole('dialog', { name: 'Review Munder import' });
  await expect(review).toContainText('Lina');
  await expect(review).toContainText('command');
  await expect(review).toContainText('Import never starts a session');
  if (CAPTURE) {
    for (const size of [
      { width: 1024, height: 768, key: 'compact' },
      { width: 1440, height: 900, key: 'large' },
    ]) {
      await setViewport(desktop.app, size.width, size.height);
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({ path: path.join(PALETTE_CAPTURE_DIR, `munder-review-${size.key}.png`), fullPage: true });
    }
    await setViewport(desktop.app, 1280, 800);
    await page.setViewportSize({ width: 1280, height: 800 });
  }
  await page.keyboard.press('Escape');

  await page.evaluate(() => {
    window.location.hash = '/people?action=create';
  });
  await expect(page.getByRole('dialog', { name: 'Create Person' })).toBeVisible();
  await expect(page).toHaveURL(/workspace=/);
  await page.getByRole('dialog', { name: 'Create Person' }).getByRole('button', { name: 'Cancel' }).click();
});

test('palette workspace switching focuses the native harness chooser', async () => {
  const { page } = desktop;
  await page.keyboard.press('Control+k');
  const palette = page.getByRole('dialog', { name: 'Commands' });
  await palette.getByLabel('Filter commands').fill('Switch workspace');
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/#\/settings/);
  await expect(page).toHaveURL(/panel=harness/);
  await expect(page.getByRole('button', { name: /Change harness/ })).toBeFocused();
});

test('palette protects backend restart behind a consequence review', async () => {
  const { page } = desktop;
  await expect(
    page.getByText('Reading workspace, projects, memory, tools, jobs, and active People sessions'),
  ).toBeHidden();
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
  await expect(page.getByRole('application', { name: 'Semantic workspace world' })).toBeVisible();
  await page.keyboard.press('Control+k');
  const palette = page.getByRole('dialog', { name: 'Commands' });
  await palette.getByLabel('Filter commands').fill('Restart backend');
  await page.keyboard.press('Enter');
  const review = page.getByRole('dialog', { name: 'Restart the local backend?' });
  await expect(review).toContainText('Current API requests or jobs may be interrupted');
  if (process.env.ATK_CAPTURE === '1') {
    const captureDir =
      process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/palette');
    fs.mkdirSync(captureDir, { recursive: true });
    for (const size of [
      { width: 1024, height: 640, key: 'compact' },
      { width: 1600, height: 1000, key: 'large' },
    ]) {
      await setViewport(desktop.app, size.width, size.height);
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({ path: path.join(captureDir, `backend-restart-${size.key}.png`), fullPage: true });
    }
    await setViewport(desktop.app, 1280, 800);
    await page.setViewportSize({ width: 1280, height: 800 });
  }
  await review.getByRole('button', { name: 'Cancel' }).click();
  await expect(review).toBeHidden();
  await waitForBackend(page);
});

test('Settings also reviews backend restart before it can interrupt work', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
  const backend = page.getByRole('region', { name: 'Backend' });
  await backend.getByRole('button', { name: 'Restart backend' }).click();
  const review = page.getByRole('dialog', { name: 'Restart the local backend?' });
  await expect(review.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await review.getByRole('button', { name: 'Cancel' }).click();
  await expect(review).toBeHidden();
  await waitForBackend(page);
});

test('every destination renders from live data without a crash boundary', async () => {
  const { page } = desktop;
  const nav = page.getByRole('navigation', { name: 'Destinations' });
  for (const destination of DESTINATIONS) {
    await nav.getByRole('link', { name: destination.link }).click();
    await expect(page).toHaveURL(new RegExp(`#${destination.path}`));
    await expect(nav.getByRole('link', { name: destination.link })).toHaveAttribute('aria-current', 'page');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByText(/stopped working/i)).toHaveCount(0);
  }
});

test('workspace reads the scratch workspace through the backend', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
  await expect(page.getByRole('region', { name: 'Context budget' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Personas' })).toContainText(/architect|implementer/);
});

test('library shows catalog vs detected vs configured vs verified without dumping envelopes', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Library' }).click();
  const tools = page.getByRole('region', { name: 'Coding tools' });
  await expect(tools.getByRole('columnheader', { name: 'Detected' })).toBeVisible();
  await expect(tools.getByRole('columnheader', { name: 'Configured' })).toBeVisible();
  await expect(tools.getByRole('columnheader', { name: 'Enabled' })).toBeVisible();
  await expect(tools.getByRole('columnheader', { name: 'Verified' })).toBeVisible();
  await expect(tools.getByText('unknown').first()).toBeVisible();
  const personas = page.getByRole('region', { name: 'Agent definitions' });
  await expect(personas).toBeVisible();
  await expect(personas).toContainText(/in catalog|No agent definitions in the catalog/i);
  await expect(page.getByText(/plugin\/list/i)).toHaveCount(0);
  await expect(page.getByRole('region', { name: 'Memory' })).toHaveCount(0);
  await expect(page.getByRole('heading', { level: 1, name: 'Library board' })).toBeVisible();
  await page.screenshot({ path: 'test-results/review/library.png', fullPage: true });
});

test('a contextual tool destination opens the same target-specific Library review', async () => {
  const { page } = desktop;
  const appUrl = page.url().split('#')[0];
  await page.goto(`${appUrl}#/library?install_target=claude-code`);
  await expect(page.getByRole('heading', { level: 1, name: 'Library board' })).toBeVisible();
  const review = page.getByRole('dialog', { name: 'Review capability installation' });
  await expect(review).toBeVisible();
  await expect(review.getByRole('checkbox', { name: 'Claude Code' })).toBeChecked();
  await expect(review.getByLabel('Installation preview')).toContainText('Tools to install: claude-code');
  await review.getByRole('button', { name: 'Cancel' }).click();
});

test('insights shows doctor checks and usage without invented cost', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Insights' }).click();
  const doctor = page.getByRole('region', { name: 'Doctor' });
  await expect(doctor).toBeVisible();
  await expect(
    doctor.getByRole('columnheader', { name: 'Check' }).or(doctor.getByText('Doctor returned no structured checks.')),
  ).toBeVisible();
  await expect(doctor.getByText(/health score:\s*\d|\$\d/i)).toHaveCount(0);
  const usage = page.getByRole('region', { name: 'Usage by tool' });
  await expect(usage).toBeVisible();
  await expect(usage).toContainText(/Unknown|No usage rows/);
  await page.screenshot({ path: 'test-results/review/insights.png', fullPage: true });
});

test('settings keeps Meadow/Dusk/System and names a rejected binary as a table when present', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
  const theme = page.getByRole('group', { name: 'Theme' });
  await expect(theme.getByRole('radio', { name: /Meadow/ })).toBeVisible();
  await expect(theme.getByRole('radio', { name: /Dusk/ })).toBeVisible();
  await expect(theme.getByRole('radio', { name: /System/ })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Backend' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Change harness…' })).toBeVisible();
  await page.screenshot({ path: 'test-results/review/settings.png', fullPage: true });
});

test('a job started from Operations runs on the backend and streams to completion', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start job' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a job' });
  await expect(dialog).toBeVisible();
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('version');
  await expect(dialog.getByText('agent-toolkit version', { exact: true })).toBeVisible();
  await dialog.getByRole('button', { name: 'Start job' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText('Job started');
  await expect(page).toHaveURL(/job=/);

  const detail = page.getByRole('region', { name: 'version' });
  await expect(detail.getByText('completed')).toBeVisible();
  await expect(detail.getByText(/\d+\.\d+\.\d+/).first()).toBeVisible();
});

test('Operations shows doctor, loops and swarms from live endpoints', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Operations' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Doctor' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Board' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Loops' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Swarms' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Swarms' })).toContainText(/GET \/api\/v1\/swarms|No swarm runs/);
});

test('Library installs Skills and preserves user changes during reviewed removal', async () => {
  const { page } = desktop;
  let applyRequests = 0;
  let appliedTargets: string[] = [];
  let uninstallRequests = 0;
  const preservedSkill = path.join(desktop.home, '.claude', 'skills', 'review', 'SKILL.md');
  fs.mkdirSync(path.dirname(preservedSkill), { recursive: true });
  fs.writeFileSync(preservedSkill, 'User-owned skill, keep this file.\n');
  await page.route('**/api/v1/install/reviewed', async (route) => {
    applyRequests += 1;
    appliedTargets = (route.request().postDataJSON() as { tools: string[] }).tools;
    await route.continue();
  });
  await page.route('**/api/v1/uninstall/reviewed**', async (route) => {
    uninstallRequests += 1;
    await new Promise((resolve) => setTimeout(resolve, 2500));
    await route.continue();
  });
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Library' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Library board' })).toBeVisible();
  await expect(page.getByText('Discovering coding tools')).toBeHidden();
  await expect(page.getByText('Loading agent definitions')).toBeHidden();
  await expect(page.getByText('Loading the skills catalog')).toBeHidden();
  await page.getByRole('button', { name: 'Review installation' }).click();
  const preview = page.getByRole('dialog', { name: 'Review capability installation' });
  await expect(preview).toBeVisible();
  await expect(preview).toContainText('does not write files');
  await expect(preview.getByLabel('Installation preview')).toContainText('DRY RUN');
  await expect(preview.getByLabel('Installation preview')).toContainText('no files or receipts will be changed');
  await expect(preview.getByLabel('Installation preview')).toContainText(
    path.join(desktop.home, '.claude', 'skills', 'pr-fallback', 'references', 'pr-body-default.md'),
  );
  await expect(preview.getByLabel('Installation preview')).toContainText(preservedSkill);
  for (const target of ['Claude Code', 'Cursor', 'OpenCode', 'Windsurf', 'Pi', 'Muse Code']) {
    await preview.getByRole('checkbox', { name: target }).setChecked(target === 'Claude Code' || target === 'Cursor');
  }
  await preview.getByRole('button', { name: 'Preview selected targets' }).click();
  await expect(preview.getByLabel('Installation preview')).toContainText('Tools to install: claude-code, cursor');
  if (CAPTURE) {
    fs.mkdirSync(LIBRARY_CAPTURE_DIR, { recursive: true });
    for (const size of [
      { width: 1024, height: 768, key: 'compact' },
      { width: 1440, height: 900, key: 'large' },
    ]) {
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({
        path: path.join(LIBRARY_CAPTURE_DIR, `install-preview-${size.key}.png`),
        fullPage: true,
      });
    }
    await page.setViewportSize({ width: 1280, height: 800 });
  }
  await preview.getByRole('button', { name: 'Cancel' }).click();
  await expect(preview).toBeHidden();
  expect(applyRequests).toBe(0);
  await expect(page.getByRole('region', { name: 'Receipts' })).not.toContainText('Toolkit capabilities installed');

  await page.getByRole('button', { name: 'Review installation' }).click();
  const reviewedInstall = page.getByRole('dialog', { name: 'Review capability installation' });
  for (const target of ['Claude Code', 'Cursor', 'OpenCode', 'Windsurf', 'Pi', 'Muse Code']) {
    await reviewedInstall
      .getByRole('checkbox', { name: target })
      .setChecked(target === 'Claude Code' || target === 'Cursor');
  }
  await reviewedInstall.getByRole('button', { name: 'Preview selected targets' }).click();
  await expect(reviewedInstall.getByLabel('Installation preview')).toContainText(
    'Tools to install: claude-code, cursor',
  );
  await reviewedInstall.getByRole('button', { name: 'Install reviewed targets' }).click();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText('Toolkit capabilities installed');
  expect(applyRequests).toBe(1);
  expect(appliedTargets).toEqual(['claude-code', 'cursor']);
  await expect(page.getByRole('region', { name: 'Installation evidence' })).toContainText('receipts');
  await expect(page.getByRole('region', { name: 'Installation evidence' })).toContainText('Claude Code');
  await expect(page.getByRole('region', { name: 'Installation evidence' })).toContainText('Cursor');
  await page.reload();
  await expect(page.getByRole('region', { name: 'Installation evidence' })).toContainText('Claude Code');
  await expect(page.getByRole('region', { name: 'Installation evidence' })).toContainText('Cursor');
  await expect(page.getByText('Discovering coding tools')).toBeHidden();
  await expect(page.getByText('Loading agent definitions')).toBeHidden();
  await expect(page.getByText('Listing swarm runners')).toBeHidden();
  await expect(page.getByText('Loading the skills catalog')).toBeHidden();
  if (CAPTURE) {
    fs.mkdirSync(LIBRARY_CAPTURE_DIR, { recursive: true });
    for (const size of [
      { width: 1024, height: 768, key: 'compact' },
      { width: 1440, height: 900, key: 'large' },
    ]) {
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({
        path: path.join(LIBRARY_CAPTURE_DIR, `installation-receipts-${size.key}.png`),
        fullPage: true,
      });
    }
    await page.setViewportSize({ width: 1280, height: 800 });
  }
  expect(fs.readFileSync(preservedSkill, 'utf8')).toBe('User-owned skill, keep this file.\n');
  const toolkitSkill = path.join(desktop.home, '.claude', 'skills', 'pr-fallback', 'references', 'pr-body-default.md');
  expect(fs.existsSync(toolkitSkill)).toBe(true);
  fs.writeFileSync(toolkitSkill, 'Edited by the user after Toolkit installed it.\n');

  await page.getByRole('button', { name: 'Review removal' }).click();
  const removal = page.getByRole('dialog', { name: 'Review Toolkit file removal' });
  await expect(removal).toBeVisible();
  await expect(removal).toContainText('Files you edited after installation and merged settings are preserved');
  await expect(removal.getByLabel('Removal preview')).toContainText(
    `Would remove: ${path.join(desktop.home, '.claude', 'skills', 'pr-fallback', 'SKILL.md')}`,
  );
  await expect(removal.getByLabel('Removal preview')).toContainText(
    `Preserving file changed since Toolkit installed it: ${toolkitSkill}`,
  );
  const changedAfterReview = path.join(desktop.home, '.claude', 'skills', 'assistant', 'SKILL.md');
  if (CAPTURE) {
    fs.mkdirSync(LIBRARY_CAPTURE_DIR, { recursive: true });
    for (const size of [
      { width: 1024, height: 768, key: 'compact' },
      { width: 1440, height: 900, key: 'large' },
    ]) {
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({
        path: path.join(LIBRARY_CAPTURE_DIR, `removal-preview-${size.key}.png`),
        fullPage: true,
      });
    }
    await page.setViewportSize({ width: 1280, height: 800 });
  }
  expect(uninstallRequests).toBe(0);
  await removal.getByRole('button', { name: 'Keep files' }).click();
  await expect(removal).toBeHidden();
  expect(uninstallRequests).toBe(0);

  await page.getByRole('button', { name: 'Review removal' }).click();
  const confirmedRemoval = page.getByRole('dialog', { name: 'Review Toolkit file removal' });
  await expect(confirmedRemoval).toBeVisible();
  fs.writeFileSync(changedAfterReview, 'Edited between review and confirmation.\n');
  await confirmedRemoval.getByRole('button', { name: 'Remove reviewed files' }).click();
  await expect.poll(() => uninstallRequests).toBe(1);
  await expect(confirmedRemoval.getByRole('button', { name: 'Removing files…' })).toBeVisible();
  await expect(confirmedRemoval.getByRole('button', { name: 'Keep files' })).toBeDisabled();
  await page.keyboard.press('Escape');
  await expect(confirmedRemoval).toBeVisible();
  await expect(confirmedRemoval.getByRole('alert')).toContainText('Removal plan changed since review');
  expect(fs.readFileSync(changedAfterReview, 'utf8')).toBe('Edited between review and confirmation.\n');
  await confirmedRemoval.getByRole('button', { name: 'Refresh removal plan' }).click();
  await expect(confirmedRemoval.getByLabel('Removal preview')).toContainText(
    `Preserving file changed since Toolkit installed it: ${changedAfterReview}`,
  );
  await confirmedRemoval.getByRole('button', { name: 'Remove reviewed files' }).click();
  await expect(
    page.getByRole('region', { name: 'Receipts' }).getByText('Toolkit files removed', { exact: true }),
  ).toBeVisible();
  expect(uninstallRequests).toBe(2);
  expect(fs.readFileSync(toolkitSkill, 'utf8')).toBe('Edited by the user after Toolkit installed it.\n');
  expect(fs.readFileSync(preservedSkill, 'utf8')).toBe('User-owned skill, keep this file.\n');
  expect(
    fs.existsSync(
      path.join(desktop.home, '.config', 'agent-toolkit', 'receipts', 'claude-code-agent-toolkit-profiles.json'),
    ),
  ).toBe(false);
  await expect(page.getByRole('region', { name: 'Installation evidence' })).toContainText(
    'No Toolkit capability installations recorded on this machine.',
  );
});

test('Library configures MCP providers with secret-free previews and explicit checks', async () => {
  const { page } = desktop;
  let enabled = false;
  let configured = false;
  let setupRequests = 0;
  let validationRequests = 0;
  let probeRequests = 0;
  let removeRequests = 0;

  await page.route('**/api/v1/mcp/providers', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        ok: true,
        message: '',
        config_path: path.join(desktop.home, '.config/agent-toolkit/mcp-config.json'),
        providers: [
          {
            id: 'github',
            display_name: 'GitHub',
            package: 'ghcr.io/github/github-mcp-server',
            required_env: ['GITHUB_PERSONAL_ACCESS_TOKEN'],
            missing_env: ['GITHUB_PERSONAL_ACCESS_TOKEN'],
            configured,
            enabled,
            template_available: true,
            template_sha: 'f1aeee47',
            template_is_pinned: true,
            template_matches_pin: true,
          },
        ],
      }),
    }),
  );
  await page.route('**/api/v1/mcp/setup', async (route) => {
    setupRequests += 1;
    const body = route.request().postDataJSON() as { provider: string; offline: boolean };
    expect(body).toEqual({ provider: 'github', offline: true });
    expect(JSON.stringify(body)).not.toContain('secret');
    configured = true;
    enabled = true;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ ok: true, message: 'Saved provider to Toolkit MCP configuration.', data: { count: '1' } }),
    });
  });
  await page.route('**/api/v1/mcp/doctor', async (route) => {
    validationRequests += 1;
    const body = route.request().postDataJSON() as { provider: string; offline: boolean };
    expect(body).toEqual({ provider: 'github', offline: false });
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        ok: true,
        message: 'GITHUB_PERSONAL_ACCESS_TOKEN: not set in environment',
        data: { count: '1' },
      }),
    });
  });
  await page.route('**/api/v1/mcp/health', async (route) => {
    probeRequests += 1;
    const body = route.request().postDataJSON() as { provider: string; offline: boolean };
    expect(body).toEqual({ provider: 'github', offline: true });
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        ok: true,
        message: 'probe binary: docker present; health probe ok',
        data: { count: '1' },
      }),
    });
  });
  await page.route('**/api/v1/mcp/uninstall', async (route) => {
    removeRequests += 1;
    const body = route.request().postDataJSON() as { provider: string; offline: boolean };
    expect(body.provider).toBe('github');
    configured = false;
    enabled = false;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        ok: true,
        message: 'Removed github from Toolkit MCP configuration.',
        data: { count: '1' },
      }),
    });
  });

  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Library' }).click();
  const panel = page.getByRole('region', { name: 'MCP providers' });
  await expect(panel).toBeVisible();
  const row = panel.getByRole('row', { name: /GitHub/ });
  await row.getByRole('button', { name: 'Configure' }).click();
  const configure = page.getByRole('dialog', { name: 'Configure GitHub' });
  await expect(configure).toContainText('does not store secret values');
  await expect(configure).toContainText('GITHUB_PERSONAL_ACCESS_TOKEN');
  await expect(configure).toContainText('not in app environment');
  expect(setupRequests).toBe(0);
  if (CAPTURE) {
    fs.mkdirSync(LIBRARY_CAPTURE_DIR, { recursive: true });
    for (const size of [
      { width: 1024, height: 768, key: 'mcp-configure-compact' },
      { width: 1600, height: 1000, key: 'mcp-configure-large' },
    ]) {
      await setViewport(desktop.app, size.width, size.height);
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({ path: path.join(LIBRARY_CAPTURE_DIR, `${size.key}.png`), fullPage: true });
    }
    await setViewport(desktop.app, 1280, 800);
    await page.setViewportSize({ width: 1280, height: 800 });
  }
  await configure.getByRole('button', { name: 'Save provider' }).click();
  await expect(configure.getByRole('status')).toContainText('Saved provider');
  await configure.getByRole('button', { name: 'Close' }).click();
  await expect(row.getByText('enabled')).toBeVisible();
  expect(setupRequests).toBe(1);

  await row.getByRole('button', { name: 'Validate' }).click();
  const validate = page.getByRole('dialog', { name: 'Validate GitHub' });
  await validate.getByRole('button', { name: 'Validate' }).click();
  await expect(validate.getByRole('status')).toContainText('not set in environment');
  await validate.getByRole('button', { name: 'Close' }).click();
  expect(validationRequests).toBe(1);

  await row.getByRole('button', { name: 'Probe' }).click();
  const probe = page.getByRole('dialog', { name: 'Probe GitHub' });
  await expect(probe).toContainText('does not start an MCP session');
  await probe.getByRole('button', { name: 'Run probe' }).click();
  await expect(probe.getByRole('status')).toContainText('health probe ok');
  await probe.getByRole('button', { name: 'Close' }).click();
  expect(probeRequests).toBe(1);

  await row.getByRole('button', { name: 'Remove' }).click();
  const remove = page.getByRole('dialog', { name: 'Remove GitHub' });
  await expect(remove).toContainText('does not delete environment variables');
  await remove.getByRole('button', { name: 'Remove provider' }).click();
  await expect(remove.getByRole('status')).toContainText('Removed github');
  await remove.getByRole('button', { name: 'Close' }).click();
  await expect(row.getByText('not configured')).toBeVisible();
  expect(removeRequests).toBe(1);
});

test('swarm start reviews canonical topology and keeps runner separate from adapter', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
  await page.getByRole('button', { name: 'Create Person' }).click();
  const personDialog = page.getByRole('dialog', { name: 'Create Person' });
  await personDialog.getByRole('textbox', { name: 'Name' }).fill('Lina');
  await personDialog.getByRole('textbox', { name: 'ID' }).fill('lina');
  await personDialog.getByRole('textbox', { name: 'Role' }).fill('reviewer');
  await personDialog.getByRole('textbox', { name: 'Goal' }).fill('Review work assigned to my swarm role');
  await personDialog.getByRole('button', { name: 'Create Person' }).click();
  await expect(personDialog).toBeHidden();
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start swarm' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a swarm' });
  await expect(dialog.getByText('.ai-workspace')).toBeVisible();
  await expect(dialog.getByLabel('Team recipe')).toContainText('pair · 3 roles');
  await expect(dialog.getByRole('region', { name: 'pair recipe topology' })).toContainText('implementer');
  await expect(dialog.getByRole('group', { name: 'Recipe write permissions' })).toContainText(
    'Direct base merge: Not allowed',
  );
  await dialog.getByLabel('Task').fill('Inspect the existing Desktop architecture');
  await expect(dialog.getByRole('region', { name: 'Resolved swarm People' })).toContainText(
    'reviewer → Lina · matched role',
  );
  await dialog.getByLabel('Person for reviewer').selectOption('lina');
  await expect(dialog.getByRole('region', { name: 'Resolved swarm People' })).toContainText(
    'reviewer → Lina · selected',
  );
  await expect(dialog.getByText(/Runner and model remain swarm-wide settings/)).toBeVisible();
  await setViewport(desktop.app, 1024, 768);
  await page.screenshot({ path: 'test-results/review/swarms-start-compact.png', fullPage: true });
  if (CAPTURE) {
    fs.mkdirSync(CAPTURE_DIR, { recursive: true });
    await page.screenshot({ path: path.join(CAPTURE_DIR, 'swarm-start-compact.png'), fullPage: true });
  }
  await setViewport(desktop.app, 1600, 1000);
  await page.screenshot({ path: 'test-results/review/swarms-start-large.png', fullPage: true });
  if (CAPTURE) await page.screenshot({ path: path.join(CAPTURE_DIR, 'swarm-start-large.png'), fullPage: true });
  await dialog.getByText('Runtime options').click();
  await dialog.getByLabel('Session adapter').selectOption('headless');
  await expect(dialog.getByText(/Headless records the run without launching agents/)).toBeVisible();
  await dialog.getByLabel('Dry run').check();
  await expect(dialog.getByText('Automatic runner · headless adapter')).toBeVisible();
  await dialog.getByRole('button', { name: 'Start swarm' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText(/Swarm start posted/);
});

test('Operations refreshes a live swarm when its state changes outside Desktop', async () => {
  const { page, workspace } = desktop;
  await waitForBackend(page);
  initializeTestRepository(workspace);
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start swarm' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a swarm' });
  await dialog.getByLabel('Task').fill('Observe externally updated run state');
  await dialog.getByText('Runtime options').click();
  await dialog.getByLabel('Session adapter').selectOption('headless');
  await expect(dialog.getByText(/Headless records the run without launching agents/)).toBeVisible();
  await dialog.getByRole('button', { name: 'Start swarm' }).click();
  await expect(dialog).toBeHidden();

  const runRow = page.getByRole('button', { name: /Observe externally updated run state/ });
  await expect(runRow).toBeVisible();
  const dismissReceipt = page.getByRole('button', { name: 'Dismiss: Swarm start posted' }).last();
  if (await dismissReceipt.isVisible()) await dismissReceipt.click();
  const runId = (await runRow.innerText()).trim().split(/\s+/)[0];
  if (!runId) throw new Error('The new swarm run did not expose an ID');
  await runRow.click();
  const inspector = page.getByRole('region', { name: 'pair' });
  await expect(inspector.getByText('running', { exact: true })).toBeVisible();
  await expect(inspector).toContainText('headless');
  await expect(inspector.getByRole('region', { name: 'Artifacts' })).toContainText('task-contract.md');
  await setViewport(desktop.app, 1024, 768);
  await inspector.evaluate((element) => element.scrollIntoView({ block: 'start' }));
  await page.screenshot({ path: 'test-results/review/swarm-run-watch-compact.png', fullPage: true });
  if (CAPTURE) {
    fs.mkdirSync(CAPTURE_DIR, { recursive: true });
    await page.screenshot({ path: path.join(CAPTURE_DIR, 'swarm-run-watch-compact.png'), fullPage: true });
  }
  await setViewport(desktop.app, 1600, 1000);
  await inspector.evaluate((element) => element.scrollIntoView({ block: 'start' }));
  await page.screenshot({ path: 'test-results/review/swarm-run-watch-large.png', fullPage: true });
  if (CAPTURE) await page.screenshot({ path: path.join(CAPTURE_DIR, 'swarm-run-watch-large.png'), fullPage: true });

  runSwarmCli(desktop, ['pause', runId]);
  await expect(inspector.getByText('paused', { exact: true })).toBeVisible({ timeout: 14_000 });
  await page.keyboard.press('Control+k');
  const palette = page.getByRole('dialog', { name: 'Commands' });
  await palette.getByLabel('Filter commands').fill('Review paused swarm');
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(new RegExp(`swarm=${encodeURIComponent(runId)}`));
  await expect(inspector.getByRole('button', { name: 'Resume run' })).toBeVisible();
  await inspector.getByRole('button', { name: 'Resume run' }).click();
  await expect(inspector.getByText('running', { exact: true })).toBeVisible();

  await inspector.getByRole('button', { name: 'Stop' }).click();
  const stopDialog = page.getByRole('dialog', { name: 'Stop this swarm run?' });
  await stopDialog.getByRole('button', { name: 'Stop run' }).click();
  await expect(inspector.getByText('cancelled', { exact: true })).toBeVisible({ timeout: 8_000 });
});

test('a failed job can be retried as a new job', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start job' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a job' });
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('no-such-command');
  await dialog.getByRole('button', { name: 'Start job' }).click();
  await expect(dialog).toBeHidden();

  const detail = page.getByRole('region', { name: 'no-such-command' });
  await expect(detail.getByText(/failed|rejected/)).toBeVisible();
  const retry = detail.getByRole('button', { name: 'Retry job' });
  if (await retry.isVisible()) {
    await retry.click();
    await expect(page.getByRole('region', { name: 'Receipts' })).toContainText('Job retried');
    await expect(page.getByRole('region', { name: 'no-such-command' })).toContainText(/retry of/i);
  } else {
    await expect(detail).toContainText('rejected');
  }
});

test('dialogs focus their first field and Escape returns focus to the trigger', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  const trigger = page.getByRole('button', { name: 'Start job' });
  await trigger.focus();
  await page.keyboard.press('Enter');
  const dialog = page.getByRole('dialog', { name: 'Start a job' });
  await expect(dialog.getByRole('textbox', { name: 'Command', exact: true })).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();
  await expect(trigger).toBeFocused();
});

test('theme choice applies immediately and survives a reload', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
  await page.getByRole('radio', { name: /Dusk/ }).check();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dusk');
  await page.reload();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dusk');
  await page.getByRole('radio', { name: /Meadow/ }).check();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'meadow');
});

test('a failed job appears in Office attention and Next that needs me opens it', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start job' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a job' });
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('no-such-command');
  await dialog.getByRole('button', { name: 'Start job' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'no-such-command' }).getByText('failed')).toBeVisible();

  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Office' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Attention' })).toBeVisible();
  const needsYou = page.getByRole('region', { name: 'Needs you' });
  await expect(needsYou).toContainText(/no-such-command failed/);
  await expect(needsYou).not.toContainText(/Nothing needs you/);
  await expect(page.getByRole('main')).not.toContainText(/quiet/i);
  await expect(needsYou.locator('tr[data-attention="failed-job"]').first()).toBeVisible();
  await expect(page.getByRole('region', { name: 'Failed' })).toContainText('no-such-command');

  await page.keyboard.press('Control+k');
  const palette = page.getByRole('dialog', { name: 'Commands' });
  await palette.getByLabel('Filter commands').fill('Next that needs me');
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/job=/);
});

test('terminal runs a real pseudo-terminal session that survives navigation', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Terminal' }).click();
  await page.getByRole('main').getByRole('button', { name: 'New session' }).click();
  const dialog = page.getByRole('dialog', { name: 'New terminal session' });
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('/bin/sh');
  await dialog.getByRole('textbox', { name: 'Label', exact: true }).fill('e2e-shell');
  await dialog.getByRole('button', { name: 'Open session' }).click();

  await expect(page.getByRole('tab', { name: /e2e-shell/ })).toHaveAttribute('aria-selected', 'true');
  const terminal = page.getByLabel('Terminal for e2e-shell');
  await terminal.click();
  await page.keyboard.type('echo atk-e2e-$((40+2))');
  await page.keyboard.press('Enter');
  await expect(terminal.locator('.xterm-rows')).toContainText('atk-e2e-42');

  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Office' }).click();
  const dock = page.getByRole('complementary', { name: 'Terminal dock' });
  await expect(dock.getByRole('tab', { name: /e2e-shell/ })).toBeVisible();
  await expect(dock.getByLabel('Terminal for e2e-shell').locator('.xterm-rows')).toContainText('atk-e2e-42');
  await expect(page.getByRole('button', { name: 'New session' })).toHaveCount(1);
});

test('the world focuses a real PTY and does not invent one', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Terminal' }).click();
  await page.getByRole('main').getByRole('button', { name: 'New session' }).click();
  const dialog = page.getByRole('dialog', { name: 'New terminal session' });
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('/bin/sh');
  await dialog.getByRole('textbox', { name: 'Label', exact: true }).fill('e2e-world');
  await dialog.getByRole('button', { name: 'Open session' }).click();

  const first = page.getByRole('tab', { name: /e2e-shell/ });
  const second = page.getByRole('tab', { name: /e2e-world/ });
  const firstId = await first.getAttribute('data-session-id');
  const secondId = await second.getAttribute('data-session-id');
  expect(firstId).toBeTruthy();
  expect(secondId).toBeTruthy();
  if (!firstId || !secondId) throw new Error('missing session id');
  await expect(second).toHaveAttribute('aria-selected', 'true');
  expect(page.url()).toContain(`pty=${secondId}`);

  await first.click();
  await expect(first).toHaveAttribute('aria-selected', 'true');
  expect(page.url()).toContain(`pty=${firstId}`);

  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Office' }).click();
  expect(page.url()).toContain(`pty=${firstId}`);
  await expect(first).toHaveAttribute('aria-selected', 'true');

  await page.evaluate((id) => {
    const raw = window.location.hash.slice(1);
    const q = raw.indexOf('?');
    const path = q >= 0 ? raw.slice(0, q) : raw;
    const params = new URLSearchParams(q >= 0 ? raw.slice(q + 1) : '');
    params.set('pty', id);
    window.location.hash = `${path}?${params}`;
  }, secondId);
  await expect(second).toHaveAttribute('aria-selected', 'true');

  const before = await page.getByRole('tab').count();
  await page.evaluate(() => {
    const raw = window.location.hash.slice(1);
    const q = raw.indexOf('?');
    const path = q >= 0 ? raw.slice(0, q) : raw;
    const params = new URLSearchParams(q >= 0 ? raw.slice(q + 1) : '');
    params.set('pty', 'missing-world-pty');
    window.location.hash = `${path}?${params}`;
  });
  await expect(page.getByRole('tab')).toHaveCount(before);
  await expect(second).toHaveAttribute('aria-selected', 'true');
});

test('an exited session keeps its output and can restart', async () => {
  const { page } = desktop;
  // Bind a real run identity so the dock tab (and restart) carry it — do not invent labels in asserts.
  const runField = page.getByRole('form', { name: 'Session context' }).getByRole('textbox', { name: 'Run' });
  await runField.fill('e2e-run');
  await runField.press('Enter');
  await expect(page).toHaveURL(/run=e2e-run/);
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Terminal' }).click();
  await page.getByRole('main').getByRole('button', { name: 'New session' }).click();
  const dialog = page.getByRole('dialog', { name: 'New terminal session' });
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('/bin/sh');
  await dialog.getByRole('textbox', { name: 'Label', exact: true }).fill('e2e-exit');
  await dialog.getByRole('button', { name: 'Open session' }).click();

  await expect(page.getByRole('tab', { name: /e2e-exit · e2e-run · \.ai-workspace · running/ })).toBeVisible();
  const terminal = page.getByLabel('Terminal for e2e-exit');
  await terminal.click();
  await page.keyboard.type('exit 7');
  await page.keyboard.press('Enter');
  await expect(page.getByRole('tab', { name: /e2e-exit · e2e-run · \.ai-workspace · exited 7/ })).toBeVisible();
  await expect(page.getByRole('status').filter({ hasText: 'exit code 7' })).toBeVisible();
  await page.getByRole('button', { name: 'Restart' }).click();
  await expect(page.getByRole('tab', { name: /e2e-exit · e2e-run · \.ai-workspace · running/ })).toBeVisible();
  await page.getByRole('button', { name: 'Close' }).click();
  const closeDialog = page.getByRole('dialog', { name: 'Close this session?' });
  await expect(closeDialog).toContainText('The process is killed and its scrollback is discarded.');
  await closeDialog.getByRole('button', { name: 'Kill and close' }).click();
  await expect(page.getByRole('tab', { name: /e2e-exit/ })).toHaveCount(0);
});

test('a crashed backend is attention, while its real PTY stays available for recovery', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Terminal' }).click();
  await page.getByRole('main').getByRole('button', { name: 'New session' }).click();
  const terminalDialog = page.getByRole('dialog', { name: 'New terminal session' });
  await terminalDialog.getByRole('textbox', { name: 'Command', exact: true }).fill('/bin/sh');
  await terminalDialog.getByRole('textbox', { name: 'Label', exact: true }).fill('backend-independent-pty');
  await terminalDialog.getByRole('button', { name: 'Open session' }).click();
  const terminalTab = page.getByRole('tab', { name: /backend-independent-pty.*running/ });
  await expect(terminalTab).toBeVisible();
  const terminal = page.getByLabel('Terminal for backend-independent-pty');
  await terminal.click();
  await page.keyboard.type("printf 'pty-survives-backend-crash\\n'; sleep 30");
  await page.keyboard.press('Enter');
  await expect(terminal.locator('.xterm-rows')).toContainText('pty-survives-backend-crash');

  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Office' }).click();
  const binaryPath = await page.evaluate(async () => {
    const state = await window.atk?.backendStatus();
    return state?.binary?.path ?? null;
  });
  expect(binaryPath).toBeTruthy();
  if (!binaryPath) return;
  killSupervisedServe(binaryPath);

  await expect(page.getByRole('alert')).toContainText(/crashed|not answering|stopped/i);
  const needsYou = page.getByRole('region', { name: 'Needs you' });
  await expect(needsYou).toContainText(/Backend crashed|Backend not answering|Backend failed/i);
  await expect(needsYou).not.toContainText(/Nothing needs you/);
  await expect(page.getByRole('main')).not.toContainText(/the workstation is quiet/i);
  await expect(terminalTab).toBeVisible();
  await expect(terminalTab).toHaveAttribute('aria-selected', 'true');
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Terminal' }).click();
  await expect(page.getByLabel('Terminal for backend-independent-pty').locator('.xterm-rows')).toContainText(
    'pty-survives-backend-crash',
  );
  await page.getByRole('button', { name: 'Close' }).click();
  await page
    .getByRole('dialog', { name: 'Close this session?' })
    .getByRole('button', { name: 'Kill and close' })
    .click();
  await expect(page.getByRole('tab', { name: /backend-independent-pty/ })).toHaveCount(0);
});
