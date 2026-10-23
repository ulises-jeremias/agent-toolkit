import { expect, test } from '@playwright/test';
import { openDesktop, waitForBackend } from './fixtures';

test('Library shows the real agent delegation graph and highlights a selected pair', async () => {
  const desktop = await openDesktop();
  try {
    const { page } = desktop;
    await waitForBackend(page);
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Library' }).click();

    // The graph is built from the backend catalog's own delegates data:
    // assistant is the orchestrator that delegates to the holistic roles.
    const graph = page.getByLabel('Delegation graph');
    await graph.scrollIntoViewIfNeeded();
    await expect(graph.getByText(/Delegation graph \(\d+ edges?\)/)).toBeVisible();
    const edge = graph.getByRole('button', { name: 'assistant delegates to architect' });
    await expect(edge).toBeVisible();

    await edge.click();
    await expect(edge).toHaveAttribute('aria-pressed', 'true');
    await expect(graph.getByRole('status')).toHaveText('assistant delegates to architect.');

    // Toggling the same edge clears the highlight pair.
    await edge.click();
    await expect(edge).toHaveAttribute('aria-pressed', 'false');
    await expect(graph.getByRole('status')).toHaveText('Select a delegation edge to highlight the pair.');
  } finally {
    await desktop.close();
  }
});
