import { contextBridge, ipcRenderer } from 'electron';
import type { AtkBridge, PtyCreateOptions, PtyExitEvent, PtyDataEvent } from '../src/types/electron';

const bridge: AtkBridge = {
  backendStatus: () => ipcRenderer.invoke('atk:backend-status'),
  backendRestart: () => ipcRenderer.invoke('atk:backend-restart'),
  onBackendState: (listener) => {
    const wrapped = (_event: unknown, state: unknown): void => {
      listener(state as Parameters<Parameters<AtkBridge['onBackendState']>[0]>[0]);
    };
    ipcRenderer.on('atk:backend-state', wrapped);
    return () => {
      ipcRenderer.removeListener('atk:backend-state', wrapped);
    };
  },
  ptyList: () => ipcRenderer.invoke('atk:pty-list'),
  ptyCreate: (options: PtyCreateOptions) => ipcRenderer.invoke('atk:pty-create', options),
  ptyWrite: (id: string, data: string) => ipcRenderer.invoke('atk:pty-write', id, data),
  ptyResize: (id: string, cols: number, rows: number) => ipcRenderer.invoke('atk:pty-resize', id, cols, rows),
  ptySignal: (id: string, signal: 'int' | 'term' | 'kill') => ipcRenderer.invoke('atk:pty-signal', id, signal),
  ptyClose: (id: string) => ipcRenderer.invoke('atk:pty-close', id),
  onPtyData: (listener) => {
    const wrapped = (_event: unknown, payload: unknown): void => {
      listener(payload as PtyDataEvent);
    };
    ipcRenderer.on('atk:pty-data', wrapped);
    return () => {
      ipcRenderer.removeListener('atk:pty-data', wrapped);
    };
  },
  onPtyExit: (listener) => {
    const wrapped = (_event: unknown, payload: unknown): void => {
      listener(payload as PtyExitEvent);
    };
    ipcRenderer.on('atk:pty-exit', wrapped);
    return () => {
      ipcRenderer.removeListener('atk:pty-exit', wrapped);
    };
  },
};

contextBridge.exposeInMainWorld('atk', bridge);
