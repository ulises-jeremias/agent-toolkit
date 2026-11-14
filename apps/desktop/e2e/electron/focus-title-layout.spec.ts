import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';
import { goTo } from './navigation';

test('a long Focus session title remains readable and available in full', async () => {
  const desktop = await openDesktop();
  try {
    const { page, workspace } = desktop;
    await waitForBackend(page);
    await goTo(page, 'Focus');

    const title =
      'Review the changed files carefully and explain the exact repository behavior before recommending any edits';
    const result = await page.evaluate(
      async ({ cwd, sessionTitle }) => {
        const focus = Object.getOwnPropertyDescriptor(window.atk, 'focus')?.value as
          | {
              createThread?: (input: {
                cwd: string;
                projectName: string | null;
                provider: 'claude';
                model: null;
                permissionMode: 'ask';
                title: string;
              }) => Promise<{ ok: boolean; value?: { id: string }; error?: string }>;
            }
          | undefined;
        if (!focus?.createThread) throw new Error('Focus runtime bridge is unavailable.');
        return focus.createThread({
          cwd,
          projectName: null,
          provider: 'claude',
          model: null,
          permissionMode: 'ask',
          title: sessionTitle,
        });
      },
      { cwd: workspace, sessionTitle: title },
    );
    if (!result.ok || !result.value?.id) throw new Error(result.error ?? 'Could not create test session.');

    await expect
      .poll(() => page.evaluate(() => window.atk?.focus.listThreads() ?? []))
      .toMatchObject([{ id: result.value!.id, title }]);
    await page.getByRole('button').filter({ hasText: title }).first().click();

    const titleButton = page.locator('h1').getByRole('button', { name: title });
    await expect(titleButton).toHaveAttribute('title', `${title} — Rename this session`);
    const layout = await titleButton.evaluate((element) => {
      const style = getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return { height: rect.height, lineHeight: Number.parseFloat(style.lineHeight) };
    });
    expect(layout.height).toBeGreaterThan(layout.lineHeight * 1.2);
    expect(layout.height).toBeLessThanOrEqual(layout.lineHeight * 2.2);

    const captureDir = process.env['ATK_CAPTURE_DIR'];
    if (captureDir) {
      fs.mkdirSync(captureDir, { recursive: true });
      await page.screenshot({ path: path.join(captureDir, 'focus-long-session-title.png') });
    }
  } finally {
    await desktop.close();
  }
});
