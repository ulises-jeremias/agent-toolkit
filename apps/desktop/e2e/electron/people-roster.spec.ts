import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

const CAPTURE = process.env.ATK_CAPTURE === '1';
const CAPTURE_DIR =
  process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/people');

test('People can edit durable identity and archive or restore while remaining offline', async () => {
  const desktop = await openDesktop();
  try {
    const { app, page } = desktop;
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();

    await page.getByRole('button', { name: 'Create Person' }).click();
    const create = page.getByRole('dialog', { name: 'Create Person' });
    await create.getByRole('textbox', { name: 'Name' }).fill('Milo');
    await create.getByRole('textbox', { name: 'ID' }).fill('milo-builder');
    await create.getByRole('textbox', { name: 'Role' }).fill('toolsmith');
    await create.getByRole('textbox', { name: 'Goal' }).fill('Keep project tools useful and easy to reach.');
    await create.getByRole('button', { name: 'Create Person' }).click();
    await expect(create).toBeHidden();
    const card = page.getByRole('button', { name: /Milo.*toolsmith.*Offline/ });
    await expect(card).toBeVisible();
    await card.click();
    await expect(page.getByText('Configured · offline')).toBeVisible();

    await page.getByRole('button', { name: 'Edit Person' }).click();
    const edit = page.getByRole('dialog', { name: 'Edit Milo' });
    await edit.getByRole('textbox', { name: 'Goal' }).fill('Maintain reliable project tools and workflows.');
    await edit.getByText('Runner and appearance').click();
    await edit.getByRole('combobox', { name: 'Character' }).selectOption('maker');
    if (CAPTURE) {
      fs.mkdirSync(CAPTURE_DIR, { recursive: true });
      for (const size of [
        { width: 1024, height: 768, key: 'people-roster-edit-compact' },
        { width: 1600, height: 1000, key: 'people-roster-edit-large' },
      ]) {
        await setViewport(app, size.width, size.height);
        await page.setViewportSize({ width: size.width, height: size.height });
        await page.screenshot({ path: path.join(CAPTURE_DIR, `${size.key}.png`), fullPage: true });
      }
    }
    await edit.getByRole('button', { name: 'Save changes' }).click();
    await expect(edit).toBeHidden();
    await expect(page.getByText('Maintain reliable project tools and workflows.')).toBeVisible();
    await expect(page.getByRole('button', { name: /Milo.*toolsmith.*Offline/ })).toBeVisible();

    await page.getByRole('button', { name: 'Archive' }).click();
    const archive = page.getByRole('dialog', { name: 'Archive Milo?' });
    await expect(archive).toContainText('No session is started or stopped');
    await archive.getByRole('button', { name: 'Archive' }).click();
    await expect(page.getByRole('button', { name: /Milo.*toolsmith.*Archived/ })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Start Milo' })).toHaveCount(0);

    await page.getByRole('button', { name: 'Restore' }).click();
    const restore = page.getByRole('dialog', { name: 'Restore Milo?' });
    await expect(restore).toContainText('does not start a session');
    await restore.getByRole('button', { name: 'Restore' }).click();
    await expect(page.getByRole('button', { name: /Milo.*toolsmith.*Offline/ })).toBeVisible();
    await expect(page.getByText('Configured · offline')).toBeVisible();
  } finally {
    await desktop.close();
  }
});
