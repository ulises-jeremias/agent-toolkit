import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';

/**
 * Swarm Person-session linkage (slice: canonical PersonSession per launched
 * role). A Person bound to a recipe role must become a real PersonSession
 * only when the runner actually launches in a process adapter (tmux), must
 * be listed in the Operations run inspector, and must close when the run
 * stops. A binding alone (headless/dry-run) creates no session — that side
 * is covered by the binding test in desktop.spec.ts.
 *
 * Skips when no tmux adapter is available on the host (e.g. minimal CI
 * images): without a process adapter there is nothing truthful to launch.
 */
let desktop: Desktop;

test.beforeAll(async () => {
  desktop = await openDesktop();
});

test.afterAll(async () => {
  await desktop?.close();
});

function initRepo(dir: string): void {
  execFileSync('git', ['init', '--quiet', dir]);
  execFileSync(
    'git',
    [
      '-C',
      dir,
      '-c',
      'user.name=Agent Toolkit E2E',
      '-c',
      'user.email=e2e@agent-toolkit.invalid',
      'commit',
      '--allow-empty',
      '-m',
      'init',
    ],
    { stdio: 'pipe' },
  );
}

test('tmux swarm launch records a PersonSession that closes on stop', async () => {
  const { page, workspace } = desktop;
  await waitForBackend(page);
  initRepo(workspace);
  const link = path.join(workspace, 'projects', 'e2e-workspace');
  fs.mkdirSync(path.dirname(link), { recursive: true });
  if (!fs.existsSync(link)) fs.symlinkSync(workspace, link, 'dir');

  // Create the durable Person through the GUI.
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
  await page.getByRole('button', { name: 'Create Person' }).click();
  const personDialog = page.getByRole('dialog', { name: 'Create Person' });
  await personDialog.getByRole('textbox', { name: 'Name' }).fill('Mara');
  await personDialog.getByRole('textbox', { name: 'ID' }).fill('mara');
  await personDialog.getByRole('textbox', { name: 'Role' }).fill('implementer');
  await personDialog.getByRole('textbox', { name: 'Goal' }).fill('Implement work assigned to my swarm role');
  await personDialog.getByRole('button', { name: 'Create Person' }).click();
  await expect(personDialog).toBeHidden();

  // Start a real tmux swarm with Mara bound to the implementer role.
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start swarm' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a swarm' });
  await dialog.getByLabel('Project').selectOption('e2e-workspace');
  await dialog.getByLabel('Task').fill('Link the launched worker to a Person session');
  await dialog.getByLabel('Person for implementer').selectOption('mara');
  await dialog.getByText('Runtime options').click();
  const adapter = dialog.getByLabel('Session adapter');
  const adapterOptions = await adapter.locator('option').allTextContents();
  test.skip(
    !adapterOptions.some((label) => label.startsWith('tmux')),
    `tmux session adapter unavailable on this host (options: ${adapterOptions.join(', ')})`,
  );
  await adapter.selectOption('tmux');
  const roleRuntime = dialog.getByRole('group', { name: 'Runtime settings for implementer' });
  await roleRuntime.locator('summary').click();
  await dialog.getByLabel('Runner for implementer').selectOption('skeleton');
  await expect(dialog.getByLabel('Launch real role sessions')).toBeChecked();
  await dialog.getByRole('button', { name: 'Start swarm' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText(/Swarm start posted/);

  const swarmPanel = page.getByRole('region', { name: 'Swarms' });
  const runRow = swarmPanel
    .getByRole('row')
    .filter({ hasText: 'Link the launched worker to a Person session' })
    .getByRole('button', { name: /Link the launched worker to a Person session/ });
  await expect(runRow).toBeVisible();
  const runId = (await runRow.innerText()).trim().split(/\s+/)[0] ?? '';
  expect(runId).not.toBe('');
  await runRow.click();

  // The canonical store holds the launched role's PersonSession.
  const sessionsDir = path.join(workspace, '.agent-toolkit', 'sessions');
  await expect
    .poll(
      () =>
        fs.existsSync(sessionsDir)
          ? fs
              .readdirSync(sessionsDir)
              .map((file) => fs.readFileSync(path.join(sessionsDir, file), 'utf8'))
              .join('\n')
          : '',
      { timeout: 20_000 },
    )
    .toContain('"source":"swarm"');

  // The inspector lists the canonical PersonSession for the launched role.
  const inspector = page.getByRole('region', { name: 'pair' });
  const roleExecution = inspector.getByRole('region', { name: 'Role execution' });
  const sessionTable = roleExecution.locator('table').filter({ hasText: 'Person session' });
  const sessionRow = sessionTable.getByRole('row').filter({ hasText: 'Mara' });
  await expect(sessionRow).toContainText('implementer', { timeout: 20_000 });
  await expect(sessionRow).toContainText('running');

  // Stopping the run closes the PersonSession.
  await inspector.getByRole('button', { name: 'Stop' }).click();
  const stopDialog = page.getByRole('dialog', { name: 'Stop this swarm run?' });
  await stopDialog.getByRole('button', { name: 'Stop run' }).click();
  await expect(inspector.getByText('cancelled', { exact: true })).toBeVisible({ timeout: 20_000 });
  await expect(sessionRow).toContainText('stopped', { timeout: 20_000 });

  // The same record is durable in People history with its swarm origin.
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
  await page.getByRole('button', { name: 'Mara implementer Offline' }).click();
  await expect(page.getByText(/Swarm implementer · run/)).toBeVisible();

  // Best-effort: the run's tmux server must not leak past the test.
  try {
    execFileSync('tmux', ['-L', `agent-toolkit-swarm-${runId}`, 'kill-server'], { stdio: 'pipe' });
  } catch {
    // Already gone with the run stop; nothing to clean.
  }
});
