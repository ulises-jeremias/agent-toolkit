import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';

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
    await page.keyboard.press('Enter');
    await expect(page.getByRole('dialog', { name: pattern })).toBeVisible();
  };

  await openAction('Start a swarm', 'Start a swarm');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'Start a swarm' })).toBeHidden();

  await openAction('Run a loop', 'Run a loop once');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'Run a loop once' })).toBeHidden();

  await openAction('Start a job', 'Start a job');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'Start a job' })).toBeHidden();

  await openAction('New terminal session', 'New terminal session');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog', { name: 'New terminal session' })).toBeHidden();
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

test('swarm start reviews canonical topology and keeps runner separate from adapter', async () => {
  const { page } = desktop;
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
  await setViewport(desktop.app, 1024, 768);
  await page.screenshot({ path: 'test-results/review/swarms-start-compact.png', fullPage: true });
  await dialog.getByText('Runtime options').click();
  await expect(dialog.getByText(/Person assignment is not available/)).toBeVisible();
  await dialog.getByLabel('Session adapter').selectOption('headless');
  await dialog.getByLabel('Dry run').check();
  await expect(dialog.getByText('Automatic runner · headless adapter')).toBeVisible();
  await setViewport(desktop.app, 1600, 1000);
  await page.screenshot({ path: 'test-results/review/swarms-start-large.png', fullPage: true });
  await dialog.getByRole('button', { name: 'Start swarm' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText(/Swarm start posted/);
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
});

test('a crashed backend is attention, not a quiet office', async () => {
  const { page } = desktop;
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
});
