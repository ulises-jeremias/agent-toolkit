import test from 'node:test';
import assert from 'node:assert/strict';
import { validateEvidence, packagedGateStatus } from './daily-driver-evidence.mjs';

const real = (id) => ({
  journey_id: id, outcome: 'pass', evidence_level: 'P',
  toolkit_sha: '0123456789abcdef', package_version: 'test-app sha256:example',
  platform: 'Linux x86_64', provider: 'Claude Code authenticated locally',
  timestamp_utc: '2026-11-11T09:00:00Z', steps_to_reproduce: 'Open installed app and run task',
  observed: 'Observed live process and file diff', tested_by: 'human',
  logs: ['redacted-trace.txt'],
});

test('mock, replay and unverified rows cannot pass a real-provider journey', () => {
  for (const level of ['M', 'R', 'U']) {
    assert.match(validateEvidence([{ ...real('D03'), evidence_level: level }]).join(' '), /cannot pass/);
  }
});

test('packaged evidence requires trace and package identity', () => {
  assert.match(validateEvidence([{ ...real('D03'), logs: [] }]).join(' '), /trace\/log/);
  assert.match(validateEvidence([{ ...real('D03'), package_version: '' }]).join(' '), /package_version/);
});

test('source-level proof is not packaged acceptance', () => {
  const rows = Array.from({ length: 7 }, (_, i) => ({ ...real(`D0${i + 1}`), evidence_level: 'S' }));
  assert.equal(validateEvidence(rows).length, 0);
  assert.equal(packagedGateStatus(rows).status, 'unverified');
});

test('seven complete packaged rows only become reviewable, never automatically accepted', () => {
  const rows = Array.from({ length: 7 }, (_, i) => real(`D0${i + 1}`));
  assert.deepEqual(packagedGateStatus(rows), { status: 'evidence-recorded-needs-human-review', missing: [], errors: [] });
});

test('missing journey or invalid row stays unverified', () => {
  assert.deepEqual(packagedGateStatus([]).missing, ['D01','D02','D03','D04','D05','D06','D07']);
  assert.match(validateEvidence([null]).join(' '), /expected object/);
});

test('mixed packaged versions or target platforms cannot be treated as one installed journey', () => {
  const rows = Array.from({ length: 7 }, (_, i) => real(`D0${i + 1}`));
  for (const patch of [
    { toolkit_sha: 'another-commit' },
    { package_version: 'different-installer sha256:other' },
    { platform: 'Windows x64' },
  ]) {
    const mixed = rows.map((row, i) => i === 3 ? { ...row, ...patch } : row);
    const gate = packagedGateStatus(mixed);
    assert.equal(gate.status, 'unverified');
    assert.match(gate.errors.join(' '), /multiple builds\/platforms/);
  }
});
