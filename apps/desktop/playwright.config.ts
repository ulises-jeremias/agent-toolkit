import { defineConfig, devices } from '@playwright/test';

const PORT = process.env.PORT ?? '3000';

/**
 * Two projects:
 * - renderer: the React app under vite dev, no backend (shell, fallbacks).
 * - electron: the built app (`pnpm build:all`) launched through Playwright's
 *   Electron driver with the real V backend (see e2e/electron/fixtures.ts).
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: 'on-first-retry',
  },
  webServer: {
    command: `pnpm dev --port ${PORT}`,
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
      fullyParallel: false,
      timeout: 90_000,
      expect: { timeout: 20_000 },
    },
  ],
});
