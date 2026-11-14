import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';
import { goTo } from './navigation';

const CAPTURE_DIR = process.env['ATK_CAPTURE_DIR'];

test('Person Start previews policy and opens a canonical Focus conversation only on explicit submit', async () => {
  const desktop = await openDesktop();
  try {
    await waitForBackend(desktop.page);
    const projectPath = path.join(desktop.home, 'dev', 'agent-toolkit');
    fs.mkdirSync(projectPath, { recursive: true });
    execFileSync(desktop.backendBin, ['project', 'add', projectPath, '--workspace', desktop.workspace], {
      env: {
        ...process.env,
        HOME: desktop.home,
        XDG_CONFIG_HOME: path.join(desktop.home, '.config'),
        XDG_DATA_HOME: path.join(desktop.home, '.local', 'share'),
      },
      stdio: 'pipe',
    });

    const page = desktop.page;
    await goTo(page, 'People');
    await page.getByRole('button', { name: 'Create Person' }).click();
    const create = page.getByRole('dialog', { name: 'Create Person' });
    await create.getByRole('textbox', { name: 'Name' }).fill('Lina');
    await create.getByRole('textbox', { name: 'ID' }).fill('lina');
    await create.getByRole('textbox', { name: 'Role' }).fill('reviewer');
    await create.getByRole('textbox', { name: 'Goal' }).fill('Review changes in this project');
    await create.getByRole('textbox', { name: 'Durable notes' }).fill('Prefer small, verified patches.');
    await create.getByText('Capabilities and limits', { exact: true }).click();
    await create.getByRole('combobox', { name: 'Isolation' }).selectOption('worktree');
    await create.getByRole('spinbutton', { name: 'Max tokens' }).fill('1000');
    await create.getByRole('spinbutton', { name: 'Max seconds' }).fill('120');
    await create.getByRole('button', { name: 'Create Person' }).click();
    await expect(create).toBeHidden();
    await page.getByRole('button', { name: /Lina.*reviewer.*Offline/ }).click();

    await page.keyboard.press(process.platform === 'darwin' ? 'Meta+K' : 'Control+K');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByRole('textbox', { name: 'Filter commands' }).fill('Start Lina');
    await palette.getByRole('option', { name: /Start Lina/ }).click();

    const start = page.getByRole('dialog', { name: 'Start Lina in Focus' });
    await expect(start.getByRole('combobox', { name: 'Project and working folder' })).toHaveValue('agent-toolkit');
    await expect(start.getByRole('textbox', { name: 'Task for this session' })).toHaveValue(
      'Review changes in this project',
    );
    await expect(start.locator('pre')).toContainText('Role: reviewer');
    await expect(start.locator('pre')).toContainText('Durable notes: Prefer small, verified patches.');
    await expect(start).toContainText('Skills, MCP, capabilities and isolation remain saved metadata');
    await expect(start).toContainText('token, cost and runtime limits are not enforced in Focus');
    await expect(start.getByRole('combobox', { name: 'Permission mode' })).toHaveValue('ask');
    const startButton = start.getByRole('button', { name: 'Start in Focus' });
    await expect(startButton).toBeDisabled();
    if (CAPTURE_DIR) {
      fs.mkdirSync(CAPTURE_DIR, { recursive: true });
      await setViewport(desktop.app, 1024, 640);
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'person-start-compact.png') });
      await setViewport(desktop.app, 1440, 900);
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'person-start-desktop.png') });
    }

    const providerSelect = start.getByRole('combobox', { name: 'Provider' });
    const usableProviders = providerSelect.locator('option:enabled:not([value=""])');
    if ((await usableProviders.count()) === 0) {
      await expect(start).toContainText('No installed and signed-in provider supports Focus sessions yet.');
    } else {
      const providerId = await usableProviders.first().getAttribute('value');
      if (!providerId) throw new Error('The enabled Focus provider option has no id.');
      await providerSelect.selectOption(providerId);
      await expect(start.getByRole('checkbox')).toBeVisible();
      await start.getByRole('checkbox').check();
      await expect(startButton).toBeEnabled();
      await start.getByRole('textbox', { name: 'Task for this session' }).fill('');
      await expect(startButton).toBeDisabled();
    }
    await start.getByRole('button', { name: 'Cancel' }).click();
    await expect(start).toBeHidden();
    await expect(page.getByRole('button', { name: /Lina.*reviewer.*Offline/ })).toBeVisible();
    await expect(page.getByText('Active Focus sessions')).toHaveCount(0);
    await expect(page.getByRole('region', { name: 'Lina Focus history' })).toHaveCount(0);
  } finally {
    await desktop.close();
  }
});
