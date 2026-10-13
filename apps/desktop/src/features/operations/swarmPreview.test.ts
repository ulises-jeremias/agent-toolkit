import { describe, expect, it } from 'vitest';
import { hasProjectBoundSwarmPreview } from './swarmPreview';

describe('hasProjectBoundSwarmPreview', () => {
  it('accepts only a preview that confirms both the selected project and its repository path', () => {
    expect(
      hasProjectBoundSwarmPreview(
        { project_id: 'agent-toolkit', project_path: '/repos/agent-toolkit' },
        'agent-toolkit',
      ),
    ).toBe(true);
    expect(hasProjectBoundSwarmPreview({ project_path: '/workspace' }, 'agent-toolkit')).toBe(false);
    expect(
      hasProjectBoundSwarmPreview(
        { project_id: 'other-project', project_path: '/repos/other-project' },
        'agent-toolkit',
      ),
    ).toBe(false);
    expect(hasProjectBoundSwarmPreview({ project_id: 'agent-toolkit', project_path: ' ' }, 'agent-toolkit')).toBe(
      false,
    );
  });
});
