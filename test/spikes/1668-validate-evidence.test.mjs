import test from 'node:test';
import assert from 'node:assert/strict';
import { packagedGateStatus, validateLedger } from '../../scripts/spikes/1668-validate-evidence.mjs';

test('empty ledger cannot certify packaged daily driver', () => {
  assert.deepEqual(packagedGateStatus([]).missing, ['D01','D02','D03','D04','D05','D06','D07']);
});
test('mock or source-only passes do not satisfy packaged gate', () => {
  assert.equal(packagedGateStatus([{ journey_id: 'D01', outcome: 'pass', evidence_level: 'M' }]).ready, false);
});
test('unverified evidence cannot be called pass', () => {
  assert.match(validateLedger([{ journey_id: 'D01', outcome: 'pass', evidence_level: 'U' }])[0], /cannot pass/);
});
test('packaged evidence must include reproducible provenance', () => {
  assert.ok(validateLedger([{ journey_id: 'D01', outcome: 'pass', evidence_level: 'P' }]).length > 5);
});
test('complete P rows can satisfy the gate', () => {
  const rows = Array.from({length: 7}, (_, i) => ({journey_id:`D0${i+1}`, outcome:'pass', evidence_level:'P', toolkit_sha:'a'.repeat(40), package_version:'test+sha256:abc', platform:'Linux', provider:'authenticated provider', timestamp_utc:'2026-11-07T00:00:00Z', steps_to_reproduce:'open installed app', observed:'test observed', tested_by:'tester', logs:['redacted artifact reference']}));
  assert.equal(packagedGateStatus(rows).ready, true);
});

test('placeholder metadata and artifact references cannot certify P evidence', () => {
  const row = { journey_id: 'D01', outcome: 'pass', evidence_level: 'P',
    toolkit_sha: 'a'.repeat(40), package_version: '<installer/release + checksum>',
    platform: 'Linux', provider: 'authenticated provider',
    timestamp_utc: '2026-11-07T00:00:00Z', steps_to_reproduce: 'TODO',
    observed: 'test observed', tested_by: 'tester', logs: ['<redacted path or CI artifact URL>'] };
  const errors = validateLedger([row]).join(' ');
  assert.match(errors, /package_version/);
  assert.match(errors, /steps_to_reproduce/);
  assert.match(errors, /artifact references/);
  assert.equal(packagedGateStatus([row]).ready, false);
});

test('malformed or non-UTC timestamps cannot certify P evidence', () => {
  const row = { journey_id: 'D01', outcome: 'pass', evidence_level: 'P',
    toolkit_sha: 'a'.repeat(40), package_version: 'v1.49.0 sha256:abc',
    platform: 'Linux', provider: 'authenticated provider',
    timestamp_utc: '2026-99-99T00:00:00Z', steps_to_reproduce: 'open app',
    observed: 'actual event', tested_by: 'tester', logs: ['artifact://redacted-log'] };
  assert.match(validateLedger([row]).join(' '), /timestamp_utc/);
  row.timestamp_utc = '2026-11-07T00:00:00-03:00';
  assert.match(validateLedger([row]).join(' '), /timestamp_utc/);
});

test('conflicting packaged results cannot be cherry-picked into a passing gate', () => {
  const rows = Array.from({ length: 7 }, (_, i) => ({
    journey_id: `D0${i + 1}`, outcome: 'pass', evidence_level: 'P',
    toolkit_sha: 'a'.repeat(40), package_version: 'v1.49.0 sha256:abc',
    platform: 'Linux', provider: 'authenticated provider',
    timestamp_utc: '2026-11-07T00:00:00Z',
    steps_to_reproduce: 'open installed app', observed: 'actual event',
    tested_by: 'tester', logs: ['artifact://redacted-log']
  }));
  assert.equal(packagedGateStatus(rows).ready, true);
  rows.push({ ...rows[2], outcome: 'fail', observed: 'provider crashed' });
  const status = packagedGateStatus(rows);
  assert.equal(status.ready, false);
  assert.match(status.errors.join(' '), /D03: conflicting packaged outcomes/);
});
