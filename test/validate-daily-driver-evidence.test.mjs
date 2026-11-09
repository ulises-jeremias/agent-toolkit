import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateLedger } from '../scripts/validate-daily-driver-evidence.mjs';

const baseline = JSON.parse(readFileSync(new URL('../docs/desktop/daily-driver-evidence.json', import.meta.url)));
const clone = () => structuredClone(baseline);

test('unverified baseline is structurally valid, not accepted', () => {
  assert.deepEqual(validateLedger(baseline), []);
  assert.equal(baseline.status, 'unverified');
});
test('cannot accept gate with missing installed provider evidence', () => {
  const ledger = clone(); ledger.status = 'accepted';
  assert.match(validateLedger(ledger).join(' '), /D01-D07 P-level passes/);
});
test('mock-only aggregate pass is rejected', () => {
  const ledger = clone(); ledger.journeys.D03.outcome = 'pass'; ledger.journeys.D03.evidence_level = 'M';
  assert.match(validateLedger(ledger).join(' '), /aggregate pass requires P-level evidence/);
});
test('P-level claim without provenance is rejected', () => {
  const ledger = clone(); ledger.journeys.D03.outcome = 'pass'; ledger.journeys.D03.evidence_level = 'P';
  ledger.journeys.D03.runs.push({ journey_id: 'D03', outcome: 'pass', evidence_level: 'P' });
  assert.match(validateLedger(ledger).join(' '), /missing toolkit_sha/);
});
test('missing journey and false packaged trial fail', () => {
  const ledger = clone(); delete ledger.journeys.D10;
  ledger.packaged_field_trial = { outcome: 'pass', evidence_level: 'M', runs: [] };
  const errors = validateLedger(ledger).join(' ');
  assert.match(errors, /exactly D01-D10/);
  assert.match(errors, /packaged field trial pass requires P-level runs/);
});
