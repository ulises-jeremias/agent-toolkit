import { test, expect } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { assertFreshFirstRunState } from './first-run-state.mjs';

function withIsolatedProfile(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-d01-'));
  try {
    run(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

test('D01 accepts a pristine isolated profile', () => {
  withIsolatedProfile((root) => {
    expect(() => assertFreshFirstRunState(root)).not.toThrow();
  });
});

for (const name of ['home', 'user-data', 'pty-runtime', 'setup-done']) {
  test(`D01 rejects reused ${name} state before launching Electron`, () => {
    withIsolatedProfile((root) => {
      if (name === 'setup-done') fs.writeFileSync(path.join(root, name), 'ok');
      else fs.mkdirSync(path.join(root, name));
      expect(() => assertFreshFirstRunState(root)).toThrow(/D01 requires a fresh profile/);
    });
  });
}
