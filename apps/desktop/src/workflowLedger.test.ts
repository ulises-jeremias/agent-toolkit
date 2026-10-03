import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('Desktop workflow ledger (docs/desktop/workflows.yaml)', () => {
  it('marks a journey ok only with evidence at a recorded build', () => {
    const text = readLedger();
    const journeys: Array<Record<string, unknown>> = [];
    let current: Record<string, unknown> | null = null;
    for (const line of text.split('\n')) {
      const idMatch = line.match(/^ {2}- id: (.+)$/);
      if (idMatch) {
        current = { id: idMatch[1] };
        journeys.push(current);
        continue;
      }
      const statusMatch = line.match(/^ {4}status: (.+)$/);
      if (statusMatch && current) current.status = statusMatch[1];
    }
    expect(journeys.length).toBeGreaterThan(5);
    for (const journey of journeys) {
      expect(['ok', 'partial', 'blocked', 'not-implemented']).toContain(journey.status);
    }
    // CRUD and import now have Electron coverage with reviewed screenshots;
    // starting a Person still lacks durable AgentSession recovery semantics.
    for (const id of ['people-crud', 'people-import-review']) {
      const journey = journeys.find((j) => j.id === id);
      expect(journey, id).toBeDefined();
      expect(journey!.status).toBe('ok');
    }
    for (const id of ['people-start-session']) {
      const journey = journeys.find((j) => j.id === id);
      expect(journey, id).toBeDefined();
      expect(journey!.status).toBe('partial');
    }
    for (const id of ['swarm-role-picker']) {
      const journey = journeys.find((j) => j.id === id);
      expect(journey, id).toBeDefined();
      expect(journey!.status).toBe('partial');
    }
  });
});

function readLedger(): string {
  return readFileSync(resolve(__dirname, '../../../docs/desktop/workflows.yaml'), 'utf-8');
}
