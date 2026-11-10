import test from 'node:test';
import assert from 'node:assert/strict';
import { validateLedger } from './validate-daily-driver-evidence.mjs';

function acceptedFixture() {
  const journeys = {};
  const runs = [];
  for (let i = 1; i <= 10; i++) {
    const id = `D${String(i).padStart(2, '0')}`;
    const required = i <= 7;
    const run = {
      journey_id: id, outcome: 'pass', evidence_level: 'P',
      toolkit_sha: 'a'.repeat(40), package_version: 'installed-package@1',
      platform: 'linux-x64', provider: 'claude',
      timestamp_utc: '2026-11-10T12:00:00Z',
      steps_to_reproduce: 'Open packaged app and execute journey',
      observed: 'Synthetic fixture only', tested_by: 'test',
      logs: ['synthetic://fixture']
    };
    journeys[id] = required
      ? { outcome: 'pass', evidence_level: 'P', runs: [run] }
      : { outcome: 'unverified', evidence_level: 'U', runs: [] };
    if (required) runs.push(run);
  }
  return {
    mission: 1667, gate: 0, status: 'accepted', evidence_level: 'P',
    journeys, packaged_field_trial: { outcome: 'pass', evidence_level: 'P', runs }
  };
}

test('synthetic internally consistent P-level acceptance ledger validates structurally', () => {
  assert.deepEqual(validateLedger(acceptedFixture()), []);
});

test('accepted gate cannot claim U-level evidence while journeys and field trial claim P', () => {
  const ledger = acceptedFixture();
  ledger.evidence_level = 'U';
  assert.match(validateLedger(ledger).join('\n'), /accepted gate requires P-level gate evidence/);
});

test('unverified baseline remains valid without P-level gate evidence', () => {
  const ledger = acceptedFixture();
  ledger.status = 'unverified';
  ledger.evidence_level = 'U';
  assert.deepEqual(validateLedger(ledger), []);
});
