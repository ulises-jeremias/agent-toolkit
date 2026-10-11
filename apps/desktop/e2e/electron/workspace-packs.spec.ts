import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

test('reviews workspace context packs and applies or clears one from the GUI', async () => {
  if (process.env['ATK_CAPTURE'] === '1') test.setTimeout(5 * 60_000);
  const desktop = await openDesktop();
  try {
    const { page, workspace } = desktop;
    await waitForBackend(page);
    const packDir = path.join(workspace, 'packs');
    fs.mkdirSync(packDir, { recursive: true });
    fs.writeFileSync(
      path.join(packDir, 'team.yaml'),
      'name: Product Team\ndescription: Shared project context for product work.\nprojects:\n  - agent-toolkit\n  - my-ai-workspace\n',
    );
    fs.writeFileSync(path.join(packDir, 'invalid.yaml'), 'description: Missing the required name.\n');

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
    const panel = page.getByRole('region', { name: 'Workspace context packs' });
    await expect(panel).toContainText('Product Team');
    await expect(panel).toContainText('agent-toolkit, my-ai-workspace');
    await expect(panel).toContainText("Missing required field 'name'.");
    await expect(panel.getByRole('button', { name: 'Use for future sessions' }).first()).toBeDisabled();

    await panel.getByRole('button', { name: 'Use for future sessions' }).last().click();
    await expect(panel.getByText('Context selected')).toBeVisible();
    await expect
      .poll(() => fs.readFileSync(path.join(workspace, '.active-pack'), 'utf8').trim())
      .toBe('packs/team.yaml');
    await expect(panel).toContainText('Its context applies to future workspace sessions');

    if (process.env['ATK_CAPTURE'] === '1') {
      const captureDir =
        process.env.ATK_CAPTURE_DIR ??
        path.resolve(__dirname, '../../../../docs/desktop/assets/electron/workspace-packs');
      fs.mkdirSync(captureDir, { recursive: true });
      for (const size of [
        { width: 1024, height: 640, key: 'workspace-packs-compact' },
        { width: 1920, height: 1080, key: 'workspace-packs-large' },
      ]) {
        await setViewport(desktop.app, size.width, size.height);
        await panel.scrollIntoViewIfNeeded();
        await page.screenshot({ path: path.join(captureDir, `${size.key}.png`) });
      }
    }

    await page.reload();
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
    const restoredPanel = page.getByRole('region', { name: 'Workspace context packs' });
    await expect(restoredPanel).toContainText('Used for future sessions');
    await restoredPanel.getByRole('button', { name: 'Clear selected context' }).click();
    await expect.poll(() => fs.existsSync(path.join(workspace, '.active-pack'))).toBe(false);
    await expect(page.getByRole('status').filter({ hasText: 'Active workspace pack cleared.' })).toBeVisible();
  } finally {
    await desktop.close();
  }
});
