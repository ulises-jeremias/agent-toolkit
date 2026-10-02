import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

test('links an existing project from the GUI and places it in the world', async () => {
  const desktop = await openDesktop();
  try {
    const { page, home } = desktop;
    await waitForBackend(page);
    const projectPath = path.join(home, '.ai-workspace', 'repos', 'local', 'garden-api');
    fs.mkdirSync(projectPath, { recursive: true });
    fs.writeFileSync(path.join(projectPath, 'README.md'), '# Garden API\n');

    // The native picker itself is platform-owned. Stub only its result, then
    // exercise the real preload bridge and HTTP API, including an outside-root
    // rejection with a recoverable message before the successful retry.
    const pick = (selected: string) =>
      desktop.app.evaluate(({ dialog }, folder) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
      }, selected);
    const outsideAllowedRoots =
      process.platform === 'win32'
        ? (process.env.SystemRoot ?? 'C:/Windows').replaceAll('\\', '/')
        : process.platform === 'darwin'
          ? '/System'
          : '/etc';
    expect(fs.existsSync(outsideAllowedRoots)).toBe(true);
    await pick(outsideAllowedRoots);

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    await page.getByRole('button', { name: /No projects yet/ }).click();
    await expect(page.getByRole('heading', { name: 'Projects' })).toBeVisible();
    await page.getByRole('button', { name: 'Link existing folder' }).click();

    const review = page.getByRole('dialog', { name: 'Review project link' });
    const outsideName = path.basename(outsideAllowedRoots);
    await expect(review.getByText(new RegExp(`projects/${outsideName}`))).toBeVisible();
    await review.getByRole('button', { name: `Link ${outsideName}` }).click();
    await expect(review.getByRole('alert')).toContainText('outside allowed roots');

    await pick(projectPath);
    await review.getByRole('button', { name: 'Choose another folder' }).click();
    await expect(review.getByText(projectPath)).toBeVisible();
    await expect(review.getByText(/projects\/garden-api/)).toBeVisible();
    await review.getByRole('button', { name: 'Link garden-api' }).click();
    await expect(review).toBeHidden();
    await expect(
      page.getByRole('region', { name: 'Receipts' }).getByText('Project linked', { exact: true }),
    ).toBeVisible();

    const linkPath = path.join(home, '.ai-workspace', 'projects', 'garden-api');
    await expect.poll(() => fs.realpathSync(linkPath)).toBe(fs.realpathSync(projectPath));
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    await expect(page.getByRole('button', { name: /garden-api.*Project/ })).toBeVisible();
    await page.setViewportSize({ width: 1024, height: 640 });
    const world = page.getByRole('application', { name: 'Semantic workspace world' });
    await page.getByRole('button', { name: 'Fit world' }).click();
    await expect(world).toHaveAttribute('data-zoom', '16');
    await page.getByRole('button', { name: 'Pan map with arrow keys; Home fits the world' }).focus();
    await page.keyboard.press('Home');
    await expect(world).toHaveAttribute('data-zoom', '16');
  } finally {
    await desktop.close();
  }
});
