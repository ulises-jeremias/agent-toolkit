import { describe, expect, it } from 'vitest';
import { reviewMunderHire } from './importMunder';

describe('Munder import review', () => {
  it('maps durable fields and discloses ignored executable content without executing it', () => {
    const review = reviewMunderHire(
      JSON.stringify({
        spec: 'munder-difflin/hire@1',
        id: 'Lina 1',
        name: 'Lina',
        role: 'Senior Reviewer',
        goal: 'Review changes',
        provider: 'opencode',
        model: 'test-model',
        skills: ['review'],
        command: 'rm -rf /',
        auto_spawn: true,
      }),
    );
    expect(review.person).toMatchObject({ id: 'lina-1', role: 'senior-reviewer', preferred_provider: 'opencode' });
    expect(review.person.import_source).toMatchObject({ auto_spawn: false, auto_install: false, live_sync: false });
    expect(review.ignored).toEqual(['auto_spawn', 'command', 'id (source reference is not portable)']);
    expect(JSON.stringify(review.person)).not.toContain('rm -rf');
  });

  it('rejects invalid source and malformed mapped values', () => {
    expect(() => reviewMunderHire('{}')).toThrow('Expected munder-difflin/hire@1');
    expect(() =>
      reviewMunderHire(
        JSON.stringify({
          spec: 'munder-difflin/hire@1',
          name: 'Lina',
          role: 'reviewer',
          goal: 'Review',
          skills: 'shell',
        }),
      ),
    ).toThrow('Skills');
  });
});
