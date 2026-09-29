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
 */
export function registerIpc(deps: IpcDeps): void {
  ipcMain.handle('atk:backend-status', () => deps.getBackend()?.snapshot() ?? null);
  ipcMain.handle('atk:backend-restart', async () => deps.getBackend()?.restart() ?? false);

  ipcMain.handle('atk:pty-list', () => deps.getTerminals()?.list() ?? []);
  ipcMain.handle(
    'atk:pty-create',
    (_event, options: { agent: string; cmd: string; args?: string[]; cwd?: string; cols?: number; rows?: number }) =>
      deps.getTerminals()?.create(options) ?? null,
  );
  ipcMain.handle('atk:pty-write', (_event, id: string, data: string) => deps.getTerminals()?.write(id, data) ?? false);
  ipcMain.handle('atk:pty-resize', (_event, id: string, cols: number, rows: number) => deps.getTerminals()?.resize(id, cols, rows) ?? false);
  ipcMain.handle('atk:pty-signal', (_event, id: string, signal: 'int' | 'term' | 'kill') => deps.getTerminals()?.signal(id, signal) ?? false);
  ipcMain.handle('atk:pty-close', (_event, id: string) => deps.getTerminals()?.close(id) ?? false);
}
