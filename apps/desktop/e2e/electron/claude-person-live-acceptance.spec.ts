import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';
import { goTo } from './navigation';

const LIVE_CLAUDE = process.env['ATK_LIVE_CLAUDE_ACCEPTANCE'] === '1';

async function stopDetachedPtyHost(root: string): Promise<void> {
  try {
    const registry = JSON.parse(fs.readFileSync(path.join(root, 'pty-runtime', 'pty-registry.json'), 'utf8')) as {
      pid?: number;
    };
    if (typeof registry.pid !== 'number') return;
    try {
      process.kill(registry.pid, 'SIGTERM');
    } catch {
      return;
    }
    const deadline = Date.now() + 5_000;
    while (Date.now() < deadline) {
      try {
        process.kill(registry.pid, 0);
      } catch {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    throw new Error(`Test-owned PTY host ${registry.pid} did not stop.`);
  } catch (error) {
    if (error instanceof Error && error.message.includes('did not stop')) throw error;
  }
}

test.skip(!LIVE_CLAUDE, 'Set ATK_LIVE_CLAUDE_ACCEPTANCE=1 with Claude Code authenticated outside the scratch profile.');

test('packaged Desktop starts a Person with Claude, reviews changes, stops safely, and recovers history', async () => {
  test.setTimeout(12 * 60_000);
  let desktop: Desktop | null = await openDesktop({
    preserveRootOnClose: true,
    preservePtyHostOnClose: true,
  });
  const profileRoot = desktop.root;
  const repo = path.join(desktop.home, 'code', 'person-live-acceptance');
  const output = path.join(repo, 'person-live-result.txt');
  const exactLine = 'Person-linked Claude acceptance completed in Focus.';
  const task = `Create person-live-result.txt in this repository with exactly this line: ${exactLine}\nDo not edit any other file.`;

  try {
    fs.mkdirSync(repo, { recursive: true });
    // A clean profile makes interactive zsh offer its first-run setup menu.
    // Keep the shell inside the disposable profile and make it non-interactive.
    fs.writeFileSync(path.join(desktop.home, '.zshrc'), '# Isolated acceptance shell.\n');
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
    await expect(page.getByRole('button', { name: /^person-live-acceptance\s/ })).toBeVisible();
    expect(fs.realpathSync(path.join(desktop.workspace, 'projects', 'person-live-acceptance'))).toBe(
      fs.realpathSync(repo),
    );

    await goTo(page, 'People');
    await page.getByRole('button', { name: 'Create Person' }).click();
    const create = page.getByRole('dialog', { name: 'Create Person' });
    await create.getByRole('textbox', { name: 'Name' }).fill('Live Implementer');
    await create.getByRole('textbox', { name: 'ID' }).fill('live-implementer');
    await create.getByRole('textbox', { name: 'Role' }).fill('implementer');
    await create.getByRole('textbox', { name: 'Goal' }).fill('Complete the requested change and verify it.');
    await create.getByRole('button', { name: 'Create Person' }).click();
    await expect(create).toBeHidden();
    await page.getByRole('button', { name: /Live Implementer.*implementer.*Offline/ }).click();
    await page.keyboard.press(process.platform === 'darwin' ? 'Meta+K' : 'Control+K');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByRole('textbox', { name: 'Filter commands' }).fill('Start Live Implementer');
    await palette.getByRole('option', { name: /Start Live Implementer/ }).click();

    const start = page.getByRole('dialog', { name: 'Start Live Implementer in Focus' });
    await expect(start.getByRole('combobox', { name: 'Project and working folder' })).toHaveValue(
      'person-live-acceptance',
    );
    const provider = start.getByRole('combobox', { name: 'Provider' });
    await expect(provider.locator('option[value="claude"]')).toBeEnabled({ timeout: 30_000 });
    await provider.selectOption('claude');
    const acknowledgeLimits = start.getByRole('checkbox');
    if (await acknowledgeLimits.count()) await acknowledgeLimits.check();
    await start.getByRole('textbox', { name: 'Task for this session' }).fill(task);
    await start.getByRole('button', { name: 'Start in Focus' }).click();
    await expect(start).toBeHidden();

    let log = page.getByRole('log', { name: 'Conversation' });
    await expect(log).toContainText(task);
    const writeApproval = page.getByRole('alertdialog', { name: 'Approval needed' });
    await expect(writeApproval).toBeVisible({ timeout: 120_000 });
    await expect(writeApproval).toContainText('person-live-result.txt');
    await writeApproval.getByRole('button', { name: 'Allow once' }).click();
    await expect.poll(() => fs.existsSync(output), { timeout: 120_000, intervals: [500, 1000, 2000] }).toBe(true);
    await expect.poll(() => fs.readFileSync(output, 'utf8').trim(), { timeout: 10_000 }).toBe(exactLine);
    await expect(log.locator('[data-outcome="completed"]')).toBeVisible({ timeout: 120_000 });
    expect(
      execFileSync('git', ['-C', repo, 'status', '--short', '--untracked-files=all'], { encoding: 'utf8' }),
    ).toContain('?? person-live-result.txt');

    // Re-enter Focus after the provider turn; this also makes the review surface
    // perform a fresh read from the real backend before inspecting the file.
    await goTo(page, 'Projects');
    await goTo(page, 'Focus');
    const finishedThread = page
      .getByRole('navigation', { name: 'Sessions' })
      .getByRole('button')
      .filter({ hasText: /person-live-result\.txt/ });
    await expect(finishedThread).toBeVisible();
    await finishedThread.click();
    await setViewport(app, 1440, 900);
    const changes = page.getByRole('region', { name: 'Changes', exact: true });
    await expect(changes).toBeVisible();
    await expect(changes).toContainText('person-live-result.txt');
    await changes.getByRole('button', { name: /person-live-result\.txt/ }).click();
    await expect(changes.getByLabel('Diff for person-live-result.txt')).toContainText(exactLine);

    await page.getByRole('button', { name: 'Terminal', exact: true }).click();
    const terminal = page.getByLabel('Terminal for shell');
    await expect(terminal).toBeVisible();
    await terminal.click();
    await page.keyboard.type("pwd; printf 'PERSON_LIVE_TERMINAL_OK\\n'");
    await page.keyboard.press('Enter');
    await expect(terminal.locator('.xterm-rows')).toContainText(repo, { timeout: 15_000 });
    await expect(terminal.locator('.xterm-rows')).toContainText('PERSON_LIVE_TERMINAL_OK', { timeout: 15_000 });
    const terminalId = await page.getByRole('tab', { name: /shell/ }).getAttribute('data-session-id');
    expect(terminalId).toBeTruthy();

    // Interrupt a read-only response while it is actively streaming. Claude's
    // shell tool backgrounds long sleeps, so a sleep-based cancellation would
    // leave a detached command instead of exercising the Focus stop control.
    await goTo(page, 'Focus');
    const sessions = page.getByRole('navigation', { name: 'Sessions' });
    const thread = sessions.getByRole('button').filter({ hasText: /person-live-result\.txt/ });
    await expect(thread).toBeVisible();
    await thread.click();
    const composer = page.getByRole('textbox', { name: 'Message', exact: true });
    await expect(composer).toBeEnabled();
    const cancelTask =
      'Read README.md and package.json, then explain the available package scripts in detail. Do not run commands or edit files. I will stop this response while it is streaming.';
    await composer.fill(cancelTask);
    await page.getByRole('button', { name: 'Send', exact: true }).click();
    await expect(page.getByRole('button', { name: 'Stop' })).toBeVisible({ timeout: 30_000 });
    await page.getByRole('button', { name: 'Stop' }).click();
    await expect(log.locator('[data-outcome="interrupted"]')).toBeVisible({ timeout: 30_000 });
    expect(fs.readFileSync(output, 'utf8').trim()).toBe(exactLine);

    // Reuse the same scratch profile, userData, workspace and provider config.
    await desktop.close();
    desktop = null;
    desktop = await openDesktop({
      root: profileRoot,
      initWorkspace: false,
      skipOnboarding: true,
      preserveRootOnClose: true,
      preservePtyHostOnClose: true,
    });
    ({ app, page } = desktop);
    await waitForBackend(page);
    await goTo(page, 'Focus');
    const recoveredThread = page
      .getByRole('navigation', { name: 'Sessions' })
      .getByRole('button')
      .filter({ hasText: /person-live-result\.txt/ });
    await expect(recoveredThread).toBeVisible({ timeout: 30_000 });
    await recoveredThread.click();
    log = page.getByRole('log', { name: 'Conversation' });
    await expect(log).toContainText(task);
    await expect(log).toContainText(cancelTask);
    await expect(log.getByRole('region', { name: 'Turn 1' }).locator('[data-outcome="completed"]')).toBeVisible();
    await expect(log.getByRole('region', { name: 'Turn 2' }).locator('[data-outcome="interrupted"]')).toBeVisible();
    expect(fs.readFileSync(output, 'utf8').trim()).toBe(exactLine);

    await goTo(page, 'Terminal');
    const terminalRow = page.locator(`tr[data-session-id="${terminalId}"]`);
    await expect(terminalRow).toBeVisible();
    await terminalRow.getByRole('button', { name: 'shell', exact: true }).click();
    const recoveredTerminal = page.getByLabel('Terminal for shell');
    await expect(recoveredTerminal.locator('.xterm-rows')).toContainText('PERSON_LIVE_TERMINAL_OK', {
      timeout: 15_000,
    });
    await recoveredTerminal.click();
    await page.keyboard.type("printf 'PERSON_LIVE_TERMINAL_RESUMED\\n'");
    await page.keyboard.press('Enter');
    await expect(recoveredTerminal.locator('.xterm-rows')).toContainText('PERSON_LIVE_TERMINAL_RESUMED', {
      timeout: 15_000,
    });

    await goTo(page, 'World');
    await page.getByRole('button', { name: /^person-live-acceptance:/ }).click();
    await expect(page.getByRole('region', { name: 'Selected place' })).toContainText('person-live-acceptance');
    await goTo(page, 'Focus');
    const returnedThread = page
      .getByRole('navigation', { name: 'Sessions' })
      .getByRole('button')
      .filter({ hasText: /person-live-result\.txt/ });
    await expect(returnedThread).toBeVisible();
    await returnedThread.click();
    await expect(page.locator('header p').filter({ hasText: 'person-live-acceptance' })).toBeVisible();
    await expect(page.getByRole('log', { name: 'Conversation' })).toContainText(exactLine);
  } finally {
    await desktop?.close();
    await stopDetachedPtyHost(profileRoot);
    fs.rmSync(profileRoot, { recursive: true, force: true });
  }
});
