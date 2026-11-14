import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';
import { goTo } from './navigation';

const LIVE_CODEX_PLAN_QUESTION = process.env['ATK_LIVE_CODEX_PLAN_QUESTION'] === '1';

test.skip(
  !LIVE_CODEX_PLAN_QUESTION || !process.env['CODEX_HOME'],
  'Set ATK_LIVE_CODEX_PLAN_QUESTION=1 with CODEX_HOME pointing to an authenticated disposable-test account.',
);

test('packaged Focus handles a real blocking Codex plan question', async () => {
  test.setTimeout(180_000);
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    const repo = path.join(desktop.home, 'code', 'plan-question');
    fs.mkdirSync(repo, { recursive: true });
    execFileSync('git', ['init', '--quiet', repo]);
    await goTo(page, 'Projects');
    await desktop.app.evaluate(({ dialog }, selected) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [selected] });
    }, repo);
    await page.getByRole('button', { name: 'Link a repository' }).click();
    await goTo(page, 'Focus');
    await page.getByLabel('Project', { exact: true }).selectOption('plan-question');
    await page.getByRole('radio', { name: /^Codex\b/ }).check();
    await page.getByLabel('Permissions', { exact: true }).selectOption('plan');
    await page
      .getByRole('textbox', { name: 'Task' })
      .fill(
        'Before doing anything else, ask me a blocking question with exactly two choices using the user input question tool: “Which title should the file contain?” The choices are “Morning” and “Evening”. Wait for my answer. After I answer, propose a short plan without changing any files.',
      );
    await page.getByRole('button', { name: 'Start session' }).click();
    const log = page.getByRole('log', { name: 'Conversation' });
    const answer = page.getByRole('radio', { name: /Morning|Evening/ }).first();
    await expect(answer).toBeVisible({ timeout: 150_000 });
    await expect(answer).toBeFocused();
    await expect(log).toContainText('Which title should the file contain?');
    await answer.check();
    await page.getByRole('button', { name: 'Continue', exact: true }).click();
    await expect(log.getByRole('region', { name: 'Turn 1' }).locator('[data-outcome="completed"]')).toBeVisible({
      timeout: 90_000,
    });
  } finally {
    await desktop.close();
  }
});
