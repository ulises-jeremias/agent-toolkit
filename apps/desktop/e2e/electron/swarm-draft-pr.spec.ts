import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';

/**
 * The §19 "create / inspect PR" leg as one continuous GUI flow against a
 * REAL GitHub repository:
 *
 *   start a tmux swarm in the GUI -> the integrator branch gains a commit
 *   -> Create draft PR in the run inspector -> the inspector shows the
 *   live GitHub PR status -> Mark PR ready for review -> verified with
 *   `gh` outside the app -> stop the run.
 *
 * Opt-in only: set ATK_E2E_GH_PR_REPO=owner/name to a disposable GitHub
 * repository the local `gh` can push to. CI never sets it, so the spec
 * skips there instead of creating external state. The fixture commit
 * stands in for the integrator agent's git output (the skeleton runner
 * produces no code, exactly as in the other swarm specs); every product
 * step under test — branch push, draft PR creation, live status, mark
 * ready — is the real backend talking to real GitHub through the GUI.
 * The PR is closed and its branch deleted in cleanup; the sandbox repo
 * itself is left intact for the next run.
 */
test('swarm run to real draft PR to ready for review in one flow', async () => {
  const ghRepo = process.env['ATK_E2E_GH_PR_REPO'];
  test.skip(
    !ghRepo,
    'ATK_E2E_GH_PR_REPO not set; this spec creates a real PR in a disposable GitHub repo and stays opt-in',
  );
  test.setTimeout(8 * 60_000);

  // The Desktop runs under a scratch HOME, so hand its backend the
  // operator's gh credentials explicitly: GH_TOKEN for `gh`, and a
  // credential helper (written into the scratch HOME below) for `git push`.
  const ghToken = execFileSync('gh', ['auth', 'token'], { stdio: 'pipe' }).toString().trim();
  expect(ghToken).not.toBe('');
  process.env['GH_TOKEN'] = ghToken;

  const desktop: Desktop = await openDesktop();
  const { page, workspace, home } = desktop;
  let runId = '';
  let prUrl = '';
  try {
    await waitForBackend(page);
    fs.writeFileSync(path.join(home, '.gitconfig'), '[credential]\n\thelper = !gh auth git-credential\n');
    // Role shells spawn under this scratch HOME; an empty .zshrc keeps
    // zsh from parking autostarted roles at its new-user wizard.
    fs.writeFileSync(path.join(home, '.zshrc'), '# e2e scratch home\n');

    // Fixture only: the workspace is a real clone-in-place of the sandbox
    // repo (initial commit pushed before the app is driven), and the
    // project symlinks to it, as in the full-journey spec.
    initRepoWithRemote(workspace, ghRepo!);
    const link = path.join(workspace, 'projects', 'e2e-workspace');
    fs.mkdirSync(path.dirname(link), { recursive: true });
    if (!fs.existsSync(link)) fs.symlinkSync(workspace, link, 'dir');

    // Start real work: a tmux swarm with skeleton runners, reviewed in
    // the start dialog.
    const task = 'Carry the draft PR leg end to end';
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
    await page.getByRole('button', { name: 'Start swarm' }).click();
    const dialog = page.getByRole('dialog', { name: 'Start a swarm' });
    await dialog.getByLabel('Project').selectOption('e2e-workspace');
    await dialog.getByLabel('Task').fill(task);
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
    const inspector = page.getByRole('region', { name: 'pair' });
    await expect(inspector).toBeVisible();

    // Move work along the recipe exactly as real agents do: each role
    // issues its handoff from inside its own terminal (typed into the
    // tmux pane), which autostarts the next role and provisions its
    // worktree. The skeleton shells only need the commands typed.
    const socket = `agent-toolkit-swarm-${runId}`;
    const session = `swarm-${runId}`;
    const worktreeFor = (role: string) =>
      path.join(workspace, '.agent-toolkit', 'swarm', 'runs', runId, 'worktrees', role);
    await expect
      .poll(() => tmuxCapture(socket, session, 'implementer'), { timeout: 30_000 })
      .toContain('[skeleton:implementer] ready');
    tmuxType(
      socket,
      session,
      'implementer',
      `agent-toolkit swarm handoff create --type artifact --from implementer --to reviewer --artifact artifacts/task-contract.md --run-id ${runId}`,
    );
    await expect.poll(() => fs.existsSync(worktreeFor('reviewer')), { timeout: 60_000 }).toBe(true);
    await expect
      .poll(() => tmuxCapture(socket, session, 'reviewer'), { timeout: 30_000 })
      .toContain('[skeleton:reviewer] ready');
    tmuxType(
      socket,
      session,
      'reviewer',
      `agent-toolkit swarm handoff create --type artifact --from reviewer --to integrator --artifact artifacts/task-contract.md --run-id ${runId}`,
    );
    const integratorWorktree = worktreeFor('integrator');
    await waitForWorktree(integratorWorktree, socket, session, 'reviewer', page);

    // The integrator agent's output, stood in for by a fixture commit on
    // the run's real integrator worktree/branch (skeleton makes none).
    fs.writeFileSync(
      path.join(integratorWorktree, 'PR_LEG.md'),
      '# Draft PR leg\n\nReal change carried by the swarm integrator branch.\n',
    );
    git(integratorWorktree, ['add', 'PR_LEG.md']);
    git(integratorWorktree, ['commit', '-m', 'feat: draft PR leg change']);

    // Create / inspect PR: the backend pushes the integrator branch and
    // opens the draft PR through the operator's gh; the inspector then
    // reports live GitHub status for it.
    await inspector.getByRole('button', { name: 'Create draft PR' }).click();
    // The persistent evidence is the inspector's Pull request row (the
    // mutation's own "View draft PR" link is replaced by it on refetch).
    const prLink = inspector.getByRole('link', {
      name: new RegExp(`github\\.com/${ghRepo!.replace('/', '\\/')}/pull/\\d+`),
    });
    await expect(prLink).toBeVisible({ timeout: 60_000 });
    prUrl = (await prLink.getAttribute('href')) ?? '';
    expect(prUrl).toMatch(new RegExp(`^https://github\\.com/${ghRepo}/pull/\\d+$`));
    await expect(inspector).toContainText(/\(draft\)/, { timeout: 30_000 });

    // Review outcome: marking ready from the GUI flips the real PR.
    await inspector.getByRole('button', { name: 'Mark PR ready for review' }).click();
    await expect
      .poll(
        () => {
          const view = JSON.parse(
            execFileSync('gh', ['pr', 'view', prUrl, '--json', 'isDraft,state'], { stdio: 'pipe' }).toString(),
          ) as { isDraft: boolean; state: string };
          return `${view.state}:${view.isDraft}`;
        },
        { timeout: 60_000 },
      )
      .toBe('OPEN:false');

    // Stop the run from the same inspector.
    await inspector.getByRole('button', { name: 'Stop' }).click();
    const stopDialog = page.getByRole('dialog', { name: 'Stop this swarm run?' });
    await stopDialog.getByRole('button', { name: 'Stop run' }).click();
    await expect(inspector.getByText('cancelled', { exact: true })).toBeVisible({ timeout: 20_000 });
  } finally {
    // Close by branch lookup as well as by URL: a failure mid-leg may
    // leave a real PR open even when prUrl was never captured.
    const prTargets = new Set<string>(prUrl ? [prUrl] : []);
    if (runId && ghRepo) {
      try {
        const found = JSON.parse(
          execFileSync(
            'gh',
            ['pr', 'list', '--repo', ghRepo, '--head', `agent-toolkit-swarm/${runId}/integrator`, '--json', 'url'],
            { stdio: 'pipe' },
          ).toString(),
        ) as Array<{ url: string }>;
        for (const pr of found) prTargets.add(pr.url);
      } catch {
        // Lookup failed (offline/auth); URL-based close below still runs.
      }
    }
    for (const target of prTargets) {
      try {
        execFileSync('gh', ['pr', 'close', target, '--delete-branch'], { stdio: 'pipe' });
      } catch {
        // Already closed or branch already gone; sandbox stays reusable.
      }
    }
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

/**
 * Waits for a lazily provisioned role worktree; on timeout the error
 * carries the role pane and the run trace tail so CI logs show why the
 * handoff chain stalled instead of a bare false.
 */
async function waitForWorktree(
  worktree: string,
  socket: string,
  session: string,
  role: string,
  page: import('@playwright/test').Page,
): Promise<void> {
  const deadline = Date.now() + 60_000;
  while (!fs.existsSync(worktree) && Date.now() < deadline) {
    await page.waitForTimeout(1_000);
  }
  if (fs.existsSync(worktree)) return;
  const runDir = path.dirname(path.dirname(worktree));
  let traceTail = '(no trace)';
  try {
    traceTail = fs.readFileSync(path.join(runDir, 'trace.jsonl'), 'utf8').slice(-3_000);
  } catch {
    // Run dir unreadable; pane capture below is the remaining evidence.
  }
  throw new Error(
    `worktree never appeared: ${worktree}\n--- ${role} pane ---\n${tmuxCapture(socket, session, role)}\n--- trace tail ---\n${traceTail}`,
  );
}

function tmuxCapture(socket: string, session: string, window: string): string {
  try {
    return execFileSync('tmux', ['-L', socket, 'capture-pane', '-p', '-t', `${session}:${window}`], {
      stdio: 'pipe',
    }).toString();
  } catch {
    return '';
  }
}

function tmuxType(socket: string, session: string, window: string, command: string): void {
  execFileSync('tmux', ['-L', socket, 'send-keys', '-t', `${session}:${window}`, '-l', command], { stdio: 'pipe' });
  execFileSync('tmux', ['-L', socket, 'send-keys', '-t', `${session}:${window}`, 'Enter'], { stdio: 'pipe' });
}

function git(cwd: string, args: string[]): void {
  execFileSync(
    'git',
    ['-C', cwd, '-c', 'user.name=Agent Toolkit E2E', '-c', 'user.email=e2e@agent-toolkit.invalid', ...args],
    { stdio: 'pipe' },
  );
}

function initRepoWithRemote(dir: string, ghRepo: string): void {
  execFileSync('git', ['init', '--quiet', '-b', 'main', dir]);
  git(dir, ['remote', 'add', 'origin', `https://github.com/${ghRepo}.git`]);
  // Repeat runs fork from the sandbox main previous runs pushed: fetch
  // and adopt it when present (an empty repo simply has no ref yet),
  // then advance it with an empty commit so the integrator branch forks
  // from a pushed tip.
  try {
    git(dir, ['fetch', '--quiet', 'origin']);
    git(dir, ['checkout', '-B', 'main', 'origin/main']);
  } catch {
    // Empty sandbox: the freshly initialized main is the base.
  }
  git(dir, ['commit', '--allow-empty', '-m', 'chore: e2e sandbox base']);
  git(dir, ['push', '-u', 'origin', 'main']);
}
