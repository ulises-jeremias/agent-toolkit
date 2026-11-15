import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { assertFreshFirstRunState } from './first-run-state.mjs';

test('D01 accepts a pristine isolated profile', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-d01-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  assert.doesNotThrow(() => assertFreshFirstRunState(root));
});

for (const name of ['home', 'user-data', 'pty-runtime', 'setup-done']) {
  test(`D01 rejects reused ${name} state before launching Electron`, (t) => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-d01-'));
    t.after(() => fs.rmSync(root, { recursive: true, force: true }));
    if (name === 'setup-done') fs.writeFileSync(path.join(root, name), 'ok');
    else fs.mkdirSync(path.join(root, name));
    assert.throws(() => assertFreshFirstRunState(root), /D01 requires a fresh profile/);
  });
}
