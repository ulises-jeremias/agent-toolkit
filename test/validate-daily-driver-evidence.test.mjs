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

test('packaged field trial cannot be certified by an unrelated placeholder', () => {
  const ledger = clone();
  ledger.packaged_field_trial = { outcome: 'pass', evidence_level: 'P', runs: [{}] };
  assert.match(validateLedger(ledger).join(' '), /missing matching P-level D01 run/);
});

test('packaged field trial requires matching provenance for every D01-D07 run', () => {
  const ledger = clone();
  const makeRun = id => ({
    journey_id: id, outcome: 'pass', evidence_level: 'P',
    toolkit_sha: 'a'.repeat(40), package_version: 'v1.49.0 sha256:fixture',
    platform: 'linux-x64', provider: 'claude', timestamp_utc: '2026-11-10T09:00:00Z',
    steps_to_reproduce: 'Open packaged app and perform task',
    observed: 'Completed real provider task', tested_by: 'tester',
    logs: ['artifacts/redacted/run.log']
  });
  for (const id of ['D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07']) {
    ledger.journeys[id] = { outcome: 'pass', evidence_level: 'P', runs: [makeRun(id)] };
  }
  ledger.packaged_field_trial = {
    outcome: 'pass', evidence_level: 'P',
    runs: ['D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07'].map(makeRun)
  };
  ledger.status = 'accepted';
  ledger.evidence_level = 'P';
  assert.deepEqual(validateLedger(ledger), []);

  ledger.packaged_field_trial.runs[3].package_version = 'different-package';
  assert.match(validateLedger(ledger).join(' '), /missing matching P-level D04 run/);
});


test('field trial cannot reuse provenance while substituting observation or artifacts', () => {
  const ledger = clone();
  const makeRun = id => ({ journey_id: id, outcome: 'pass', evidence_level: 'P',
    toolkit_sha: 'a'.repeat(40), package_version: 'v1.49.0 sha256:real',
    platform: 'linux-x64', provider: 'claude', timestamp_utc: '2026-11-11T12:00:00Z',
    steps_to_reproduce: 'Open packaged app', observed: 'Real task result',
    tested_by: 'tester', logs: ['artifacts/redacted/run.log'] });
  const ids = ['D01','D02','D03','D04','D05','D06','D07'];
  for (const id of ids) ledger.journeys[id] = { outcome: 'pass', evidence_level: 'P', runs: [makeRun(id)] };
  ledger.packaged_field_trial = { outcome: 'pass', evidence_level: 'P', runs: ids.map(makeRun) };
  ledger.status = 'accepted'; ledger.evidence_level = 'P';
  assert.deepEqual(validateLedger(ledger), []);
  ledger.packaged_field_trial.runs[2].observed = 'Unrelated result';
  assert.match(validateLedger(ledger).join(' '), /missing matching P-level D03 run/);
  ledger.packaged_field_trial.runs[2].observed = 'Real task result';
  ledger.packaged_field_trial.runs[2].logs = ['artifacts/redacted/other.log'];
  assert.match(validateLedger(ledger).join(' '), /missing matching P-level D03 run/);
  ledger.packaged_field_trial.runs[2].logs = [];
  assert.match(validateLedger(ledger).join(' '), /missing concrete artifact reference/);
});
