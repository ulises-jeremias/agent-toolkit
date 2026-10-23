import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

function git(cwd: string, ...args: string[]) {
  execFileSync('git', args, { cwd, stdio: 'pipe' });
}

test('reviews, stages, and commits real project changes from the GUI', async () => {
  const desktop = await openDesktop();
  try {
    const { page, home } = desktop;
    await waitForBackend(page);

    // A disposable real git repository, linked as a project below.
    const projectPath = path.join(home, '.ai-workspace', 'repos', 'local', 'garden-api');
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

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
    const linkFolder = page.getByRole('button', { name: 'Link existing folder' });
    await expect(linkFolder).toBeEnabled();
    await linkFolder.click();
    const review = page.getByRole('dialog', { name: 'Review project link' });
    await expect(review.getByText(projectPath)).toBeVisible();
    await review.getByRole('button', { name: 'Link garden-api' }).click();
    await expect(review).toBeHidden();
    await page.getByRole('button', { name: 'Dismiss: Project linked' }).click();

    // Changes panel: README is Changed, notes.txt is Untracked.
    const changes = page.locator('section', { has: page.getByRole('heading', { name: 'Changes' }) });
    await changes.scrollIntoViewIfNeeded();
    await expect(changes.getByText('branch main')).toBeVisible();
    await expect(changes.getByRole('heading', { name: 'Changed (1)' })).toBeVisible();
    await expect(changes.getByRole('heading', { name: 'Untracked (1)' })).toBeVisible();

    // Inspect the unstaged diff before staging anything.
    await changes.getByRole('button', { name: /README\.md/ }).click();
    await expect(changes.getByLabel('Diff for README.md')).toContainText('+Now with notes.');

    // Stage both files from their groups.
    await changes.getByRole('list', { name: 'Changed files' }).getByRole('button', { name: 'Stage' }).click();
    await expect(changes.getByRole('heading', { name: 'Staged (1)' })).toBeVisible();
    await changes.getByRole('list', { name: 'Untracked files' }).getByRole('button', { name: 'Stage' }).click();
    await expect(changes.getByRole('heading', { name: 'Staged (2)' })).toBeVisible();
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
  } finally {
    await desktop.close();
  }
});

test('stages a single hunk from the GUI and leaves the other unstaged', async () => {
  const desktop = await openDesktop();
  try {
    const { page, home } = desktop;
    await waitForBackend(page);

    const projectPath = path.join(home, '.ai-workspace', 'repos', 'local', 'garden-api');
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
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
    await page.getByRole('button', { name: 'Link existing folder' }).click();
    const review = page.getByRole('dialog', { name: 'Review project link' });
    await review.getByRole('button', { name: 'Link garden-api' }).click();
    await expect(review).toBeHidden();
    await page.getByRole('button', { name: 'Dismiss: Project linked' }).click();

    const changes = page.locator('section', { has: page.getByRole('heading', { name: 'Changes' }) });
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
