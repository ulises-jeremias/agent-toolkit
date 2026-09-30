import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { _electron as electron, expect, type ElectronApplication, type Page } from '@playwright/test';

const APP_DIR = path.resolve(__dirname, '..', '..');
const REPO_ROOT = path.resolve(APP_DIR, '..', '..');

/**
 * The real V backend. CI builds it into dist/; locally any binary works via
 * ATK_E2E_BACKEND_BIN. This suite never builds V.
 */
function backendBinary(): string {
  const candidates = [
    process.env.ATK_E2E_BACKEND_BIN,
    path.join(REPO_ROOT, 'dist', 'agent-toolkit'),
    path.join(REPO_ROOT, 'build', 'agent-toolkit'),
  ].filter((candidate): candidate is string => Boolean(candidate));
  const found = candidates.find((candidate) => fs.existsSync(candidate));
  if (!found) {
    throw new Error(
      `No agent-toolkit backend binary. Build one into dist/ or set ATK_E2E_BACKEND_BIN. Looked in: ${candidates.join(', ')}`,
    );
  }
  return found;
}

function assertBuilt(): void {
  for (const required of ['dist/index.html', 'dist-electron/main.js']) {
    if (!fs.existsSync(path.join(APP_DIR, required))) {
      throw new Error(`Missing ${required}. Run \`pnpm build:all\` before the electron project.`);
    }
  }
}

export interface Desktop {
  app: ElectronApplication;
  page: Page;
  /** Scratch workspace scaffolded by the real CLI; the backend's cwd. */
  workspace: string;
  close: () => Promise<void>;
}

/**
 * Launches the built app against the real backend inside a throwaway HOME
 * and workspace, so runs never read or write the developer's own state.
 */
export async function openDesktop(): Promise<Desktop> {
  assertBuilt();
  const backendBin = backendBinary();
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-desktop-e2e-'));
  const home = path.join(root, 'home');
  // The default harness, so the supervisor resolves it without an override.
  const workspace = path.join(home, '.ai-workspace');
  fs.mkdirSync(home, { recursive: true });

  // Harness overrides from the developer's shell would point at their real workspace.
  const dropped = new Set(['ELECTRON_RUN_AS_NODE', 'AGENT_TOOLKIT_WORKSPACE', 'HARNESS_DIR']);
  const env: Record<string, string> = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (value !== undefined && !dropped.has(key)) env[key] = value;
  }
  env['HOME'] = home;
  env['XDG_CONFIG_HOME'] = path.join(home, '.config');
  env['XDG_DATA_HOME'] = path.join(home, '.local', 'share');
  env['PATH'] = `${path.dirname(backendBin)}${path.delimiter}${process.env.PATH ?? ''}`;
  env['NO_COLOR'] = '1';

  execFileSync(backendBin, ['workspace', 'init', '--dir', workspace], {
    env,
    stdio: 'pipe',
  });

  const args = [APP_DIR, `--user-data-dir=${path.join(root, 'user-data')}`];
  // GitHub runners have no setuid sandbox helper for Chromium.
  if (process.env.CI) args.push('--no-sandbox');
  const app = await electron.launch({ args, cwd: workspace, env });
  const page = await app.firstWindow();
  await page.waitForLoadState('domcontentloaded');

  return {
    app,
    page,
    workspace,
    close: async () => {
      await app.close();
      fs.rmSync(root, { recursive: true, force: true });
    },
  };
}

export async function waitForBackend(page: Page): Promise<void> {
  await expect(page.getByRole('status').filter({ hasText: /^(Connected|Live)/ })).toBeVisible({ timeout: 30_000 });
}

/** Resize the window's content area; Xvfb has no window manager to clamp it. */
export async function setViewport(app: ElectronApplication, width: number, height: number): Promise<void> {
  await app.evaluate(
    ({ BrowserWindow }, size) => {
      const [win] = BrowserWindow.getAllWindows();
      win?.setContentSize(size.width, size.height);
    },
    { width, height },
  );
}
