import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { withContext } from '../../shell/sessionContext';
import { worldDetailBackExtra, worldDetailBackLabel } from './inspectors';
import { MemoryRecordInspector } from './MemoryRecordInspector';
import { ToolRecordInspector } from './ToolRecordInspector';
import { useWorldDetailEscape } from './useWorldDetailEscape';
import { ReceiptsProvider } from '../../ui';
import type { MemoryReadResponse, ToolInfo } from '../../lib/api';

const memoryFixture: MemoryReadResponse = {
  ok: true,
  entry: {
    id: 'knowledge/learnings/fixture.md',
    kind: 'learning',
    title: 'Fixture note',
    snippet: '',
    body: 'Body',
    tags: [],
    provenance: {
      file: 'knowledge/learnings/fixture.md',
      author: '',
      timestamp: '',
      project: 'alpha',
      agent: '',
    },
  },
};

const toolFixture: ToolInfo = {
  id: 'claude',
  tool_name: 'Claude Code',
  detected: true,
  configured: false,
  enabled: 'unknown',
  verified: false,
  resolved_path: '',
  config_paths: [],
  version: '',
  reason: '',
  install_hint: '',
};

describe('worldDetailBackExtra', () => {
  it('keeps project when leaving memory or tool detail', () => {
    const session = { workspace: '/ws', agent: '', run: '' };
    const withProject = withContext('/world', session, {
      ...worldDetailBackExtra('alpha'),
      memory: 'knowledge/learnings/a.md',
    });
    // Building the back href clears memory/tool and keeps project.
    expect(withContext('/world', session, worldDetailBackExtra('alpha'))).toBe('/world?workspace=%2Fws&project=alpha');
    expect(withProject).toContain('memory=');
    expect(withContext('/world', session, worldDetailBackExtra('alpha'))).not.toContain('memory=');
    expect(withContext('/world', session, worldDetailBackExtra('alpha'))).not.toContain('tool=');
  });

  it('returns to world grounds when no project was set', () => {
    const session = { workspace: '/ws', agent: '', run: '' };
    expect(withContext('/world', session, worldDetailBackExtra(null))).toBe('/world?workspace=%2Fws');
    expect(withContext('/world', session, worldDetailBackExtra(''))).toBe('/world?workspace=%2Fws');
  });

  it('labels Back for interior vs grounds', () => {
    expect(worldDetailBackLabel('alpha')).toBe('Back to alpha house');
    expect(worldDetailBackLabel(null)).toBe('Back to world');
  });
});

describe('detail Back control', () => {
  it('Back from memory returns via onBack (project interior path)', async () => {
    const onBack = vi.fn();
    const user = userEvent.setup();
    render(
      <MemoryRecordInspector
        path={memoryFixture.entry.provenance.file}
        data={memoryFixture}
        onBack={onBack}
        backLabel="Back to alpha house"
      />,
    );
    const back = screen.getByRole('button', { name: 'Back to alpha house' });
    await user.click(back);
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('Back from tool returns via onBack (world path)', async () => {
    const onBack = vi.fn();
    const user = userEvent.setup();
    render(
      <ReceiptsProvider>
        <ToolRecordInspector toolId="claude" tool={toolFixture} onBack={onBack} backLabel="Back to world" />
      </ReceiptsProvider>,
    );
    await user.click(screen.getByRole('button', { name: 'Back to world' }));
    expect(onBack).toHaveBeenCalledTimes(1);
  });
});

describe('useWorldDetailEscape', () => {
  function Harness({ active, onBack }: { active: boolean; onBack: () => void }) {
    useWorldDetailEscape(onBack, active);
    return <div>detail</div>;
  }

  it('Escape leaves memory detail when active', async () => {
    const onBack = vi.fn();
    const user = userEvent.setup();
    render(<Harness active onBack={onBack} />);
    await user.keyboard('{Escape}');
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('Escape leaves tool detail when active', async () => {
    const onBack = vi.fn();
    const user = userEvent.setup();
    render(<Harness active onBack={onBack} />);
    await user.keyboard('{Escape}');
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('Escape does nothing when inactive', async () => {
    const onBack = vi.fn();
    const user = userEvent.setup();
    render(<Harness active={false} onBack={onBack} />);
    await user.keyboard('{Escape}');
    expect(onBack).not.toHaveBeenCalled();
  });

  it('Escape can leave a project interior when the caller marks it active', async () => {
    const onBack = vi.fn();
    const user = userEvent.setup();
    render(<Harness active onBack={onBack} />);
    await user.keyboard('{Escape}');
    expect(onBack).toHaveBeenCalledTimes(1);
  });
});
