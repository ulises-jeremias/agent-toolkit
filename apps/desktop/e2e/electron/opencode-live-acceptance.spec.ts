import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';
import { goTo } from './navigation';

const LIVE_OPENCODE = process.env['ATK_LIVE_OPENCODE_ACCEPTANCE'] === '1';
const LIVE_DATABASE = process.env['ATK_LIVE_OPENCODE_DB'];
const EXACT_LINE = 'OpenCode Focus packaged acceptance succeeded.';

function persistedProviderSessionId(workspace: string): string | null {
  const root = path.join(workspace, '.agent-toolkit', 'focus', 'threads');
  if (!fs.existsSync(root)) return null;
  for (const threadId of fs.readdirSync(root)) {
    try {
      const metadata = JSON.parse(fs.readFileSync(path.join(root, threadId, 'thread.json'), 'utf8')) as {
        providerSessionId?: unknown;
      };
      if (typeof metadata.providerSessionId === 'string' && /^ses_[A-Za-z0-9_-]+$/.test(metadata.providerSessionId))
        return metadata.providerSessionId;
    } catch {
      // The journal can appear before its atomic metadata write completes.
    }
  }
  return null;
}

function removeTemporaryOpenCodeProjects(databasePath: string, profileRoot: string): void {
  const database = new DatabaseSync(databasePath);
  try {
    database.exec('BEGIN IMMEDIATE');
    const roots = new Set([profileRoot, fs.realpathSync.native(profileRoot)]);
    const projects = new Map<string, string>();
    for (const root of roots) {
      const rows = database
        .prepare('SELECT id, worktree FROM project WHERE worktree LIKE ?')
        .all(`${root}${path.sep}%`) as { id: string; worktree: string }[];
      for (const row of rows) projects.set(row.id, row.worktree);
    }
    const sessions = database.prepare(
      'SELECT (SELECT COUNT(*) FROM session WHERE project_id = ?) + (SELECT COUNT(*) FROM session_v2 WHERE project_id = ?) AS count',
    );
    const remove = database.prepare('DELETE FROM project WHERE id = ?');
    for (const id of projects.keys()) {
      const result = sessions.get(id, id) as { count: number };
      if (result.count > 0) throw new Error('Refusing to remove a temporary OpenCode project that still has sessions.');
      remove.run(id);
    }
    database.exec('COMMIT');
  } catch (error) {
    database.exec('ROLLBACK');
    throw error;
  } finally {
    database.close();
  }
}

test.skip(
  !LIVE_OPENCODE,
  'Set ATK_LIVE_OPENCODE_ACCEPTANCE=1 and ATK_LIVE_OPENCODE_DB to an authenticated OpenCode database path.',
);

test('packaged Focus runs, interrupts, and reloads a real OpenCode ACP session', async () => {
  test.setTimeout(12 * 60_000);
  expect(LIVE_DATABASE, 'Set ATK_LIVE_OPENCODE_DB to the authenticated OpenCode DB path.').toBeTruthy();
  const previousDatabase = process.env['OPENCODE_DB'];
  process.env['OPENCODE_DB'] = LIVE_DATABASE;
  let desktop: Desktop | null = await openDesktop({ preserveRootOnClose: true });
  const profileRoot = desktop.root;
  const repository = path.join(desktop.home, 'code', 'opencode-live-acceptance');
  const output = path.join(repository, 'live-result.txt');
  const task = `Create live-result.txt in this repository with exactly one line: ${EXACT_LINE}\nDo not run shell commands or edit another file. Briefly confirm when finished.`;
  let providerSessionId: string | null = null;

  try {
    fs.mkdirSync(repository, { recursive: true });
    fs.writeFileSync(path.join(desktop.home, '.zshrc'), '# Isolated acceptance shell.\n');
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

    let { app, page } = desktop;
    await waitForBackend(page);
    await app.evaluate(({ dialog }, selected) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [selected] });
    }, repository);
    await goTo(page, 'Projects');
    await page.getByRole('button', { name: 'Link a repository' }).click();
    await expect(page.getByRole('button', { name: /^opencode-live-acceptance\s/ })).toBeVisible();

    await goTo(page, 'Focus');
    await page.getByLabel('Project', { exact: true }).selectOption('opencode-live-acceptance');
    const provider = page.getByRole('radio', { name: /^OpenCode\b/ });
    await expect(provider).toBeEnabled({ timeout: 30_000 });
    await provider.check();
    const model = page.getByLabel('Model', { exact: true });
    await expect(model.locator('option').filter({ hasText: 'github-copilot/gpt-5.6-luna' })).toHaveCount(1);
    await model.selectOption('github-copilot/gpt-5.6-luna');
    await expect(page.getByText(/OpenCode applies its own project and global policies/)).toBeVisible();
    await page.getByRole('textbox', { name: 'Task' }).fill(task);
    await page.getByRole('button', { name: 'Start session' }).click();

    const log = page.getByRole('log', { name: 'Conversation' });
    await expect(log).toContainText(task);
    let approvedWrite = false;
    await expect
      .poll(
        async () => {
          providerSessionId ??= persistedProviderSessionId(desktop!.workspace);
          const approval = page.getByRole('alertdialog', { name: 'Approval needed' });
          if (!approvedWrite && (await approval.isVisible().catch(() => false))) {
            approvedWrite = true;
            await approval.getByRole('button', { name: 'Allow once' }).click();
          }
          return fs.existsSync(output);
        },
        { timeout: 240_000, intervals: [500, 1000, 2000] },
      )
      .toBe(true);
    expect(fs.readFileSync(output, 'utf8').trim()).toBe(EXACT_LINE);
    await expect(log.locator('[data-outcome="completed"]')).toBeVisible({ timeout: 120_000 });
    providerSessionId ??= persistedProviderSessionId(desktop.workspace);
    expect(providerSessionId).toMatch(/^ses_[A-Za-z0-9_-]+$/);

    await goTo(page, 'Projects');
    await page
      .getByRole('list', { name: 'Untracked files' })
      .getByRole('button', { name: /live-result\.txt/ })
      .click();
    await page.getByRole('button', { name: 'Stage', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Staged (1)' })).toBeVisible();
    await expect(page.getByLabel('Diff for live-result.txt')).toContainText(EXACT_LINE);
    await page.getByRole('button', { name: 'Terminal', exact: true }).click();
    const terminal = page.getByLabel('Terminal for shell');
    await terminal.click();
    await page.keyboard.type('pwd; echo atk-opencode-terminal');
    await page.keyboard.press('Enter');
    await expect(terminal.locator('.xterm-rows')).toContainText(repository, { timeout: 10_000 });
    await expect(terminal.locator('.xterm-rows')).toContainText('atk-opencode-terminal', { timeout: 10_000 });

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
    const thread = page
      .getByRole('navigation', { name: 'Sessions' })
      .getByRole('button')
      .filter({ hasText: /live-result\.txt/ });
    await expect(thread).toBeVisible();
    await thread.click();
    const resumedLog = page.getByRole('log', { name: 'Conversation' });
    await expect(resumedLog).toContainText(task);
    await expect(resumedLog.locator('[data-outcome="completed"]')).toBeVisible();
    const composer = page.getByRole('textbox', { name: 'Message', exact: true });
    await composer.fill('Read live-result.txt and reply with its exact contents. Do not edit files.');
    await page.getByRole('button', { name: 'Send', exact: true }).click();
    const followupTurn = resumedLog.getByRole('region', { name: 'Turn 2' });
    await expect(followupTurn.locator('[data-outcome="completed"]')).toBeVisible({ timeout: 120_000 });
    await expect(followupTurn).toContainText(EXACT_LINE);

    await composer.fill(
      "Run `python3 -c 'import time; time.sleep(45)'` in the terminal and do not edit files. I will interrupt you while it waits.",
    );
    await page.getByRole('button', { name: 'Send', exact: true }).click();
    let approvedWait = false;
    await expect
      .poll(
        async () => {
          const approval = page.getByRole('alertdialog', { name: 'Approval needed' });
          if (!approvedWait && (await approval.isVisible().catch(() => false))) {
            approvedWait = true;
            await approval.getByRole('button', { name: 'Allow once' }).click();
            return 'approved';
          }
          if (
            await page
              .getByRole('button', { name: 'Stop' })
              .isVisible()
              .catch(() => false)
          )
            return 'running';
          return null;
        },
        { timeout: 45_000 },
      )
      .not.toBeNull();
    await page.getByRole('button', { name: 'Stop' }).click();
    await expect(resumedLog.locator('[data-outcome="interrupted"]')).toBeVisible({ timeout: 30_000 });

    await goTo(page, 'World');
    await page.getByRole('button', { name: /opencode-live-acceptance · Project/ }).click();
    await expect(page.getByRole('application', { name: 'Interior of opencode-live-acceptance' })).toBeVisible();
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Focus' }).click();
    await expect(
      page
        .getByRole('navigation', { name: 'Sessions' })
        .getByRole('button')
        .filter({ hasText: /live-result\.txt/ }),
    ).toBeVisible();
  } finally {
    try {
      await desktop?.close();
    } finally {
      try {
        if (providerSessionId) {
          execFileSync('opencode', ['session', 'delete', providerSessionId, '--standalone'], {
            env: { ...process.env, OPENCODE_DB: LIVE_DATABASE },
            input: 'y\n',
            stdio: ['pipe', 'ignore', 'ignore'],
            timeout: 30_000,
          });
        }
      } finally {
        try {
          removeTemporaryOpenCodeProjects(LIVE_DATABASE!, profileRoot);
        } finally {
          fs.rmSync(profileRoot, { recursive: true, force: true });
          if (previousDatabase === undefined) delete process.env['OPENCODE_DB'];
          else process.env['OPENCODE_DB'] = previousDatabase;
        }
      }
    }
  }
});
