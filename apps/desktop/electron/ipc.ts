import { ipcMain, type BrowserWindow } from 'electron';
import type { BackendSupervisor } from './backend';
import type { TerminalService } from './terminal';

export interface IpcDeps {
  getBackend: () => BackendSupervisor | null;
  getTerminals: () => TerminalService | null;
  getWindow: () => BrowserWindow | null;
}

/**
 * Narrow IPC surface. The renderer reaches the V backend over HTTP directly;
 * IPC carries only desktop infrastructure: backend lifecycle + PTY transport.
 *
 * Payloads are validated before reaching the services: TypeScript types do
 * not cross the IPC boundary. (Sender-frame pinning is deliberately absent:
 * with nodeIntegration off + contextIsolation + sandbox, only the loaded
 * renderer holds the bridge; an XSS there already owns everything IPC can
 * do, so frame checks would be theater.)
 */
export function registerIpc(deps: IpcDeps): void {
  ipcMain.handle('atk:backend-status', () => deps.getBackend()?.snapshot() ?? null);
  ipcMain.handle('atk:backend-restart', async () => deps.getBackend()?.restart() ?? false);

  ipcMain.handle('atk:pty-list', () => deps.getTerminals()?.list() ?? []);
  ipcMain.handle('atk:pty-tail', (_event, id: unknown) =>
    typeof id === 'string' && id ? (deps.getTerminals()?.tail(id) ?? '') : '',
  );
  ipcMain.handle(
    'atk:pty-create',
    (
      _event,
      options: { agent: string; run?: string; cmd: string; args?: string[]; cwd?: string; cols?: number; rows?: number },
    ) => {
      if (!isRecord(options)) return null;
      const { agent, run, cmd, args, cwd, cols, rows } = options;
      if (typeof agent !== 'string' || !agent.trim()) return null;
      if (run !== undefined && (typeof run !== 'string' || run.length > 200)) return null;
      if (typeof cmd !== 'string' || !cmd.trim()) return null;
      if (args !== undefined && (!Array.isArray(args) || args.some((a) => typeof a !== 'string'))) return null;
      if (cwd !== undefined && typeof cwd !== 'string') return null;
      if (cols !== undefined && !isPositiveInt(cols)) return null;
      if (rows !== undefined && !isPositiveInt(rows)) return null;
      return (
        deps.getTerminals()?.create({ agent, run: run || undefined, cmd, args: args ?? [], cwd, cols, rows }) ?? null
      );
    },
  );
  ipcMain.handle('atk:pty-write', (_event, id: unknown, data: unknown) =>
    typeof id === 'string' && typeof data === 'string'
      ? (deps.getTerminals()?.write(id, data) ?? false)
      : false,
  );
  ipcMain.handle('atk:pty-resize', (_event, id: unknown, cols: unknown, rows: unknown) =>
    typeof id === 'string' && isPositiveInt(cols) && isPositiveInt(rows)
      ? (deps.getTerminals()?.resize(id, cols, rows) ?? false)
      : false,
  );
  ipcMain.handle('atk:pty-signal', (_event, id: unknown, signal: unknown) =>
    typeof id === 'string' && (signal === 'int' || signal === 'term' || signal === 'kill')
      ? (deps.getTerminals()?.signal(id, signal) ?? false)
      : false,
  );
  ipcMain.handle('atk:pty-close', (_event, id: unknown) =>
    typeof id === 'string' && id ? (deps.getTerminals()?.close(id) ?? false) : false,
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isPositiveInt(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value > 0;
}
