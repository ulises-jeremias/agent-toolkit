import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

// Gate 1 subprocess-boundary experiment, NOT a coding-provider adapter.
// JSONL is a fixture protocol, not a claimed Claude/Codex/OpenCode interface.
export async function* processEvents(command, args = [], { cwd, signal } = {}) {
  if (typeof command !== 'string' || !command) throw new TypeError('command required');
  const child = spawn(command, args, { cwd, signal, stdio: ['ignore', 'pipe', 'pipe'], shell: false });
  const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
  // Drain stderr so the child cannot block on a full pipe. Never surface raw
  // provider stderr in an exception: it may contain prompts, paths or tokens.
  child.stderr.resume();
  const closed = new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', (code, childSignal) => resolve({ code, childSignal }));
  });
  // An early spawn error must not produce an unhandled rejection.
  closed.catch(() => {});
  let pendingCompletion = null;
  try {
    for await (const line of lines) {
      if (!line.trim()) continue;
      if (line.length > 1024 * 1024) throw new Error('oversized transport event');
      let event;
      try { event = JSON.parse(line); } catch { throw new Error('invalid JSONL transport event'); }
      // A provider-like completion is not authoritative until its supervising
      // process exits successfully. Never publish success before a later crash.
      if (event?.type === 'completed') {
        if (pendingCompletion) throw new Error('duplicate transport completion');
        pendingCompletion = event;
      } else {
        if (pendingCompletion) throw new Error('event after transport completion');
        yield event;
      }
    }
    const { code, childSignal } = await closed;
    if (code !== 0) throw new Error(`transport exited ${childSignal ?? code}`);
    if (pendingCompletion) yield pendingCompletion;
  } finally {
    lines.close();
    if (child.exitCode === null && child.signalCode === null) {
      // A provider process may ignore SIGTERM (or keep stdout open). Do not
      // hang session teardown indefinitely while awaiting its close event.
      child.kill('SIGTERM');
      const escalation = setTimeout(() => {
        // signalCode can already be SIGTERM immediately after kill(), even
        // while a stubborn process is still alive. Only close settles `closed`;
        // do not suppress escalation based on signalCode.
        if (child.exitCode === null) child.kill('SIGKILL');
      }, 500);
      escalation.unref();
      try { await closed.catch(() => {}); } finally { clearTimeout(escalation); }
    } else {
      await closed.catch(() => {});
    }
  }
}
