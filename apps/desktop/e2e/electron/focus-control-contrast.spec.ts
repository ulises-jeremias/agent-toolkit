import { expect, test } from '@playwright/test';
import { goTo } from './navigation';
import { openDesktop, waitForBackend } from './fixtures';

test('Focus control boundaries remain distinguishable in Meadow and Dusk', async () => {
  const desktop = await openDesktop({ skipOnboarding: true });
  try {
    await waitForBackend(desktop.page);
    for (const theme of ['meadow', 'dusk'] as const) {
      await goTo(desktop.page, 'Settings');
      await desktop.page.locator(`input[name="theme"][value="${theme}"]`).check();
      await expect.poll(() => desktop.page.evaluate(() => document.documentElement.dataset.theme)).toBe(theme);
      await goTo(desktop.page, 'Focus');
      await expect(desktop.page.getByRole('status').filter({ hasText: /No coding agent is signed in/ })).toBeVisible();

      const boundaries = await desktop.page.evaluate(() => {
        type RGB = [number, number, number];
        type Color = { rgb: RGB; alpha: number };
        const parse = (value: string): Color | null => {
          const match = value.match(/rgba?\(([^)]+)\)/);
          if (!match) return null;
          const channels = match[1]!
            .split(/[ ,/]+/)
            .filter(Boolean)
            .map(Number);
          return channels.length >= 3
            ? { rgb: [channels[0]!, channels[1]!, channels[2]!], alpha: channels[3] ?? 1 }
            : null;
        };
        const over = (top: Color, bottom: RGB): RGB =>
          top.rgb.map((channel, index) => channel * top.alpha + bottom[index]! * (1 - top.alpha)) as RGB;
        const luminance = (color: RGB) => {
          const [r, g, b] = color.map((channel) => {
            const value = channel / 255;
            return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
          });
          return 0.2126 * r! + 0.7152 * g! + 0.0722 * b!;
        };
        const contrast = (a: RGB, b: RGB) => {
          const [lighter, darker] = [luminance(a), luminance(b)].sort((x, y) => y - x);
          return Number(((lighter! + 0.05) / (darker! + 0.05)).toFixed(2));
        };
        const background = (element: HTMLElement): RGB => {
          const layers: HTMLElement[] = [];
          for (let node: HTMLElement | null = element; node; node = node.parentElement) layers.unshift(node);
          let result: RGB = [255, 255, 255];
          for (const node of layers) {
            const color = parse(getComputedStyle(node).backgroundColor);
            if (color) result = over(color, result);
          }
          return result;
        };
        const controls = [
          document.querySelector<HTMLElement>('button[aria-haspopup="dialog"]'),
          [...document.querySelectorAll<HTMLElement>('button')].find(
            (button) => button.innerText.trim() === 'New session',
          ) ?? null,
          [...document.querySelectorAll<HTMLSelectElement>('select')].find((select) =>
            select.labels?.[0]?.innerText.includes('Permissions'),
          ) ?? null,
        ];
        return controls.map((element) => {
          if (!element) return { name: 'missing control', fill: 0, surface: 0 };
          const style = getComputedStyle(element);
          const border = parse(style.borderTopColor);
          if (!border || style.borderTopStyle === 'none' || Number.parseFloat(style.borderTopWidth) < 1) {
            return { name: element.innerText.trim() || element.tagName, fill: 0, surface: 0 };
          }
          const fillColor = parse(style.backgroundColor);
          const fill = fillColor ? over(fillColor, background(element.parentElement ?? element)) : background(element);
          const parent = element.parentElement;
          const surface = parent ? background(parent) : fill;
          return {
            name:
              element.innerText.trim() ||
              (element instanceof HTMLSelectElement ? element.labels?.[0]?.innerText.trim() : '') ||
              element.tagName,
            fill: contrast(over(border, fill), fill),
            surface: contrast(over(border, surface), surface),
          };
        });
      });

      expect(boundaries, `${theme} control boundary contrast`).toHaveLength(3);
      for (const boundary of boundaries) {
        expect(boundary.name, `${theme} control must be present`).not.toBe('missing control');
        expect(boundary.fill, `${theme} ${boundary.name} border against its fill`).toBeGreaterThanOrEqual(3);
        expect(boundary.surface, `${theme} ${boundary.name} border against its surface`).toBeGreaterThanOrEqual(3);
      }
    }
  } finally {
    await desktop.close();
  }
});
