import test from 'node:test';
import assert from 'node:assert/strict';
import { copyFileSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inspectEvidence } from '../../scripts/spikes/1668-evidence-check.mjs';

const valid = id => ({ mission: 1667, execution_id: 'trial-2026-11-17-a', journey_id: id, outcome: 'pass', evidence_level: 'P', toolkit_sha: 'a'.repeat(40), package_version: 'v1.49.0 sha256:' + 'b'.repeat(64), platform: 'Linux', provider: 'Claude Code installed auth', workspace: '/tmp/fixture', test_task: 'sum-fixture', timestamp_utc: '2026-11-17T12:00:00Z', steps_to_reproduce: 'open packaged app and perform task', observed: 'task executed', expected: 'task executed', tested_by: 'tester', logs: ['redacted-log'], screenshots: ['redacted-screen'] });

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
test('historical failed rows do not override a complete later packaged trial', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows.push({ ...valid('D01'), execution_id: 'previous-trial', outcome: 'fail', evidence_level: 'S' });
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


test('one field trial cannot stitch different workspaces or active providers', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[5].workspace = '/tmp/other-project';
  assert.equal(inspectEvidence(rows).releaseReady, false);
  rows[5].workspace = rows[0].workspace;
  rows[4].provider = 'Codex installed auth';
  assert.equal(inspectEvidence(rows).releaseReady, false);
  rows[4].provider = rows[0].provider;
  rows[1].provider = 'discovery: Claude, Codex, OpenCode';
  assert.equal(inspectEvidence(rows).releaseReady, true, 'D02 discovery may enumerate other providers');
});

test('a field trial cannot claim recovery before the task started', () => {
  const rows = Array.from({ length: 7 }, (_, i) => ({
    ...valid(`D0${i + 1}`),
    timestamp_utc: new Date(Date.UTC(2026, 10, 17, 12, i)).toISOString(),
  }));
  assert.equal(inspectEvidence(rows).releaseReady, true);
  rows[6].timestamp_utc = '2026-11-17T12:02:00Z';
  assert.equal(inspectEvidence(rows).releaseReady, false);
});

test('duplicate packaged passes in one trial cannot conceal a contradictory chronology', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows.push({ ...valid('D04'), timestamp_utc: '2026-11-17T11:00:00Z' });
  assert.equal(inspectEvidence(rows).releaseReady, false);
});


test('a field trial cannot stitch distinct coding tasks or omit task identity', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[5].test_task = 'different-task';
  assert.equal(inspectEvidence(rows).releaseReady, false);
  for (const missing of [undefined, '', '<task>']) {
    rows[5].test_task = missing;
    assert.equal(inspectEvidence(rows).releaseReady, false);
  }
  rows[5].test_task = 'sum-fixture';
  assert.equal(inspectEvidence(rows).releaseReady, true);
});

test('impossible UTC calendar dates cannot certify packaged acceptance', () => {
  for (const timestamp of ['2026-02-30T12:00:00Z', '2026-11-31T12:00:00Z', '2026-11-17T24:00:00Z']) {
    const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
    rows[3].timestamp_utc = timestamp;
    const result = inspectEvidence(rows);
    assert.equal(result.releaseReady, false, timestamp);
    assert.match(result.errors.join('\n'), /timestamp_utc/);
  }
});


test('evidence CLI executes and fails closed when installed under a path containing URL fragments', () => {
  const root = mkdtempSync(join(tmpdir(), 'gate0-cli-'));
  try {
    const folder = join(root, 'desktop #1');
    mkdirSync(folder);
    const script = join(folder, '1668-evidence-check.mjs');
    const ledger = join(folder, 'evidence.json');
    copyFileSync(fileURLToPath(new URL('../../scripts/spikes/1668-evidence-check.mjs', import.meta.url)), script);
    writeFileSync(ledger, '[]');
    const run = spawnSync(process.execPath, [script, ledger], { encoding: 'utf8' });
    assert.equal(run.status, 1, `stdout: ${run.stdout}; stderr: ${run.stderr}`);
    assert.match(run.stdout, /"releaseReady": false/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});


test('short source IDs and truncated package checksums cannot certify an installed build', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[2].toolkit_sha = 'abc123';
  rows[3].package_version = 'v1.49.0 sha256:abc';
  const result = inspectEvidence(rows);
  assert.equal(result.releaseReady, false);
  assert.match(result.errors.join(' '), /toolkit_sha must be a full 40-character Git SHA/);
  assert.match(result.errors.join(' '), /package_version must include a full sha256/);
});


test('future-dated packaged evidence cannot certify an already completed trial', () => {
  const rows = Array.from({ length: 7 }, (_, i) => valid(`D0${i + 1}`));
  rows[3].timestamp_utc = '2099-01-01T00:00:00Z';
  const result = inspectEvidence(rows);
  assert.equal(result.releaseReady, false);
  assert.match(result.errors.join('\n'), /timestamp_utc cannot be in the future/);
});
