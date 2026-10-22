import type { ModelInfo, Person, ProviderInfo } from '../../lib/api';
import type { PtyCreateOptions } from '../../types/electron';
import { newProviderSessionId, providerResumeSupport, providerSessionIdFlag } from './providerResume';

export type InitialPromptMode = 'positional' | 'opencode-mini' | 'copilot-interactive' | 'unsupported';

/** Runner prompt support is explicit: unknown CLIs open normally and never receive guessed flags. */
// Positional-prompt runners are verified against their installed CLIs:
// `cursor-agent [prompt...]` documents the positional as "Initial prompt
// for the agent" and stays interactive without --print; `muse [PROMPT]`
// documents "pass a prompt to start a session" in its interactive TUI.
export function initialPromptMode(providerId: string): InitialPromptMode {
  switch (providerId) {
    case 'claude':
    case 'codex':
    case 'cursor':
    case 'muse':
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
  // Assign-strategy runners (claude, copilot, opencode) get a session id
  // we choose, so the conversation can be resumed later. It must precede
  // the prompt; opencode uses --session with a ses_-prefixed id.
  const providerSessionId =
    providerResumeSupport(provider.id)?.kind === 'assign' ? newProviderSessionId(provider.id) : undefined;
  if (providerSessionId) args.push(providerSessionIdFlag(provider.id), providerSessionId);
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
    ...(providerSessionId ? { providerSessionId } : {}),
    cmd: provider.bin,
    args,
    cwd,
    ...(person.budget?.max_seconds ? { maxSeconds: person.budget.max_seconds } : {}),
  };
}
