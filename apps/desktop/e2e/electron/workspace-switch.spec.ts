import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

test('switches workspaces, reads their own projects, and returns safely', async () => {
  const desktop = await openDesktop();
  try {
    const { page, home, workspace } = desktop;
    await waitForBackend(page);

    const alternateWorkspace = path.join(home, 'workspaces', 'alternate');
    const serverState = path.join(workspace, '.agent-toolkit', 'server');
    fs.cpSync(workspace, alternateWorkspace, {
      recursive: true,
      filter: (source) => !source.startsWith(serverState),
    });

    const project = path.join(home, 'fixtures', 'maple-worker');
    fs.mkdirSync(project, { recursive: true });
    fs.writeFileSync(path.join(project, 'README.md'), '# Maple Worker\n');
    const chooseFolder = async (folder: string) => {
      await desktop.app.evaluate(({ dialog }, selected) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [selected] });
      }, folder);
    };
    const harnessValue = page.getByText('Harness', { exact: true }).locator('..').locator('dd');

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
    await expect(harnessValue).toContainText(workspace);
    await chooseFolder(alternateWorkspace);
    await page.getByRole('button', { name: /Change harness/ }).click();
    await expect(harnessValue).toContainText(alternateWorkspace, { timeout: 20_000 });
    await waitForBackend(page);

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
    const linkProject = page.getByRole('button', { name: 'Link existing folder' });
    await expect(linkProject).toBeEnabled({ timeout: 15_000 });
    await chooseFolder(project);
    await linkProject.click();
    const review = page.getByRole('dialog', { name: 'Review project link' });
    await expect(review).toContainText('maple-worker');
    await review.getByRole('button', { name: 'Link maple-worker' }).click();
    await expect(review).toBeHidden();
    await page.getByRole('button', { name: 'Dismiss: Project linked' }).click();

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    await expect(page.getByRole('button', { name: /maple-worker/ })).toBeVisible();
    const captureDir =
      process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/workspace');
    if (process.env.ATK_CAPTURE === '1') {
      fs.mkdirSync(captureDir, { recursive: true });
      for (const size of [
        { width: 1024, height: 640, key: 'workspace-project-compact' },
        { width: 1920, height: 1080, key: 'workspace-project-large' },
      ]) {
        await setViewport(desktop.app, size.width, size.height);
        await page.getByRole('button', { name: 'Fit world' }).click();
        await page.screenshot({ path: path.join(captureDir, `${size.key}.png`) });
      }
    }

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
    await chooseFolder(workspace);
    await page.getByRole('button', { name: /Change harness/ }).click();
    await expect(harnessValue).toContainText(workspace, { timeout: 20_000 });
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    await expect(page.getByRole('button', { name: /No projects yet/ })).toBeVisible();
    if (process.env.ATK_CAPTURE === '1') {
      for (const size of [
        { width: 1024, height: 640, key: 'workspace-return-compact' },
        { width: 1920, height: 1080, key: 'workspace-return-large' },
      ]) {
        await setViewport(desktop.app, size.width, size.height);
        await page.getByRole('button', { name: 'Fit world' }).click();
        await page.screenshot({ path: path.join(captureDir, `${size.key}.png`) });
      }
    }
  } finally {
    await desktop.close();
  }
});
