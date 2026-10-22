import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, spawn } from 'node:child_process';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend, type Desktop } from './fixtures';

/**
 * Swarm Person-session linkage (slice: canonical PersonSession per launched
 * role). A Person bound to a recipe role must become a real PersonSession
 * only when the runner actually launches in a process adapter (tmux), must
 * be listed in the Operations run inspector, and must close when the run
 * stops. A binding alone (headless/dry-run) creates no session — that side
 * is covered by the binding test in desktop.spec.ts.
 *
 * Skips when no tmux adapter is available on the host (e.g. minimal CI
 * images): without a process adapter there is nothing truthful to launch.
 */
let desktop: Desktop;

test.beforeAll(async () => {
  desktop = await openDesktop();
});

test.afterAll(async () => {
  await desktop?.close();
});

function backendBinary(): string {
  const candidates = [
    process.env['ATK_E2E_BACKEND_BIN'],
    path.resolve(__dirname, '../../../../dist/agent-toolkit'),
    path.resolve(__dirname, '../../../../build/agent-toolkit'),
  ].filter((candidate): candidate is string => Boolean(candidate));
  const binary = candidates.find((candidate) => fs.existsSync(candidate));
  if (!binary) throw new Error('The E2E backend binary is unavailable for swarm handoff commands');
  return binary;
}

function swarmCli(args: string[]): string {
  return execFileSync(backendBinary(), ['swarm', ...args, '--workspace', desktop.workspace], {
    env: {
      ...process.env,
      HOME: desktop.home,
      XDG_CONFIG_HOME: path.join(desktop.home, '.config'),
      XDG_DATA_HOME: path.join(desktop.home, '.local', 'share'),
      AGENT_TOOLKIT_WORKSPACE: desktop.workspace,
    },
    encoding: 'utf8',
    stdio: 'pipe',
  });
}

function sessionRecords(): string {
  const sessionsDir = path.join(desktop.workspace, '.agent-toolkit', 'sessions');
  if (!fs.existsSync(sessionsDir)) return '';
  return fs
    .readdirSync(sessionsDir)
    .map((file) => fs.readFileSync(path.join(sessionsDir, file), 'utf8'))
    .join('\n');
}

async function createPerson(name: string, id: string, role: string): Promise<void> {
  const { page } = desktop;
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
  await page.getByRole('button', { name: 'Create Person' }).click();
  const personDialog = page.getByRole('dialog', { name: 'Create Person' });
  await personDialog.getByRole('textbox', { name: 'Name' }).fill(name);
  await personDialog.getByRole('textbox', { name: 'ID' }).fill(id);
  await personDialog.getByRole('textbox', { name: 'Role' }).fill(role);
  await personDialog.getByRole('textbox', { name: 'Goal' }).fill(`Work assigned to the ${role} swarm role`);
  await personDialog.getByRole('button', { name: 'Create Person' }).click();
  await expect(personDialog).toBeHidden();
}

async function startTmuxSwarm(
  task: string,
  bindings: Record<string, string>,
  adapterName: 'tmux' | 'herdr' = 'tmux',
): Promise<string> {
  const { page, workspace } = desktop;
  initRepo(workspace);
  const link = path.join(workspace, 'projects', 'e2e-workspace');
  fs.mkdirSync(path.dirname(link), { recursive: true });
  if (!fs.existsSync(link)) fs.symlinkSync(workspace, link, 'dir');
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start swarm' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a swarm' });
  await dialog.getByLabel('Project').selectOption('e2e-workspace');
  await dialog.getByLabel('Task').fill(task);
  for (const [role, personId] of Object.entries(bindings)) {
    await dialog.getByLabel(`Person for ${role}`).selectOption(personId);
  }
  await dialog.getByText('Runtime options').click();
  const adapter = dialog.getByLabel('Session adapter');
  const adapterOptions = await adapter.locator('option').allTextContents();
  test.skip(
    !adapterOptions.some((label) => label.startsWith(adapterName)),
    `${adapterName} session adapter unavailable on this host (options: ${adapterOptions.join(', ')})`,
  );
  await adapter.selectOption(adapterName);
  for (const role of ['implementer', 'reviewer', 'integrator']) {
    const roleRuntime = dialog.getByRole('group', { name: `Runtime settings for ${role}` });
    await roleRuntime.locator('summary').click();
    await dialog.getByLabel(`Runner for ${role}`).selectOption('skeleton');
  }
  await expect(dialog.getByLabel('Launch real role sessions')).toBeChecked();
  await dialog.getByRole('button', { name: 'Start swarm' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText(/Swarm start posted/);
  const swarmPanel = page.getByRole('region', { name: 'Swarms' });
  const runRow = swarmPanel
    .getByRole('row')
    .filter({ hasText: task })
    .getByRole('button', { name: new RegExp(task) });
  await expect(runRow).toBeVisible();
  const runId = (await runRow.innerText()).trim().split(/\s+/)[0] ?? '';
  expect(runId).not.toBe('');
  await runRow.click();
  return runId;
}

function inspectorSessionRow(personName: string) {
  const inspector = desktop.page.getByRole('region', { name: 'pair' });
  const roleExecution = inspector.getByRole('region', { name: 'Role execution' });
  const sessionTable = roleExecution.locator('table').filter({ hasText: 'Person session' });
  return sessionTable.getByRole('row').filter({ hasText: personName });
}

async function stopRunFromInspector(): Promise<void> {
  const { page } = desktop;
  const inspector = page.getByRole('region', { name: 'pair' });
  await inspector.getByRole('button', { name: 'Stop' }).click();
  const stopDialog = page.getByRole('dialog', { name: 'Stop this swarm run?' });
  await stopDialog.getByRole('button', { name: 'Stop run' }).click();
  await expect(inspector.getByText('cancelled', { exact: true })).toBeVisible({ timeout: 20_000 });
}

function initRepo(dir: string): void {
  execFileSync('git', ['init', '--quiet', dir]);
  execFileSync(
    'git',
    [
      '-C',
      dir,
      '-c',
      'user.name=Agent Toolkit E2E',
      '-c',
      'user.email=e2e@agent-toolkit.invalid',
      'commit',
      '--allow-empty',
      '-m',
      'init',
    ],
    { stdio: 'pipe' },
  );
}

test('tmux swarm launch records a PersonSession that closes on stop', async () => {
  const { page, workspace } = desktop;
  await waitForBackend(page);
  initRepo(workspace);
  const link = path.join(workspace, 'projects', 'e2e-workspace');
  fs.mkdirSync(path.dirname(link), { recursive: true });
  if (!fs.existsSync(link)) fs.symlinkSync(workspace, link, 'dir');

  // Create the durable Person through the GUI.
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
  await page.getByRole('button', { name: 'Create Person' }).click();
  const personDialog = page.getByRole('dialog', { name: 'Create Person' });
  await personDialog.getByRole('textbox', { name: 'Name' }).fill('Mara');
  await personDialog.getByRole('textbox', { name: 'ID' }).fill('mara');
  await personDialog.getByRole('textbox', { name: 'Role' }).fill('implementer');
  await personDialog.getByRole('textbox', { name: 'Goal' }).fill('Implement work assigned to my swarm role');
  await personDialog.getByRole('button', { name: 'Create Person' }).click();
  await expect(personDialog).toBeHidden();

  // Start a real tmux swarm with Mara bound to the implementer role.
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Operations' }).click();
  await page.getByRole('button', { name: 'Start swarm' }).click();
  const dialog = page.getByRole('dialog', { name: 'Start a swarm' });
  await dialog.getByLabel('Project').selectOption('e2e-workspace');
  await dialog.getByLabel('Task').fill('Link the launched worker to a Person session');
  await dialog.getByLabel('Person for implementer').selectOption('mara');
  await dialog.getByText('Runtime options').click();
  const adapter = dialog.getByLabel('Session adapter');
  const adapterOptions = await adapter.locator('option').allTextContents();
  test.skip(
    !adapterOptions.some((label) => label.startsWith('tmux')),
    `tmux session adapter unavailable on this host (options: ${adapterOptions.join(', ')})`,
  );
  await adapter.selectOption('tmux');
  // Every role must use the skeleton runner: the default runner binary is
  // not guaranteed to exist on the test host (notably CI), and the engine
  // validates launchable runners at start.
  for (const role of ['implementer', 'reviewer', 'integrator']) {
    const roleRuntime = dialog.getByRole('group', { name: `Runtime settings for ${role}` });
    await roleRuntime.locator('summary').click();
    await dialog.getByLabel(`Runner for ${role}`).selectOption('skeleton');
  }
  await expect(dialog.getByLabel('Launch real role sessions')).toBeChecked();
  await dialog.getByRole('button', { name: 'Start swarm' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Receipts' })).toContainText(/Swarm start posted/);

  const swarmPanel = page.getByRole('region', { name: 'Swarms' });
  const runRow = swarmPanel
    .getByRole('row')
    .filter({ hasText: 'Link the launched worker to a Person session' })
    .getByRole('button', { name: /Link the launched worker to a Person session/ });
  await expect(runRow).toBeVisible();
  const runId = (await runRow.innerText()).trim().split(/\s+/)[0] ?? '';
  expect(runId).not.toBe('');
  await runRow.click();

  // The canonical store holds the launched role's PersonSession.
  const sessionsDir = path.join(workspace, '.agent-toolkit', 'sessions');
  await expect
    .poll(
      () =>
        fs.existsSync(sessionsDir)
          ? fs
              .readdirSync(sessionsDir)
              .map((file) => fs.readFileSync(path.join(sessionsDir, file), 'utf8'))
              .join('\n')
          : '',
      { timeout: 20_000 },
    )
    .toContain('"source":"swarm"');

  // The inspector lists the canonical PersonSession for the launched role.
  const inspector = page.getByRole('region', { name: 'pair' });
  const roleExecution = inspector.getByRole('region', { name: 'Role execution' });
  const sessionTable = roleExecution.locator('table').filter({ hasText: 'Person session' });
  const sessionRow = sessionTable.getByRole('row').filter({ hasText: 'Mara' });
  await expect(sessionRow).toContainText('implementer', { timeout: 20_000 });
  await expect(sessionRow).toContainText('running');

  // Stopping the run closes the PersonSession.
  await inspector.getByRole('button', { name: 'Stop' }).click();
  const stopDialog = page.getByRole('dialog', { name: 'Stop this swarm run?' });
  await stopDialog.getByRole('button', { name: 'Stop run' }).click();
  await expect(inspector.getByText('cancelled', { exact: true })).toBeVisible({ timeout: 20_000 });
  await expect(sessionRow).toContainText('stopped', { timeout: 20_000 });

  // The same record is durable in People history with its swarm origin.
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
  await page.getByRole('button', { name: 'Mara implementer Offline' }).click();
  await expect(page.getByText(/Swarm implementer · run/)).toBeVisible();

  // Best-effort: the run's tmux server must not leak past the test.
  try {
    execFileSync('tmux', ['-L', `agent-toolkit-swarm-${runId}`, 'kill-server'], { stdio: 'pipe' });
  } catch {
    // Already gone with the run stop; nothing to clean.
  }
});

test('handoff to a waiting role launches its bound Person session', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await createPerson('Hana', 'hana', 'implementer');
  await createPerson('Rui', 'rui', 'reviewer');
  const runId = await startTmuxSwarm('Hand the implementation to the reviewer', {
    implementer: 'hana',
    reviewer: 'rui',
  });

  // Only the first role launches at start; the reviewer waits for a handoff.
  await expect(inspectorSessionRow('Hana')).toContainText('running', { timeout: 20_000 });
  await expect(inspectorSessionRow('Rui')).toHaveCount(0);
  expect(sessionRecords()).not.toContain('"rui"');

  // A real handoff to the waiting role auto-starts its runner, which is
  // what records Rui's canonical PersonSession.
  swarmCli(['handoff', 'create', '--type', 'artifact', '--from', 'implementer', '--to', 'reviewer', '--run-id', runId]);
  await expect(inspectorSessionRow('Rui')).toContainText('reviewer', { timeout: 60_000 });
  await expect(inspectorSessionRow('Rui')).toContainText('running');
  await expect.poll(() => sessionRecords(), { timeout: 20_000 }).toContain('"rui"');
  const trace = fs.readFileSync(
    path.join(desktop.workspace, '.agent-toolkit', 'swarm', 'runs', runId, 'trace.jsonl'),
    'utf8',
  );
  expect(trace).toContain('handoff_autostart_ok');

  await stopRunFromInspector();
  await expect(inspectorSessionRow('Hana')).toContainText('stopped', { timeout: 20_000 });
  await expect(inspectorSessionRow('Rui')).toContainText('stopped', { timeout: 20_000 });
  try {
    execFileSync('tmux', ['-L', `agent-toolkit-swarm-${runId}`, 'kill-server'], { stdio: 'pipe' });
  } catch {
    // Already gone with the run stop; nothing to clean.
  }
});

test('a running swarm worker appears as a World character at its project house and opens the run', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await createPerson('Sora', 'sora', 'implementer');
  const runId = await startTmuxSwarm('Show the swarm worker in the World', { implementer: 'sora' });
  await expect(inspectorSessionRow('Sora')).toContainText('running', { timeout: 20_000 });

  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
  const character = page.getByRole('button', { name: /Sora.*Person session.*session open/i });
  await expect(character).toBeVisible({ timeout: 20_000 });
  const house = page.locator('[data-entity-id="place:project:e2e-workspace"]');
  await expect(house).toBeVisible();
  const characterBox = await character.boundingBox();
  const houseBox = await house.boundingBox();
  expect(characterBox).not.toBeNull();
  expect(houseBox).not.toBeNull();
  expect(characterBox!.x).toBeGreaterThanOrEqual(houseBox!.x);
  expect(characterBox!.x).toBeLessThan(houseBox!.x + houseBox!.width);
  expect(characterBox!.y).toBeGreaterThanOrEqual(houseBox!.y);
  expect(characterBox!.y).toBeLessThan(houseBox!.y + houseBox!.height);
  if (process.env['ATK_CAPTURE_DIR']) {
    await setViewport(desktop.app, 1920, 1080);
    await page.screenshot({ path: path.join(process.env['ATK_CAPTURE_DIR'], 'world-swarm-person-large.png') });
    await setViewport(desktop.app, 1024, 768);
    await page.screenshot({ path: path.join(process.env['ATK_CAPTURE_DIR'], 'world-swarm-person-compact.png') });
  }

  // The character inspects the real work: it opens the Operations run,
  // never a fabricated terminal for a tmux session.
  await character.click();
  await expect(page).toHaveURL(new RegExp(`#/operations\\?[^#]*swarm=${runId}`));
  await expect(page.getByRole('region', { name: 'pair' })).toBeVisible();

  await stopRunFromInspector();
  await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
  await expect(character).toHaveCount(0, { timeout: 20_000 });
  try {
    execFileSync('tmux', ['-L', `agent-toolkit-swarm-${runId}`, 'kill-server'], { stdio: 'pipe' });
  } catch {
    // Already gone with the run stop; nothing to clean.
  }
});

test('a dead tmux worker surface closes its Person session as interrupted, then the run still stops', async () => {
  const { page } = desktop;
  await waitForBackend(page);
  await createPerson('Kenji', 'kenji', 'implementer');
  const runId = await startTmuxSwarm('Lose the worker surface mid-run', { implementer: 'kenji' });
  await expect(inspectorSessionRow('Kenji')).toContainText('running', { timeout: 20_000 });

  // The worker surface dies without the run reaching a terminal state:
  // the record must not keep claiming `running` once anyone looks.
  execFileSync('tmux', ['-L', `agent-toolkit-swarm-${runId}`, 'kill-server'], { stdio: 'pipe' });
  await expect(inspectorSessionRow('Kenji')).toContainText('interrupted', { timeout: 30_000 });
  await expect.poll(() => sessionRecords(), { timeout: 20_000 }).toContain('"interrupted"');

  // Recovery stays operator-driven: stopping the run still resolves it.
  await stopRunFromInspector();
  try {
    execFileSync('tmux', ['-L', `agent-toolkit-swarm-${runId}`, 'kill-server'], { stdio: 'pipe' });
  } catch {
    // Already gone with the run stop; nothing to clean.
  }
});

function herdrTestEnv(): NodeJS.ProcessEnv {
  return {
    ...process.env,
    HOME: desktop.home,
    XDG_CONFIG_HOME: path.join(desktop.home, '.config'),
    XDG_DATA_HOME: path.join(desktop.home, '.local', 'share'),
  };
}

function herdrAvailableOnHost(): boolean {
  try {
    execFileSync('herdr', ['--version'], { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

// `herdr workspace create` needs a running server; start the headless
// server only when none is answering in the isolated test HOME, and
// report whether this call started it (so the test can stop it again).
async function ensureHerdrServer(env: NodeJS.ProcessEnv): Promise<boolean> {
  const list = () => execFileSync('herdr', ['workspace', 'list'], { env, encoding: 'utf8' });
  try {
    list();
    return false;
  } catch {
    const server = spawn('herdr', ['server'], { detached: true, stdio: 'ignore', env });
    server.unref();
    await expect
      .poll(
        () => {
          try {
            list();
            return true;
          } catch {
            return false;
          }
        },
        { timeout: 20_000 },
      )
      .toBe(true);
    return true;
  }
}

function stopHerdrServerIfStarted(env: NodeJS.ProcessEnv, started: boolean): void {
  if (!started) return;
  try {
    execFileSync('herdr', ['server', 'stop'], { env, stdio: 'pipe' });
  } catch {
    // Already gone with the workspace close; nothing to clean.
  }
}

test('a lost herdr workspace closes its Person session as interrupted, then the run still stops', async () => {
  test.setTimeout(240_000);
  const { page } = desktop;
  test.skip(!herdrAvailableOnHost(), 'herdr session adapter unavailable on this host');
  // The backend spawns herdr with the isolated test HOME, so every herdr
  // call in this test must use that same environment and socket.
  const herdrEnv = herdrTestEnv();
  const herdrList = () => execFileSync('herdr', ['workspace', 'list'], { env: herdrEnv, encoding: 'utf8' });
  const startedServer = await ensureHerdrServer(herdrEnv);
  await waitForBackend(page);
  await createPerson('Mira', 'mira', 'implementer');
  const runId = await startTmuxSwarm('Lose the herdr workspace mid-run', { implementer: 'mira' }, 'herdr');
  await expect(inspectorSessionRow('Mira')).toContainText('running', { timeout: 30_000 });

  // The herdr workspace dies without the run reaching a terminal state:
  // the record must not keep claiming `running` once anyone looks.
  const list = herdrList();
  const labelAt = list.indexOf(`"label":"swarm-${runId}"`);
  expect(labelAt).toBeGreaterThanOrEqual(0);
  const idMarker = '"workspace_id":"';
  const idAt = list.indexOf(idMarker, labelAt);
  const workspaceId = list.slice(idAt + idMarker.length, list.indexOf('"', idAt + idMarker.length));
  expect(workspaceId).not.toBe('');
  execFileSync('herdr', ['workspace', 'close', workspaceId], { env: herdrEnv, stdio: 'pipe' });

  await expect(inspectorSessionRow('Mira')).toContainText('interrupted', { timeout: 30_000 });
  await expect.poll(() => sessionRecords(), { timeout: 20_000 }).toContain('"interrupted"');

  // Recovery stays operator-driven: stopping the run still resolves it.
  await stopRunFromInspector();
  stopHerdrServerIfStarted(herdrEnv, startedServer);
});

test('handoff to a waiting role launches its bound herdr Person session', async () => {
  test.setTimeout(240_000);
  const { page } = desktop;
  test.skip(!herdrAvailableOnHost(), 'herdr session adapter unavailable on this host');
  const herdrEnv = herdrTestEnv();
  const startedServer = await ensureHerdrServer(herdrEnv);
  try {
    await waitForBackend(page);
    await createPerson('Noa', 'noa', 'implementer');
    await createPerson('Iris', 'iris', 'reviewer');
    const runId = await startTmuxSwarm(
      'Hand the herdr implementation to the reviewer',
      { implementer: 'noa', reviewer: 'iris' },
      'herdr',
    );

    // Only the first role launches at start; the reviewer waits.
    await expect(inspectorSessionRow('Noa')).toContainText('running', { timeout: 30_000 });
    await expect(inspectorSessionRow('Iris')).toHaveCount(0);
    expect(sessionRecords()).not.toContain('"iris"');

    // A real handoff to the waiting role auto-starts its herdr pane,
    // which is what records Iris's canonical PersonSession.
    swarmCli([
      'handoff',
      'create',
      '--type',
      'artifact',
      '--from',
      'implementer',
      '--to',
      'reviewer',
      '--run-id',
      runId,
    ]);
    await expect(inspectorSessionRow('Iris')).toContainText('reviewer', { timeout: 60_000 });
    await expect(inspectorSessionRow('Iris')).toContainText('running');
    await expect.poll(() => sessionRecords(), { timeout: 20_000 }).toContain('"iris"');
    const trace = fs.readFileSync(
      path.join(desktop.workspace, '.agent-toolkit', 'swarm', 'runs', runId, 'trace.jsonl'),
      'utf8',
    );
    expect(trace).toContain('handoff_autostart_ok');

    await stopRunFromInspector();
    await expect(inspectorSessionRow('Noa')).toContainText('stopped', { timeout: 20_000 });
    await expect(inspectorSessionRow('Iris')).toContainText('stopped', { timeout: 20_000 });
  } finally {
    stopHerdrServerIfStarted(herdrEnv, startedServer);
  }
});
