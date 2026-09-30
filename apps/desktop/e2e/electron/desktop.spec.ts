import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend, type Desktop } from './fixtures';

const DESTINATIONS: ReadonlyArray<{ link: string; path: string }> = [
  { link: 'Office', path: '/office' },
  { link: 'Operations', path: '/operations' },
  { link: 'Workspace', path: '/workspace' },
  { link: 'Library', path: '/library' },
  { link: 'Insights', path: '/insights' },
  { link: 'Terminal', path: '/terminal' },
  { link: 'Settings', path: '/settings' },
];

test.describe.configure({ mode: 'serial' });

let desktop: Desktop;

test.beforeAll(async () => {
  desktop = await openDesktop();
});

test.afterAll(async () => {
  await desktop?.close();
});

test('supervisor starts the real backend and the shell connects', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await expect(page.getByRole('heading', { level: 1, name: 'What needs you' })).toBeVisible();
  await expect(page.getByRole('alert')).toHaveCount(0);
});

test('the context bar shows the default ~/.ai-workspace harness', async () => {
  const { page, workspace } = desktop;
  const bar = page.getByRole('form', { name: 'Session context' });
  await expect(bar.getByLabel('Workspace')).toHaveValue(workspace);
  await expect(bar).toContainText('default');
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
  await expect(page.getByRole('region', { name: 'Backend' })).toContainText(`${workspace} (default)`);
  await expect(page.getByText('Harness notice')).toHaveCount(0);
});

test('Ctrl+K opens the command palette and keeps session context', async () => {
  const { page, workspace } = desktop;
  await page.keyboard.press('Control+k');
  const dialog = page.getByRole('dialog', { name: 'Commands' });
  await expect(dialog).toBeVisible();
  await dialog.getByLabel('Filter commands').fill('settings');
  await page.keyboard.press('Enter');
  await expect(dialog).toBeHidden();
  await expect(page).toHaveURL(/#\/settings/);
  await expect(page).toHaveURL(new RegExp(`workspace=${encodeURIComponent(workspace)}`));
});

test('every destination renders from live data without a crash boundary', async () => {
  const { page } = desktop;
  const nav = page.getByRole('navigation', { name: 'Destinations' });
  for (const destination of DESTINATIONS) {
    await nav.getByRole('link', { name: destination.link }).click();
    await expect(page).toHaveURL(new RegExp(`#${destination.path}`));
    await expect(nav.getByRole('link', { name: destination.link })).toHaveAttribute('aria-current', 'page');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByText(/stopped working/i)).toHaveCount(0);
  }
});

test('workspace reads the scratch workspace through the backend', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
  await expect(page.getByRole('region', { name: 'Context budget' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Personas' })).toContainText(/architect|implementer/);
});

test('a job started from Operations runs on the backend and streams to completion', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start job' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a job' });
  await expect(dialog).toBeVisible();
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('version');
  await expect(dialog.getByText('agent-toolkit version', { exact: true })).toBeVisible();
  await dialog.getByRole('button', { name: 'Start job' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText('Job started');
  await expect(page).toHaveURL(/job=/);

  const detail = page.getByRole('region', { name: 'version' });
  await expect(detail.getByText('completed')).toBeVisible();
  await expect(detail.getByText(/\d+\.\d+\.\d+/).first()).toBeVisible();
});

test('dialogs focus their first field and Escape returns focus to the trigger', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  const trigger = page.getByRole('button', { name: 'Start job' });
  await trigger.focus();
  await page.keyboard.press('Enter');
  const dialog = page.getByRole('dialog', { name: 'Start a job' });
  await expect(dialog.getByRole('textbox', { name: 'Command', exact: true })).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();
  await expect(trigger).toBeFocused();
});

test('theme choice applies immediately and survives a reload', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Settings' }).click();
  await page.getByRole('radio', { name: /Ink/ }).check();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'ink');
  await page.reload();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'ink');
  await page.getByRole('radio', { name: /Paper/ }).check();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'paper');
});

test('terminal runs a real pseudo-terminal session that survives navigation', async () => {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Terminal' }).click();
  await page.getByRole('main').getByRole('button', { name: 'New session' }).click();
  const dialog = page.getByRole('dialog', { name: 'New terminal session' });
  await dialog.getByRole('textbox', { name: 'Command', exact: true }).fill('/bin/sh');
  await dialog.getByRole('textbox', { name: 'Label', exact: true }).fill('e2e-shell');
  await dialog.getByRole('button', { name: 'Open session' }).click();

  await expect(page.getByRole('tab', { name: /e2e-shell/ })).toHaveAttribute('aria-selected', 'true');
  const terminal = page.getByLabel('Terminal for e2e-shell');
  await terminal.click();
  await page.keyboard.type('echo atk-e2e-$((40+2))');
  await page.keyboard.press('Enter');
  await expect(terminal.locator('.xterm-rows')).toContainText('atk-e2e-42');

  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Office' }).click();
  const dock = page.getByRole('complementary', { name: 'Terminal dock' });
  await expect(dock.getByRole('tab', { name: /e2e-shell/ })).toBeVisible();
  await expect(dock.getByLabel('Terminal for e2e-shell').locator('.xterm-rows')).toContainText('atk-e2e-42');
});
