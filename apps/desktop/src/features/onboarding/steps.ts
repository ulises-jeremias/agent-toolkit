import type { BackendState, HarnessResolution } from '../../types/electron';

export function harnessIsChosen(harness: HarnessResolution | null | undefined): boolean {
  return harness != null && harness.source !== 'fallback';
}

export function harnessNeedsCreate(harness: HarnessResolution | null | undefined): boolean {
  return harness?.source === 'fallback';
}

export function backendIsReady(backend: BackendState | null | undefined): boolean {
  return backend?.status === 'ready';
}
