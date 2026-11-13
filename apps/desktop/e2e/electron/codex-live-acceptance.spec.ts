import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';
import { goTo } from './navigation';

const LIVE_CODEX = process.env['ATK_LIVE_CODEX_ACCEPTANCE'] === '1';

test.skip(
  !LIVE_CODEX,
  'Set ATK_LIVE_CODEX_ACCEPTANCE=1 with CODEX_HOME pointing to an authenticated disposable-test account.',
);

test('packaged Desktop completes a real Codex task, stops safely, and reports provider resume limits', async () => {
  test.setTimeout(12 * 60_000);
  let desktop: Desktop | null = await openDesktop({ preserveRootOnClose: true });
  const profileRoot = desktop.root;
  const repo = path.join(desktop.home, 'code', 'codex-live-acceptance');
  const output = path.join(repo, 'live-result.txt');
  const exactLine = 'Codex real-provider acceptance succeeded.';
  const task = `Create live-result.txt in this repository with exactly this one line: ${exactLine}\nDo not run shell commands or edit any other file. Then briefly confirm the filename.`;

  try {
    fs.mkdirSync(repo, { recursive: true });
    execFileSync('git', ['init', '--quiet', repo]);
    execFileSync(
      'git',
      [
        '-C',
        repo,
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

    let { app, page } = desktop;
    await waitForBackend(page);
    const pickRepository = (folder: string) =>
      app.evaluate(({ dialog }, selected) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [selected] });
      }, folder);

    await goTo(page, 'Projects');
    await pickRepository(repo);
    await page.getByRole('button', { name: 'Link a repository' }).click();
    await expect(page.getByRole('button', { name: /^codex-live-acceptance\s/ })).toBeVisible();
    expect(fs.realpathSync(path.join(desktop.workspace, 'projects', 'codex-live-acceptance'))).toBe(
      fs.realpathSync(repo),
    );

    await goTo(page, 'Focus');
    await page.getByLabel('Project', { exact: true }).selectOption('codex-live-acceptance');
    const codex = page.getByRole('radio', { name: /^Codex\b/ });
    await expect(codex).toBeEnabled();
    await codex.check();
    await page.getByLabel('Permissions', { exact: true }).selectOption('accept-edits');
    await page.getByRole('textbox', { name: 'Task' }).fill(task);
    await expect(page.getByRole('button', { name: 'Start session' })).toBeEnabled();
    await page.getByRole('button', { name: 'Start session' }).click();

    const log = page.getByRole('log', { name: 'Conversation' });
    await expect(log).toContainText(task);
    await expect.poll(() => fs.existsSync(output), { timeout: 240_000, intervals: [500, 1000, 2000] }).toBe(true);
    await expect.poll(() => fs.readFileSync(output, 'utf8').trim(), { timeout: 10_000 }).toBe(exactLine);
    await expect(log.locator('[data-outcome="completed"]')).toBeVisible({ timeout: 120_000 });

    // Review the actual provider-produced working-tree diff in Desktop.
    await goTo(page, 'Projects');
    // The Desktop diff endpoint currently renders Git's tracked/staged diff;
    // stage this new file to inspect its real patch through that supported path.
    await page.getByRole('list', { name: 'Untracked files' }).getByRole('button', { name: 'Stage' }).click();
    await page
      .getByRole('list', { name: 'Staged files' })
      .getByRole('button', { name: /live-result\.txt/ })
      .click();
    await expect(page.locator('[aria-label="Diff for live-result.txt"]')).toContainText(exactLine);
    await page.getByRole('button', { name: 'Terminal', exact: true }).click();
    const terminal = page.getByLabel('Terminal for shell');
    await expect(terminal).toBeVisible();
    await terminal.click();
    await page.keyboard.type('pwd; echo atk-live-terminal');
    await page.keyboard.press('Enter');
    await expect(terminal.locator('.xterm-rows')).toContainText(repo, { timeout: 10_000 });
    await expect(terminal.locator('.xterm-rows')).toContainText('atk-live-terminal', { timeout: 10_000 });

    // A second, read-only turn is deliberately cancelled while the real
    // provider is working. It must produce an interrupted result, not a fake
    // completion or a filesystem change.
    await goTo(page, 'Focus');
    await expect(page).toHaveURL(/#\/focus/);
    const sessions = page.getByRole('navigation', { name: 'Sessions' });
    const threadButton = sessions.getByRole('button').filter({ hasText: /live-result\.txt/ });
    await expect(threadButton).toBeVisible();
    await threadButton.click();
    const composer = page.getByRole('textbox', { name: 'Message' });
    await expect(composer).toBeEnabled();
    await composer.fill(
      "Use the terminal to run python3 -c 'import time; time.sleep(45)' and do not edit any files. After it exits, briefly confirm. I will stop this turn while it is waiting.",
    );
    await expect(page.getByRole('button', { name: 'Send', exact: true })).toBeEnabled();
    await page.getByRole('button', { name: 'Send', exact: true }).click();
    const stop = page.getByRole('button', { name: 'Stop' });
    await expect(stop).toBeVisible({ timeout: 30_000 });
    await stop.click();
    await expect(log.locator('[data-outcome="interrupted"]')).toBeVisible({ timeout: 30_000 });
    expect(fs.readFileSync(output, 'utf8').trim()).toBe(exactLine);

    // Close and relaunch against the same scratch HOME, userData, workspace,
    // and provider credentials. The provider CLI itself remains the installed
    // authenticated binary; no credential files are copied into the fixture.
    await desktop.close();
    desktop = null;
    desktop = await openDesktop({
      root: profileRoot,
      initWorkspace: false,
      skipOnboarding: false,
      preserveRootOnClose: true,
    });
    ({ app, page } = desktop);
    await waitForBackend(page);
    await goTo(page, 'Focus');
    const reopenedSessions = page.getByRole('navigation', { name: 'Sessions' });
    const reopenedThread = reopenedSessions.getByRole('button').filter({ hasText: /live-result\.txt/ });
    await expect(reopenedThread).toBeVisible({ timeout: 30_000 });
    await reopenedThread.click();
    const reopenedLog = page.getByRole('log', { name: 'Conversation' });
    await expect(reopenedLog).toContainText(task);
    await expect(reopenedLog.locator('[data-outcome="interrupted"]')).toBeVisible();
    expect(fs.readFileSync(output, 'utf8').trim()).toBe(exactLine);

    const resumeComposer = page.getByRole('textbox', { name: 'Message' });
    await resumeComposer.fill(
      'Use a read-only tool to read live-result.txt, then reply with its exact contents. Do not edit files or run commands.',
    );
    await page.getByRole('button', { name: 'Send', exact: true }).click();
    const followupTurn = reopenedLog.getByRole('region', { name: 'Turn 3' });
    await expect
      .poll(
        async () => {
          const text = await followupTurn.innerText();
          return text.includes(exactLine) || text.includes('The saved provider conversation could not be resumed');
        },
        { timeout: 120_000 },
      )
      .toBe(true);
    const followup = await followupTurn.innerText();
    if (followup.includes(exactLine)) {
      await expect(followupTurn.locator('[data-outcome="completed"]')).toBeVisible();
    } else {
      expect(followup).toContain('The saved provider conversation could not be resumed');
    }
    await expect(reopenedLog.getByRole('region', { name: 'Turn 1' })).toContainText(exactLine);

    // World remains an optional semantic layer, and opening the project house
    // keeps a canonical route back to the same project and session.
    await goTo(page, 'World');
    await page.getByRole('button', { name: /codex-live-acceptance · Project/ }).click();
    await expect(page.getByRole('application', { name: 'Interior of codex-live-acceptance' })).toBeVisible();
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Focus' }).click();
    const returnedThread = page
      .getByRole('navigation', { name: 'Sessions' })
      .getByRole('button')
      .filter({ hasText: /live-result\.txt/ });
    await expect(returnedThread).toBeVisible();
    await returnedThread.click();
    await expect(page.locator('header p').filter({ hasText: 'codex-live-acceptance' })).toBeVisible();
  } finally {
    await desktop?.close();
    fs.rmSync(profileRoot, { recursive: true, force: true });
  }
});
