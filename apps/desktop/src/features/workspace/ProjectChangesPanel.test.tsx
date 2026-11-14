import { render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ProjectChangesPanel } from './ProjectChangesPanel';

const mocks = vi.hoisted(() => ({
  status: {
    ok: true,
    project: 'demo',
    branch: 'main',
    staged: [],
    unstaged: [],
    untracked: [{ path: 'live-result.txt', code: '??' }],
    detail: '',
  },
  diff: {
    ok: true,
    project: 'demo',
    path: 'live-result.txt',
    staged: false,
    diff: [
      'diff --git a/live-result.txt b/live-result.txt',
      'new file mode 100644',
      '--- /dev/null',
      '+++ b/live-result.txt',
      '@@ -0,0 +1 @@',
      '+Codex real-provider acceptance succeeded.',
    ].join('\n'),
    truncated: false,
    detail: '',
  },
  diffRequest: vi.fn(),
}));

vi.mock('../../data/projects', () => {
  const mutation = () => ({ isPending: false, mutateAsync: vi.fn(async () => ({ ok: true, detail: '' })) });
  return {
    useProjectGitCommit: mutation,
    useProjectGitDiff: (...args: unknown[]) => {
      mocks.diffRequest(...args);
      return { data: mocks.diff, isPending: false, isError: false };
    },
    useProjectGitLog: () => ({ data: { ok: true, project: 'demo', commits: [], detail: '' }, isPending: false }),
    useProjectGitShow: () => ({ isPending: false, isError: false }),
    useProjectGitStage: mutation,
    useProjectGitStageHunk: mutation,
    useProjectGitStatus: () => ({ data: mocks.status, isPending: false, isError: false }),
    useProjectGitUnstage: mutation,
  };
});

describe('ProjectChangesPanel', () => {
  beforeEach(() => {
    mocks.status.untracked = [{ path: 'live-result.txt', code: '??' }];
  });

  it('opens the first changed file diff without requiring a manual selection', async () => {
    render(<ProjectChangesPanel workspace="/ws" projects={[{ name: 'demo', status: 'ok' }]} />);

    expect(await screen.findByRole('heading', { name: 'Untracked (1)' })).toBeVisible();
    await waitFor(() =>
      expect(screen.getByLabelText('Diff for live-result.txt')).toHaveTextContent(
        '+Codex real-provider acceptance succeeded.',
      ),
    );
  });

  it('switches the selected file diff to the index after staging it', async () => {
    render(<ProjectChangesPanel workspace="/ws" projects={[{ name: 'demo', status: 'ok' }]} />);

    expect(await screen.findByRole('heading', { name: 'Untracked (1)' })).toBeVisible();
    await screen.getByRole('button', { name: /^Stage$/ }).click();

    await waitFor(() => expect(mocks.diffRequest).toHaveBeenLastCalledWith('/ws', 'demo', 'live-result.txt', true));
    expect(screen.getByLabelText('Diff for live-result.txt')).toHaveTextContent(
      '+Codex real-provider acceptance succeeded.',
    );
  });
});
