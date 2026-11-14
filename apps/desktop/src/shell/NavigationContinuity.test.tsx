import { cleanup, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MemoryRouter, useLocation } from 'react-router';
import { NavigationContinuity } from './NavigationContinuity';
import { rememberRoute, updateDesktopPreferences } from './desktopPreferences';

const state = vi.hoisted(() => ({ workspace: '/one' }));
vi.mock('../data/backend', () => ({ useBackend: () => ({ backend: { harness: { path: state.workspace } } }) }));

function Location() {
  const location = useLocation();
  return (
    <output aria-label="current location">
      {location.pathname}
      {location.search}
    </output>
  );
}

function App({ initial = '/' }: { initial?: string }) {
  return (
    <MemoryRouter initialEntries={[initial]}>
      <NavigationContinuity>
        <Location />
      </NavigationContinuity>
    </MemoryRouter>
  );
}

function expectLocation(path: string, expected: Record<string, string>): void {
  const value = screen.getByLabelText('current location').textContent ?? '';
  const split = value.indexOf('?');
  expect(value.slice(0, split < 0 ? undefined : split)).toBe(path);
  const params = new URLSearchParams(split < 0 ? '' : value.slice(split + 1));
  for (const [key, expectedValue] of Object.entries(expected)) expect(params.get(key)).toBe(expectedValue);
}

beforeEach(() => {
  state.workspace = '/one';
  updateDesktopPreferences({ routes: {} });
});
afterEach(cleanup);

describe('workspace navigation continuity', () => {
  it('restores the last internal route and scope on a fresh launch', async () => {
    rememberRoute('/one', { pathname: '/focus', search: '?project=repo&thread=thread-1' });
    render(<App />);
    await waitFor(() => expectLocation('/focus', { workspace: '/one', project: 'repo', thread: 'thread-1' }));
  });

  it('honors an explicit deep link and scopes it to the active workspace', async () => {
    rememberRoute('/one', { pathname: '/people', search: '' });
    render(<App initial="/world?project=repo&pty=dead" />);
    await waitFor(() => expectLocation('/world', { workspace: '/one', project: 'repo', pty: 'dead' }));
    expect(screen.getByLabelText('current location')).not.toHaveTextContent('thread=');
  });

  it('restores the destination for a newly selected workspace without leaking old project state', async () => {
    rememberRoute('/two', { pathname: '/focus', search: '?thread=thread-two' });
    const view = render(<App initial="/world?workspace=%2Fone&project=private&pty=old-session" />);
    state.workspace = '/two';
    view.rerender(<App initial="/world?workspace=%2Fone&project=private&pty=old-session" />);
    await waitFor(() => expectLocation('/focus', { workspace: '/two', thread: 'thread-two' }));
    expect(screen.getByLabelText('current location')).not.toHaveTextContent('private');
    expect(screen.getByLabelText('current location')).not.toHaveTextContent('pty=');
  });

  it('starts a workspace without saved navigation in Focus', async () => {
    render(<App />);
    await waitFor(() => expectLocation('/focus', { workspace: '/one' }));
  });
});
