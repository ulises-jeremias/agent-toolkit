import type { ModelInfo, Person, ProviderInfo } from '../../lib/api';
import type { PtyCreateOptions } from '../../types/electron';

/** Build an argv-only PTY launch from real Toolkit runner discovery. */
export function personSessionOptions(
  person: Person,
  provider: ProviderInfo,
  model: ModelInfo | undefined,
  cwd: string,
  projectId: string,
): PtyCreateOptions | null {
  if (!provider.available || provider.id === 'skeleton' || !provider.bin || !cwd) return null;
  const args = model?.model ? ['--model', model.model] : [];
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
