import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';
import { goTo } from './navigation';

const LIVE_CODEX_APPROVAL = process.env['ATK_LIVE_CODEX_APPROVAL_ACCEPTANCE'] === '1';

test.skip(
  !LIVE_CODEX_APPROVAL || !process.env['CODEX_HOME'],
  'Set ATK_LIVE_CODEX_APPROVAL_ACCEPTANCE=1 and CODEX_HOME to an authenticated Codex profile.',
);

test('packaged Focus approves a real Codex write in an isolated repository', async () => {
  test.setTimeout(240_000);
  const desktop = await openDesktop();
  const repository = path.join(desktop.home, 'code', 'codex-live-approval');
  const output = path.join(desktop.home, 'code', 'codex-live-approval-result.txt');
  const contents = 'Codex approval was granted once.\n';

  try {
    fs.mkdirSync(repository, { recursive: true });
    execFileSync('git', ['init', '--quiet', repository]);
    execFileSync(
      'git',
      [
        '-C',
        repository,
        '-c',
        'user.name=Agent Toolkit Acceptance',
        '-c',
        'user.email=acceptance@example.invalid',
        'commit',
        '--allow-empty',
        '-m',
        'Initial disposable repository',
      ],
      { stdio: 'pipe' },
    );

    const { app, page } = desktop;
    await waitForBackend(page);
    await goTo(page, 'Projects');
    await app.evaluate(({ dialog }, selected) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [selected] });
    }, repository);
    await page.getByRole('button', { name: 'Link a repository' }).click();
    await expect(page.getByRole('button', { name: /^codex-live-approval\s/ })).toBeVisible();

    await goTo(page, 'Focus');
    await page.getByLabel('Project', { exact: true }).selectOption('codex-live-approval');
    await page.getByRole('radio', { name: /^Codex\b/ }).check();
    await page.getByLabel('Permissions', { exact: true }).selectOption('ask');
    await page
      .getByRole('textbox', { name: 'Task' })
      .fill(
        `The selected project is read-only under this permission policy. Use a shell command to create ${output} with exactly this content: ${JSON.stringify(contents)}. It is outside the project but inside the disposable test HOME. Request the normal one-time command approval and wait for it. Do not write anywhere else. Then confirm the filename.`,
      );
    await page.getByRole('button', { name: 'Start session' }).click();

    const log = page.getByRole('log', { name: 'Conversation' });
    const approval = page.getByRole('alertdialog', { name: 'Approval needed' });
    await expect(approval).toBeVisible({ timeout: 90_000 });
    await expect(approval).toContainText('Codex wants to run a command');
    await expect(approval.getByRole('button', { name: 'Allow once' })).toBeEnabled();
    await approval.getByRole('button', { name: 'Allow once' }).click();

    await expect.poll(() => fs.existsSync(output), { timeout: 90_000, intervals: [250, 500, 1000] }).toBe(true);
    expect(fs.readFileSync(output, 'utf8')).toBe(contents);
    await expect(log.locator('[data-outcome="completed"]')).toBeVisible({ timeout: 90_000 });
    expect(execFileSync('git', ['-C', repository, 'status', '--porcelain'], { encoding: 'utf8' })).toBe('');
  } finally {
    await desktop.close();
  }
});
