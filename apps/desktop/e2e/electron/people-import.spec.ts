import fs from 'node:fs';
import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';

const CAPTURE = process.env.ATK_CAPTURE === '1';
const CAPTURE_DIR = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/people');

let desktop: Desktop;

test.beforeEach(async () => {
  desktop = await openDesktop();
  await waitForBackend(desktop.page);
  await desktop.page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
});

test.afterEach(async () => {
  if (desktop) await desktop.close();
});

function hire(name = 'Lina') {
  return {
    spec: 'munder-difflin/hire@1',
    id: name.toLowerCase(),
    name,
    role: 'Senior Reviewer',
    goal: 'Review changes before they merge',
    provider: 'opencode',
    model: 'gpt-5',
    capabilities: ['review'],
    skills: ['code-review'],
    mcp_servers: ['github'],
    command: 'must never execute',
    auto_spawn: true,
  };
}

async function importFile(page: Page, content: string, name = 'hire.json') {
  await page.locator('input[aria-label="Choose Munder hire JSON"]').setInputFiles({
    name,
    mimeType: 'application/json',
    buffer: Buffer.from(content),
  });
}

test('Munder import explains malformed files and recovers from Person ID collisions', async () => {
  const { page } = desktop;
  await importFile(page, '{broken json', 'broken.json');
  const error = page.getByRole('alert').filter({ hasText: 'Could not review import' });
  await expect(error).toContainText('Import file is not valid JSON');
  await expect(page.getByRole('dialog', { name: 'Review Munder import' })).toHaveCount(0);
  await expect(page.getByRole('region', { name: 'Roster' })).not.toContainText('Lina');

  const source = JSON.stringify(hire());
  await importFile(page, source);
  const firstReview = page.getByRole('dialog', { name: 'Review Munder import' });
  await expect(firstReview).toContainText(/auto_spawn.*command/);
  await expect(firstReview).toContainText('MCP references');
  await expect(firstReview).toContainText('github');
  await expect(firstReview).toContainText('Import never starts a session');
  await firstReview.getByRole('button', { name: 'Save Person' }).click();
  await expect(firstReview).toBeHidden();
  await expect(page.getByRole('region', { name: 'Roster' })).toContainText('Lina');

  await importFile(page, source, 'lina-copy.json');
  const collision = page.getByRole('dialog', { name: 'Review Munder import' });
  await expect(collision).toContainText('lina');
  await collision.getByRole('button', { name: 'Save Person' }).click();
  await expect(collision.getByRole('alert')).toContainText('Could not save imported Person');
  await expect(collision).toContainText('person already exists');

  if (CAPTURE) {
    fs.mkdirSync(CAPTURE_DIR, { recursive: true });
    for (const size of [
      { width: 1024, height: 768, key: 'munder-import-collision-compact' },
      { width: 1600, height: 1000, key: 'munder-import-collision-large' },
    ]) {
      await setViewport(desktop.app, size.width, size.height);
      await page.setViewportSize({ width: size.width, height: size.height });
      await page.screenshot({ path: path.join(CAPTURE_DIR, `${size.key}.png`), fullPage: true });
    }
    await setViewport(desktop.app, 1280, 800);
    await page.setViewportSize({ width: 1280, height: 800 });
  }

  await collision.getByRole('button', { name: 'Edit before saving' }).click();
  const edit = page.getByRole('dialog', { name: 'Create Person' });
  await expect(edit.getByRole('alert')).toHaveCount(0);
  await expect(edit.getByRole('textbox', { name: 'ID' })).toHaveValue('lina');
  await edit.getByRole('textbox', { name: 'ID' }).fill('lina-reviewer');
  await edit.getByRole('button', { name: 'Create Person' }).click();
  await expect(edit).toBeHidden();
  await expect(page.getByRole('region', { name: 'Roster' })).toContainText('Lina');
  await expect(page.getByRole('button', { name: /Lina.*senior-reviewer/i })).toHaveCount(2);
});
