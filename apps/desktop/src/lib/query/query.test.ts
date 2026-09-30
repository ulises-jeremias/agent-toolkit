import { QueryClient } from '@tanstack/react-query';
import { describe, expect, it } from 'vitest';
import { invalidateDomains, OPERATION_EFFECTS } from './invalidation';
import { qk } from './keys';

describe('query keys', () => {
  it('roots every key at its domain so domains invalidate as a unit', () => {
    expect(qk.sub('workspace', 'context')[0]).toBe('workspace');
    expect(qk.report('doctor')[0]).toBe('doctor');
    expect(qk.jobs.log('j')[0]).toBe('jobs');
  });

  it('keys subcommand reads by body so different scopes never share a cache entry', () => {
    expect(qk.sub('workspace', 'budget', { workspace: '/a' })).not.toEqual(
      qk.sub('workspace', 'budget', { workspace: '/b' }),
    );
    expect(qk.sub('workspace', 'context')).toEqual(qk.sub('workspace', 'context', {}));
    expect(qk.catalog.tools()[0]).toBe('tools');
    expect(qk.catalog.agents()[0]).toBe('agents');
  });
});

describe('invalidateDomains', () => {
  it('invalidates exactly the domains an operation declares', async () => {
    const queryClient = new QueryClient();
    const seeded = [qk.sub('skills', 'list'), qk.report('doctor'), qk.jobs.list(), qk.backend.health()];
    for (const key of seeded) queryClient.setQueryData(key, 'x');

    await invalidateDomains(queryClient, OPERATION_EFFECTS.doctorFix);

    const invalidated = seeded.filter((key) => queryClient.getQueryState(key)?.isInvalidated);
    expect(invalidated).toEqual([qk.report('doctor')]);
  });

  it('never lets toolkit operations touch jobs or backend health', () => {
    for (const domains of Object.values(OPERATION_EFFECTS)) {
      expect(domains).not.toContain('jobs');
      expect(domains).not.toContain('backend');
    }
  });
});
