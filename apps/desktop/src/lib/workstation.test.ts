import { describe, expect, it } from 'vitest';
import { matchWorkstationSession, type WorkstationSession } from './workstation';

function session(partial: WorkstationSession): WorkstationSession {
  return partial;
}

const architect = session({ id: 'pty-a', agent: 'architect', cwd: '/ws' });
const implementer = session({ id: 'pty-i', agent: 'implementer', cwd: '/ws' });
const extras = { 'pty-a': { run: 'run-1' }, 'pty-i': { run: 'run-2' } };

describe('matchWorkstationSession', () => {
  it('returns null when there is nothing to match', () => {
    expect(matchWorkstationSession([architect], extras, {})).toBeNull();
  });

  it('does not treat harness cwd alone as a focus request', () => {
    expect(matchWorkstationSession([architect, implementer], extras, { cwd: '/ws' })).toBeNull();
  });

  it('focuses an existing PTY id and refuses unknown ids', () => {
    expect(matchWorkstationSession([architect, implementer], extras, { pty: 'pty-i' })).toEqual(implementer);
    expect(matchWorkstationSession([architect], extras, { pty: 'missing' })).toBeNull();
  });

  it('does not fall back to identity when an explicit PTY is missing', () => {
    expect(
      matchWorkstationSession([architect], extras, { pty: 'missing', agent: 'architect', run: 'run-1', cwd: '/ws' }),
    ).toBeNull();
  });

  it('matches agent, run and harness cwd together', () => {
    expect(
      matchWorkstationSession([architect, implementer], extras, {
        agent: 'architect',
        run: 'run-1',
        cwd: '/ws',
      }),
    ).toEqual(architect);
  });

  it('does not invent a session for an identity that is not running', () => {
    expect(matchWorkstationSession([architect], extras, { agent: 'reviewer', run: 'run-1', cwd: '/ws' })).toBeNull();
  });
});
