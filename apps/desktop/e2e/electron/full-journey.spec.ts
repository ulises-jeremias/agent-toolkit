import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';

/**
 * The §19 definition-of-done journey as ONE continuous GUI flow in a
 * single Desktop launch:
 *
 *   open Desktop → select workspace context pack → create a Person →
 *   start a real (tmux, skeleton-runner) swarm bound to that Person →
 *   observe the live PersonSession in Operations and as a World
 *   character → stop the run → reopen the run from the Person's
 *   history (recovery/inspection path).
 *
 * Fixture-level scaffolding only: the workspace itself, the pack file,
 * the project symlink, and git init. Every product step is driven
 * through the GUI. Skips when the tmux session adapter is unavailable
 * on the host. GitHub PR creation is out of scope (needs a real remote);
 * the run's inspection/recovery path stands in for the review leg.
 */
test('workspace to context pack to Person swarm to recovery in one flow', async () => {
  test.setTimeout(6 * 60_000);
  const desktop: Desktop = await openDesktop();
  const { page, workspace } = desktop;
  let runId = '';
  try {
    await waitForBackend(page);

    // 1. Choose context: review and apply a workspace context pack.
    const packDir = path.join(workspace, 'packs');
    fs.mkdirSync(packDir, { recursive: true });
    fs.writeFileSync(
      path.join(packDir, 'team.yaml'),
      'name: Product Team\ndescription: Shared project context for product work.\nprojects:\n  - e2e-workspace\n',
    );
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
    const packPanel = page.getByRole('region', { name: 'Workspace context packs' });
    await expect(packPanel).toContainText('Product Team');
    await packPanel.getByRole('button', { name: 'Use for future sessions' }).first().click();
    await expect(packPanel.getByText('Context selected')).toBeVisible();
    await expect
      .poll(() => fs.readFileSync(path.join(workspace, '.active-pack'), 'utf8').trim())
      .toBe('packs/team.yaml');

    // 2. Create the Person who will own the swarm role, in the GUI.
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.getByRole('button', { name: 'Create Person' }).click();
    const personDialog = page.getByRole('dialog', { name: 'Create Person' });
    await personDialog.getByRole('textbox', { name: 'Name' }).fill('Mara');
    await personDialog.getByRole('textbox', { name: 'ID' }).fill('mara');
    await personDialog.getByRole('textbox', { name: 'Role' }).fill('implementer');
    await personDialog.getByRole('textbox', { name: 'Goal' }).fill('Deliver the assigned swarm role');
    await personDialog.getByRole('button', { name: 'Create Person' }).click();
    await expect(personDialog).toBeHidden();

    // 3. Enter the project and start real work: a tmux swarm whose
    // implementer role is bound to Mara, reviewed in the start dialog.
    initRepo(workspace);
    const link = path.join(workspace, 'projects', 'e2e-workspace');
    fs.mkdirSync(path.dirname(link), { recursive: true });
    if (!fs.existsSync(link)) fs.symlinkSync(workspace, link, 'dir');
    const task = 'Carry the full journey end to end';
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
    await page.getByRole('button', { name: 'Start swarm' }).click();
    const dialog = page.getByRole('dialog', { name: 'Start a swarm' });
    await dialog.getByLabel('Project').selectOption('e2e-workspace');
    await dialog.getByLabel('Task').fill(task);
    await dialog.getByLabel('Person for implementer').selectOption('mara');
    await dialog.getByText('Runtime options').click();
    const adapter = dialog.getByLabel('Session adapter');
    const adapterOptions = await adapter.locator('option').allTextContents();
    test.skip(
      !adapterOptions.some((label) => label.startsWith('tmux')),
      `tmux session adapter unavailable on this host (options: ${adapterOptions.join(', ')})`,
    );
    await adapter.selectOption('tmux');
    for (const role of ['implementer', 'reviewer', 'integrator']) {
      const roleRuntime = dialog.getByRole('group', { name: `Runtime settings for ${role}` });
      await roleRuntime.locator('summary').click();
      await dialog.getByLabel(`Runner for ${role}`).selectOption('skeleton');
    }
    await expect(dialog.getByLabel('Launch real role sessions')).toBeChecked();
    await dialog.getByRole('button', { name: 'Start swarm' }).click();
    await expect(dialog).toBeHidden();
    await expect(page.getByRole('region', { name: 'Receipts' })).toContainText(/Swarm start posted/);
    const runRow = page
      .getByRole('region', { name: 'Swarms' })
      .getByRole('row')
      .filter({ hasText: task })
      .getByRole('button', { name: new RegExp(task) });
    await expect(runRow).toBeVisible();
    runId = (await runRow.innerText()).trim().split(/\s+/)[0] ?? '';
    expect(runId).not.toBe('');
    await runRow.click();

    // 4. Observe live work: Mara's canonical PersonSession runs in the
    // inspector, and Mara stands at the project house in the World.
    const inspector = page.getByRole('region', { name: 'pair' });
    const sessionRow = inspector
      .getByRole('region', { name: 'Role execution' })
      .locator('table')
      .filter({ hasText: 'Person session' })
      .getByRole('row')
      .filter({ hasText: 'Mara' });
    await expect(sessionRow).toContainText('running', { timeout: 20_000 });
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    const character = page.getByRole('button', { name: /Mara.*Person session.*session open/i });
    await expect(character).toBeVisible({ timeout: 20_000 });
    await character.click();
    await expect(page.getByRole('region', { name: 'pair' })).toBeVisible();
    await expect(page).toHaveURL(new RegExp(`swarm=${runId}`));

    // 5. Stop the run: the PersonSession closes with it.
    await inspector.getByRole('button', { name: 'Stop' }).click();
    const stopDialog = page.getByRole('dialog', { name: 'Stop this swarm run?' });
    await stopDialog.getByRole('button', { name: 'Stop run' }).click();
    await expect(inspector.getByText('cancelled', { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(sessionRow).toContainText('stopped', { timeout: 20_000 });

    // 6. Recover/continue: from Mara's durable history, Open run returns
    // to this exact run's inspector — no CLI, no run-id hunting.
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.getByRole('button', { name: 'Mara implementer Offline' }).click();
    await expect(page.getByText(/Swarm implementer · run/)).toBeVisible();
    await page.getByRole('button', { name: 'Open run' }).click();
    await expect(page.getByRole('region', { name: 'pair' })).toBeVisible({ timeout: 20_000 });
    await expect(page).toHaveURL(new RegExp(`swarm=${runId}`));
  } finally {
    if (runId) {
      try {
        execFileSync('tmux', ['-L', `agent-toolkit-swarm-${runId}`, 'kill-server'], { stdio: 'pipe' });
      } catch {
        // Already gone with the run stop; nothing to clean.
      }
    }
    await desktop.close();
  }
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
