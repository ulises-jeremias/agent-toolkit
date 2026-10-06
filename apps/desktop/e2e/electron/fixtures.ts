import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { _electron as electron, expect, type ElectronApplication, type Page } from '@playwright/test';

const APP_DIR = path.resolve(__dirname, '..', '..');
const REPO_ROOT = path.resolve(APP_DIR, '..', '..');
const packagedApp = process.env.ATK_E2E_APP_PATH;

/**
 * The real V backend. CI builds it into dist/; locally any binary works via
 * ATK_E2E_BACKEND_BIN. This suite never builds V.
 */
function backendBinary(): string {
  const candidates = [
    process.env.ATK_E2E_BACKEND_BIN,
    packagedApp ? path.join(path.dirname(packagedApp), 'resources', 'bin', 'agent-toolkit') : undefined,
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
  if (packagedApp) {
    if (!fs.existsSync(packagedApp)) throw new Error(`Missing packaged Desktop: ${packagedApp}`);
    return;
  }
  for (const required of ['dist/index.html', 'dist-electron/main.js']) {
    if (!fs.existsSync(path.join(APP_DIR, required))) {
      throw new Error(`Missing ${required}. Run \`pnpm build:all\` before the electron project.`);
    }
  }
}

export interface Desktop {
  app: ElectronApplication;
  page: Page;
  /** Scratch HOME; the default harness is `$HOME/.ai-workspace` when created. */
  home: string;
  /** Scratch workspace scaffolded by the real CLI when `initWorkspace` is true. */
  workspace: string;
  close: () => Promise<void>;
}

export interface OpenDesktopOptions {
  /** Scaffold ~/.ai-workspace with `workspace init`. Default true. */
  initWorkspace?: boolean;
  /** Persist first-run complete so existing specs land on World. Default true. */
  skipOnboarding?: boolean;
}

/**
 * Launches the built app against the real backend inside a throwaway HOME
 * and workspace, so runs never read or write the developer's own state.
 */
export async function openDesktop(options: OpenDesktopOptions = {}): Promise<Desktop> {
  const initWorkspace = options.initWorkspace ?? true;
  const skipOnboarding = options.skipOnboarding ?? true;
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
  // The Electron supervisor must launch the same binary used to scaffold and
  // smoke this workspace. Otherwise a stale dist/ binary can win discovery
  // and make the renderer appear to target an older API than the test setup.
  env['ATK_BACKEND_BIN'] = backendBin;
  const schedulerShim = process.env['ATK_E2E_SYSTEMCTL_SHIM'];
  env['PATH'] = [schedulerShim, path.dirname(backendBin), process.env.PATH]
    .filter((entry): entry is string => Boolean(entry))
    .join(path.delimiter);
  env['NO_COLOR'] = '1';

  if (initWorkspace) {
    execFileSync(backendBin, ['workspace', 'init', '--dir', workspace], {
      env,
      stdio: 'pipe',
    });
  }

  const args = [...(packagedApp ? [] : [APP_DIR]), `--user-data-dir=${path.join(root, 'user-data')}`];
  // GitHub runners have no setuid sandbox helper for Chromium.
  if (process.env.CI) args.push('--no-sandbox');
  const app = await electron.launch({ executablePath: packagedApp, args, cwd: initWorkspace ? workspace : home, env });
  const page = await app.firstWindow();
  await page.waitForLoadState('domcontentloaded');
  if (skipOnboarding) {
    await page.addInitScript(() => {
      localStorage.setItem('atk.desktop.onboarding.complete', '1');
    });
    await page.reload();
    await page.waitForLoadState('domcontentloaded');
  }

  return {
    app,
    page,
    home,
    workspace,
    close: async () => {
      const process = app.process();
      let killTimer: ReturnType<typeof setTimeout> | undefined;
      try {
        await Promise.race([
          app.close(),
          new Promise<void>((resolve) => {
            killTimer = setTimeout(() => {
              try {
                process.kill('SIGKILL');
              } catch {
                // The Electron process may have exited while shutdown was pending.
              }
              resolve();
            }, 20_000);
          }),
        ]);
      } finally {
        if (killTimer) clearTimeout(killTimer);
        fs.rmSync(root, { recursive: true, force: true });
      }
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
      if (!win) throw new Error('Desktop window is unavailable while resizing.');
      win.setContentSize(size.width, size.height);
      return win.webContents.executeJavaScript(
        `new Promise((resolve, reject) => {
          const started = performance.now();
          const check = () => {
            if (window.innerWidth === ${size.width} && window.innerHeight === ${size.height}) {
              resolve(true);
            } else if (performance.now() - started > 3000) {
              reject(new Error('Desktop viewport did not reach ${size.width}x${size.height}.'));
            } else {
              requestAnimationFrame(check);
            }
          };
          check();
        })`,
      );
    },
    { width, height },
  );
}
