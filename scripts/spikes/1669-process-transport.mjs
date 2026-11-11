import { spawn } from 'node:child_process';
// Bound raw bytes before parsing: readline buffers unbounded lines until newline.
const MAX_EVENT_BYTES = 1024 * 1024;

async function* boundedLines(stream) {
  let fragments = [];
  let size = 0;
  for await (const chunk of stream) {
    let start = 0;
    for (let i = 0; i < chunk.length; i++) {
      if (chunk[i] !== 10) continue;
      const part = chunk.subarray(start, i);
      if (size + part.length > MAX_EVENT_BYTES) throw new Error('oversized transport event');
      const line = Buffer.concat([...fragments, part], size + part.length).toString('utf8');
      yield line.endsWith('\r') ? line.slice(0, -1) : line;
      fragments = [];
      size = 0;
      start = i + 1;
    }
    if (start < chunk.length) {
      const part = chunk.subarray(start);
      if (size + part.length > MAX_EVENT_BYTES) throw new Error('oversized transport event');
      fragments.push(part);
      size += part.length;
    }
  }
  if (size) yield Buffer.concat(fragments, size).toString('utf8');
}

// Gate 1 subprocess-boundary experiment, NOT a coding-provider adapter.
// JSONL is a fixture protocol, not a claimed Claude/Codex/OpenCode interface.
// child.kill() can refuse a second signal once Node marks the first as sent.
// Use the OS PID for escalation; an exited process is already handled.
function forceKill(child) {
  if (child.exitCode !== null || child.pid == null) return;
  try { process.kill(child.pid, 'SIGKILL'); }
  catch (error) { if (error?.code !== 'ESRCH') throw error; }
}

export async function* processEvents(command, args = [], { cwd, signal } = {}) {
  if (typeof command !== 'string' || !command) throw new TypeError('command required');
  const child = spawn(command, args, { cwd, signal, stdio: ['ignore', 'pipe', 'pipe'], shell: false });

  // Drain stderr so the child cannot block on a full pipe. Never surface raw
  // provider stderr in an exception: it may contain prompts, paths or tokens.
  child.stderr.resume();
  // AbortSignal's spawn integration sends SIGTERM, but a stubborn child may
  // keep stdout open forever. Unblock the async line iterator on abort.
  let abortEscalation;
  let spawnError;
  const onAbort = () => {
    // Destroy the byte-bounded stdout iterator immediately on cancellation.
    child.stdout.destroy();
    // The line iterator can finish before the child exits. Start the bounded
    // escalation here, not only in finally (which may be waiting on `closed`).
    if (child.exitCode === null) {
      child.kill('SIGTERM');
      abortEscalation = setTimeout(() => {
        forceKill(child);
      }, 500);
    }
  };
  // An AbortSignal may emit an 'error' before 'close'. Never treat that
  // error as process reaping: the child can still be alive and own pipes.
  // Keep waiting for the authoritative close event before clearing SIGKILL.
  const closed = new Promise(resolve => {
    child.once('error', error => { spawnError = error; });
    child.once('close', (code, childSignal) => resolve({ code, childSignal }));
  });
  // Install close/error listeners before handling an already-aborted signal.
  // Otherwise a rapidly closing child can race the close promise.
  if (signal?.aborted) onAbort();
  else signal?.addEventListener('abort', onAbort, { once: true });
  let pendingCompletion = null;
  try {
    try {
      for await (const line of boundedLines(child.stdout)) {
      if (!line.trim()) continue;
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
    } catch (error) {
      // Destroying stdout on abort makes Node's async stream iterator reject
      // with ERR_STREAM_PREMATURE_CLOSE. Preserve cancellation semantics only
      // when an actual abort was requested; other stream errors remain fatal.
      if (!(signal?.aborted && error?.code === 'ERR_STREAM_PREMATURE_CLOSE')) throw error;
    }
    const { code, childSignal } = await closed;
    if (spawnError) throw spawnError;
    if (signal?.aborted) throw Object.assign(new Error('transport aborted'), { name: 'AbortError' });
    if (code !== 0) throw new Error(`transport exited ${childSignal ?? code}`);
    if (pendingCompletion) yield pendingCompletion;
  } finally {
    signal?.removeEventListener('abort', onAbort);
    child.stdout.destroy();
    if (child.exitCode === null) {
      // A provider process may ignore SIGTERM (or keep stdout open). Do not
      // hang session teardown indefinitely while awaiting its close event.
      child.kill('SIGTERM');
      const escalation = setTimeout(() => {
        // signalCode can already be SIGTERM immediately after kill(), even
        // while a stubborn process is still alive. Only close settles `closed`;
        // do not suppress escalation based on signalCode.
        forceKill(child);
      }, 500);
      try { await closed; } finally { clearTimeout(escalation); clearTimeout(abortEscalation); }
    } else {
      await closed.catch(() => {});
      clearTimeout(abortEscalation);
    }
  }
}
