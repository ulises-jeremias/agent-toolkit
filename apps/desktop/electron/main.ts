import { app, BrowserWindow, dialog, safeStorage, shell } from 'electron';
import path from 'node:path';
import { BackendSupervisor, type BackendState } from './backend';
import { HarnessController } from './harness-controller';
import { HARNESS_STORE_FILE, HarnessStore } from './harness-store';
import { registerIpc } from './ipc';
import { electronStorageName, McpSecretStore, mcpSecretStorePath } from './mcp-secrets';
import { startRendererServer, type RendererServer } from './renderer-server';
import { TerminalService } from './terminal';

let mainWindow: BrowserWindow | null = null;
let backend: BackendSupervisor | null = null;
let terminals: TerminalService | null = null;
let harness: HarnessController | null = null;
let mcpSecrets: McpSecretStore | null = null;
let rendererServer: RendererServer | null = null;
let ipcRegistered = false;

async function chooseHarnessDirectory(defaultPath: string): Promise<string | null> {
  const options: Electron.OpenDialogOptions = {
    title: 'Choose harness folder',
    buttonLabel: 'Use as harness',
    defaultPath,
    // createDirectory is macOS-only; elsewhere the native picker offers its own
    // "new folder" action, which is an explicit user choice.
    properties: ['openDirectory', 'createDirectory'],
  };
  const result = mainWindow ? await dialog.showOpenDialog(mainWindow, options) : await dialog.showOpenDialog(options);
  return result.canceled ? null : (result.filePaths[0] ?? null);
}

async function chooseProjectDirectory(defaultPath: string): Promise<string | null> {
  const options: Electron.OpenDialogOptions = {
    title: 'Choose an existing project folder',
    buttonLabel: 'Review project link',
    defaultPath,
    properties: ['openDirectory'],
  };
  const result = mainWindow ? await dialog.showOpenDialog(mainWindow, options) : await dialog.showOpenDialog(options);
  return result.canceled ? null : (result.filePaths[0] ?? null);
}

async function resolveRendererUrl(): Promise<string> {
  const devUrl = process.env.ATK_DESKTOP_DEV_URL;
  if (devUrl) return devUrl;
  // Packaged / local production: serve dist over loopback (not file://) so
  // mutating calls to serve keep a loopback Origin. See renderer-server.ts.
  if (!rendererServer) {
    rendererServer = await startRendererServer(path.join(__dirname, '..', 'dist'));
  }
  return rendererServer.url;
}

async function createWindow(): Promise<void> {
  // Singleflight: macOS `activate` re-enters createWindow. Rebuilding the
  // services would orphan the running backend/PTYs and re-registering IPC
  // handlers throws. Reuse what exists.
  if (!harness) {
    harness = new HarnessController({
      store: new HarnessStore(path.join(app.getPath('userData'), HARNESS_STORE_FILE)),
      getSupervisor: () => backend,
      chooseDirectory: chooseHarnessDirectory,
    });
  }
  const harnessController = harness;
  if (!mcpSecrets) {
    mcpSecrets = new McpSecretStore(mcpSecretStorePath(app.getPath('userData')), safeStorage, () =>
      electronStorageName(process.platform, safeStorage.getSelectedStorageBackend()),
    );
  }
  const secretStore = mcpSecrets;
  if (!backend) {
    backend = new BackendSupervisor({
      resolveHarness: () => harnessController.resolve(),
      resolveEnvironmentSecrets: () => secretStore.environment(),
    });
  }
  const supervisor = backend;
  if (!terminals) {
    // New shells open where serve runs; before the first start, where it will run.
    terminals = new TerminalService({
      defaultCwd: () => supervisor.snapshot().harness?.path ?? harnessController.resolve().path,
    });
  }

  const url = await resolveRendererUrl();

  mainWindow = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1024,
    minHeight: 640,
    title: 'Agent Toolkit',
    backgroundColor: '#f6ebd7',
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
      getHarness: () => harness,
      getMcpSecrets: () => mcpSecrets,
      getPublicBackendUrl: () => rendererServer?.url ?? null,
      chooseProjectDirectory,
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
    if (rendererServer && state.url) {
      rendererServer.setBackendTarget(state.url);
      mainWindow?.webContents.send('atk:backend-state', { ...state, url: rendererServer.url });
      return;
    }
    mainWindow?.webContents.send('atk:backend-state', state);
  };
  backend.onState(onBackendState);

  await mainWindow.loadURL(`${url}/`);

  // Start the bundled V backend after the window exists so failures are visible.
  const started = await backend.start();
  if (!started) {
    onBackendState(backend.snapshot());
  } else {
    onBackendState(backend.snapshot());
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
  if (rendererServer) {
    await rendererServer.close().catch(() => undefined);
    rendererServer = null;
  }
}
