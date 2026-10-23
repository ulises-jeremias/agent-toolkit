import type { AgentInfo } from '../../lib/api';

export interface DelegationEdge {
  from: string;
  to: string;
}

/**
 * Delegation edges from real AgentInfo data. Edges pointing at ids that
 * are not in the catalog are dropped: the graph only draws relationships
 * the backend actually reported between known definitions.
 */
export function delegationEdges(agents: AgentInfo[]): DelegationEdge[] {
  const known = new Set(agents.map((agent) => agent.id));
  const edges: DelegationEdge[] = [];
  for (const agent of agents) {
    for (const target of agent.delegates ?? []) {
      if (known.has(target) && target !== agent.id) edges.push({ from: agent.id, to: target });
    }
  }
  return edges;
}

/** Ids that take part in at least one delegation edge, in catalog order. */
export function delegationNodes(agents: AgentInfo[], edges: DelegationEdge[]): string[] {
  const involved = new Set<string>();
  for (const edge of edges) {
    involved.add(edge.from);
    involved.add(edge.to);
  }
  return agents.map((agent) => agent.id).filter((id) => involved.has(id));
}
