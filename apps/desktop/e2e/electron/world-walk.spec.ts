import { expect, test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { openDesktop, waitForBackend } from './fixtures';

test('walks in the world only while it has focus and keeps typing local to the command palette', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await expect(page.getByText('Checking live workspace details…')).toBeHidden();
    const world = page.getByRole('application', { name: 'Semantic workspace world' });
    await expect(world).toHaveAttribute('data-player-ready', 'true');
    const player = world.getByRole('img', { name: 'You, exploring the workspace' });
    await expect(player).toHaveAttribute('data-ready', 'true');
    await expect(player).toHaveCSS('animation-duration', '1.6s');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect.poll(() => player.evaluate((element) => element.getAnimations().length)).toBe(0);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await expect(player).toHaveCSS('animation-duration', '1.6s');
    if (process.env['ATK_CAPTURE_WORLD_EXPLORATION'] === '1') {
      await page.setViewportSize({ width: 1024, height: 640 });
    }
    const position = () => player.evaluate((element) => [element.style.left, element.style.top]);
    await expect(world).toHaveAttribute('data-camera-mode', 'follow');
    const initialZoom = Number(await world.getAttribute('data-zoom'));
    if (process.env['ATK_CAPTURE_WORLD_EXPLORATION'] === '1') {
      const outputDir = process.env['ATK_CAPTURE_WORLD_EXPLORATION_DIR'] ?? '/tmp/agent-toolkit-world-exploration';
      fs.mkdirSync(outputDir, { recursive: true });
      for (const viewport of [
        { name: 'compact', width: 1024, height: 640 },
        { name: 'large', width: 1920, height: 1080 },
      ]) {
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
        await page.waitForTimeout(250);
        await page.screenshot({ path: path.resolve(outputDir, `world-player-start-${viewport.name}.png`) });
      }
      await page.setViewportSize({ width: 1024, height: 640 });
    }

    const bounds = await world.boundingBox();
    expect(bounds).toBeTruthy();
    const beforePointerWalk = await position();
    await world.click({ position: { x: bounds!.width * 0.88, y: bounds!.height * 0.78 } });
    await expect.poll(position, { timeout: 3_000 }).not.toEqual(beforePointerWalk);
    await expect(player).toHaveAttribute('data-walking', 'true');
    await expect(player).toHaveCSS('animation-duration', '0.26s');
    if (process.env['ATK_CAPTURE_WORLD_EXPLORATION'] === '1') {
      const outputDir = process.env['ATK_CAPTURE_WORLD_EXPLORATION_DIR'] ?? '/tmp/agent-toolkit-world-exploration';
      fs.mkdirSync(outputDir, { recursive: true });
      await page.screenshot({ path: path.resolve(outputDir, 'world-player-walking-compact.png') });
    }
    await expect(world).toHaveAttribute('data-camera-mode', 'follow');
    expect(Number(await world.getAttribute('data-zoom'))).toBeGreaterThanOrEqual(initialZoom);
    await expect(player).not.toHaveAttribute('data-walking', { timeout: 15_000 });

    const appearance = page.getByRole('combobox', { name: 'Your appearance' });
    await appearance.selectOption('grove');
    await expect(player).toHaveCSS('background-image', /char-player-grove-(north|south|east|west)\.png/);
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            Object.entries(localStorage).find(([key]) => key.startsWith('agent-toolkit:world-player-appearance:'))?.[1],
        ),
      )
      .toBe('grove');
    if (process.env['ATK_CAPTURE_WORLD_EXPLORATION'] === '1') {
      const outputDir = process.env['ATK_CAPTURE_WORLD_EXPLORATION_DIR'] ?? '/tmp/agent-toolkit-world-exploration';
      fs.mkdirSync(outputDir, { recursive: true });
      for (const viewport of [
        { name: 'compact', width: 1024, height: 640 },
        { name: 'large', width: 1920, height: 1080 },
      ]) {
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
        const output = path.join(outputDir, `world-player-click-to-move-${viewport.name}.png`);
        await page.screenshot({ path: path.resolve(output) });
      }
      await page.setViewportSize({ width: 1024, height: 640 });
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
