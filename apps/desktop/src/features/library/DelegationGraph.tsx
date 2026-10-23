import { useState } from 'react';
import type { AgentInfo } from '../../lib/api';
import { delegationEdges, delegationNodes, type DelegationEdge } from './delegation';
import styles from './delegation.module.css';

/**
 * Delegation graph mini-view for the agent-definition catalog. Nodes and
 * edges come only from the backend-reported `delegates` frontmatter;
 * selecting an edge highlights exactly that pair. This is definition
 * topology, not live runtime activity.
 */
export function DelegationGraph({ agents }: { agents: AgentInfo[] }) {
  const edges = delegationEdges(agents);
  const nodes = delegationNodes(agents, edges);
  const [selected, setSelected] = useState<DelegationEdge | null>(null);

  if (edges.length === 0) return null;

  const inPair = (id: string) => selected !== null && (selected.from === id || selected.to === id);

  return (
    <div className={styles.graph} aria-label="Delegation graph">
      <p className={styles.title}>
        Delegation graph ({edges.length} {edges.length === 1 ? 'edge' : 'edges'})
      </p>
      <ul className={styles.nodes} aria-label="Delegating and delegated agent definitions">
        {nodes.map((id) => (
          <li key={id}>
            <span className={inPair(id) ? `${styles.node} ${styles.nodeActive}` : styles.node}>{id}</span>
          </li>
        ))}
      </ul>
      <ul className={styles.edges} aria-label="Delegation edges">
        {edges.map((edge) => {
          const active = selected?.from === edge.from && selected?.to === edge.to;
          return (
            <li key={`${edge.from}->${edge.to}`}>
              <button
                type="button"
                className={active ? `${styles.edge} ${styles.edgeActive}` : styles.edge}
                aria-pressed={active}
                aria-label={`${edge.from} delegates to ${edge.to}`}
                onClick={() => setSelected(active ? null : edge)}
              >
                {edge.from} → {edge.to}
              </button>
            </li>
          );
        })}
      </ul>
      <p className={styles.readout} role="status">
        {selected ? `${selected.from} delegates to ${selected.to}.` : 'Select a delegation edge to highlight the pair.'}
      </p>
    </div>
  );
}
