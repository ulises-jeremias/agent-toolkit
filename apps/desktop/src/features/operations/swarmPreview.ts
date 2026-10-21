/** A successful legacy preview can ignore `project_id`; require explicit backend evidence. */
export function hasProjectBoundSwarmPreview(data: Record<string, string> | undefined, projectId: string): boolean {
  return data?.['project_id'] === projectId && Boolean(data['project_path']?.trim());
}

export interface HandoffLike {
  state: string;
  act: string;
  hops: number;
  max_hops: number;
}

/** Handoffs the engine routed to a human (ADR-039): they wait in Needs-you until resolved. */
export function needsYouHandoffs<T extends HandoffLike>(handoffs: readonly T[]): T[] {
  return handoffs.filter((handoff) => handoff.state === 'awaiting_human');
}

/** Chain position label, e.g. "hop 7 of 6" once a chain passed its budget. */
export function hopLabel(handoff: HandoffLike): string {
  return handoff.max_hops > 0 ? `hop ${handoff.hops} of ${handoff.max_hops}` : `hop ${handoff.hops}`;
}
