import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';

/**
 * Screenshot tour for design review, not a regression gate. Opt in with
 * ATK_CAPTURE=1; images land in ATK_CAPTURE_DIR (default: the docs assets).
 * Every job and session shown is real, created through the UI.
 */
const CAPTURE = process.env.ATK_CAPTURE === '1';
const WORLD_ONLY = process.env.ATK_CAPTURE_WORLD_ONLY === '1';
const OUT_DIR =
  process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/foundations');

const SIZES = [
  { width: 1024, height: 640 },
  { width: 1920, height: 1080 },
] as const;
const THEMES = ['meadow', 'dusk'] as const;
const DESTINATIONS = WORLD_ONLY
  ? ['World']
  : ([
      'World',
      'Attention',
      'Operations',
      'Workspace',
      'Library',
      'People',
      'Insights',
      'Terminal',
      'Settings',
    ] as const);

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
  await expect(
    page
      .getByRole('status')
      .filter({ hasText: /^(Loading|Checking|Listing|Counting|Discovering|Running|Reading|Comparing|Probing)/ }),
  ).toHaveCount(0, { timeout: 30_000 });
  await page.evaluate(() => document.fonts.ready.then(() => undefined));
}

test('capture every destination in Meadow and Dusk at both sizes', async () => {
  test.setTimeout(10 * 60_000);
  const { app, page } = desktop;
  await waitForBackend(page);
  let createdPerson = false;

  if (!WORLD_ONLY) {
    await startJob(page, 'version');
    await startJob(page, 'workspace');
  }

  let terminal = page.getByLabel('Terminal for shell');
  if (!WORLD_ONLY) {
    await nav(page).getByRole('link', { name: 'Terminal' }).click();
    await page.getByRole('main').getByRole('button', { name: 'New session' }).click();
    const session = page.getByRole('dialog', { name: 'New terminal session' });
    await session.getByRole('textbox', { name: 'Command', exact: true }).fill('/bin/sh');
    await session.getByRole('textbox', { name: 'Label', exact: true }).fill('shell');
    await session.getByRole('button', { name: 'Open session' }).click();
    terminal = page.getByLabel('Terminal for shell');
    await expect(page.getByRole('region', { name: 'Receipts' }).getByRole('listitem')).toHaveCount(0, {
      timeout: 20_000,
    });
  }

  for (const theme of THEMES) {
    await nav(page).getByRole('link', { name: 'Settings' }).click();
    await page.getByRole('radio', { name: new RegExp(theme === 'meadow' ? 'Meadow' : 'Dusk') }).check();
    await expect(page.locator('html')).toHaveAttribute('data-theme', theme);
    for (const size of SIZES) {
      await setViewport(app, size.width, size.height);
      await expect.poll(() => page.evaluate(() => [innerWidth, innerHeight])).toEqual([size.width, size.height]);
      for (const destination of DESTINATIONS) {
        await nav(page).getByRole('link', { name: destination }).click();
        if (destination === 'World') {
          await expect(page.getByRole('application', { name: 'Semantic workspace world' })).toBeVisible();
          // A visible route/header can precede the workspace query. Wait for a
          // real canonical landmark so design-review captures never preserve
          // the loading background as if it were an empty world.
          await expect(page.locator('[data-entity-id="object:library"]')).toBeVisible();
        }
        if (destination === 'People' && !createdPerson) {
          await page.getByRole('button', { name: 'Create Person' }).click();
          const dialog = page.getByRole('dialog', { name: 'Create Person' });
          await dialog.getByRole('textbox', { name: 'Name' }).fill('Lina');
          await dialog.getByRole('textbox', { name: 'ID' }).fill('lina');
          await dialog.getByRole('textbox', { name: 'Role' }).fill('reviewer');
          await dialog.getByRole('textbox', { name: 'Goal' }).fill('Review project changes');
          await page.screenshot({
            path: path.join(OUT_DIR, `${theme}-${size.width}x${size.height}-person-create.png`),
          });
          await dialog.getByRole('button', { name: 'Create Person' }).click();
          await expect(dialog).toBeHidden();
          await expect(page.getByRole('button', { name: /Lina.*reviewer.*Offline/ })).toBeVisible();
          await page.locator('input[aria-label="Choose Munder hire JSON"]').setInputFiles({
            name: 'maya.json',
            mimeType: 'application/json',
            buffer: Buffer.from(
              JSON.stringify({
                spec: 'munder-difflin/hire@1',
                id: 'maya',
                name: 'Maya',
                role: 'architect',
                goal: 'Plan project work',
                provider: 'opencode',
                skills: ['planning'],
                command: 'ignored and never executed',
              }),
            ),
          });
          const importDialog = page.getByRole('dialog', { name: 'Review Munder import' });
          await expect(importDialog).toContainText('command');
          await page.screenshot({
            path: path.join(OUT_DIR, `${theme}-${size.width}x${size.height}-munder-import-review.png`),
          });
          await importDialog.getByRole('button', { name: 'Save Person' }).click();
          await expect(importDialog).toBeHidden();
          await expect(page.getByRole('button', { name: /Maya.*architect.*Offline/ })).toBeVisible();
          await page.locator('input[aria-label="Choose Munder hire JSON"]').setInputFiles({
            name: 'june.json',
            mimeType: 'application/json',
            buffer: Buffer.from(
              JSON.stringify({
                spec: 'munder-difflin/hire@1',
                id: 'june',
                name: 'June',
                role: 'designer',
                goal: 'Design screens',
              }),
            ),
          });
          await importDialog.getByRole('button', { name: 'Edit before saving' }).click();
          const importedForm = page.getByRole('dialog', { name: 'Create Person' });
          await importedForm.getByRole('textbox', { name: 'Goal' }).fill('Design the workspace interface');
          await importedForm.getByRole('button', { name: 'Create Person' }).click();
          await expect(importedForm).toBeHidden();
          await expect(page.getByRole('button', { name: /June.*designer.*Offline/ })).toBeVisible();
          createdPerson = true;
        }
        if (destination === 'Operations') {
          await page.getByRole('button', { name: /^agent-toolkit version/ }).click();
        }
        await settle(page);
        if (!WORLD_ONLY && destination === 'Terminal') {
          await terminal.click();
          // Keep the published visual evidence useful as a real workstation:
          // show the actual workspace directory and bundled backend version.
          // Clear the terminal on each size/theme capture because the renderer
          // can remount xterm when its viewport or color scheme changes.
          await page.keyboard.type('clear && pwd && agent-toolkit version');
          await page.keyboard.press('Enter');
          await expect(terminal.locator('.xterm-rows')).toContainText(/agent-toolkit \d+\.\d+\.\d+/);
        }
        await page.mouse.move(size.width - 1, size.height - 1);
        await page.screenshot({
          path: path.join(OUT_DIR, `${theme}-${size.width}x${size.height}-${destination.toLowerCase()}.png`),
        });
      }
    }
  }

  // Capture opens a real PTY for the terminal screenshots. Close it through
  // the same reviewed UI action as a user so the Electron process and backend
  // can shut down promptly after the tour.
  if (!WORLD_ONLY) {
    await nav(page).getByRole('link', { name: 'Terminal' }).click();
    await page.getByRole('button', { name: 'Close' }).click();
    const closeDialog = page.getByRole('dialog', { name: 'Close this session?' });
    await closeDialog.getByRole('button', { name: 'Kill and close' }).click();
    await expect(page.getByRole('tab', { name: /shell.*running/ })).toHaveCount(0);
  }
});
