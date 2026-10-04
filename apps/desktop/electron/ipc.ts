import { ipcMain, type BrowserWindow } from 'electron';
import type { BackendSupervisor } from './backend';
import { createDefaultHarnessFromProcess, isDefaultHarnessPath } from './harness';
import type { HarnessController, HarnessSwitchResult } from './harness-controller';
import type { McpSecretStore } from './mcp-secrets';
import { TerminalCwdError, type TerminalService } from './terminal';

export interface IpcDeps {
  getBackend: () => BackendSupervisor | null;
  getTerminals: () => TerminalService | null;
  getWindow: () => BrowserWindow | null;
  getHarness: () => HarnessController | null;
  getMcpSecrets?: () => McpSecretStore | null;
  chooseProjectDirectory?: (defaultPath: string) => Promise<string | null>;
  /** When set, rewrite backend.url to the same-origin renderer proxy. */
  getPublicBackendUrl?: () => string | null;
}

const NO_HARNESS: HarnessSwitchResult = { ok: false, error: 'unavailable', message: 'Harness controller is not ready' };

/**
 * Narrow IPC surface. The renderer reaches the V backend over HTTP directly;
 * IPC carries only desktop infrastructure: backend lifecycle, harness
 * selection, and PTY transport.
 *
 * Payloads are validated before reaching the services: TypeScript types do
 * not cross the IPC boundary. (Sender-frame pinning is deliberately absent:
 * with nodeIntegration off + contextIsolation + sandbox, only the loaded
 * renderer holds the bridge; an XSS there already owns everything IPC can
 * do, so frame checks would be theater.)
 */
export function registerIpc(deps: IpcDeps): void {
  ipcMain.handle('atk:backend-status', () => {
    const snapshot = deps.getBackend()?.snapshot() ?? null;
    if (!snapshot) return null;
    const publicUrl = deps.getPublicBackendUrl?.();
    return publicUrl && snapshot.url ? { ...snapshot, url: publicUrl } : snapshot;
  });
  ipcMain.handle('atk:backend-restart', async () => deps.getBackend()?.restart() ?? false);

  ipcMain.handle(
    'atk:mcp-secret-status',
    () =>
      deps.getMcpSecrets?.()?.status() ?? {
        available: false,
        storage: 'Unavailable',
        names: [],
        error: 'Credential storage is not ready.',
      },
  );
  ipcMain.handle('atk:mcp-secret-set', (_event, request: unknown) => {
    if (!isRecord(request)) return { ok: false, message: 'Invalid credential request.' };
    return (
      deps.getMcpSecrets?.()?.set(request.name, request.value) ?? {
        ok: false,
        message: 'Credential storage is not ready.',
      }
    );
  });
  ipcMain.handle('atk:mcp-secret-remove', (_event, name: unknown) =>
    typeof name === 'string'
      ? (deps.getMcpSecrets?.()?.remove(name) ?? { ok: false, message: 'Credential storage is not ready.' })
      : { ok: false, message: 'Invalid environment variable name.' },
  );

  ipcMain.handle('atk:harness-status', () => deps.getHarness()?.status() ?? null);
  ipcMain.handle('atk:harness-recent', () => deps.getHarness()?.recent() ?? []);
  ipcMain.handle('atk:harness-set', async (_event, request: unknown) => {
    const harness = deps.getHarness();
    if (!harness) return NO_HARNESS;
    if (!isRecord(request) || typeof request.path !== 'string') {
      return { ok: false, error: 'invalid-path', message: 'Expected { path: string }' } satisfies HarnessSwitchResult;
    }
    // mkdir is opt-in and default-path only. harnessSet/Choose/Reset never
    // create ~/.ai-workspace unless the renderer passed create:true after confirm.
    if (request.create === true) {
      if (!isDefaultHarnessPath(request.path)) {
        return {
          ok: false,
          error: 'invalid-path',
          message: 'create:true only applies to the default ~/.ai-workspace path',
        } satisfies HarnessSwitchResult;
      }
      const created = createDefaultHarnessFromProcess();
      if (!created.ok) {
        return {
          ok: false,
          error: 'not-found',
          message: created.error ?? 'Could not create the default harness folder.',
        } satisfies HarnessSwitchResult;
      }
      return harness.set(created.path);
    }
    return harness.set(request.path);
  });
  ipcMain.handle('atk:harness-choose', async () => deps.getHarness()?.choose() ?? NO_HARNESS);
  ipcMain.handle('atk:harness-reset', async () => deps.getHarness()?.reset() ?? NO_HARNESS);
  ipcMain.handle('atk:project-choose-directory', async (_event, defaultPath: unknown) => {
    if (typeof defaultPath !== 'string') return null;
    return deps.chooseProjectDirectory?.(defaultPath) ?? null;
  });

  ipcMain.handle('atk:pty-list', () => deps.getTerminals()?.list() ?? []);
  ipcMain.handle('atk:pty-tail', (_event, id: unknown) =>
    typeof id === 'string' && id ? (deps.getTerminals()?.tail(id) ?? '') : '',
  );
  ipcMain.handle(
    'atk:pty-create',
    (
      _event,
      options: {
        agent: string;
        personId?: string;
        projectId?: string;
        provider?: string;
        model?: string;
        cmd: string;
        args?: string[];
        cwd?: string;
        maxSeconds?: number;
        cols?: number;
        rows?: number;
      },
    ) => {
      if (!isRecord(options)) return null;
      const { agent, personId, projectId, provider, model, cmd, args, cwd, maxSeconds, cols, rows } = options;
      if (typeof agent !== 'string' || !agent.trim()) return null;
      if (typeof cmd !== 'string' || !cmd.trim()) return null;
      if (args !== undefined && (!Array.isArray(args) || args.some((a) => typeof a !== 'string'))) return null;
      if (cwd !== undefined && typeof cwd !== 'string') return null;
      if (maxSeconds !== undefined && (!isPositiveInt(maxSeconds) || maxSeconds > 31_536_000)) return null;
      if (personId !== undefined && (typeof personId !== 'string' || !/^[a-z0-9][a-z0-9_-]{0,63}$/.test(personId)))
        return null;
      if (projectId !== undefined && (typeof projectId !== 'string' || projectId.length > 256)) return null;
      if (provider !== undefined && (typeof provider !== 'string' || provider.length > 64)) return null;
      if (model !== undefined && (typeof model !== 'string' || model.length > 256)) return null;
      if (cols !== undefined && !isPositiveInt(cols)) return null;
      if (rows !== undefined && !isPositiveInt(rows)) return null;
      try {
        return (
          deps.getTerminals()?.create({
            agent,
            personId,
            projectId,
            provider,
            model,
            cmd,
            args: args ?? [],
            cwd,
            maxSeconds,
            cols,
            rows,
          }) ?? null
        );
      } catch (error) {
        if (error instanceof TerminalCwdError) return null;
        throw error;
      }
    },
  );
  ipcMain.handle('atk:pty-write', (_event, id: unknown, data: unknown) =>
    typeof id === 'string' && typeof data === 'string' ? (deps.getTerminals()?.write(id, data) ?? false) : false,
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
