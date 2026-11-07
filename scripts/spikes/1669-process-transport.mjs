import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

// Gate 1 subprocess-boundary experiment, NOT a coding-provider adapter.
// JSONL is a fixture protocol, not a claimed Claude/Codex/OpenCode interface.
export async function* processEvents(command, args = [], { cwd, signal } = {}) {
  if (typeof command !== 'string' || !command) throw new TypeError('command required');
  const child = spawn(command, args, { cwd, signal, stdio: ['ignore', 'pipe', 'pipe'], shell: false });
  const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
  let stderr = '';
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', chunk => { stderr = (stderr + chunk).slice(-4096); });
  const closed = new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', (code, childSignal) => resolve({ code, childSignal }));
  });
  // An early spawn error must not produce an unhandled rejection.
  closed.catch(() => {});
  try {
    for await (const line of lines) {
      if (!line.trim()) continue;
      if (line.length > 1024 * 1024) throw new Error('oversized transport event');
      let event;
      try { event = JSON.parse(line); } catch { throw new Error('invalid JSONL transport event'); }
      yield event;
    }
    const { code, childSignal } = await closed;
    if (code !== 0) throw new Error(`transport exited ${childSignal ?? code}: ${stderr}`);
  } finally {
    lines.close();
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGTERM');
    await closed.catch(() => {});
  }
}
