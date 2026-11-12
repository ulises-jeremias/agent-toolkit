import { describe, expect, it } from 'vitest';
import type { ProjectListEntry } from '../../lib/api';
import { selectStartProject } from './NewSession';

const projects = [
  { name: 'alpha', target: '/tmp/alpha', status: 'ok' },
  { name: 'beta', target: '/tmp/beta', status: 'ok' },
  { name: 'broken', target: '/tmp/broken', status: 'missing' },
] as unknown as ProjectListEntry[];

describe('selectStartProject', () => {
  it('does not silently switch to another repository when the requested project is absent', () => {
    expect(selectStartProject(projects, 'deleted')).toBeUndefined();
    expect(selectStartProject(projects, 'broken')).toBeUndefined();
  });

  it('honors an explicit project and only defaults when none was requested', () => {
    expect(selectStartProject(projects, 'beta')?.name).toBe('beta');
    expect(selectStartProject(projects, '')?.name).toBe('alpha');
  });

  it('does not choose an unavailable project', () => {
    expect(selectStartProject(projects.slice(2), '')).toBeUndefined();
  });
});
