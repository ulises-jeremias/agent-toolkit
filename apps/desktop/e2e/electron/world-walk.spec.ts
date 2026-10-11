import { expect, test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { openDesktop, waitForBackend } from './fixtures';

test('walks in the world only while it has focus and keeps typing local to the command palette', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    const world = page.getByRole('application', { name: 'Semantic workspace world' });
    const player = world.getByRole('img', { name: 'You, exploring the workspace' });
    const position = () => player.evaluate((element) => [element.style.left, element.style.top]);

    const appearance = page.getByRole('combobox', { name: 'Your appearance' });
    await appearance.selectOption('grove');
    await expect(player).toHaveCSS('background-image', /char-player-grove-south\.png/);
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            Object.entries(localStorage).find(([key]) => key.startsWith('agent-toolkit:world-player-appearance:'))?.[1],
        ),
      )
      .toBe('grove');
    if (process.env['ATK_CAPTURE_WORLD_PLAYER'] === '1') {
      const outputDir = process.env['ATK_CAPTURE_WORLD_PLAYER_DIR'] ?? '/tmp/agent-toolkit-world-player';
      fs.mkdirSync(outputDir, { recursive: true });
      for (const viewport of [
        { name: 'compact', width: 1024, height: 640 },
        { name: 'large', width: 1920, height: 1080 },
      ]) {
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
        const output = path.join(outputDir, `world-player-appearance-${viewport.name}.png`);
        await page.screenshot({ path: path.resolve(output) });
      }
    }

    await page.getByRole('button', { name: 'Explore by walking' }).click();
    const initial = await position();
    let moved = false;
    for (const key of ['ArrowDown', 'ArrowRight', 'ArrowLeft', 'ArrowUp']) {
      await page.keyboard.down(key);
      await page.waitForTimeout(250);
      await page.keyboard.up(key);
      if ((await position()).some((coordinate, index) => coordinate !== initial[index])) {
        moved = true;
        break;
      }
    }
    expect(moved).toBe(true);

    const beforeTyping = await position();
    await page.getByRole('button', { name: 'Commands' }).click();
    const filter = page.getByRole('textbox', { name: 'Filter commands' });
    await filter.fill('');
    await page.keyboard.type('wasd');
    await expect(filter).toHaveValue('wasd');
    await expect.poll(position).toEqual(beforeTyping);
  } finally {
    await desktop.close();
  }
});
