import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';

/**
 * Swarm v1 is retired for new Toolkit runs. Existing run records remain
 * inspectable, but neither Operations nor the command palette may imply that
 * Toolkit still owns the coding-agent execution engine.
 */
test('Toolkit Desktop keeps historical Swarm inspection and directs new work to Veasel Code', async () => {
  const desktop: Desktop = await openDesktop();
  const { page, workspace } = desktop;
  try {
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();

    const runs = page.getByRole('region', { name: 'Swarms' });
    await expect(runs).toBeVisible();
    await expect(runs).toContainText(
      'Existing Toolkit run records remain available here for inspection and deliberate recovery actions.',
    );
    await expect(page.getByRole('button', { name: 'Start swarm' })).toHaveCount(0);
    await expect(page.getByRole('dialog', { name: 'Start a swarm' })).toHaveCount(0);

    await page.keyboard.press('Control+k');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByLabel('Filter commands').fill('Start a swarm');
    await expect(palette.getByRole('option')).toHaveCount(0);
    await page.keyboard.press('Escape');

    const before = path.join(workspace, '.agent-toolkit', 'swarm', 'runs');
    const sentinel = path.join(before, 'existing-run', 'state.json');
    fs.mkdirSync(path.dirname(sentinel), { recursive: true });
    fs.writeFileSync(sentinel, '{"run_id":"existing-run","state":"preserved"}\n');
    const existing = fs.readdirSync(before).sort();
    const existingState = fs.readFileSync(sentinel);
    let failure = '';
    try {
      execFileSync(desktop.backendBin, ['swarm', 'start', '--recipe', 'pair', '--workspace', workspace, '--dry-run'], {
        env: {
          ...process.env,
          HOME: desktop.home,
          XDG_CONFIG_HOME: path.join(desktop.home, '.config'),
          XDG_DATA_HOME: path.join(desktop.home, '.local', 'share'),
          AGENT_TOOLKIT_WORKSPACE: workspace,
        },
        encoding: 'utf8',
        stdio: 'pipe',
      });
    } catch (error) {
      const result = error as { stderr?: Buffer | string; stdout?: Buffer | string };
      failure = `${result.stderr?.toString() ?? ''}${result.stdout?.toString() ?? ''}`;
    }
    expect(failure).toContain('feature-frozen');
    expect(fs.readdirSync(before).sort()).toEqual(existing);
    expect(fs.readFileSync(sentinel)).toEqual(existingState);
  } finally {
    await desktop.close();
  }
});
