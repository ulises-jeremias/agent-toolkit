import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectEvidence } from '../../scripts/spikes/1668-evidence-check.mjs';

const valid = id => ({ mission: 1667, execution_id: 'trial-2026-11-17-a', journey_id: id, outcome: 'pass', evidence_level: 'P', toolkit_sha: 'abc123', package_version: 'v1 + sha256', platform: 'Linux', provider: 'Claude Code installed auth', workspace: '/tmp/fixture', timestamp_utc: '2026-11-17T12:00:00Z', steps_to_reproduce: 'open packaged app and perform task', observed: 'task executed', expected: 'task executed', tested_by: 'tester', logs: ['redacted-log'], screenshots: ['redacted-screen'] });

test('all seven packaged journeys with concrete evidence can satisfy baseline', () => {
  const result = inspectEvidence(Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`)));
  assert.equal(result.releaseReady, true);
  assert.equal(result.journeys.D08.status, 'unverified');
});
test('synthetic, source and unverified claims cannot certify packaged acceptance', () => {
  for (const level of ['M', 'R', 'S', 'U']) {
    const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
    rows[2].evidence_level = level;
    assert.equal(inspectEvidence(rows).releaseReady, false);
  }
});
test('missing artifacts and placeholder values invalidate packaged pass', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[1].screenshots = [];
  rows[2].toolkit_sha = '<exact commit>';
  const result = inspectEvidence(rows);
  assert.equal(result.releaseReady, false);
  assert.match(result.errors.join('\n'), /screenshot/);
  assert.match(result.errors.join('\n'), /toolkit_sha/);
});
test('duplicate and failed rows never override a valid packaged pass', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows.push({ ...valid('D01'), outcome: 'fail', evidence_level: 'S' });
  assert.equal(inspectEvidence(rows).releaseReady, true);
});
test('invalid rows are rejected and no empty ledger is accepted', () => {
  assert.equal(inspectEvidence([]).releaseReady, false);
  assert.deepEqual(inspectEvidence(null).errors, ['expected JSON array of evidence rows']);
  assert.match(inspectEvidence([{ journey_id: 'D99' }]).errors.join(), /unknown/);
});

test('packaged journeys from different builds cannot be stitched into a release pass', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[6].toolkit_sha = 'different-source-sha';
  assert.equal(inspectEvidence(rows).releaseReady, false);
  rows[6].toolkit_sha = rows[0].toolkit_sha;
  rows[6].package_version = 'different-installer-checksum';
  assert.equal(inspectEvidence(rows).releaseReady, false);
  rows[6].package_version = rows[0].package_version;
  rows[6].platform = 'Windows';
  assert.equal(inspectEvidence(rows).releaseReady, false);
});

test('one complete coherent build can qualify despite unrelated historical evidence', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows.push({ ...valid('D01'), toolkit_sha: 'older-build' });
  assert.equal(inspectEvidence(rows).releaseReady, true);
});

test('packaged evidence rejects null, blank and template artifact references', () => {
  for (const field of ['logs', 'screenshots']) {
    for (const invalid of [null, '', '   ', '<redacted path>']) {
      const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
      rows[3][field] = [invalid];
      const result = inspectEvidence(rows);
      assert.equal(result.releaseReady, false, `${field} ${String(invalid)}`);
      assert.match(result.errors.join('\\n'), new RegExp(field));
    }
  }
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[0].logs = ['valid-log', null];
  assert.equal(inspectEvidence(rows).releaseReady, false);
});


test('packaged passes from separate trials cannot certify one uninterrupted journey', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[6].execution_id = 'trial-2026-11-17-b';
  assert.equal(inspectEvidence(rows).releaseReady, false);
});

test('missing or placeholder execution identity cannot certify packaged acceptance', () => {
  for (const execution_id of [undefined, '', '<trial-id>']) {
    const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
    rows[0].execution_id = execution_id;
    const result = inspectEvidence(rows);
    assert.equal(result.releaseReady, false);
    assert.match(result.errors.join('\\n'), /execution_id/);
  }
});

test('a conflicting failure in the same field trial vetoes release readiness', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows.push({ ...valid('D05'), outcome: 'fail', evidence_level: 'P', observed: 'approval was not handled' });
  assert.equal(inspectEvidence(rows).releaseReady, false);
});

test('a historical failure in a separate trial does not veto a complete retest', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows.push({ ...valid('D05'), execution_id: 'previous-trial', outcome: 'fail', evidence_level: 'P' });
  assert.equal(inspectEvidence(rows).releaseReady, true);
});
