import type { BackendState, HarnessResolution } from '../../types/electron';

export const ONBOARDING_STEPS = ['ready', 'harness', 'tools', 'agent', 'work'] as const;

export type OnboardingStep = (typeof ONBOARDING_STEPS)[number];

export const STEP_LABELS: Record<OnboardingStep, string> = {
  ready: 'Backend',
  harness: 'Harness',
  tools: 'Coding tools',
  agent: 'Agent',
  work: 'First work',
};

export function harnessIsChosen(harness: HarnessResolution | null | undefined): boolean {
  return harness?.source === 'default' || harness?.source === 'override';
}

export function harnessNeedsCreate(harness: HarnessResolution | null | undefined): boolean {
  return harness?.source === 'fallback';
}

export function backendIsReady(backend: BackendState | null | undefined): boolean {
  return backend?.status === 'ready';
}

/**
 * No typed per-CLI discovery route exists on serve (MUNDER_GAP Phase 2 PR C).
 * The wizard must not invent INSTALLED / NOT INSTALLED badges from CLI text.
 */
export function codingAgentDiscoveryAvailable(): boolean {
  return false;
}

/**
 * No typed agent / provider / model catalog for first-run configuration.
 * Swarm `models` is a different family and must not be reused as a fake picker.
 */
export function agentProviderModelApiAvailable(): boolean {
  return false;
}
