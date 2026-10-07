import { describe, expect, it } from 'vitest';
import type { InstallReceiptSummary } from '../../lib/api';
import { libraryResourceEvidence } from './resourceEvidence';

function receipt(target: string, artifacts: InstallReceiptSummary['artifacts']): InstallReceiptSummary {
  return {
    product: 'agent-toolkit-profiles',
    target,
    scope: 'user',
    version: '1.42.0',
    installed_at: '2026-10-07T00:00:00Z',
    artifact_count: artifacts.length,
    created_count: artifacts.length,
    merged_count: 0,
    receipt_path: '/home/example/.config/agent-toolkit/receipts/receipt.json',
    artifacts,
  };
}

describe('libraryResourceEvidence', () => {
  it('reports only Toolkit receipt evidence and keeps catalog presence distinct', () => {
    const evidence = libraryResourceEvidence('skill', 'review', [
      receipt('claude-code', [
        {
          path: '/home/example/.claude/skills/review/SKILL.md',
          ownership: 'created',
          status: 'unchanged',
        },
      ]),
    ]);

    expect(evidence).toEqual({ state: 'verified', targets: ['claude-code'] });
  });

  it('aggregates a changed receipt without hiding another verified target', () => {
    const evidence = libraryResourceEvidence('skill', 'review', [
      receipt('claude-code', [
        {
          path: '/home/example/.claude/skills/review/references/checklist.md',
          ownership: 'created',
          status: 'modified',
        },
      ]),
      receipt('opencode', [
        {
          path: '/home/example/.config/opencode/skills/review/SKILL.md',
          ownership: 'created',
          status: 'unchanged',
        },
      ]),
    ]);

    expect(evidence).toEqual({ state: 'needs-attention', targets: ['claude-code', 'opencode'] });
  });

  it('does not call a skill verified when only supporting files have Toolkit receipts', () => {
    const evidence = libraryResourceEvidence('skill', 'review', [
      receipt('claude-code', [
        {
          path: '/home/example/.claude/skills/review/references/checklist.md',
          ownership: 'created',
          status: 'unchanged',
        },
      ]),
    ]);

    expect(evidence).toEqual({ state: 'partial', targets: ['claude-code'] });
  });

  it('matches agent definitions, including Pi paths, and ignores unrelated markdown', () => {
    const evidence = libraryResourceEvidence('agent', 'reviewer', [
      receipt('claude-code', [
        {
          path: 'C:\\Users\\example\\.claude\\agents\\reviewer.md',
          ownership: 'created',
          status: 'unchanged',
        },
        {
          path: '/home/example/.claude/skills/review/SKILL.md',
          ownership: 'created',
          status: 'unchanged',
        },
        {
          path: '/home/example/.claude/rules/reviewer.md',
          ownership: 'created',
          status: 'unchanged',
        },
      ]),
      receipt('pi', [
        {
          path: '/home/example/.pi/agent/skills/reviewer.md',
          ownership: 'created',
          status: 'unchanged',
        },
      ]),
    ]);

    expect(evidence).toEqual({ state: 'verified', targets: ['claude-code', 'pi'] });
  });

  it('uses no receipt when no matching Toolkit artifact exists', () => {
    expect(
      libraryResourceEvidence('skill', 'assistant', [
        receipt('claude-code', [
          {
            path: '/home/example/.claude/skills/review/SKILL.md',
            ownership: 'created',
            status: 'unchanged',
          },
        ]),
      ]),
    ).toEqual({ state: 'none', targets: [] });
  });
});
