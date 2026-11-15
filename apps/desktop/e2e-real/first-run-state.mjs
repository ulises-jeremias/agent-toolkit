// Fail closed rather than treating a reused profile as clean D01 evidence.
import fs from 'node:fs';
import path from 'node:path';

export function assertFreshFirstRunState(root) {
  for (const name of ['home', 'user-data', 'pty-runtime', 'setup-done']) {
    if (fs.existsSync(path.join(root, name))) {
      throw new Error(`D01 requires a fresh profile: ${name} already exists under ${root}. Use a new isolated HOME/ATK_PROVIDER or remove only this throwaway test profile after preserving evidence.`);
    }
  }
}
