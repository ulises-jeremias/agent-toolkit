import { describe, expect, it } from 'vitest';
import { parseLoopNames } from './loopList';

describe('parseLoopNames', () => {
  it('reads installed loop names from the list report', () => {
    expect(
      parseLoopNames(
        {
          ok: true,
          message: 'oss-triage\ttier=L1\tcadence=daily\noss-pr-monitor\ttier=L2\tcadence=hourly',
          data: { count: '2' },
        },
        'installed',
      ),
    ).toEqual([
      { name: 'oss-triage', meta: 'tier=L1\tcadence=daily', source: 'installed' },
      { name: 'oss-pr-monitor', meta: 'tier=L2\tcadence=hourly', source: 'installed' },
    ]);
  });

  it('treats the empty-list sentence as no names', () => {
    expect(
      parseLoopNames(
        { ok: true, message: 'No loops found. Run: agent-toolkit loop init <pattern>', data: { count: '0' } },
        'installed',
      ),
    ).toEqual([]);
  });

  it('reads template names from indented lines', () => {
    expect(
      parseLoopNames({ ok: true, message: '  oss-triage\n  oss-daily-briefing', data: { count: '2' } }, 'template'),
    ).toEqual([
      { name: 'oss-triage', meta: '', source: 'template' },
      { name: 'oss-daily-briefing', meta: '', source: 'template' },
    ]);
  });
});
