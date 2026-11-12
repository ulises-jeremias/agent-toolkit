import type { Locator, Page } from '@playwright/test';

/** Pages that are tabs of the Operations section rather than rail entries. */
const OPERATIONS_TABS: Record<string, string> = {
  Attention: 'Needs you',
  Terminal: 'Terminals',
  Insights: 'Health',
};

export function rail(page: Page): Locator {
  return page.getByRole('navigation', { name: 'Destinations' });
}

export function sectionTab(page: Page, label: string): Locator {
  return page.getByRole('navigation', { name: 'Section' }).getByRole('link', { name: OPERATIONS_TABS[label] ?? label });
}

/** Open a page the way a user does: through the rail, or through a tab of Operations. */
export async function goTo(page: Page, label: string): Promise<void> {
  if (label in OPERATIONS_TABS) {
    await rail(page).getByRole('link', { name: 'Operations' }).click();
    await sectionTab(page, label).click();
    return;
  }
  await rail(page).getByRole('link', { name: label }).click();
}
