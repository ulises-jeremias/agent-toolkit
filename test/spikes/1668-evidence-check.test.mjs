import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectEvidence } from '../../scripts/spikes/1668-evidence-check.mjs';

const valid = id => ({ mission: 1667, journey_id: id, outcome: 'pass', evidence_level: 'P', toolkit_sha: 'abc123', package_version: 'v1 + sha256', platform: 'Linux', provider: 'Claude Code installed auth', workspace: '/tmp/fixture', timestamp_utc: '2026-11-17T12:00:00Z', steps_to_reproduce: 'open packaged app and perform task', observed: 'task executed', expected: 'task executed', tested_by: 'tester', logs: ['redacted-log'], screenshots: ['redacted-screen'] });

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
