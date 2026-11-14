import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop } from './fixtures';

test('onboarding signs in through an ephemeral Electron PTY and rechecks provider status', async () => {
  test.skip(process.platform === 'win32', 'The disposable provider fixture uses a POSIX executable script.');

  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-provider-signin-e2e-'));
  const binDir = path.join(root, 'bin');
  const fakeProviderState = path.join(root, 'authenticated');
  const fakeProviderOutput = 'FAKE_AUTH_OUTPUT_SECRET_MARKER';
  fs.mkdirSync(binDir);
  const fakeProvider = path.join(binDir, 'claude');
  fs.writeFileSync(
    fakeProvider,
    `#!/bin/sh
if [ "$1" = "--version" ]; then
  printf '2.1.0\\n'
  exit 0
fi
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  if [ -f "$FAKE_CLAUDE_STATE" ]; then
    printf '{"loggedIn":true,"authMethod":"api"}\\n'
  else
    printf '{"loggedIn":false}\\n'
  fi
  exit 0
fi
if [ "$1" = "auth" ] && [ "$2" = "login" ]; then
  printf 'FAKE_AUTH_OUTPUT_SECRET_MARKER\\nEnter the test code: '
  IFS= read -r code
  if [ "$code" = "test-code" ]; then
    : > "$FAKE_CLAUDE_STATE"
    printf 'Sign-in complete.\\n'
    exit 0
  fi
  printf 'Invalid test code.\\n'
  exit 1
fi
exit 2
`,
    { mode: 0o700 },
  );

  const previous = {
    path: process.env['PATH'],
    state: process.env['FAKE_CLAUDE_STATE'],
    backend: process.env['ATK_E2E_BACKEND_BIN'],
    systemctlShim: process.env['ATK_E2E_SYSTEMCTL_SHIM'],
  };
  process.env['PATH'] = [binDir, previous.path].filter(Boolean).join(path.delimiter);
  process.env['FAKE_CLAUDE_STATE'] = fakeProviderState;
  // openDesktop deliberately puts this directory before the backend's bin dir.
  process.env['ATK_E2E_SYSTEMCTL_SHIM'] = binDir;
  process.env['ATK_E2E_BACKEND_BIN'] ??= '/usr/bin/agent-toolkit';

  let desktop: Awaited<ReturnType<typeof openDesktop>> | null = null;
  try {
    desktop = await openDesktop({ skipOnboarding: false });
    const { page } = desktop;
    await expect(page.getByRole('heading', { name: 'Set up Agent Toolkit' })).toBeVisible();

    const provider = page.getByText('Claude Code', { exact: true }).locator('..');
    await expect(provider).toContainText('Not signed in');
    await provider.getByRole('button', { name: 'Sign in' }).click();

    const dialog = page.getByRole('dialog', { name: 'Sign in to Claude Code' });
    await expect(dialog).toBeVisible();
    await expect(dialog.getByLabel('Temporary provider sign-in terminal')).toBeVisible();
    await dialog.locator('.xterm').click();
    await page.keyboard.type('test-code');
    await page.keyboard.press('Enter');
    await expect(dialog.getByRole('status')).toContainText('exited with code 0');
    await dialog.getByRole('button', { name: 'Close and check connection' }).click();

    await expect(page.getByRole('dialog')).toHaveCount(0);
    await expect(provider).toContainText('Signed in with an API account');
    expect(fs.existsSync(fakeProviderState)).toBe(true);
    expect(await page.evaluate(() => window.atk?.ptyList() ?? [])).toEqual([]);

    const ptyRuntime = path.join(desktop.root, 'pty-runtime');
    const runtimeFiles = fs.readdirSync(ptyRuntime).filter((name) => name !== 'pty-host.sock');
    expect(runtimeFiles.filter((name) => name.startsWith('pty-') && name.endsWith('.log'))).toEqual([]);
    const runtimeContents = runtimeFiles
      .filter((name) => fs.statSync(path.join(ptyRuntime, name)).isFile())
      .map((name) => fs.readFileSync(path.join(ptyRuntime, name), 'utf8'))
      .join('\n');
    expect(runtimeContents).not.toContain(fakeProviderOutput);
  } finally {
    if (desktop) await desktop.close();
    if (previous.path === undefined) delete process.env['PATH'];
    else process.env['PATH'] = previous.path;
    if (previous.state === undefined) delete process.env['FAKE_CLAUDE_STATE'];
    else process.env['FAKE_CLAUDE_STATE'] = previous.state;
    if (previous.backend === undefined) delete process.env['ATK_E2E_BACKEND_BIN'];
    else process.env['ATK_E2E_BACKEND_BIN'] = previous.backend;
    if (previous.systemctlShim === undefined) delete process.env['ATK_E2E_SYSTEMCTL_SHIM'];
    else process.env['ATK_E2E_SYSTEMCTL_SHIM'] = previous.systemctlShim;
    fs.rmSync(root, { recursive: true, force: true });
  }
});
