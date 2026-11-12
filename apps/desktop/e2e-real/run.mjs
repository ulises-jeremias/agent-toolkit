// Genuine real-provider D01-D07 journey (manual evidence, never CI).
// Usage: node e2e-real/run.mjs <phase>   phase = start | relaunch-check
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { _electron as electron } from '@playwright/test';

const APP_DIR = path.resolve(process.cwd());
const REPO = path.resolve(APP_DIR, '..', '..');
const PACKAGED = process.env['ATK_PACKAGED'] === '1';
const PROVIDER = process.env['ATK_PROVIDER'] ?? 'claude';
if (!['claude', 'codex', 'opencode'].includes(PROVIDER)) throw new Error(`ATK_PROVIDER must be claude|codex|opencode, got ${PROVIDER}`);
const SUFFIX = PROVIDER === 'claude' ? '' : `-${PROVIDER}`;
const ROOT = path.join(process.env.HOME, 'dd-journey', (PACKAGED ? 'state-packaged' : 'state') + SUFFIX);
const HOME_DIR = path.join(ROOT, 'home');
const WORKSPACE = path.join(HOME_DIR, '.ai-workspace');
const FIXTURE = path.join(process.env.HOME, 'dd-journey', 'fixture-repo');
const EVIDENCE = path.join(process.env.HOME, 'dd-journey', (PACKAGED ? 'evidence-packaged' : 'evidence') + SUFFIX);
const BACKEND = path.join(REPO, 'build', 'agent-toolkit');
fs.mkdirSync(EVIDENCE, { recursive: true });

const evidence = { steps: [], started_at: new Date().toISOString(), provider: PROVIDER, packaged: PACKAGED };
const note = (step, detail) => {
  evidence.steps.push({ step, detail, at: new Date().toISOString() });
  console.log(`[${step}] ${detail}`);
};

function setupOnce() {
  if (fs.existsSync(path.join(ROOT, 'setup-done'))) return;
  fs.mkdirSync(HOME_DIR, { recursive: true });
  // Link only the provider credential file into the throwaway HOME.
  if (PROVIDER === 'codex') {
    const codexDir = path.join(HOME_DIR, '.codex');
    fs.mkdirSync(codexDir, { recursive: true });
    for (const f of ['auth.json', 'config.toml']) {
      const src = path.join(process.env.HOME, '.codex', f);
      const dst = path.join(codexDir, f);
      if (fs.existsSync(src) && !fs.existsSync(dst)) fs.symlinkSync(src, dst);
    }
  }
  if (PROVIDER === 'opencode') {
    // OpenCode stores auth under $XDG_DATA_HOME/opencode (launch() points
    // XDG_DATA_HOME at HOME_DIR/.local/share).
    const ocDir = path.join(HOME_DIR, '.local', 'share', 'opencode');
    fs.mkdirSync(ocDir, { recursive: true });
    const src = path.join(process.env.HOME, '.local', 'share', 'opencode', 'auth.json');
    const dst = path.join(ocDir, 'auth.json');
    if (fs.existsSync(src) && !fs.existsSync(dst)) fs.symlinkSync(src, dst);
  }
  const claudeDir = path.join(HOME_DIR, '.claude');
  fs.mkdirSync(claudeDir, { recursive: true });
  const cred = path.join(process.env.HOME, '.claude', '.credentials.json');
  const credLink = path.join(claudeDir, '.credentials.json');
  if (fs.existsSync(cred) && !fs.existsSync(credLink)) fs.symlinkSync(cred, credLink);
  // A real first-run user completes Claude's onboarding + folder trust once;
  // seed that state so the interactive runner starts on the task, exactly
  // like a configured developer machine (the provider itself is untouched).
  fs.writeFileSync(
    path.join(HOME_DIR, '.claude.json'),
    JSON.stringify({
      hasCompletedOnboarding: true,
      theme: 'dark',
      projects: { [FIXTURE]: { hasTrustDialogAccepted: true, hasCompletedProjectOnboarding: true } },
    }),
  );
  const env = {
    ...process.env,
    HOME: HOME_DIR,
    XDG_CONFIG_HOME: path.join(HOME_DIR, '.config'),
    XDG_DATA_HOME: path.join(HOME_DIR, '.local', 'share'),
  };
  execFileSync(BACKEND, ['workspace', 'init', '--dir', WORKSPACE], { env, stdio: 'pipe' });
  try {
    execFileSync(BACKEND, ['project', 'add', FIXTURE, '--workspace', WORKSPACE], { env, stdio: 'pipe' });
  } catch { /* already registered on re-runs */ }
  fs.writeFileSync(path.join(ROOT, 'setup-done'), 'ok');
  note('setup', `workspace + project registered (${FIXTURE})`);
}

async function launch() {
  const env = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env['ELECTRON_RUN_AS_NODE'];
  env['HOME'] = HOME_DIR;
  env['XDG_CONFIG_HOME'] = path.join(HOME_DIR, '.config');
  env['XDG_DATA_HOME'] = path.join(HOME_DIR, '.local', 'share');
  env['ATK_BACKEND_BIN'] = BACKEND;
  env['AGENT_TOOLKIT_PTY_RUNTIME_DIR'] = path.join(ROOT, 'pty-runtime');
  env['ELECTRON_DISABLE_SANDBOX'] = '1';
  env['NO_COLOR'] = '1';
  const packagedExe = path.join(APP_DIR, 'release', 'linux-unpacked', 'agent-toolkit-desktop');
  const app = await electron.launch({
    // Repo-pinned Electron 44.4.5 segfaults on this host's kernel/ozone;
    // the system Electron (44.10.1) runs the same app build fine. In
    // packaged mode the real packaged binary is used as-is.
    executablePath: PACKAGED ? packagedExe : (process.env['ATK_ELECTRON_BIN'] ?? '/usr/bin/electron'),
    args: [...(PACKAGED ? [] : [APP_DIR]), `--user-data-dir=${path.join(ROOT, 'user-data')}`, '--ozone-platform=headless', '--use-gl=angle', '--use-angle=swiftshader'],
    cwd: WORKSPACE,
    env,
  });
  const page = await app.firstWindow();
  await page.waitForLoadState('domcontentloaded');
  await page.addInitScript(() => localStorage.setItem('atk.desktop.onboarding.complete', '1'));
  await page.reload();
  await page.waitForLoadState('domcontentloaded');
  return { app, page };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function phaseStart() {
  setupOnce();
  const { app, page } = await launch();
  try {
    await page.getByRole('status').filter({ hasText: /^(Connected|Live)/ }).waitFor({ timeout: 30_000 });
    note('D01-D02', 'Desktop launched (ozone headless), backend Connected/Live');
    await page.screenshot({ path: path.join(EVIDENCE, '01-world.png') });

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(EVIDENCE, '00-people.png') });
    console.log('people buttons:', await page.getByRole('button').allInnerTexts().then((t) => t.join(' | ').slice(0, 400)));
    if (await page.getByRole('button', { name: /Ada/ }).count() === 0) {
      await page.getByRole('button', { name: 'Create Person' }).click();
      const create = page.getByRole('dialog', { name: 'Create Person' });
      await create.getByRole('textbox', { name: 'Name' }).fill('Ada');
      await create.getByRole('textbox', { name: 'ID' }).fill('ada');
      await create.getByRole('textbox', { name: 'Role' }).fill('implementer');
      await create.getByRole('textbox', { name: 'Goal' }).fill('Fix failing tests in the daily-driver fixture');
      await create.getByText('Capabilities and limits', { exact: true }).click();
      await create.getByRole('combobox', { name: 'Isolation' }).selectOption('worktree');
      await create.getByRole('spinbutton', { name: 'Max tokens' }).fill('200000');
      await create.getByRole('spinbutton', { name: 'Max seconds' }).fill('900');
      await create.getByRole('button', { name: 'Create Person' }).click();
      await create.waitFor({ state: 'hidden' });
    }
    note('setup', 'Person Ada exists');
    await page.getByRole('button', { name: /Ada.*implementer.*Offline/ }).click();
    await page.keyboard.press('Control+K');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByRole('textbox', { name: 'Filter commands' }).fill('Start Ada');
    await palette.getByRole('option', { name: /Start Ada/ }).click();

    const start = page.getByRole('dialog', { name: 'Start Ada' });
    const runner = start.getByRole('combobox', { name: 'Runner' });
    for (let i = 0; i < 20 && (await runner.locator('option').count()) === 0; i++) await sleep(500);
    const opts = await runner.locator('option').all();
    const values = [];
    for (const o of opts) values.push(`${await o.getAttribute('value')}:${await o.isEnabled()}`);
    note('D02', `runner options: ${values.join(', ')}`);
    await runner.selectOption(PROVIDER);
    if (process.env['ATK_MODEL']) {
      const model = start.getByRole('combobox', { name: 'Model' });
      await model.selectOption({ label: process.env['ATK_MODEL'] }).catch(() => model.selectOption(process.env['ATK_MODEL']));
      note('D02', `model selected: ${process.env['ATK_MODEL']}`);
    }
    const ack = start.getByRole('checkbox');
    if (await ack.count()) await ack.first().check();
    const task = start.getByRole('textbox', { name: 'Task for this session' });
    await task.fill('Fix the failing test in this project: run the test suite, fix the source so all tests pass, then re-run the tests to verify.');
    await page.screenshot({ path: path.join(EVIDENCE, '02-start-dialog.png') });
    await start.getByRole('button', { name: 'Start and open terminal' }).click();
    await start.waitFor({ state: 'hidden', timeout: 20_000 });
    note('D03', 'session started, terminal opened');

    // Poll for the real fix in the fixture repo (max 6 min). Like a human
    // operator, answer interactive provider prompts that block on Enter
    // (first-run import/trust confirmations keep their safe default).
    let fixed = false;
    let interventions = 0;
    for (let i = 0; i < 36 && !fixed; i++) {
      const termText = await page.locator('.xterm').first().innerText().catch(() => '');
      if (/Enter to confirm|Do you want to proceed|trust.*files/i.test(termText) && interventions < 6) {
        await page.locator('.xterm').first().click();
        await page.keyboard.press('Enter');
        interventions++;
        note('D05-intervene', `answered interactive provider prompt with Enter (#${interventions})`);
      }
      await sleep(10_000);
      try {
        execFileSync('node', ['--test'], { cwd: FIXTURE, stdio: 'pipe' });
        fixed = true;
      } catch { /* still failing */ }
      if (i === 2) await page.screenshot({ path: path.join(EVIDENCE, '03-streaming.png') });
    }
    const diff = execFileSync('git', ['-C', FIXTURE, 'diff'], { encoding: 'utf8' });
    note('D04-D06', `tests pass in fixture: ${fixed}; diff bytes: ${diff.length}`);
    fs.writeFileSync(path.join(EVIDENCE, 'fixture.diff'), diff);
    await page.screenshot({ path: path.join(EVIDENCE, '04-after-fix.png') });

    // World character check.
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    const character = page.getByRole('button', { name: /Ada.*Person session/i });
    const charVisible = await character.count();
    const runningLabel = await page.getByText(/Ada.*running/i).count();
    note('world', `Ada world character buttons: ${charVisible}; running labels: ${runningLabel}`);
    await page.screenshot({ path: path.join(EVIDENCE, '05-world-character.png') });

    // Intervene: stop the session from People.
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.getByRole('button', { name: 'Stop session' }).click();
    const stopDialog = page.getByRole('dialog', { name: "Stop Ada's session?" });
    await stopDialog.getByRole('button', { name: 'Stop session' }).click();
    await page.getByRole('button', { name: /Ada.*implementer.*Offline/ }).waitFor({ timeout: 30_000 });
    const stoppedVisible = await page.getByText('Stopped', { exact: true }).count();
    note('D05-D07a', `session stopped; 'Stopped' labels: ${stoppedVisible}`);
    await page.screenshot({ path: path.join(EVIDENCE, '06-stopped-history.png') });
    evidence.result = { fixed, stopped_labels: stoppedVisible };
  } finally {
    fs.writeFileSync(path.join(EVIDENCE, 'evidence-start.json'), JSON.stringify(evidence, null, 2));
    await app.close();
  }
}

async function phaseRelaunch() {
  const { app, page } = await launch();
  try {
    await page.getByRole('status').filter({ hasText: /^(Connected|Live)/ }).waitFor({ timeout: 30_000 });
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'People' }).click();
    await page.getByText('CONFIGURED · OFFLINE').first().waitFor({ timeout: 15_000 }).catch(() => {});
    const offline = await page.getByText('CONFIGURED · OFFLINE').count();
    const stopped = await page.getByText('STOPPED').count();
    const recent = await page.getByText('RECENT SESSIONS').count();
    const sessions = fs.readdirSync(path.join(WORKSPACE, '.agent-toolkit', 'sessions')).filter((f) => f.endsWith('.json'));
    note('D07', `after relaunch: Offline badges=${offline}, STOPPED labels=${stopped}, RECENT SESSIONS=${recent}, durable session records=${sessions.length} (${sessions.join(',')})`);
    await page.screenshot({ path: path.join(EVIDENCE, PACKAGED ? '17-relaunch-history.png' : '07-relaunch-history.png') });
    evidence.result = { offline, stopped, recent, session_records: sessions };
  } finally {
    fs.writeFileSync(path.join(EVIDENCE, 'evidence-relaunch.json'), JSON.stringify(evidence, null, 2));
    await app.close();
  }
}

const phase = process.argv[2];
if (phase === 'start') await phaseStart();
else if (phase === 'relaunch-check') await phaseRelaunch();
else throw new Error('phase must be start|relaunch-check');
