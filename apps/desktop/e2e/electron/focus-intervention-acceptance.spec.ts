import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';
import { goTo } from './navigation';

const fakeCodexBin = path.resolve(__dirname, '../../electron/focus/testing/fake-bin');

test('packaged Focus presents approvals and private questions, and reports provider failures', async () => {
  test.setTimeout(180_000);
  const desktop = await openDesktop({ providerBinDir: fakeCodexBin });
  const repository = path.join(desktop.home, 'code', 'focus-intervention-acceptance');

  try {
    fs.mkdirSync(repository, { recursive: true });
    execFileSync('git', ['init', '--quiet', repository]);
    execFileSync(
      'git',
      [
        '-C',
        repository,
        '-c',
        'user.name=Acceptance',
        '-c',
        'user.email=acceptance@example.invalid',
        'commit',
        '--allow-empty',
        '-m',
        'Disposable acceptance repository',
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
    await expect(page.getByRole('button', { name: /^focus-intervention-acceptance\s/ })).toBeVisible();

    const startTask = async (task: string) => {
      await goTo(page, 'Focus');
      const taskField = page.getByRole('textbox', { name: 'Task' });
      await expect(taskField).toBeVisible();
      await page.getByRole('radio', { name: /^Codex\b/ }).check();
      await taskField.fill(task);
      await page.getByRole('button', { name: 'Start session' }).click();
      return page.getByRole('log', { name: 'Conversation' });
    };

    const approvalLog = await startTask('approval-allow');
    const approval = await page.getByRole('alertdialog', { name: 'Approval needed' });
    await expect(approval).toContainText('Codex wants to run a command');
    await expect(approval).toContainText('yes');
    await approval.getByRole('button', { name: 'Allow once' }).click();
    await expect(approvalLog).toContainText('accept');
    await expect(approvalLog.locator('[data-outcome="completed"]')).toBeVisible();

    const deniedLog = await startTask('approval-deny');
    const deniedApproval = await page.getByRole('alertdialog', { name: 'Approval needed' });
    await expect(deniedApproval).toContainText('Codex wants to run a command');
    await deniedApproval.getByRole('button', { name: 'Don’t allow' }).click();
    await expect(deniedLog).toContainText('decline');
    await expect(deniedLog.locator('[data-outcome="completed"]')).toBeVisible();

    const questionLog = await startTask('question');
    const question = await page.getByRole('form', { name: 'Codex asks a question' });
    await expect(question).toContainText('Enter the private value');
    const privateAnswer = 'private token';
    await page.getByLabel('Private answer').fill(privateAnswer);
    await question.getByRole('button', { name: 'Continue' }).click();
    await expect(questionLog).toContainText('received');
    await expect(questionLog.locator('[data-outcome="completed"]')).toBeVisible();
    await expect(questionLog).not.toContainText(privateAnswer);

    const failedLog = await startTask('failure');
    await expect(failedLog.getByRole('alert')).toContainText('This turn failed.');
    await expect(failedLog.getByRole('alert')).toContainText('Codex reported an error.');
  } finally {
    await desktop.close();
  }
});
