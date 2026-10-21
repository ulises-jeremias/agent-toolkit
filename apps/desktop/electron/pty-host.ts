import { randomUUID } from 'node:crypto';
import { PtyHostCore } from './pty-host-core.js';
import { ensureRuntimeDir, ptyRuntimeDir, readOrCreateToken } from './pty-protocol.js';

/**
 * Detached PTY host entry (ADR-037). Spawned detached by the first client
 * (Electron main with ELECTRON_RUN_AS_NODE=1, or plain Node in tests) and
 * outlives it: `node pty-host.js [--runtime-dir <dir>]`.
 *
 * The host owns every interactive PTY. It exits after the last session
 * ends and no client has connected for a grace period.
 */

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const dirFlag = args.indexOf('--runtime-dir');
  const runtimeDir = dirFlag >= 0 && args[dirFlag + 1] ? args[dirFlag + 1]! : ptyRuntimeDir();
  ensureRuntimeDir(runtimeDir);
  const token = readOrCreateToken(runtimeDir, () => randomUUID());
  const core = new PtyHostCore({
    runtimeDir,
    token,
    onIdleExit: () => {
      void core.close().then(() => process.exit(0));
    },
  });
  await core.listen();
  process.on('SIGTERM', () => {
    void core.close().then(() => process.exit(0));
  });
  process.on('SIGINT', () => {
    void core.close().then(() => process.exit(0));
  });
}

void main();
