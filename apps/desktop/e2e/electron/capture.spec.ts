import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';

/**
 * Screenshot tour for design review, not a regression gate. Opt in with
 * ATK_CAPTURE=1; images land in ATK_CAPTURE_DIR (default: the docs assets).
 * Every job and session shown is real, created through the UI.
 */
const CAPTURE = process.env.ATK_CAPTURE === '1';
const OUT_DIR =
  process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/foundations');

const SIZES = [
  { width: 1024, height: 640 },
  { width: 1920, height: 1080 },
] as const;
const THEMES = ['paper', 'ink'] as const;
const DESTINATIONS = [
  'World',
  'Office',
  'Operations',
  'Workspace',
  'Library',
  'Insights',
  'Terminal',
  'Settings',
] as const;

test.describe.configure({ mode: 'serial' });
test.skip(!CAPTURE, 'Set ATK_CAPTURE=1 to capture design review screenshots.');

let desktop: Desktop;

test.beforeAll(async () => {
  desktop = await openDesktop();
});

test.afterAll(async () => {
  await desktop?.close();
});

function nav(page: Page) {
  return page.getByRole('navigation', { name: 'Destinations' });
}

async function startJob(page: Page, cmd: string): Promise<void> {
  await nav(page).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start job' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a job' });
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill(cmd);
  await dialog.getByRole('button', { name: 'Start job' }).click();
  await expect(dialog).toBeHidden();
}

async function settle(page: Page): Promise<void> {
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await expect(page.getByText(/^(Loading|Checking|Listing)/)).toHaveCount(0, { timeout: 30_000 });
  await page.evaluate(() => document.fonts.ready.then(() => undefined));
}

test('capture every destination in Paper and Ink at both sizes', async () => {
  test.setTimeout(10 * 60_000);
  const { app, page } = desktop;
  await waitForBackend(page);

  await startJob(page, 'version');
  await startJob(page, 'workspace');
  await startJob(page, 'no-such-command');

  await nav(page).getByRole('link', { name: 'Terminal' }).click();
  await page.getByRole('main').getByRole('button', { name: 'New session' }).click();
  const session = page.getByRole('dialog', { name: 'New terminal session' });
  await session.getByRole('textbox', { name: 'Command', exact: true }).fill('/bin/sh');
  await session.getByRole('textbox', { name: 'Label', exact: true }).fill('shell');
  await session.getByRole('button', { name: 'Open session' }).click();
  const terminal = page.getByLabel('Terminal for shell');
  await terminal.click();
  await page.keyboard.type('agent-toolkit version');
  await page.keyboard.press('Enter');
  await expect(terminal.locator('.xterm-rows')).toContainText(/\d+\.\d+/);
  await expect(page.getByRole('region', { name: 'Receipts' }).getByRole('listitem')).toHaveCount(0, {
    timeout: 20_000,
  });

  for (const theme of THEMES) {
    await nav(page).getByRole('link', { name: 'Settings' }).click();
    await page.getByRole('radio', { name: new RegExp(theme === 'paper' ? 'Paper' : 'Ink') }).check();
    await expect(page.locator('html')).toHaveAttribute('data-theme', theme);
    for (const size of SIZES) {
      await setViewport(app, size.width, size.height);
      await expect.poll(() => page.evaluate(() => [innerWidth, innerHeight])).toEqual([size.width, size.height]);
      for (const destination of DESTINATIONS) {
        await nav(page).getByRole('link', { name: destination }).click();
        if (destination === 'Operations') {
          await page.getByRole('button', { name: /^agent-toolkit version/ }).click();
        }
        await settle(page);
        await page.mouse.move(size.width - 1, size.height - 1);
        await page.screenshot({
          path: path.join(OUT_DIR, `${theme}-${size.width}x${size.height}-${destination.toLowerCase()}.png`),
        });
      }
    }
  }
});
