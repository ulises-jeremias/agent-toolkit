#!/usr/bin/env node
/**
 * Daily Driver Gate 0 preflight. Never starts a coding agent session, probes
 * authentication, copies user configuration, or modifies an existing project.
 * Actual product acceptance is still a human/real-provider activity (#1668).
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const PROVIDERS = ['claude', 'codex', 'opencode', 'muse', 'cursor-agent'];
const JOURNEYS = [
  'D01 first-run',
  'D02 provider-discovery',
  'D03 real-task-start',
  'D04 streaming-observation',
  'D05 permission-and-interruption',
  'D06 terminal-and-diff',
  'D07 restart-and-resume',
  'D08 truthful-world-presence',
  'D09 cross-provider-delegation',
  'D10 toolkit-capabilities',
];

function parseArgs(argv) {
  if (argv.includes('--help') || argv.includes('-h')) {
    process.stdout.write('Usage: node scripts/daily-driver-baseline.mjs --output-dir NEW_DIR [--app INSTALLED_APP] [--backend V_BINARY]\n');
    process.exit(0);
  }
  const valid = new Set(['--output-dir', '--app', '--backend']);
  const values = {};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i];
    if (!valid.has(key) || !argv[i + 1] || argv[i + 1].startsWith('--') || values[key]) {
      throw new Error('Invalid or duplicated argument: ' + String(key));
    }
    values[key] = argv[i + 1];
  }
  if (!values['--output-dir']) throw new Error('An explicit --output-dir is required.');
  return { output: path.resolve(values['--output-dir']), app: values['--app'], backend: values['--backend'] };
}

function createEmptyOutput(dir) {
  // Reject symlinks in existing ancestor components as well as the leaf.
  // Otherwise --output-dir /trusted/link/new could write outside the intended tree.
  let ancestor = path.resolve(dir);
  while (true) {
    try {
      if (fs.lstatSync(ancestor).isSymbolicLink()) {
        throw new Error('Refusing symlink in output directory path.');
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    const parent = path.dirname(ancestor);
    if (parent === ancestor) break;
    ancestor = parent;
  }
  if (fs.existsSync(dir)) {
    if (fs.lstatSync(dir).isSymbolicLink()) throw new Error('Refusing symlink output directory.');
    if (!fs.statSync(dir).isDirectory() || fs.readdirSync(dir).length) {
      throw new Error('Output directory must be empty; refusing to overwrite existing files.');
    }
  } else {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function exec(command, argv, cwd) {
  const result = spawnSync(command, argv, {
    cwd,
    encoding: 'utf8',
    timeout: 5000,
    maxBuffer: 32768,
    shell: false,
    windowsHide: true,
  });
  // Return only a numeric version if present; never store raw provider output.
  const output = String(result.stdout || result.stderr || '');
  const version = output.match(/\bv?\d+\.\d+(?:\.\d+)?(?:[-+][0-9A-Za-z.-]+)?\b/);
  return { ok: !result.error && result.status === 0, status: result.status, version: version ? version[0] : null };
}

function filePresence(filename) {
  if (!filename) return { supplied: false, executable_exists: false };
  let exists = false;
  try { exists = fs.statSync(path.resolve(filename)).isFile(); } catch { /* Absent by design. */ }
  return { supplied: true, executable_exists: exists };
}

function makeFixture(dir) {
  const root = path.join(dir, 'fixture');
  fs.mkdirSync(path.join(root, 'src'), { recursive: true });
  fs.mkdirSync(path.join(root, 'test'), { recursive: true });
  fs.writeFileSync(path.join(root, 'src', 'sum.mjs'), 'export const sum = (a, b) => a - b;\n');
  fs.writeFileSync(path.join(root, 'test', 'sum.test.mjs'),
    "import test from 'node:test';\nimport assert from 'node:assert/strict';\nimport { sum } from '../src/sum.mjs';\ntest('sum', () => assert.equal(sum(2, 3), 5));\n");
  const init = exec('git', ['init', '--quiet', root]);
  const add = exec('git', ['-C', root, 'add', '.']);
  const commit = exec('git', ['-C', root, '-c', 'user.name=ATK Baseline',
    '-c', 'user.email=baseline@agent-toolkit.invalid', '-c', 'commit.gpgsign=false',
    'commit', '--quiet', '-m', 'test: failing baseline']);
  if (!init.ok || !add.ok || !commit.ok) throw new Error('Could not create disposable Git fixture.');
  const regression = exec(process.execPath, ['--test', 'test/sum.test.mjs'], root);
  if (regression.status !== 1) {
    throw new Error('The disposable regression test did not fail as expected (exit=' + String(regression.status) + ').');
  }
  return { directory: 'fixture/', failing_test_confirmed: true,
    instruction: 'Fix the sum implementation without changing the test; run node --test and show the diff.' };
}

function markdown(data) {
  const providerRows = data.providers.map(p => '| ' + p.id + ' | ' +
    (p.detected ? 'Found (' + (p.version || 'version unknown') + ')' : 'Not detected') +
    ' | Authentication not checked |').join('\n');
  const journeyRows = data.journeys.map(j => '| ' + j.id + ' | ' + j.name +
    ' | unverified | U | No real session executed |').join('\n');
  return [
    '# Daily Driver Gate 0 — preflight only',
    '',
    '**No real provider session or packaged Desktop has been tested by this script.**',
    'All journey results remain U/unverified. A green automated check must not upgrade them to passed.',
    '',
    'Generated: ' + data.created_at,
    '',
    '## Provider executable presence',
    '',
    '| Provider | Executable | Auth |',
    '| --- | --- | --- |',
    providerRows,
    '',
    'Packaged app specified: ' + (data.installed_app.supplied ? 'yes' : 'no') +
      '; existing file: ' + (data.installed_app.executable_exists ? 'yes' : 'no') + '.',
    'This does not establish that the app launches.',
    '',
    '## Reproducible task',
    '',
    'The controlled Git repository is in fixture/. Its test deliberately fails.',
    'Open the installed Desktop, link this folder, select an authenticated provider,',
    'review its permission mode, and submit this task:',
    '',
    '> ' + data.fixture.instruction,
    '',
    '## Real provider acceptance — fill after testing',
    '',
    '| ID | Journey | Result | Evidence | Notes |',
    '| --- | --- | --- | --- | --- |',
    journeyRows,
    '',
    'Evidence levels: P=packaged+real provider, S=source+real provider,',
    'R=recorded replay, M=mock/skeleton, U=unverified.',
    'Record provider/version, app SHA, timestamp, exact GUI steps, real diff, test outcome,',
    'redacted logs/screenshots and recovery. Never record credentials or private prompts.',
    '',
    'Protocol: https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/desktop/DAILY_DRIVER_ACCEPTANCE.md',
    '',
  ].join('\n');
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  createEmptyOutput(args.output);
  const providers = PROVIDERS.map(executable => {
    const check = exec(executable, ['--version']);
    return { id: executable, detected: check.ok, version: check.version, authenticated: 'not_checked' };
  });
  const fixture = makeFixture(args.output);
  const journeys = JOURNEYS.map(item => {
    const [id, ...rest] = item.split(' ');
    return { id, name: rest.join(' '), outcome: 'unverified', evidence_level: 'U' };
  });
  const data = {
    schema: 'agent-toolkit/daily-driver-preflight@1',
    created_at: new Date().toISOString(),
    host: { platform: process.platform, arch: process.arch, node: process.version },
    installed_app: filePresence(args.app),
    backend: filePresence(args.backend),
    providers,
    fixture,
    journeys,
  };
  fs.writeFileSync(path.join(args.output, 'baseline.json'), JSON.stringify(data, null, 2) + '\n');
  fs.writeFileSync(path.join(args.output, 'README.md'), markdown(data));
  process.stdout.write('Created controlled failing fixture and UNVERIFIED evidence sheet at ' + args.output + '\n');
  process.stdout.write('No provider was authenticated or tasked; manual packaged acceptance remains required.\n');
}

try { main(); } catch (error) {
  process.stderr.write(String(error.message) + '\n');
  process.exitCode = 1;
}
