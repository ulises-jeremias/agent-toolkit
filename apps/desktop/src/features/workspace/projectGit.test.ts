import { describe, expect, it } from 'vitest';
import type { ProjectGitStatusResponse } from '../../lib/api';
import { diffLineTone, isClean, totalChanges } from './projectGit';

const status = (over: Partial<ProjectGitStatusResponse>): ProjectGitStatusResponse => ({
  ok: true,
  project: 'demo',
  branch: 'main',
  staged: [],
  unstaged: [],
  untracked: [],
  detail: '',
  ...over,
});

describe('diffLineTone', () => {
  it('classifies unified diff lines', () => {
    expect(diffLineTone('+added')).toBe('add');
    expect(diffLineTone('-removed')).toBe('del');
    expect(diffLineTone('+++ b/a.txt')).toBe('meta');
    expect(diffLineTone('--- a/a.txt')).toBe('meta');
    expect(diffLineTone('@@ -1,2 +1,2 @@')).toBe('meta');
    expect(diffLineTone(' context')).toBe('context');
    expect(diffLineTone('')).toBe('context');
  });
});

describe('status helpers', () => {
  it('counts every bucket and detects a clean tree', () => {
    const dirty = status({
      staged: [{ path: 'a.txt', code: 'A.' }],
      unstaged: [{ path: 'b.txt', code: '.M' }],
      untracked: [{ path: 'c.txt', code: '??' }],
    });
    expect(totalChanges(dirty)).toBe(3);
    expect(isClean(dirty)).toBe(false);
    expect(isClean(status({}))).toBe(true);
    expect(isClean(status({ ok: false, detail: 'not a git repository' }))).toBe(false);
  });
});
