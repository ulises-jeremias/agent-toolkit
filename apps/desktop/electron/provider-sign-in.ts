import type { TerminalCreateOptions } from './terminal';
import { findBinary } from './focus/providers';
import type { ProviderSignInId } from '../src/types/electron';

interface SignInCommand {
  binary: string;
  args: readonly string[];
  label: string;
}

const SIGN_IN_COMMANDS: Record<ProviderSignInId, { binaryName: string; args: readonly string[]; label: string }> = {
  claude: { binaryName: 'claude', args: ['auth', 'login'], label: 'Claude Code sign-in' },
  codex: { binaryName: 'codex', args: ['login'], label: 'Codex sign-in' },
};

/** Resolve a fixed command in Electron main; renderer input is only an allowlisted provider id. */
export function resolveProviderSignIn(
  id: unknown,
  find: (name: string) => string | null = findBinary,
): (SignInCommand & { terminal: TerminalCreateOptions }) | null {
  if (id !== 'claude' && id !== 'codex') return null;
  const spec = SIGN_IN_COMMANDS[id];
  const binary = find(spec.binaryName);
  if (!binary) return null;
  const command: SignInCommand = { binary, args: spec.args, label: spec.label };
  return {
    ...command,
    terminal: {
      agent: command.label,
      cmd: command.binary,
      args: [...command.args],
      cols: 100,
      rows: 24,
      ephemeral: true,
    },
  };
}
