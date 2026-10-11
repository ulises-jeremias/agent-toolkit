import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

async function linkGardenApiProject(desktop: Awaited<ReturnType<typeof openDesktop>>): Promise<string> {
  const { app, page, home } = desktop;
  const projectPath = path.join(home, '.ai-workspace', 'repos', 'local', 'garden-api');
  fs.mkdirSync(projectPath, { recursive: true });
  fs.writeFileSync(path.join(projectPath, 'README.md'), '# Garden API\n');

  await app.evaluate(({ dialog }, folder) => {
    dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
  }, projectPath);

  const nav = page.getByRole('navigation', { name: 'Destinations' });
  await nav.getByRole('link', { name: 'World' }).click();
  await page.getByRole('button', { name: /Add project/ }).click();
  await page.getByRole('button', { name: 'Link existing folder' }).click();
  const projectReview = page.getByRole('dialog', { name: 'Review project link' });
  await projectReview.getByRole('button', { name: 'Link garden-api' }).click();
  await expect(projectReview).toBeHidden();
  await nav.getByRole('link', { name: 'World' }).click();
  return projectPath;
}

async function observeViewTransitions(page: Awaited<ReturnType<typeof openDesktop>>['page']): Promise<void> {
  const supported = await page.evaluate(() => {
    const start = document.startViewTransition;
    if (typeof start !== 'function') return false;
    document.documentElement.dataset['atkViewTransitionCalls'] = '0';
    const nativeStart = start.bind(document);
    Object.defineProperty(document, 'startViewTransition', {
      configurable: true,
      value: (callback: Parameters<typeof start>[0]) => {
        const calls = Number(document.documentElement.dataset['atkViewTransitionCalls'] ?? '0');
        document.documentElement.dataset['atkViewTransitionCalls'] = String(calls + 1);
        return nativeStart(callback);
      },
    });
    return true;
  });
  expect(supported, 'Electron should expose the View Transitions API').toBe(true);
}

async function expectDoorTransition(page: Awaited<ReturnType<typeof openDesktop>>['page']): Promise<void> {
  await expect.poll(() => page.locator('html').getAttribute('data-atk-view-transition-calls')).toBe('1');
}

async function resetViewTransitionCalls(page: Awaited<ReturnType<typeof openDesktop>>['page']): Promise<void> {
  await page.locator('html').evaluate((element) => {
    element.setAttribute('data-atk-view-transition-calls', '0');
  });
}

async function expectNoDoorTransition(page: Awaited<ReturnType<typeof openDesktop>>['page']): Promise<void> {
  await expect(page.locator('html')).toHaveAttribute('data-atk-view-transition-calls', '0');
}

test('walks into a project house and opens its real terminal', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    const projectPath = await linkGardenApiProject(desktop);
    const world = page.getByRole('application', { name: 'Semantic workspace world' });
    await observeViewTransitions(page);
    await world.getByRole('button', { name: 'Explore by walking' }).click();
    const house = world.getByRole('button', { name: /garden-api · Project ·/ });
    await expect(house).toBeVisible();
    const approach = await house.evaluate((element) => {
      const bounds = element.getBoundingClientRect();
      const tileSize = Number.parseFloat(getComputedStyle(element).getPropertyValue('--world-tile-size'));
      return { x: bounds.left + bounds.width / 2, y: bounds.bottom + tileSize * 0.5 };
    });
    await page.mouse.click(approach.x, approach.y);
    await expect(world.getByText('Press E to enter garden-api house')).toBeVisible({ timeout: 20_000 });
    await page.keyboard.press('E');

    const interior = page.getByRole('application', { name: 'Interior of garden-api' });
    await expect(interior).toBeVisible();
    await expectDoorTransition(page);
    await interior.getByRole('button', { name: 'Explore by walking' }).click();
    const nearby = interior.getByRole('status');
    await page.keyboard.down('ArrowDown');
    await expect(nearby).toContainText('Terminal', { timeout: 4000 });
    await page.keyboard.up('ArrowDown');
    await page.keyboard.press('E');

    const terminalReview = page.getByRole('dialog', { name: 'New terminal session' });
    await expect(terminalReview).toBeVisible();
    const cwd = terminalReview.getByRole('textbox', { name: 'Working folder' });
    await expect(cwd).toHaveValue(projectPath);
    await expect(terminalReview).toContainText('Starts a process in a pseudo-terminal on this machine.');
    await expect(page.getByRole('tablist', { name: 'Sessions' }).getByRole('tab')).toHaveCount(0);
    await terminalReview.getByRole('button', { name: 'Open session' }).click();
    await expect(terminalReview).toBeHidden();
    await expect(page.getByRole('tablist', { name: 'Sessions' }).getByRole('tab')).toHaveCount(1);
    await expect(page.getByRole('tab', { name: /garden-api.*running/i })).toBeVisible();
  } finally {
    await desktop.close();
  }
});

test('walks back through the interior door to the workspace grounds', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await linkGardenApiProject(desktop);
    const world = page.getByRole('application', { name: 'Semantic workspace world' });
    await observeViewTransitions(page);
    await world.getByRole('button', { name: /garden-api · Project ·/ }).click();

    const interior = page.getByRole('application', { name: 'Interior of garden-api' });
    await expect(interior).toBeVisible();
    await resetViewTransitionCalls(page);
    await interior.getByRole('button', { name: 'Explore by walking' }).click();
    const exitDoor = interior.getByRole('button', { name: /Exit · Return to workspace grounds/ });
    const exitApproach = await exitDoor.evaluate((element) => {
      const bounds = element.getBoundingClientRect();
      const tileSize = Number.parseFloat(getComputedStyle(element).getPropertyValue('--world-tile-size'));
      return { x: bounds.right + tileSize * 0.5, y: bounds.top + bounds.height / 2 };
    });
    await page.mouse.click(exitApproach.x, exitApproach.y);
    await expect(interior.getByText('Press E to return to workspace grounds')).toBeVisible({ timeout: 20_000 });
    if (process.env['ATK_CAPTURE_WORLD_DOOR'] === '1') {
      const outputDir = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/world-player-exit');
      fs.mkdirSync(outputDir, { recursive: true });
      const receipts = page.locator('button[aria-label^="Dismiss:"]');
      while ((await receipts.count()) > 0) await receipts.first().click();
      for (const viewport of [
        { name: 'compact', width: 1024, height: 640 },
        { name: 'large', width: 1920, height: 1080 },
      ]) {
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
        await interior.getByRole('button', { name: viewport.name === 'compact' ? 'Fit world' : 'Zoom in' }).click();
        await page.evaluate(() => document.fonts.ready.then(() => undefined));
        await page.evaluate(() => {
          if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
        });
        await page.mouse.move(viewport.width - 24, viewport.height - 24);
        await page.screenshot({ path: path.join(outputDir, `${viewport.name}.png`) });
      }
    }
    await interior.getByRole('button', { name: 'Explore by walking' }).click();
    await page.keyboard.press('E');
    await expect(page.getByText('workspace valley')).toBeVisible();
    await expectDoorTransition(page);

    await page.emulateMedia({ reducedMotion: 'reduce' });
    await resetViewTransitionCalls(page);
    await page
      .getByRole('application', { name: 'Semantic workspace world' })
      .getByRole('button', { name: /garden-api · Project ·/ })
      .click();
    await expect(page.getByRole('application', { name: 'Interior of garden-api' })).toBeVisible();
    await expectNoDoorTransition(page);
  } finally {
    await desktop.close();
  }
});
