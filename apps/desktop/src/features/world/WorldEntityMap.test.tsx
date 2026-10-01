import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { entityAccessibleName, entityHasInspector } from './inspectors';
import { buildWorldModel, layoutWorld } from './model';
import type { MemoryEntryRecord, WorldDomainInput } from './model/types';
import { cozyValleyTheme } from './theme/cozyValley';
import { WorldEntityList, WorldEntityMap } from './WorldEntityMap';

function entry(
  partial: Omit<Partial<MemoryEntryRecord>, 'provenance'> &
    Pick<MemoryEntryRecord, 'id' | 'title'> & {
      provenance?: Partial<MemoryEntryRecord['provenance']>;
    },
): MemoryEntryRecord {
  const { provenance: provenancePartial, ...rest } = partial;
  return {
    kind: 'learning',
    snippet: '',
    tags: [],
    ...rest,
    provenance: {
      file: '',
      author: '',
      timestamp: '',
      project: '',
      agent: '',
      ...provenancePartial,
    },
  };
}

function baseInput(overrides: Partial<WorldDomainInput> = {}): WorldDomainInput {
  return {
    workspacePath: '/ws',
    projects: [
      { name: 'alpha', target: '/r/alpha', status: 'ok' },
      { name: 'beta', target: '/r/beta', status: 'ok' },
    ],
    projectsKnown: true,
    memory: {
      available: true,
      entries: [
        entry({
          id: 'knowledge/learnings/a.md',
          title: 'Alpha note',
          provenance: { project: 'alpha', file: 'knowledge/learnings/a.md' },
        }),
      ],
      projectKeys: ['alpha'],
    },
    tools: [
      {
        id: 'claude',
        toolName: 'Claude Code',
        detected: true,
        configured: true,
        enabled: 'true',
        verified: false,
        version: '1',
      },
    ],
    toolsKnown: true,
    jobs: [
      { id: 'j-fail', cmd: 'doctor', args: [], status: 'failed', workspace: '/r/beta' },
      { id: 'j-run', cmd: 'doctor', args: [], status: 'running', workspace: '/r/alpha' },
    ],
    ...overrides,
  };
}

describe('world inspector targets', () => {
  it('maps houses, terminal, library, and attention to existing routes', () => {
    const grounds = buildWorldModel(baseInput());
    const byId = Object.fromEntries(grounds.entities.map((e) => [e.id, e]));

    expect(byId['place:project:alpha']).toMatchObject({
      hrefPath: '/world',
      hrefExtra: { project: 'alpha' },
    });
    expect(byId['place:project:beta']).toMatchObject({ hrefPath: '/office' });
    expect(byId['object:terminal']).toMatchObject({ hrefPath: '/terminal' });
    expect(byId['object:library']).toMatchObject({ hrefPath: '/library' });
    expect(byId['object:attention']).toMatchObject({ hrefPath: '/office' });
    expect(byId['character:job:j-fail']).toMatchObject({ hrefPath: '/office' });
    expect(byId['character:job:j-run']).toMatchObject({ hrefPath: '/operations' });
  });

  it('opens memory records and tools on /world query inspectors', () => {
    const interior = buildWorldModel(baseInput({ focusProjectId: 'alpha' }));
    const memory = interior.entities.find((e) => e.id === 'object:memory:knowledge/learnings/a.md');
    const tool = interior.entities.find((e) => e.id === 'object:tool:claude');
    const terminal = interior.entities.find((e) => e.id === 'object:terminal-project:alpha');

    expect(memory).toMatchObject({
      hrefPath: '/world',
      hrefExtra: { project: 'alpha', memory: 'knowledge/learnings/a.md' },
    });
    expect(entityHasInspector(memory!)).toBe(true);
    expect(tool).toMatchObject({
      hrefPath: '/world',
      hrefExtra: { project: 'alpha', tool: 'claude' },
    });
    expect(entityHasInspector(tool!)).toBe(true);
    expect(terminal).toMatchObject({ hrefPath: '/terminal' });
  });
});

describe('WorldEntityMap activation', () => {
  function renderMap(input: WorldDomainInput = baseInput()) {
    const model = buildWorldModel(input);
    const layout = layoutWorld(model);
    const onActivate = vi.fn();
    const onSelect = vi.fn();
    const href = (path: string, extra?: Record<string, string | undefined>) => {
      const q = new URLSearchParams();
      for (const [key, value] of Object.entries(extra ?? {})) {
        if (value !== undefined) q.set(key, value);
      }
      const qs = q.toString();
      return qs ? `${path}?${qs}` : path;
    };
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <WorldEntityMap
          entities={layout.entities}
          selectedId={null}
          theme={cozyValleyTheme}
          cols={layout.cols}
          rows={layout.rows}
          ariaLabel="test world"
          mode={input.focusProjectId ? 'interior' : 'grounds'}
          onSelect={onSelect}
          onActivate={onActivate}
        />
        <WorldEntityList entities={layout.entities} selectedId={null} href={href} onSelect={onSelect} />
      </MemoryRouter>,
    );
    return { layout, onActivate, onSelect, user };
  }

  it('click and keyboard open the same inspector for terminal, library, failed house, and project house', async () => {
    const { onActivate, user } = renderMap();

    const terminal = screen.getByRole('button', { name: /Terminal · Terminal \/ PTY/i });
    await user.click(terminal);
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'object:terminal', hrefPath: '/terminal' }),
    );

    onActivate.mockClear();
    terminal.focus();
    await user.keyboard('{Enter}');
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'object:terminal', hrefPath: '/terminal' }),
    );

    onActivate.mockClear();
    const library = screen.getByRole('button', { name: /Library/i });
    await user.click(library);
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'object:library', hrefPath: '/library' }),
    );

    onActivate.mockClear();
    library.focus();
    await user.keyboard(' ');
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'object:library', hrefPath: '/library' }),
    );

    onActivate.mockClear();
    const failedHouse = screen.getByRole('button', { name: /beta · Project · needs attention/i });
    await user.click(failedHouse);
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'place:project:beta', hrefPath: '/office' }),
    );

    onActivate.mockClear();
    failedHouse.focus();
    await user.keyboard('{Enter}');
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'place:project:beta', hrefPath: '/office' }),
    );

    onActivate.mockClear();
    const calmHouse = screen.getByRole('button', { name: /alpha · Project · 1 active/i });
    await user.click(calmHouse);
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'place:project:alpha', hrefPath: '/world', hrefExtra: { project: 'alpha' } }),
    );

    onActivate.mockClear();
    calmHouse.focus();
    await user.keyboard('{Enter}');
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'place:project:alpha', hrefPath: '/world' }),
    );

    expect(screen.getAllByRole('link', { name: 'Inspect' }).length).toBeGreaterThan(0);
    const terminalInspect = document.querySelector('[data-entity-inspect="object:terminal"]');
    expect(terminalInspect?.getAttribute('href')).toContain('/terminal');
  });

  it('activates memory records and tools via click and keyboard on /world', async () => {
    const { onActivate, user } = renderMap(baseInput({ focusProjectId: 'alpha' }));

    const memoryBtn = screen.getByRole('button', { name: /Alpha note · Memory entry/i });
    expect(memoryBtn.getAttribute('data-activates')).toBe('true');
    await user.click(memoryBtn);
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({
        id: 'object:memory:knowledge/learnings/a.md',
        hrefPath: '/world',
        hrefExtra: expect.objectContaining({ memory: 'knowledge/learnings/a.md', project: 'alpha' }),
      }),
    );

    onActivate.mockClear();
    memoryBtn.focus();
    await user.keyboard('{Enter}');
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'object:memory:knowledge/learnings/a.md', hrefPath: '/world' }),
    );

    onActivate.mockClear();
    const toolBtn = screen.getByRole('button', { name: /Claude Code · Coding tool/i });
    expect(toolBtn.getAttribute('data-activates')).toBe('true');
    await user.click(toolBtn);
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({
        id: 'object:tool:claude',
        hrefPath: '/world',
        hrefExtra: expect.objectContaining({ tool: 'claude', project: 'alpha' }),
      }),
    );

    onActivate.mockClear();
    toolBtn.focus();
    await user.keyboard(' ');
    expect(onActivate).toHaveBeenLastCalledWith(
      expect.objectContaining({ id: 'object:tool:claude', hrefPath: '/world' }),
    );

    const memoryInspect = document.querySelector('[data-entity-inspect="object:memory:knowledge/learnings/a.md"]');
    expect(memoryInspect?.getAttribute('href')).toContain('memory=');
    const toolInspect = document.querySelector('[data-entity-inspect="object:tool:claude"]');
    expect(toolInspect?.getAttribute('href')).toContain('tool=claude');
  });

  it('gives every entity accessible name and state text independent of color', () => {
    const grounds = layoutWorld(buildWorldModel(baseInput()));
    const interior = layoutWorld(buildWorldModel(baseInput({ focusProjectId: 'alpha' })));
    for (const entity of [...grounds.entities, ...interior.entities]) {
      const label = entityAccessibleName(entity);
      expect(label.length).toBeGreaterThan(0);
      expect(label).toContain(entity.name);
      expect(label).toContain(entity.state);
      expect(entity.state.trim().length).toBeGreaterThan(0);
    }
  });
});
