import type { ModelInfo, Person, ProviderInfo } from '../../lib/api';
import type { PtyCreateOptions } from '../../types/electron';

export type InitialPromptMode = 'positional' | 'opencode-mini' | 'copilot-interactive' | 'unsupported';

/** Runner prompt support is explicit: unknown CLIs open normally and never receive guessed flags. */
export function initialPromptMode(providerId: string): InitialPromptMode {
  switch (providerId) {
    case 'claude':
    case 'codex':
      return 'positional';
    case 'opencode':
      return 'opencode-mini';
    case 'copilot':
      return 'copilot-interactive';
    default:
      return 'unsupported';
  }
}

export function personInitialPrompt(person: Person, task: string): string | null {
  if (!task.trim()) return null;
  return `Role: ${person.role}\nConfigured goal: ${person.goal}\n\nTask for this session:\n${task.trim()}`;
}

/** Build an argv-only PTY launch from real Toolkit runner discovery. */
export function personSessionOptions(
  person: Person,
  provider: ProviderInfo,
  model: ModelInfo | undefined,
  cwd: string,
  projectId: string,
  task = '',
): PtyCreateOptions | null {
  if (!provider.available || provider.id === 'skeleton' || !provider.bin || !cwd) return null;
  const args = model?.model ? ['--model', model.model] : [];
  const prompt = personInitialPrompt(person, task);
  switch (initialPromptMode(provider.id)) {
    case 'positional':
      if (prompt) args.push(prompt);
      break;
    case 'opencode-mini':
      if (prompt) args.unshift('mini');
      if (prompt) args.push('--prompt', prompt);
      break;
    case 'copilot-interactive':
      if (prompt) args.push('--interactive', prompt);
      break;
    case 'unsupported':
      break;
  }
  return {
    agent: person.name,
    personId: person.id,
    projectId,
    provider: provider.id,
    model: model?.model,
    cmd: provider.bin,
    args,
    cwd,
    ...(person.budget?.max_seconds ? { maxSeconds: person.budget.max_seconds } : {}),
  };
}
