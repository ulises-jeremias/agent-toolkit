import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

const CAPTURE = process.env['ATK_CAPTURE'] === '1';
const CAPTURE_DIR =
  process.env['ATK_CAPTURE_DIR'] ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/people');

test('a Person starts a discovered runner PTY in a project and can stop it', async () => {
  const desktop = await openDesktop();
  try {
    await waitForBackend(desktop.page);
    const projectPath = path.join(desktop.home, 'dev', 'agent-toolkit');
    fs.mkdirSync(projectPath, { recursive: true });
    const backendBin = process.env['ATK_E2E_BACKEND_BIN'] ?? path.resolve(__dirname, '../../../../build/agent-toolkit');
    execFileSync(backendBin, ['project', 'add', projectPath, '--workspace', desktop.workspace], {
      env: {
        ...process.env,
        HOME: desktop.home,
        XDG_CONFIG_HOME: path.join(desktop.home, '.config'),
        XDG_DATA_HOME: path.join(desktop.home, '.local', 'share'),
      },
      stdio: 'pipe',
    });

    const page = desktop.page;
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.getByRole('button', { name: 'Create Person' }).click();
    const create = page.getByRole('dialog', { name: 'Create Person' });
    await create.getByRole('textbox', { name: 'Name' }).fill('Lina');
    await create.getByRole('textbox', { name: 'ID' }).fill('lina');
    await create.getByRole('textbox', { name: 'Role' }).fill('reviewer');
    await create.getByRole('textbox', { name: 'Goal' }).fill('Review changes in this project');
    await create.getByText('Capabilities and limits', { exact: true }).click();
    await create.getByRole('combobox', { name: 'Isolation' }).selectOption('worktree');
    await create.getByRole('spinbutton', { name: 'Max tokens' }).fill('1000');
    await create.getByRole('spinbutton', { name: 'Max seconds' }).fill('120');
    await create.getByRole('button', { name: 'Create Person' }).click();
    await expect(create).toBeHidden();
    await page.getByRole('button', { name: /Lina.*reviewer.*Offline/ }).click();
    if (CAPTURE) {
      fs.mkdirSync(CAPTURE_DIR, { recursive: true });
      await setViewport(desktop.app, 1024, 640);
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'people-roster-compact.png') });
    }
    await page.keyboard.press(process.platform === 'darwin' ? 'Meta+K' : 'Control+K');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByRole('textbox', { name: 'Filter commands' }).fill('Start Lina');
    await palette.getByRole('option', { name: /Start Lina/ }).click();

    const start = page.getByRole('dialog', { name: 'Start Lina' });
    await expect(start.getByRole('combobox', { name: 'Project and working folder' })).toHaveValue('agent-toolkit');
    await expect(start.getByText('120s · enforced by Desktop')).toBeVisible();
    await expect(start.getByText(/1,000 tokens · not enforced for this interactive runner/)).toBeVisible();
    const startButton = start.getByRole('button', { name: 'Start and open terminal' });
    await expect(startButton).toBeDisabled();
    const runner = start.getByRole('combobox', { name: 'Runner' });
    const installedOptions = runner.locator('option:enabled:not([value=""])');
    await expect
      .poll(
        async () =>
          (await installedOptions.count()) > 0 ||
          (await start.getByText('No interactive runner is installed').count()) > 0,
      )
      .toBe(true);
    if ((await installedOptions.count()) === 0) {
      await expect(start.getByRole('status')).toContainText('No interactive runner is installed');
      if (CAPTURE) {
        await page.screenshot({ path: path.join(CAPTURE_DIR, 'person-start-compact.png') });
        await setViewport(desktop.app, 1920, 1080);
        await page.screenshot({ path: path.join(CAPTURE_DIR, 'person-start-large.png') });
      }
      await start.getByRole('button', { name: 'Cancel' }).click();
      await expect(page.getByRole('button', { name: /Lina.*reviewer.*Offline/ })).toBeVisible();
      return;
    }
    const runnerId = await installedOptions.first().getAttribute('value');
    if (!runnerId) throw new Error('Discovered runner option is missing its id.');
    await runner.selectOption(runnerId);
    if (CAPTURE) {
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'person-start-compact.png') });
      await setViewport(desktop.app, 1920, 1080);
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'person-start-large.png') });
    }
    await start.getByRole('checkbox').check();
    await expect(startButton).toBeEnabled();
    await start.getByRole('button', { name: 'Start and open terminal' }).click();
    await expect(start).toBeHidden();
    await expect(page).toHaveURL(/#\/terminal\?[^#]*pty=/);
    await expect(page.getByRole('tab', { name: /Lina.*agent-toolkit.*running/i })).toBeVisible({
      timeout: 20_000,
    });
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.getByRole('button', { name: 'Archive' }).click();
    const archiveDialog = page.getByRole('dialog', { name: 'Archive Lina?' });
    await archiveDialog.getByRole('button', { name: 'Archive' }).click();
    await expect(page.getByRole('button', { name: /Lina.*reviewer.*Archived · session open/ })).toBeVisible();

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    const personCharacter = page.getByRole('button', { name: /Lina.*Person session.*session open/i });
    await expect(personCharacter).toBeVisible({ timeout: 15_000 });
    const projectHouse = page.locator('[data-entity-id="place:project:agent-toolkit"]');
    await expect(projectHouse).toBeVisible();
    const personBox = await personCharacter.boundingBox();
    const houseBox = await projectHouse.boundingBox();
    expect(personBox).not.toBeNull();
    expect(houseBox).not.toBeNull();
    expect(personBox!.x).toBeGreaterThanOrEqual(houseBox!.x);
    expect(personBox!.x).toBeLessThan(houseBox!.x + houseBox!.width);
    expect(personBox!.y).toBeGreaterThanOrEqual(houseBox!.y);
    expect(personBox!.y).toBeLessThan(houseBox!.y + houseBox!.height);
    if (CAPTURE) {
      await setViewport(desktop.app, 1024, 640);
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'world-person-compact.png') });
      await setViewport(desktop.app, 1920, 1080);
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'world-person-large.png') });
    }
    await personCharacter.click();
    await expect(page).toHaveURL(/#\/people\?[^#]*person=lina/);
    await page.keyboard.press(process.platform === 'darwin' ? 'Meta+K' : 'Control+K');
    const activePalette = page.getByRole('dialog', { name: 'Commands' });
    await activePalette.getByRole('textbox', { name: 'Filter commands' }).fill("Open Lina's terminal");
    await activePalette.getByRole('option', { name: /Open Lina's terminal/ }).click();
    await expect(page).toHaveURL(/#\/terminal\?[^#]*pty=/);

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await expect(page.getByRole('button', { name: /Lina.*reviewer.*Archived · session open/ })).toBeVisible();
    await page.getByRole('button', { name: 'Restore' }).click();
    const restoreDialog = page.getByRole('dialog', { name: 'Restore Lina?' });
    await restoreDialog.getByRole('button', { name: 'Restore' }).click();
    await expect(page.getByRole('button', { name: /Lina.*reviewer.*Session open/ })).toBeVisible();
    await page.getByRole('button', { name: 'Stop session' }).click();
    const stopDialog = page.getByRole('dialog', { name: "Stop Lina's session?" });
    await stopDialog.getByRole('button', { name: 'Stop session' }).click();
    await expect(page.getByRole('button', { name: /Lina.*reviewer.*Offline/ })).toBeVisible({ timeout: 20_000 });
    if (CAPTURE) await page.screenshot({ path: path.join(CAPTURE_DIR, 'people-offline-after-stop.png') });
  } finally {
    await desktop.close();
  }
});
