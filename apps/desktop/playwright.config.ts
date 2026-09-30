import path from 'node:path';
import { defineConfig, devices } from '@playwright/test';

const APP_DIR = path.resolve(__dirname);
// Avoid colliding with sibling worktrees that reuse :3000 (reuseExistingServer
// would then smoke-test a different Office).
const PORT = process.env.PORT ?? '3177';

/**
 * Two projects:
 * - renderer: the React app under vite dev, no backend (shell, fallbacks).
 * - electron: the built app (`pnpm build:all`) launched through Playwright's
 *   Electron driver with the real V backend (see e2e/electron/fixtures.ts).
 */
export default defineConfig({
  testDir: './e2e',
  // Parallel cold loads race vite's first-run dependency optimization (which
  // reloads the page), and each Electron spec owns a backend process.
  workers: 1,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: 'on-first-retry',
  },
  webServer: {
    command: `pnpm --dir "${APP_DIR}" dev --port ${PORT}`,
    cwd: APP_DIR,
    url: `http://127.0.0.1:${PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
  projects: [
    {
      name: 'renderer',
      testIgnore: ['electron/**'],
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'electron',
      testMatch: ['electron/**/*.spec.ts'],
      timeout: 90_000,
      expect: { timeout: 20_000 },
    },
  ],
});
