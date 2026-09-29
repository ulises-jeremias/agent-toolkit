// @vitest-environment node
import { afterEach, describe, expect, it } from 'vitest';
import { BackendSupervisor } from './backend';

/**
 * Exercises the real backend lifecycle: spawn `agent-toolkit serve` on a
 * dynamic localhost port, health-gate readiness, version check, restart,
 * clean shutdown. Requires agent-toolkit on PATH.
 */
describe('BackendSupervisor', () => {
  let supervisor: BackendSupervisor | null = null;

  afterEach(async () => {
    if (supervisor) {
      await supervisor.stop();
      supervisor = null;
    }
  });

  it('starts, reports ready with a version, restarts, and stops', async () => {
    supervisor = new BackendSupervisor();
    const started = await supervisor.start();
    expect(started).toBe(true);

    const snapshot = supervisor.snapshot();
    expect(snapshot.status).toBe('ready');
    expect(snapshot.url).toMatch(/^http:\/\/127\.0\.0\.1:\d+$/);
    expect(snapshot.version).toMatch(/^\d+\.\d+\.\d+/);

    const restarted = await supervisor.restart();
    expect(restarted).toBe(true);
    expect(supervisor.snapshot().status).toBe('ready');

    await supervisor.stop();
    expect(supervisor.snapshot().status).toBe('stopped');
  }, 90_000);
});
