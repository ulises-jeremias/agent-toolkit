import { app, BrowserWindow, shell } from 'electron';
import path from 'node:path';
import { BackendSupervisor, type BackendState } from './backend';
import { TerminalService } from './terminal';
import { registerIpc } from './ipc';

let mainWindow: BrowserWindow | null = null;
let backend: BackendSupervisor | null = null;
let terminals: TerminalService | null = null;
let ipcRegistered = false;

function resolveRendererUrl(): { url: string; isDev: boolean } {
  const devUrl = process.env.ATK_DESKTOP_DEV_URL;
  if (devUrl) return { url: devUrl, isDev: true };
  return { url: `file://${path.join(__dirname, '..', 'dist', 'index.html')}`, isDev: false };
}

async function createWindow(): Promise<void> {
  // Singleflight: macOS `activate` re-enters createWindow. Rebuilding the
  // services would orphan the running backend/PTYs and re-registering IPC
  // handlers throws. Reuse what exists.
  if (!backend) backend = new BackendSupervisor();
  if (!terminals) terminals = new TerminalService();

  const { url, isDev } = resolveRendererUrl();

  mainWindow = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1024,
    minHeight: 640,
    title: 'Agent Toolkit',
    backgroundColor: '#f3ead3',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
    },
  });

  // Drop the reference as soon as the window closes so later sends and
  // backend-startup paths never touch a destroyed BrowserWindow.
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  if (!ipcRegistered) {
    registerIpc({
      getBackend: () => backend,
      getTerminals: () => terminals,
      getWindow: () => mainWindow,
    });
    ipcRegistered = true;
  }

  terminals.attachWindow(() => mainWindow);

  mainWindow.webContents.setWindowOpenHandler(({ url: target }) => {
    try {
      const protocol = new URL(target).protocol;
      if (protocol === 'http:' || protocol === 'https:') void shell.openExternal(target);
    } catch {
      // Malformed URL: stay denied.
    }
    return { action: 'deny' };
  });

  const onBackendState = (state: BackendState): void => {
    mainWindow?.webContents.send('atk:backend-state', state);
  };
  backend.onState(onBackendState);

  if (isDev) {
    await mainWindow.loadURL(url);
  } else {
    await mainWindow.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  }

  // Start the bundled V backend after the window exists so failures are visible.
  const started = await backend.start();
  if (!started) {
    mainWindow?.webContents.send('atk:backend-state', backend.snapshot());
  }
}

void app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    void shutdown().then(() => app.quit());
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    void createWindow();
  }
});

app.on('before-quit', () => {
  void shutdown();
});

async function shutdown(): Promise<void> {
  terminals?.dispose();
  terminals = null;
  if (backend) {
    await backend.stop();
    backend = null;
  }
}
