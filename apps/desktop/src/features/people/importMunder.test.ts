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

  it('imports a real gallery hire (jim-pr-reviewer) with canonical field names', () => {
    // Verbatim shape of docs/hires/manifests/jim-pr-reviewer.hire.json from
    // Munder Difflin (goal shortened): no `id`, no `role`, canonical
    // `mcpServers`-style fields, `isolate`, `tokenCap`, `commandFlags`.
    const review = reviewMunderHire(
      JSON.stringify({
        spec: 'munder-difflin/hire@1',
        name: 'Jim',
        description: 'Automated PR reviewer that reads your real source',
        goal: 'Run an automated PR-review function for a GitHub repo.',
        character: 'jim',
        accent: 'sky',
        provider: 'claude',
        model: 'claude-fable-5',
        commandFlags: ['--max-turns', '60'],
        capabilities: ['code-review', 'security', 'git'],
        isolate: false,
        tokenCap: 2500000,
        author: 'Agent Gallery',
        homepage: 'https://github.com/chaitanyagiri/munder-difflin',
      }),
    );
    expect(review.person).toMatchObject({
      id: 'jim',
      name: 'Jim',
      role: 'automated-pr-reviewer-that-reads-your-real-source',
      preferred_provider: 'claude',
      preferred_model: 'claude-fable-5',
      isolation: 'inherited',
      budget: { max_tokens: 2500000 },
    });
    // Executable/attribution fields are disclosed, never stored or run.
    expect(review.ignored).toEqual(['author', 'commandFlags', 'homepage']);
    expect(JSON.stringify(review.person)).not.toContain('--max-turns');
    expect(review.person.import_source).toMatchObject({ auto_spawn: false, original_character: 'jim' });
  });

  it('maps canonical mcpServers and isolate=true, and discloses an oversized tokenCap', () => {
    const review = reviewMunderHire(
      JSON.stringify({
        spec: 'munder-difflin/hire@1',
        name: 'Ada',
        description: 'Reviewer',
        goal: 'Review changes',
        mcpServers: ['github'],
        isolate: true,
        tokenCap: 2000000000,
      }),
    );
    expect(review.person.mcp_servers).toEqual(['github']);
    expect(review.person.isolation).toBe('worktree');
    expect(review.person.budget).toBeUndefined();
    expect(review.ignored).toEqual(['tokenCap (exceeds the Toolkit budget limit; set a budget after importing)']);
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
