#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const ids = Array.from({ length: 10 }, (_, i) => `D${String(i + 1).padStart(2, '0')}`);
const levels = new Set(['P', 'S', 'R', 'M', 'U']);
const outcomes = new Set(['pass', 'fail', 'blocked', 'unverified']);

export function validateLedger(ledger) {
  const errors = [];
  const check = (condition, message) => { if (!condition) errors.push(message); };
  check(ledger?.mission === 1667 && ledger?.gate === 0, 'incorrect mission/gate');
  check(['unverified', 'accepted'].includes(ledger?.status), 'invalid gate status');
  check(levels.has(ledger?.evidence_level), 'invalid gate evidence level');
  const journeys = ledger?.journeys ?? {};
  check(Object.keys(journeys).sort().join(',') === ids.join(','), 'expected exactly D01-D10');
  for (const id of ids) {
    const entry = journeys[id];
    if (!entry) continue;
    check(outcomes.has(entry.outcome) && levels.has(entry.evidence_level), `${id}: invalid outcome/level`);
    check(Array.isArray(entry.runs), `${id}: runs must be an array`);
    const runs = Array.isArray(entry.runs) ? entry.runs : [];
    for (const [index, run] of runs.entries()) {
      const prefix = `${id}.runs[${index}]`;
      check(run?.journey_id === id && outcomes.has(run?.outcome) && levels.has(run?.evidence_level), `${prefix}: invalid identity/outcome/level`);
      if (run?.outcome === 'pass' && run?.evidence_level === 'P') {
        for (const field of ['toolkit_sha', 'package_version', 'platform', 'provider', 'timestamp_utc', 'steps_to_reproduce', 'observed', 'tested_by']) {
          check(typeof run[field] === 'string' && run[field].trim().length > 0, `${prefix}: missing ${field}`);
        }
        check((Array.isArray(run.logs) && run.logs.length > 0) || (Array.isArray(run.screenshots) && run.screenshots.length > 0), `${prefix}: missing artifact reference`);
      }
    }
    if (entry.outcome === 'pass') {
      check(entry.evidence_level === 'P', `${id}: aggregate pass requires P-level evidence`);
      check(runs.some(run => run?.outcome === 'pass' && run?.evidence_level === 'P'), `${id}: aggregate pass lacks P-level run`);
    }
  }
  const field = ledger?.packaged_field_trial;
  check(field && outcomes.has(field.outcome) && levels.has(field.evidence_level), 'invalid packaged field trial');
  if (field?.outcome === 'pass') check(field.evidence_level === 'P' && Array.isArray(field.runs) && field.runs.length > 0, 'packaged field trial pass requires P-level runs');
  if (ledger?.status === 'accepted') {
    check(ids.slice(0, 7).every(id => journeys[id]?.outcome === 'pass' && journeys[id]?.evidence_level === 'P'), 'accepted gate requires D01-D07 P-level passes');
    check(field?.outcome === 'pass' && field?.evidence_level === 'P', 'accepted gate requires packaged field trial');
  }
  return errors;
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  const path = process.argv[2] ?? 'docs/desktop/daily-driver-evidence.json';
  try {
    const errors = validateLedger(JSON.parse(readFileSync(path, 'utf8')));
    if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
    else console.log(`Evidence ledger valid (NOT an acceptance certification): ${path}`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
