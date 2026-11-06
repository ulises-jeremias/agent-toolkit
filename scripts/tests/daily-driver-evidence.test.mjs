// Run with: node --test scripts/tests/daily-driver-evidence.test.mjs
// This validates evidence integrity, not provider behavior.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const ledger = JSON.parse(readFileSync(new URL('../../docs/desktop/daily-driver-evidence.json', import.meta.url), 'utf8'));
const ids = Array.from({ length: 10 }, (_, i) => `D${String(i + 1).padStart(2, '0')}`);
const outcomes = new Set(['pass', 'fail', 'blocked', 'unverified']);
const levels = new Set(['P', 'S', 'R', 'M', 'U']);

/** Validate recorded provenance; this does not authenticate uploaded evidence. */
function validPackagedRun(run) {
  return run.outcome === 'pass' &&
    run.evidence_level === 'P' &&
    typeof run.toolkit_sha === 'string' && /^[0-9a-f]{40}$/.test(run.toolkit_sha) &&
    typeof run.package_version === 'string' && run.package_version.length > 0 &&
    typeof run.platform === 'string' && run.platform.length > 0 &&
    typeof run.timestamp_utc === 'string' && !Number.isNaN(Date.parse(run.timestamp_utc)) &&
    typeof run.steps_to_reproduce === 'string' && run.steps_to_reproduce.length > 0 &&
    typeof run.observed === 'string' && run.observed.length > 0 &&
    Array.isArray(run.logs) && run.logs.length > 0 &&
    typeof run.tested_by === 'string' && run.tested_by.length > 0;
}

/** A later failure or blocked attempt invalidates earlier passes until retested. */
function latestRunIsPass(entry) {
  const chronological = [...entry.runs].sort((a, b) =>
    Date.parse(a.timestamp_utc || 0) - Date.parse(b.timestamp_utc || 0));
  const latest = chronological.at(-1);
  return Boolean(latest && validPackagedRun(latest));
}

/** Check a journey record and reject unsupported success claims. */
function verifyJourney(id, entry) {
  assert.ok(entry && typeof entry === 'object', `${id}: missing evidence row`);
  assert.ok(outcomes.has(entry.outcome), `${id}: invalid outcome`);
  assert.ok(levels.has(entry.evidence_level), `${id}: invalid evidence level`);
  assert.ok(Array.isArray(entry.runs), `${id}: runs must be an array`);
  if (entry.outcome === 'pass') {
    assert.equal(entry.evidence_level, 'P', `${id}: acceptance requires packaged real-provider evidence`);
    assert.ok(latestRunIsPass(entry), `${id}: latest run must be a reproducible P-level pass after any blocker`);
  }
  if (entry.outcome === 'unverified') assert.equal(entry.evidence_level, 'U');
}

test('Gate 0 ledger has all ten independent journey rows', () => {
  assert.equal(ledger.mission, 1667);
  assert.equal(ledger.gate, 0);
  assert.deepEqual(Object.keys(ledger.journeys).sort(), ids);
  for (const id of ids) verifyJourney(id, ledger.journeys[id]);
});

test('Gate 0 never declares accepted without seven packaged journey passes and a field trial', () => {
  verifyJourney('packaged_field_trial', ledger.packaged_field_trial);
  const trial = ledger.packaged_field_trial;
  const trialRun = [...trial.runs].sort((a, b) =>
    Date.parse(a.timestamp_utc || 0) - Date.parse(b.timestamp_utc || 0)).at(-1);
  const providers = ledger.required_real_providers;
  const providerCoverage = providers.every((provider) =>
    trialRun?.provider_results?.[provider]?.outcome === 'blocked' ||
    (trialRun?.provider_results?.[provider]?.outcome === 'pass' &&
      trialRun.provider_results[provider].evidence_level === 'P'));
  const accepted = ids.slice(0, 7).every((id) =>
    ledger.journeys[id].outcome === 'pass' && latestRunIsPass(ledger.journeys[id])) &&
    trial.outcome === 'pass' && latestRunIsPass(trial) &&
    Boolean(trialRun?.uninterrupted_d01_d07) &&
    Array.isArray(trialRun?.artifacts) && trialRun.artifacts.length > 0 &&
    Array.isArray(trialRun?.target_platforms) && trialRun.target_platforms.includes(trialRun.platform) &&
    providerCoverage;
  assert.equal(ledger.status === 'accepted', accepted, 'gate status must match P-level acceptance evidence');
});

test('provider coverage is explicit, not inferred from mock CI', () => {
  assert.deepEqual([...ledger.required_real_providers].sort(), ['claude', 'codex', 'opencode']);
});
