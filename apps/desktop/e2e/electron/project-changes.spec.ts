import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';
import { goTo } from './navigation';

function git(cwd: string, ...args: string[]) {
  execFileSync('git', args, { cwd, stdio: 'pipe' });
}

test('reviews, stages, and commits real project changes from the GUI', async () => {
  const desktop = await openDesktop();
  try {
    const { page, home } = desktop;
    await waitForBackend(page);

    // A disposable real git repository, linked as a project below.
    // Keep the repository outside the workspace's discovered repo roots so
    // this journey genuinely exercises the link-existing-project flow.
    const projectPath = path.join(home, 'code', 'garden-api');
    fs.mkdirSync(projectPath, { recursive: true });
    git(projectPath, 'init', '-q', '-b', 'main');
    git(projectPath, 'config', 'user.email', 'test@example.com');
    git(projectPath, 'config', 'user.name', 'Test');
    fs.writeFileSync(path.join(projectPath, 'README.md'), '# Garden API\n');
    git(projectPath, 'add', 'README.md');
    git(projectPath, 'commit', '-q', '-m', 'initial');
    fs.writeFileSync(path.join(projectPath, 'README.md'), '# Garden API\n\nNow with notes.\n');
    fs.writeFileSync(path.join(projectPath, 'notes.txt'), 'field notes\n');

    await desktop.app.evaluate(({ dialog }, folder) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
    }, projectPath);

    await goTo(page, 'Projects');
    const linkFolder = page.getByRole('button', { name: 'Link a repository' });
    await expect(linkFolder).toBeEnabled();
    await linkFolder.click();
    const projectRow = page.getByRole('button', { name: /^garden-api(?:\s|$)/ });
    await expect(projectRow).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole('region', { name: 'garden-api' }).getByText(projectPath)).toBeVisible();
    expect(fs.realpathSync(path.join(desktop.workspace, 'projects', 'garden-api'))).toBe(fs.realpathSync(projectPath));

    // Changes panel: README is Changed, notes.txt is Untracked.
    const changes = page.getByRole('region', { name: 'Changes', exact: true });
    await changes.scrollIntoViewIfNeeded();
    await expect(changes.getByText('branch main')).toBeVisible();
    await expect(changes.getByRole('heading', { name: 'Changed (1)' })).toBeVisible();
    await expect(changes.getByRole('heading', { name: 'Untracked (1)' })).toBeVisible();

    // Review new file contents before staging them into the index.
    await changes
      .getByRole('list', { name: 'Untracked files' })
      .getByRole('button', { name: /notes\.txt/ })
      .click();
    await expect(changes.getByLabel('Diff for notes.txt')).toContainText('+field notes');

    // Inspect the unstaged diff before staging anything.
    await changes.getByRole('button', { name: /README\.md/ }).click();
    await expect(changes.getByLabel('Diff for README.md')).toContainText('+Now with notes.');

    // Stage both files from their groups.
    await changes.getByRole('list', { name: 'Changed files' }).getByRole('button', { name: 'Stage' }).click();
    await expect(changes.getByRole('heading', { name: 'Staged (1)' })).toBeVisible();
    // A staged heading must correspond to the real index, not an optimistic counter.
    expect(
      execFileSync('git', ['diff', '--cached', '--name-only'], { cwd: projectPath, encoding: 'utf8' }).trim(),
    ).toBe('README.md');
    await changes.getByRole('list', { name: 'Untracked files' }).getByRole('button', { name: 'Stage' }).click();
    await expect(changes.getByRole('heading', { name: 'Staged (2)' })).toBeVisible();
    expect(
      execFileSync('git', ['diff', '--cached', '--name-only'], { cwd: projectPath, encoding: 'utf8' })
        .trim()
        .split(String.fromCharCode(10))
        .sort(),
    ).toEqual(['README.md', 'notes.txt']);
    expect(execFileSync('git', ['status', '--porcelain'], { cwd: projectPath, encoding: 'utf8' })).toContain(
      'M  README.md',
    );

    // Commit from the GUI; the tree must end clean on disk too.
    await changes.getByLabel('Commit message').fill('Document the garden');
    await changes.getByRole('button', { name: 'Commit staged (2)' }).click();
    await expect(changes.getByText('Committed staged changes.')).toBeVisible();
    await expect(changes.getByText('Working tree clean.')).toBeVisible();
    expect(execFileSync('git', ['status', '--porcelain'], { cwd: projectPath, encoding: 'utf8' })).toBe('');
    expect(execFileSync('git', ['log', '-1', '--format=%s'], { cwd: projectPath, encoding: 'utf8' }).trim()).toBe(
      'Document the garden',
    );

    // Probe the real backend response as well as the renderer. This separates
    // a stale UI query from a missing commit-history capability.
    const backendUrl = await page.evaluate(async () => (await window.atk?.backendStatus())?.url ?? null);
    expect(backendUrl).not.toBeNull();
    const gitLog = await page.evaluate(
      async ({ workspace, backendUrl }) => {
        const query = new URLSearchParams({ workspace, limit: '50' });
        const response = await fetch(`${backendUrl}/api/v1/projects/garden-api/git/log?${query}`);
        const body = await response.text();
        return { status: response.status, body };
      },
      { workspace: desktop.workspace, backendUrl },
    );
    expect(gitLog.status, gitLog.body).toBe(200);
    const gitLogBody = JSON.parse(gitLog.body) as {
      ok: boolean;
      detail?: string;
      commits: { subject: string }[];
    };
    expect(gitLogBody.ok, gitLogBody.detail).toBe(true);
    expect(gitLogBody.commits.map((entry) => entry.subject)).toEqual(['Document the garden', 'initial']);

    // History: clicking a commit renders its diff in the pane.
    await changes
      .getByRole('list', { name: 'Commit history' })
      .getByRole('button', { name: /initial/ })
      .click();
    await expect(changes.getByLabel(/Diff for commit/)).toContainText('+# Garden API');
    // Selecting a different commit must replace the displayed diff, not reuse the initial one.
    await changes
      .getByRole('list', { name: 'Commit history' })
      .getByRole('button', { name: /Document the garden/ })
      .click();
    await expect(changes.getByLabel(/Diff for commit/)).toContainText('+field notes');
  } finally {
    await desktop.close();
  }
});

test('stages a single hunk from the GUI and leaves the other unstaged', async () => {
  const desktop = await openDesktop();
  try {
    const { page, home } = desktop;
    await waitForBackend(page);

    // Keep the repository outside the workspace's discovered repo roots so
    // this journey genuinely exercises the link-existing-project flow.
    const projectPath = path.join(home, 'code', 'garden-api');
    fs.mkdirSync(projectPath, { recursive: true });
    git(projectPath, 'init', '-q', '-b', 'main');
    git(projectPath, 'config', 'user.email', 'test@example.com');
    git(projectPath, 'config', 'user.name', 'Test');
    const lines = Array.from({ length: 10 }, (_, i) => `line ${i + 1}`);
    fs.writeFileSync(path.join(projectPath, 'a.txt'), `${lines.join('\n')}\n`);
    git(projectPath, 'add', 'a.txt');
    git(projectPath, 'commit', '-q', '-m', 'initial');
    const edited = [...lines];
    edited[0] = 'FIRST';
    edited[9] = 'LAST';
    fs.writeFileSync(path.join(projectPath, 'a.txt'), `${edited.join('\n')}\n`);

    await desktop.app.evaluate(({ dialog }, folder) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
    }, projectPath);
    await goTo(page, 'Projects');
    await page.getByRole('button', { name: 'Link a repository' }).click();
    const projectRow = page.getByRole('button', { name: /^garden-api(?:\s|$)/ });
    await expect(projectRow).toBeVisible({ timeout: 30_000 });
    expect(fs.realpathSync(path.join(desktop.workspace, 'projects', 'garden-api'))).toBe(fs.realpathSync(projectPath));

    const changes = page.getByRole('region', { name: 'Changes', exact: true });
    await changes.scrollIntoViewIfNeeded();
    await changes.getByRole('button', { name: /a\.txt/ }).click();
    await expect(changes.getByLabel('Diff for a.txt')).toContainText('+FIRST');
    await expect(changes.getByLabel('Diff for a.txt')).toContainText('+LAST');

    // Stage only hunk 1: the index gains FIRST but not LAST.
    await changes.getByRole('button', { name: 'Stage hunk 1' }).click();
    await expect(changes.getByRole('heading', { name: 'Staged (1)' })).toBeVisible();
    await expect(changes.getByRole('heading', { name: 'Changed (1)' })).toBeVisible();
    const staged = execFileSync('git', ['diff', '--cached'], { cwd: projectPath, encoding: 'utf8' });
    expect(staged).toContain('+FIRST');
    expect(staged).not.toContain('+LAST');
    const unstaged = execFileSync('git', ['diff'], { cwd: projectPath, encoding: 'utf8' });
    expect(unstaged).toContain('+LAST');
  } finally {
    await desktop.close();
  }
});
