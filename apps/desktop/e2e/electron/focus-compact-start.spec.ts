import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';
import { goTo } from './navigation';

test('Focus start composer keeps the task and primary action visible in a compact Electron window', async () => {
  const fakeProviderBin = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-provider-'));
  const originalPath = process.env['PATH'] ?? '';
  const providerShim = path.join(fakeProviderBin, 'claude');
  fs.writeFileSync(
    providerShim,
    '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "Claude Code 1.0.0"; exit 0; fi\nif [ "$1" = "auth" ] && [ "$2" = "status" ]; then echo \'{"loggedIn":true,"authMethod":"claude.ai"}\'; exit 0; fi\nexit 1\n',
  );
  fs.chmodSync(providerShim, 0o755);
  process.env['PATH'] = [fakeProviderBin, originalPath].filter(Boolean).join(path.delimiter);
  let desktop: Awaited<ReturnType<typeof openDesktop>> | null = null;
  try {
    desktop = await openDesktop();
    const { app, page, home } = desktop;
    await waitForBackend(page);

    const repository = path.join(home, 'code', 'compact-focus');
    fs.mkdirSync(repository, { recursive: true });
    execFileSync('git', ['init', '--quiet', repository]);
    execFileSync(
      'git',
      [
        '-C',
        repository,
        '-c',
        'user.name=Compact Focus',
        '-c',
        'user.email=focus@example.invalid',
        'commit',
        '--allow-empty',
        '-m',
        'Initial',
      ],
      { stdio: 'pipe' },
    );
    await desktop.app.evaluate(({ dialog }, selected) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [selected] });
    }, repository);
    await goTo(page, 'Projects');
    await page.getByRole('button', { name: 'Link a repository' }).click();
    await expect(page.getByRole('button', { name: /^compact-focus(?:\s|$)/ })).toBeVisible();
    await page.getByRole('button', { name: 'Dismiss: Linked compact-focus' }).click();

    await goTo(page, 'Focus');
    await setViewport(app, 1024, 640);
    await page.getByRole('button', { name: 'Check again' }).click();
    await expect(page.getByRole('radio', { name: /^Claude Code\b/ })).toBeEnabled();
    await page.getByRole('radio', { name: /^Claude Code\b/ }).check();
    await expect(page.getByLabel('Project', { exact: true })).toHaveValue('compact-focus');
    await page.getByRole('textbox', { name: 'Task' }).fill('Review the current project changes');
    await expect(page.getByRole('textbox', { name: 'Task' })).toHaveValue('Review the current project changes');

    const start = page.locator('form[aria-labelledby="focus-start-title"]');
    const startButton = page.getByRole('button', { name: 'Start session' });
    await expect(startButton).toBeEnabled();
    await expect(startButton).toBeInViewport();
    const layout = await start.evaluate((form) => {
      const rect = form.getBoundingClientRect();
      const button = form.querySelector('button[type="submit"]')?.getBoundingClientRect();
      return {
        scrollTop: form.scrollTop,
        scrollHeight: form.scrollHeight,
        clientHeight: form.clientHeight,
        formBottom: rect.bottom,
        buttonBottom: button?.bottom ?? Number.POSITIVE_INFINITY,
        viewportHeight: window.innerHeight,
      };
    });
    expect(layout.scrollTop).toBe(0);
    expect(layout.scrollHeight).toBeLessThanOrEqual(layout.clientHeight + 1);
    expect(layout.buttonBottom).toBeLessThanOrEqual(layout.viewportHeight);
    expect(layout.formBottom).toBeLessThanOrEqual(layout.viewportHeight);

    const captureDir = process.env['ATK_CAPTURE_DIR'];
    if (captureDir) {
      fs.mkdirSync(captureDir, { recursive: true });
      await page.evaluate(() => document.fonts.ready.then(() => undefined));
      await page.screenshot({ path: path.join(captureDir, 'focus-start-1024x640.png') });
      await setViewport(app, 1440, 900);
      await page.evaluate(() => document.fonts.ready.then(() => undefined));
      await page.screenshot({ path: path.join(captureDir, 'focus-start-1440x900.png') });
    }
  } finally {
    try {
      await desktop?.close();
    } finally {
      process.env['PATH'] = originalPath;
      fs.rmSync(fakeProviderBin, { recursive: true, force: true });
    }
  }
});
