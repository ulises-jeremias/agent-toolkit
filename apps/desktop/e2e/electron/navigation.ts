import type { Locator, Page } from '@playwright/test';

/** Pages that are tabs of a rail entry rather than rail entries themselves. */
const TABS: Record<string, { owner: string; tab: string }> = {
  Attention: { owner: 'Operations', tab: 'Needs you' },
  Terminal: { owner: 'Operations', tab: 'Terminals' },
  Insights: { owner: 'Operations', tab: 'Health' },
  Context: { owner: 'Library', tab: 'Context and memory' },
};

export function rail(page: Page): Locator {
  return page.getByRole('navigation', { name: 'Destinations' });
}

export function sectionTab(page: Page, label: string): Locator {
  return page.getByRole('navigation', { name: 'Section' }).getByRole('link', { name: TABS[label]?.tab ?? label });
}

/** Open a page the way a user does: through the rail, or through a tab of its section. */
export async function goTo(page: Page, label: string): Promise<void> {
  const tab = TABS[label];
  if (tab) {
    await rail(page).getByRole('link', { name: tab.owner }).click();
    await sectionTab(page, label).click();
    return;
  }
  await rail(page).getByRole('link', { name: label }).click();
}
