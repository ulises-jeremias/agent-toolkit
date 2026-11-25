import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';
import { goTo } from './navigation';

/**
 * Migration-boundary journey for the archived Toolkit Desktop source:
 * workspace context and Person records stay user-owned, while new coding-agent
 * delegation is explicitly handled by Veasel Code instead of Swarm v1.
 */
test('preserves Toolkit workspace data and directs new coding work to Veasel Code', async () => {
  const desktop: Desktop = await openDesktop();
  const { page, workspace } = desktop;
  try {
    await waitForBackend(page);
    const packDir = path.join(workspace, 'packs');
    fs.mkdirSync(packDir, { recursive: true });
    fs.writeFileSync(
      path.join(packDir, 'team.yaml'),
      'name: Product Team\ndescription: Shared project context for product work.\nprojects: []\n',
    );
    await goTo(page, 'Context');
    const packs = page.getByRole('region', { name: 'Workspace context packs' });
    await expect(packs).toContainText('Product Team');
    await packs.getByRole('button', { name: 'Use for future sessions' }).first().click();
    await expect(packs.getByText('Context selected')).toBeVisible();
    await expect
      .poll(() => fs.readFileSync(path.join(workspace, '.active-pack'), 'utf8').trim())
      .toBe('packs/team.yaml');

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.getByRole('button', { name: 'Create Person' }).click();
    const person = page.getByRole('dialog', { name: 'Create Person' });
    await person.getByRole('textbox', { name: 'Name' }).fill('Mara');
    await person.getByRole('textbox', { name: 'ID' }).fill('mara');
    await person.getByRole('textbox', { name: 'Role' }).fill('implementer');
    await person.getByRole('textbox', { name: 'Goal' }).fill('Portable collaborator data remains user-owned');
    await person.getByRole('button', { name: 'Create Person' }).click();
    await expect(person).toBeHidden();
    await expect.poll(() => fs.readFileSync(path.join(workspace, 'people', 'mara.json'), 'utf8')).toContain('Mara');

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
    await expect(page.getByRole('region', { name: 'Swarms' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Start swarm' })).toHaveCount(0);
    await expect(page.getByText('New coding-agent delegation runs in Veasel Code.')).toBeVisible();
  } finally {
    await desktop.close();
  }
});
