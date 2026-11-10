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
      logs: ['artifacts/gate0/redacted-run.log']
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

test('P-level acceptance rejects pseudo artifact URLs', () => {
  const ledger = acceptedFixture();
  ledger.journeys.D01.runs[0].logs = ['synthetic://fixture'];
  assert.match(validateLedger(ledger).join('\n'), /D01.runs\[0\]: missing concrete artifact reference/);
});

test('P-level acceptance rejects malformed SHA and timestamps', () => {
  const ledger = acceptedFixture();
  ledger.journeys.D02.runs[0].toolkit_sha = 'not-a-commit';
  ledger.journeys.D03.runs[0].timestamp_utc = 'tomorrow';
  const errors = validateLedger(ledger).join('\n');
  assert.match(errors, /D02.runs\[0\]: invalid toolkit SHA/);
  assert.match(errors, /D03.runs\[0\]: invalid UTC timestamp/);
});

test('accepted field trial cannot stitch together different installed builds or hosts', () => {
  const ledger = acceptedFixture();
  ledger.packaged_field_trial.runs[3] = {
    ...ledger.packaged_field_trial.runs[3],
    package_version: 'different-package@2',
    platform: 'windows-x64',
    toolkit_sha: 'b'.repeat(40)
  };
  // Keep the journey record linked: the defect is cross-journey coherence,
  // not the existing trial-to-journey provenance check.
  ledger.journeys.D04.runs[0] = ledger.packaged_field_trial.runs[3];
  const errors = validateLedger(ledger).join('\\n');
  assert.match(errors, /D01-D07 must share toolkit_sha/);
  assert.match(errors, /D01-D07 must share package_version/);
  assert.match(errors, /D01-D07 must share platform/);
});

test('accepted field trial rejects a backwards journey chronology', () => {
  const ledger = acceptedFixture();
  const run = {
    ...ledger.packaged_field_trial.runs[4],
    timestamp_utc: '2026-11-10T11:59:59Z'
  };
  ledger.packaged_field_trial.runs[4] = run;
  ledger.journeys.D05.runs[0] = run;
  assert.match(validateLedger(ledger).join('\\n'), /timestamps must be chronological/);
});
