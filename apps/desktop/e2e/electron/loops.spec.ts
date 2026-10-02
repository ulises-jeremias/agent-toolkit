import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

const CAPTURE_DIR = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/loops');

test('adds a loop from the Library template, runs it, and reads its typed report', async () => {
  test.skip(process.platform !== 'linux', 'The isolated scheduler lifecycle uses Linux systemd units.');
  const fakeBin = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-fake-systemctl-'));
  const fakeSystemctl = path.join(fakeBin, 'systemctl');
  fs.writeFileSync(
    fakeSystemctl,
    '#!/bin/sh\nif [ -f "$HOME/fail-enable" ] && [ "$2" = enable ]; then echo "scheduler fixture failure" >&2; exit 1; fi\nif [ -f "$HOME/fail-stop" ] && [ "$2" = stop ]; then echo "scheduler fixture failure" >&2; exit 1; fi\nexit 0\n',
    { mode: 0o755 },
  );
  const previousPath = process.env.PATH;
  const previousShim = process.env.ATK_E2E_SYSTEMCTL_SHIM;
  process.env.PATH = `${fakeBin}${path.delimiter}${previousPath ?? ''}`;
  process.env.ATK_E2E_SYSTEMCTL_SHIM = fakeBin;
  let desktop: Awaited<ReturnType<typeof openDesktop>> | undefined;
  try {
    desktop = await openDesktop();
    const { page } = desktop;
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
    const loops = page.getByRole('region', { name: 'Loops' });
    await expect(loops).toBeVisible();

    await loops.getByRole('button', { name: 'daily-triage' }).click({ timeout: 5_000 });
    await loops.getByRole('button', { name: 'Add to workspace' }).click();
    const add = page.getByRole('dialog', { name: 'Add daily-triage to this workspace' });
    await expect(add.getByText('loops/daily-triage/loop.yaml')).toBeVisible();
    await add.getByRole('button', { name: 'Create loop' }).click();
    await expect(add).toBeHidden();

    await expect(loops).toContainText('Loop report');
    await expect(loops).toContainText('Goal');
    await expect(loops).toContainText('Token budget');
    await expect(loops.getByRole('region', { name: 'daily-triage run history' })).toContainText('No run records yet.');
    await loops.getByRole('button', { name: 'Manage schedule' }).click();
    const schedule = page.getByRole('dialog', { name: 'Schedule daily-triage' });
    await expect(schedule).toContainText('No scheduled loops found.');
    await schedule.getByRole('button', { name: 'Review install' }).click();
    await expect(schedule.getByRole('region', { name: 'Schedule change preview' })).toContainText('schedule dry-run');
    await expect(schedule.getByRole('region', { name: 'Schedule change preview' })).toContainText(
      'agent-toolkit-loop-daily-triage.service',
    );
    if (process.env.ATK_CAPTURE === '1') {
      await page.evaluate(() => document.fonts.ready.then(() => undefined));
      await page.setViewportSize({ width: 1024, height: 640 });
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-schedule-preview-compact.png') });
      await page.setViewportSize({ width: 1920, height: 1080 });
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-schedule-preview-large.png') });
    }
    await schedule.getByText('View generated scheduler details').click();
    await expect(schedule).toContainText('Would enable: systemctl --user enable');
    fs.writeFileSync(path.join(desktop.home, 'fail-enable'), 'fail');
    await schedule.getByRole('button', { name: 'Install schedule' }).click();
    await expect(schedule).toContainText('Enable failed');
    fs.rmSync(path.join(desktop.home, 'fail-enable'), { force: true });
    await schedule.getByRole('button', { name: 'Install schedule' }).click();
    await expect(schedule).toContainText('Scheduled loops:');
    await expect(schedule).toContainText('daily-triage');
    await schedule.getByRole('button', { name: 'Review disable' }).click();
    await expect(schedule.getByRole('region', { name: 'Schedule change preview' })).toContainText(
      'agent-toolkit-loop-daily-triage.service',
    );
    fs.writeFileSync(path.join(desktop.home, 'fail-stop'), 'fail');
    await schedule.getByRole('button', { name: 'Disable schedule' }).click();
    await expect(schedule).toContainText('Could not stop agent-toolkit-loop-daily-triage.timer');
    await expect(schedule).toContainText('scheduler files were kept');
    await expect(schedule).toContainText('daily-triage');
    if (process.env.ATK_CAPTURE === '1') {
      await page.setViewportSize({ width: 1024, height: 640 });
      await schedule.getByText(/Could not stop agent-toolkit-loop-daily-triage/).scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-schedule-recovery-compact.png') });
      await page.setViewportSize({ width: 1920, height: 1080 });
      await schedule.getByText(/Could not stop agent-toolkit-loop-daily-triage/).scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-schedule-recovery-large.png') });
      await page.setViewportSize({ width: 1024, height: 640 });
    }
    fs.rmSync(path.join(desktop.home, 'fail-stop'), { force: true });
    await schedule.getByRole('button', { name: 'Retry disable' }).click();
    await expect(schedule).toContainText('No scheduled loops found.');
    await schedule.getByRole('button', { name: 'Close' }).click();

    if (process.env.ATK_CAPTURE === '1') {
      const receipts = page.locator('button[aria-label^="Dismiss:"]');
      while ((await receipts.count()) > 0) await receipts.first().click();
      await page.evaluate(() => document.fonts.ready.then(() => undefined));
      await page.setViewportSize({ width: 1024, height: 640 });
      await loops.getByRole('heading', { name: 'daily-triage' }).scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-report-compact.png') });
      await page.setViewportSize({ width: 1920, height: 1080 });
      await loops.getByRole('heading', { name: 'daily-triage' }).scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-report-large.png') });
    }

    await loops.getByRole('button', { name: 'Run once' }).click();
    const run = page.getByRole('dialog', { name: 'Run a loop once' });
    await expect(run).toContainText(/does not create a schedule/i);
    await run.getByRole('button', { name: 'Run loop' }).click();
    await expect(run).toBeHidden();
    await expect(loops.getByRole('region', { name: 'daily-triage run history' })).toContainText(/completed|failed/, {
      timeout: 45_000,
    });
    await expect(loops.getByRole('region', { name: 'daily-triage audit' })).toContainText('Completed');
    await expect(loops.getByRole('region', { name: 'daily-triage cost report' })).toContainText('Unavailable');
    if (process.env.ATK_CAPTURE === '1') {
      const receipts = page.locator('button[aria-label^="Dismiss:"]');
      while ((await receipts.count()) > 0) await receipts.first().click();
      await page.screenshot({ path: path.join(CAPTURE_DIR, 'loop-report-after-run.png') });
    }
  } finally {
    process.env.PATH = previousPath;
    if (previousShim === undefined) delete process.env.ATK_E2E_SYSTEMCTL_SHIM;
    else process.env.ATK_E2E_SYSTEMCTL_SHIM = previousShim;
    await desktop?.close();
    fs.rmSync(fakeBin, { recursive: true, force: true });
  }
});
