import type { QueryClient } from '@tanstack/react-query';
import type { OperationKind } from '../api';
import { qk, type Domain } from './keys';

/**
 * Which cached domains each whole-toolkit operation can change. Explicit so
 * an install never blows away unrelated caches (jobs, backend health).
 */
export const OPERATION_EFFECTS: Record<OperationKind, readonly Domain[]> = {
  install: ['skills', 'mcp', 'plugin', 'inventory', 'doctor', 'diff', 'tools'],
  update: ['skills', 'mcp', 'plugin', 'inventory', 'doctor', 'diff', 'tools'],
  uninstall: ['skills', 'mcp', 'plugin', 'inventory', 'doctor', 'diff', 'tools'],
  build: ['plugin', 'diff', 'inventory'],
  doctorFix: ['doctor', 'inventory', 'diff'],
};

export function invalidateDomains(queryClient: QueryClient, domains: readonly Domain[]): Promise<void> {
  return Promise.all(domains.map((domain) => queryClient.invalidateQueries({ queryKey: qk.domain(domain) }))).then(
    () => undefined,
  );
}
