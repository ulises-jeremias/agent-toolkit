import { describe, expect, it } from 'vitest';
import type { ProjectGitStatusResponse } from '../../lib/api';
import { diffLineTone, isClean, splitDiffHunks, totalChanges } from './projectGit';

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

describe('splitDiffHunks', () => {
  it('splits hunks with headers and bodies, ignoring the file header', () => {
    const diff = [
      'diff --git a/a.txt b/a.txt',
      '--- a/a.txt',
      '+++ b/a.txt',
      '@@ -1,2 +1,3 @@',
      ' one',
      '+two',
      '@@ -5,2 +6,2 @@',
      ' five',
      '-six',
      '+sixx',
    ].join('\n');
    const hunks = splitDiffHunks(diff);
    expect(hunks).toHaveLength(2);
    expect(hunks[0]?.header).toBe('@@ -1,2 +1,3 @@');
    expect(hunks[0]?.lines).toContain('+two');
    expect(hunks[1]?.lines).toContain('+sixx');
    expect(splitDiffHunks('')).toEqual([]);
  });
});
